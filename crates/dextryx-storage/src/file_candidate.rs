use std::ffi::OsStr;
use std::fs::{self, File, OpenOptions};
use std::io::{Cursor, ErrorKind, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

use dextryx_core::{
    validate_catalog_projection, AssetStorageMode, AuthoritativeCatalogPersistence,
    AuthoritativeCatalogProjection, CatalogAsset, CatalogInvariantError, CatalogMutation,
    CatalogMutationResult, CatalogReadRepository, CatalogRepositoryError,
    CatalogSnapshotRepository, WorkplaceSummary,
};

use crate::{CandidateCatalogStore, DurableAuthorityCapabilities};

const SNAPSHOT_MAGIC: &[u8; 8] = b"DXTRCAT1";
const MAX_FIELD_BYTES: usize = 16 * 1024 * 1024;
const MIN_WORKPLACE_RECORD_BYTES: usize = 8;
const MIN_ASSET_RECORD_BYTES: usize = 23;
const TEMP_FILE_ATTEMPTS: usize = 128;
static TEMP_FILE_SEQUENCE: AtomicU64 = AtomicU64::new(0);

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DiskCandidateError {
    Io(String),
    CorruptSnapshot(String),
    InvalidCatalog(CatalogInvariantError),
    Repository(CatalogRepositoryError),
    NonUtf8Path(PathBuf),
}

/// Disk-backed M4 qualification candidate.
///
/// This adapter intentionally does not implement `AuthoritativeCatalogPersistence` yet.
/// The current authoritative mutation trait cannot distinguish repository/domain
/// failures from disk durability failures. Keeping this adapter outside that trait
/// prevents an I/O failure from being hidden behind a domain error before the
/// production mutation error contract is extended explicitly.
pub struct DiskCandidateCatalogStore {
    path: PathBuf,
    projection: AuthoritativeCatalogProjection,
}

impl DiskCandidateCatalogStore {
    pub fn create(
        path: impl Into<PathBuf>,
        projection: AuthoritativeCatalogProjection,
    ) -> Result<Self, DiskCandidateError> {
        validate_catalog_projection(&projection).map_err(DiskCandidateError::InvalidCatalog)?;
        let path = path.into();
        persist_snapshot(&path, &projection)?;
        Ok(Self { path, projection })
    }

    pub fn open(path: impl Into<PathBuf>) -> Result<Self, DiskCandidateError> {
        let path = path.into();
        let bytes = fs::read(&path).map_err(io_error)?;
        let projection = decode_projection(&bytes)?;
        validate_catalog_projection(&projection).map_err(DiskCandidateError::InvalidCatalog)?;
        Ok(Self { path, projection })
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn projection(&self) -> &AuthoritativeCatalogProjection {
        &self.projection
    }

    /// Apply one mutation through the already-qualified in-memory semantics,
    /// persist the resulting full snapshot, then publish the new in-memory state.
    /// If persistence fails, the in-memory state remains unchanged.
    pub fn apply_candidate_mutation(
        &mut self,
        mutation: CatalogMutation,
    ) -> Result<CatalogMutationResult, DiskCandidateError> {
        let mut staged = CandidateCatalogStore::from_projection(self.projection.clone())
            .map_err(DiskCandidateError::InvalidCatalog)?;
        let result = staged
            .apply_mutation(mutation)
            .map_err(DiskCandidateError::Repository)?;
        let next = staged.projection().clone();
        persist_snapshot(&self.path, &next)?;
        self.projection = next;
        Ok(result)
    }

    /// Evidence currently demonstrated by this candidate's tests.
    /// Durability-related capabilities remain false until dedicated fault-injection
    /// and cross-platform filesystem semantics are proven.
    pub fn demonstrated_capabilities(&self) -> DurableAuthorityCapabilities {
        DurableAuthorityCapabilities {
            atomic_commit: false,
            crash_recovery: false,
            durable_flush: false,
            single_writer_enforced: false,
            rollback_supported: false,
            snapshot_round_trip_verified: true,
            mutation_parity_verified: true,
        }
    }
}

impl CatalogReadRepository for DiskCandidateCatalogStore {
    fn workplaces(&self) -> Vec<WorkplaceSummary> {
        self.projection.workplaces.clone()
    }

    fn active_workplace_id(&self) -> Option<&str> {
        self.projection.active_workplace_id.as_deref()
    }

    fn assets(&self, workplace_id: &str) -> Result<Vec<CatalogAsset>, CatalogRepositoryError> {
        if !self
            .projection
            .workplaces
            .iter()
            .any(|workplace| workplace.id == workplace_id)
        {
            return Err(CatalogRepositoryError::UnknownWorkplace(
                workplace_id.to_string(),
            ));
        }

        let mut assets: Vec<_> = self
            .projection
            .assets
            .iter()
            .filter(|asset| asset.workplace_id == workplace_id)
            .cloned()
            .collect();
        assets.sort_by(|left, right| {
            left.import_sequence
                .cmp(&right.import_sequence)
                .then_with(|| left.id.cmp(&right.id))
        });
        Ok(assets)
    }
}

impl CatalogSnapshotRepository for DiskCandidateCatalogStore {
    fn all_assets_for_snapshot(&self) -> Result<Vec<CatalogAsset>, CatalogRepositoryError> {
        Ok(self.projection.assets.clone())
    }
}

fn persist_snapshot(
    path: &Path,
    projection: &AuthoritativeCatalogProjection,
) -> Result<(), DiskCandidateError> {
    let bytes = encode_projection(projection)?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(io_error)?;
    }

    let (temp, mut file) = create_temp_snapshot_file(path)?;
    let write_result = (|| {
        file.write_all(&bytes).map_err(io_error)?;
        file.sync_all().map_err(io_error)?;
        Ok::<(), DiskCandidateError>(())
    })();
    drop(file);
    if let Err(error) = write_result {
        let _ = fs::remove_file(&temp);
        return Err(error);
    }

    // Cross-platform replacement semantics are intentionally not claimed atomic
    // in this qualification slice. The cutover capability remains false until a
    // production implementation proves the required filesystem guarantees.
    if path.exists() {
        if let Err(error) = fs::remove_file(path) {
            let _ = fs::remove_file(&temp);
            return Err(io_error(error));
        }
    }
    if let Err(error) = fs::rename(&temp, path) {
        let _ = fs::remove_file(&temp);
        return Err(io_error(error));
    }
    Ok(())
}

fn create_temp_snapshot_file(path: &Path) -> Result<(PathBuf, File), DiskCandidateError> {
    let parent = path.parent().unwrap_or_else(|| Path::new("."));
    let file_name = path.file_name().unwrap_or_else(|| OsStr::new("catalog"));

    for _ in 0..TEMP_FILE_ATTEMPTS {
        let sequence = TEMP_FILE_SEQUENCE.fetch_add(1, Ordering::Relaxed);
        let mut temp_name = file_name.to_os_string();
        temp_name.push(format!(".next-{}-{sequence}", std::process::id()));
        let temp = parent.join(temp_name);
        match OpenOptions::new().create_new(true).write(true).open(&temp) {
            Ok(file) => return Ok((temp, file)),
            Err(error) if error.kind() == ErrorKind::AlreadyExists => continue,
            Err(error) => return Err(io_error(error)),
        }
    }

    Err(DiskCandidateError::Io(
        "unable to allocate collision-safe temporary snapshot".to_string(),
    ))
}

fn encode_projection(
    projection: &AuthoritativeCatalogProjection,
) -> Result<Vec<u8>, DiskCandidateError> {
    validate_catalog_projection(projection).map_err(DiskCandidateError::InvalidCatalog)?;
    let mut output = Vec::new();
    output.extend_from_slice(SNAPSHOT_MAGIC);

    write_optional_string(&mut output, projection.active_workplace_id.as_deref())?;
    write_u32(&mut output, projection.workplaces.len())?;
    for workplace in &projection.workplaces {
        write_string(&mut output, &workplace.id)?;
        write_string(&mut output, &workplace.name)?;
    }

    write_u32(&mut output, projection.assets.len())?;
    for asset in &projection.assets {
        write_string(&mut output, &asset.id)?;
        write_string(&mut output, &asset.workplace_id)?;
        write_path(&mut output, &asset.source_path)?;
        match asset.managed_path.as_deref() {
            Some(path) => {
                output.push(1);
                write_path(&mut output, path)?;
            }
            None => output.push(0),
        }
        output.push(match asset.storage_mode {
            AssetStorageMode::Linked => 0,
            AssetStorageMode::Managed => 1,
        });
        output.push(u8::from(asset.missing));
        output.extend_from_slice(&asset.import_sequence.to_le_bytes());
    }

    Ok(output)
}

fn decode_projection(bytes: &[u8]) -> Result<AuthoritativeCatalogProjection, DiskCandidateError> {
    let mut input = Cursor::new(bytes);
    let mut magic = [0_u8; 8];
    input.read_exact(&mut magic).map_err(corrupt_io)?;
    if &magic != SNAPSHOT_MAGIC {
        return Err(DiskCandidateError::CorruptSnapshot(
            "invalid snapshot header".to_string(),
        ));
    }

    let active_workplace_id = read_optional_string(&mut input)?;
    let workplace_count = read_u32(&mut input)? as usize;
    validate_collection_count(
        &input,
        bytes.len(),
        workplace_count,
        MIN_WORKPLACE_RECORD_BYTES,
        "workplace",
    )?;
    let mut workplaces = Vec::new();
    workplaces.try_reserve(workplace_count).map_err(|_| {
        DiskCandidateError::CorruptSnapshot("workplace allocation exceeds limits".to_string())
    })?;
    for _ in 0..workplace_count {
        workplaces.push(WorkplaceSummary {
            id: read_string(&mut input)?,
            name: read_string(&mut input)?,
        });
    }

    let asset_count = read_u32(&mut input)? as usize;
    validate_collection_count(
        &input,
        bytes.len(),
        asset_count,
        MIN_ASSET_RECORD_BYTES,
        "asset",
    )?;
    let mut assets = Vec::new();
    assets.try_reserve(asset_count).map_err(|_| {
        DiskCandidateError::CorruptSnapshot("asset allocation exceeds limits".to_string())
    })?;
    for _ in 0..asset_count {
        let id = read_string(&mut input)?;
        let workplace_id = read_string(&mut input)?;
        let source_path = PathBuf::from(read_string(&mut input)?);
        let managed_path = match read_byte(&mut input)? {
            0 => None,
            1 => Some(PathBuf::from(read_string(&mut input)?)),
            value => {
                return Err(DiskCandidateError::CorruptSnapshot(format!(
                    "invalid managed-path marker {value}"
                )))
            }
        };
        let storage_mode = match read_byte(&mut input)? {
            0 => AssetStorageMode::Linked,
            1 => AssetStorageMode::Managed,
            value => {
                return Err(DiskCandidateError::CorruptSnapshot(format!(
                    "invalid storage mode {value}"
                )))
            }
        };
        let missing = match read_byte(&mut input)? {
            0 => false,
            1 => true,
            value => {
                return Err(DiskCandidateError::CorruptSnapshot(format!(
                    "invalid missing flag {value}"
                )))
            }
        };
        let mut sequence = [0_u8; 8];
        input.read_exact(&mut sequence).map_err(corrupt_io)?;
        assets.push(CatalogAsset {
            id,
            workplace_id,
            source_path,
            managed_path,
            storage_mode,
            missing,
            import_sequence: u64::from_le_bytes(sequence),
        });
    }

    if input.position() != bytes.len() as u64 {
        return Err(DiskCandidateError::CorruptSnapshot(
            "trailing snapshot bytes".to_string(),
        ));
    }

    Ok(AuthoritativeCatalogProjection {
        workplaces,
        active_workplace_id,
        assets,
    })
}

fn validate_collection_count(
    input: &Cursor<&[u8]>,
    total_bytes: usize,
    count: usize,
    min_record_bytes: usize,
    label: &str,
) -> Result<(), DiskCandidateError> {
    let position = usize::try_from(input.position()).unwrap_or(usize::MAX);
    let remaining = total_bytes.saturating_sub(position);
    if count > remaining / min_record_bytes {
        return Err(DiskCandidateError::CorruptSnapshot(format!(
            "{label} count exceeds remaining snapshot bytes"
        )));
    }
    Ok(())
}

fn write_optional_string(
    output: &mut Vec<u8>,
    value: Option<&str>,
) -> Result<(), DiskCandidateError> {
    match value {
        Some(value) => {
            output.push(1);
            write_string(output, value)
        }
        None => {
            output.push(0);
            Ok(())
        }
    }
}

fn read_optional_string(input: &mut Cursor<&[u8]>) -> Result<Option<String>, DiskCandidateError> {
    match read_byte(input)? {
        0 => Ok(None),
        1 => Ok(Some(read_string(input)?)),
        value => Err(DiskCandidateError::CorruptSnapshot(format!(
            "invalid optional-string marker {value}"
        ))),
    }
}

fn write_path(output: &mut Vec<u8>, path: &Path) -> Result<(), DiskCandidateError> {
    let value = path
        .to_str()
        .ok_or_else(|| DiskCandidateError::NonUtf8Path(path.to_path_buf()))?;
    write_string(output, value)
}

fn write_string(output: &mut Vec<u8>, value: &str) -> Result<(), DiskCandidateError> {
    let bytes = value.as_bytes();
    if bytes.len() > MAX_FIELD_BYTES || bytes.len() > u32::MAX as usize {
        return Err(DiskCandidateError::CorruptSnapshot(
            "field exceeds snapshot limit".to_string(),
        ));
    }
    write_u32(output, bytes.len())?;
    output.extend_from_slice(bytes);
    Ok(())
}

fn read_string(input: &mut Cursor<&[u8]>) -> Result<String, DiskCandidateError> {
    let len = read_u32(input)? as usize;
    if len > MAX_FIELD_BYTES {
        return Err(DiskCandidateError::CorruptSnapshot(
            "field exceeds snapshot limit".to_string(),
        ));
    }
    let mut bytes = vec![0_u8; len];
    input.read_exact(&mut bytes).map_err(corrupt_io)?;
    String::from_utf8(bytes)
        .map_err(|_| DiskCandidateError::CorruptSnapshot("invalid UTF-8 field".to_string()))
}

fn write_u32(output: &mut Vec<u8>, value: usize) -> Result<(), DiskCandidateError> {
    let value = u32::try_from(value).map_err(|_| {
        DiskCandidateError::CorruptSnapshot("collection exceeds snapshot limit".to_string())
    })?;
    output.extend_from_slice(&value.to_le_bytes());
    Ok(())
}

fn read_u32(input: &mut Cursor<&[u8]>) -> Result<u32, DiskCandidateError> {
    let mut bytes = [0_u8; 4];
    input.read_exact(&mut bytes).map_err(corrupt_io)?;
    Ok(u32::from_le_bytes(bytes))
}

fn read_byte(input: &mut Cursor<&[u8]>) -> Result<u8, DiskCandidateError> {
    let mut byte = [0_u8; 1];
    input.read_exact(&mut byte).map_err(corrupt_io)?;
    Ok(byte[0])
}

fn io_error(error: std::io::Error) -> DiskCandidateError {
    DiskCandidateError::Io(error.to_string())
}

fn corrupt_io(error: std::io::Error) -> DiskCandidateError {
    DiskCandidateError::CorruptSnapshot(error.to_string())
}

#[cfg(test)]
mod tests {
    use std::time::{SystemTime, UNIX_EPOCH};

    use super::*;
    use dextryx_core::{snapshot_catalog_repository, AssetStorageMode};

    fn fixture_projection() -> AuthoritativeCatalogProjection {
        AuthoritativeCatalogProjection {
            workplaces: vec![
                WorkplaceSummary {
                    id: "workplace-my".to_string(),
                    name: "My workplace".to_string(),
                },
                WorkplaceSummary {
                    id: "workplace-travel".to_string(),
                    name: "Travel".to_string(),
                },
            ],
            active_workplace_id: Some("workplace-travel".to_string()),
            assets: vec![CatalogAsset {
                id: "asset-1".to_string(),
                workplace_id: "workplace-travel".to_string(),
                source_path: PathBuf::from("/external/image.jpg"),
                managed_path: None,
                storage_mode: AssetStorageMode::Linked,
                missing: true,
                import_sequence: 1,
            }],
        }
    }

    fn temp_snapshot_path(test_name: &str) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir()
            .join("dextryx-images-storage-tests")
            .join(format!(
                "{test_name}-{}-{nonce}.catalog",
                std::process::id()
            ))
    }

    #[test]
    fn snapshot_round_trip_survives_reopen() {
        let path = temp_snapshot_path("round-trip");
        let expected = fixture_projection();
        let store = DiskCandidateCatalogStore::create(&path, expected.clone()).unwrap();
        assert_eq!(
            snapshot_catalog_repository(&store).unwrap(),
            expected,
            "created candidate must expose source semantics"
        );
        drop(store);

        let reopened = DiskCandidateCatalogStore::open(&path).unwrap();
        assert_eq!(snapshot_catalog_repository(&reopened).unwrap(), expected);
        assert!(!reopened.demonstrated_capabilities().is_cutover_ready());
        let _ = fs::remove_file(path);
    }

    #[test]
    fn mutation_state_survives_process_style_reopen() {
        let path = temp_snapshot_path("mutation-reopen");
        let mut store = DiskCandidateCatalogStore::create(&path, fixture_projection()).unwrap();
        store
            .apply_candidate_mutation(CatalogMutation::SetActiveWorkplace {
                workplace_id: "workplace-my".to_string(),
            })
            .unwrap();
        store
            .apply_candidate_mutation(CatalogMutation::RelinkAsset {
                asset_id: "asset-1".to_string(),
                replacement_path: PathBuf::from("/replacement/image.jpg"),
            })
            .unwrap();
        drop(store);

        let reopened = DiskCandidateCatalogStore::open(&path).unwrap();
        assert_eq!(reopened.active_workplace_id(), Some("workplace-my"));
        let asset = reopened.assets("workplace-travel").unwrap().remove(0);
        assert_eq!(asset.source_path, PathBuf::from("/replacement/image.jpg"));
        assert!(!asset.missing);
        let _ = fs::remove_file(path);
    }

    #[test]
    fn destination_ending_in_next_and_existing_sibling_are_safe() {
        let path = temp_snapshot_path("temp-collision").with_extension("next");
        let sibling = path.with_extension("catalog.next");
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(&sibling, b"unrelated").unwrap();

        let expected = fixture_projection();
        DiskCandidateCatalogStore::create(&path, expected.clone()).unwrap();
        let reopened = DiskCandidateCatalogStore::open(&path).unwrap();
        assert_eq!(snapshot_catalog_repository(&reopened).unwrap(), expected);
        assert_eq!(fs::read(&sibling).unwrap(), b"unrelated");

        let _ = fs::remove_file(path);
        let _ = fs::remove_file(sibling);
    }

    #[test]
    fn oversized_workplace_count_is_rejected_before_allocation() {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(SNAPSHOT_MAGIC);
        bytes.push(0);
        bytes.extend_from_slice(&u32::MAX.to_le_bytes());

        assert!(matches!(
            decode_projection(&bytes),
            Err(DiskCandidateError::CorruptSnapshot(_))
        ));
    }

    #[test]
    fn oversized_asset_count_is_rejected_before_allocation() {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(SNAPSHOT_MAGIC);
        bytes.push(0);
        bytes.extend_from_slice(&0_u32.to_le_bytes());
        bytes.extend_from_slice(&u32::MAX.to_le_bytes());

        assert!(matches!(
            decode_projection(&bytes),
            Err(DiskCandidateError::CorruptSnapshot(_))
        ));
    }

    #[test]
    fn corrupt_snapshot_is_rejected() {
        let path = temp_snapshot_path("corrupt");
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(&path, b"not-a-catalog").unwrap();
        assert!(matches!(
            DiskCandidateCatalogStore::open(&path),
            Err(DiskCandidateError::CorruptSnapshot(_))
        ));
        let _ = fs::remove_file(path);
    }
}
