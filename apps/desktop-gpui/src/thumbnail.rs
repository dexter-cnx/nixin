use std::collections::hash_map::DefaultHasher;
use std::collections::HashSet;
use std::fs;
use std::hash::{Hash, Hasher};
use std::ops::Range;
use std::path::{Path, PathBuf};
use std::time::UNIX_EPOCH;

#[cfg(target_os = "macos")]
use std::process::Command;

use dextryx_frontend_api::AssetSummaryDto;

pub const MAX_THUMBNAIL_WORKING_SET: usize = 64;
const MAX_THUMBNAIL_GENERATION_ATTEMPTS_PER_SYNC: usize = 2;
const THUMBNAIL_MAX_EDGE: u32 = 320;
const MAX_THUMBNAIL_CACHE_ENTRIES: usize = 2_048;
const MAX_THUMBNAIL_CACHE_BYTES: u64 = 512 * 1024 * 1024;

const SUPPORTED_RASTER_EXTENSIONS: &[&str] =
    &["jpg", "jpeg", "png", "gif", "webp", "tif", "tiff", "bmp"];

#[derive(Clone, Debug, Default)]
pub struct ThumbnailWorkingSet {
    asset_ids: HashSet<String>,
    cache_maintenance_done: bool,
}

impl ThumbnailWorkingSet {
    pub fn sync(
        &mut self,
        assets: &[AssetSummaryDto],
        grid_range: Range<usize>,
        filmstrip_range: Range<usize>,
        selected_asset_id: Option<&str>,
    ) {
        self.asset_ids.clear();
        let mut ordered_ids = Vec::new();

        if let Some(selected_asset_id) = selected_asset_id {
            if self.insert(selected_asset_id) {
                ordered_ids.push(selected_asset_id.to_string());
            }
        }

        for index in grid_range.chain(filmstrip_range) {
            if self.asset_ids.len() >= MAX_THUMBNAIL_WORKING_SET {
                break;
            }
            if let Some(asset) = assets.get(index) {
                if self.insert(&asset.id) {
                    ordered_ids.push(asset.id.clone());
                }
            }
        }

        let mut attempts = 0;
        let mut generated_any = false;
        for asset_id in ordered_ids {
            if attempts >= MAX_THUMBNAIL_GENERATION_ATTEMPTS_PER_SYNC {
                break;
            }
            let Some(asset) = assets.iter().find(|asset| asset.id == asset_id) else {
                continue;
            };
            if asset.missing || !is_supported_raster(asset) || thumbnail_exists(asset) {
                continue;
            }
            attempts += 1;
            if prepare_thumbnail(asset).is_ok() {
                generated_any = true;
            }
        }

        if generated_any || !self.cache_maintenance_done {
            let _ = prune_thumbnail_cache(
                &cache_root(),
                MAX_THUMBNAIL_CACHE_ENTRIES,
                MAX_THUMBNAIL_CACHE_BYTES,
            );
            self.cache_maintenance_done = true;
        }
    }

    pub fn thumbnail_path(&self, asset: &AssetSummaryDto) -> Option<PathBuf> {
        if asset.missing || !self.asset_ids.contains(&asset.id) || !is_supported_raster(asset) {
            return None;
        }

        let path = cache_path(asset)?;
        path.is_file().then_some(path)
    }

    #[cfg(test)]
    fn len(&self) -> usize {
        self.asset_ids.len()
    }

    fn insert(&mut self, asset_id: &str) -> bool {
        if self.asset_ids.len() >= MAX_THUMBNAIL_WORKING_SET {
            return false;
        }
        self.asset_ids.insert(asset_id.to_string())
    }
}

fn is_supported_raster(asset: &AssetSummaryDto) -> bool {
    asset
        .effective_path
        .extension()
        .and_then(|extension| extension.to_str())
        .map(|extension| extension.to_ascii_lowercase())
        .is_some_and(|extension| SUPPORTED_RASTER_EXTENSIONS.contains(&extension.as_str()))
}

fn thumbnail_exists(asset: &AssetSummaryDto) -> bool {
    cache_path(asset).is_some_and(|path| path.is_file())
}

#[cfg(target_os = "macos")]
fn prepare_thumbnail(asset: &AssetSummaryDto) -> Result<(), String> {
    let Some(cache_path) = cache_path(asset) else {
        return Ok(());
    };
    let Some(parent) = cache_path.parent() else {
        return Ok(());
    };
    fs::create_dir_all(parent).map_err(|error| error.to_string())?;

    let partial = cache_path.with_extension("partial.png");
    let status = Command::new("/usr/bin/sips")
        .arg("-Z")
        .arg(THUMBNAIL_MAX_EDGE.to_string())
        .arg("-s")
        .arg("format")
        .arg("png")
        .arg(&asset.effective_path)
        .arg("--out")
        .arg(&partial)
        .status()
        .map_err(|error| error.to_string())?;

    if !status.success() {
        let _ = fs::remove_file(&partial);
        return Err(format!("sips failed with status {status}"));
    }

    fs::rename(&partial, &cache_path).map_err(|error| error.to_string())?;
    remove_stale_versions(asset, parent, &cache_path).map_err(|error| error.to_string())?;
    Ok(())
}

#[cfg(not(target_os = "macos"))]
fn prepare_thumbnail(_asset: &AssetSummaryDto) -> Result<(), String> {
    Ok(())
}

fn cache_root() -> PathBuf {
    std::env::temp_dir()
        .join("dextryx-images")
        .join("thumbnails-v1")
}

fn cache_path(asset: &AssetSummaryDto) -> Option<PathBuf> {
    if !is_supported_raster(asset) {
        return None;
    }

    let asset_key = asset_cache_key(&asset.id);
    let version_key = source_version_key(asset);
    Some(cache_root().join(format!("{asset_key:016x}-{version_key:016x}.png")))
}

fn asset_cache_key(asset_id: &str) -> u64 {
    let mut hasher = DefaultHasher::new();
    asset_id.hash(&mut hasher);
    hasher.finish()
}

fn source_version_key(asset: &AssetSummaryDto) -> u64 {
    let metadata = fs::metadata(&asset.effective_path).ok();
    let mut hasher = DefaultHasher::new();
    asset.effective_path.hash(&mut hasher);
    if let Some(metadata) = metadata {
        metadata.len().hash(&mut hasher);
        if let Ok(modified) = metadata.modified() {
            modified
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_nanos()
                .hash(&mut hasher);
        }
    }
    hasher.finish()
}

fn remove_stale_versions(
    asset: &AssetSummaryDto,
    directory: &Path,
    keep_path: &Path,
) -> std::io::Result<()> {
    let prefix = format!("{:016x}-", asset_cache_key(&asset.id));
    let keep_name = keep_path.file_name();

    for entry in fs::read_dir(directory)? {
        let entry = match entry {
            Ok(entry) => entry,
            Err(_) => continue,
        };
        let path = entry.path();
        let Some(name) = path.file_name().and_then(|name| name.to_str()) else {
            continue;
        };
        if !name.starts_with(&prefix) || path.file_name() == keep_name || name.contains(".partial.") {
            continue;
        }
        let _ = fs::remove_file(path);
    }
    Ok(())
}

#[derive(Debug)]
struct CacheEntry {
    path: PathBuf,
    size: u64,
    modified_nanos: u128,
}

fn prune_thumbnail_cache(
    directory: &Path,
    max_entries: usize,
    max_bytes: u64,
) -> std::io::Result<()> {
    if !directory.is_dir() {
        return Ok(());
    }

    let mut entries = Vec::new();
    for entry in fs::read_dir(directory)? {
        let entry = match entry {
            Ok(entry) => entry,
            Err(_) => continue,
        };
        let path = entry.path();
        let Some(name) = path.file_name().and_then(|name| name.to_str()) else {
            continue;
        };
        if path.extension().and_then(|extension| extension.to_str()) != Some("png")
            || name.contains(".partial.")
        {
            continue;
        }
        let metadata = match entry.metadata() {
            Ok(metadata) if metadata.is_file() => metadata,
            _ => continue,
        };
        let modified_nanos = metadata
            .modified()
            .ok()
            .and_then(|modified| modified.duration_since(UNIX_EPOCH).ok())
            .map(|duration| duration.as_nanos())
            .unwrap_or_default();
        entries.push(CacheEntry {
            path,
            size: metadata.len(),
            modified_nanos,
        });
    }

    entries.sort_by_key(|entry| entry.modified_nanos);
    let mut entry_count = entries.len();
    let mut byte_count = entries.iter().map(|entry| entry.size).sum::<u64>();

    for entry in entries {
        if entry_count <= max_entries && byte_count <= max_bytes {
            break;
        }
        if fs::remove_file(&entry.path).is_ok() {
            entry_count = entry_count.saturating_sub(1);
            byte_count = byte_count.saturating_sub(entry.size);
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use dextryx_frontend_api::AssetStorageDto;

    fn asset(index: usize, extension: &str) -> AssetSummaryDto {
        AssetSummaryDto {
            id: format!("asset-{index}"),
            workplace_id: "workplace-1".to_string(),
            effective_path: PathBuf::from(format!("/tmp/{index}.{extension}")),
            storage: AssetStorageDto::Linked,
            missing: false,
            import_sequence: index as u64,
        }
    }

    fn temp_test_dir(name: &str) -> PathBuf {
        let path = std::env::temp_dir().join(format!(
            "nixin-thumbnail-{name}-{}-{}",
            std::process::id(),
            std::thread::current().name().unwrap_or("test")
        ));
        let _ = fs::remove_dir_all(&path);
        fs::create_dir_all(&path).unwrap();
        path
    }

    #[test]
    fn working_set_is_bounded_and_keeps_selection() {
        let assets = (0..200)
            .map(|index| asset(index, "jpg"))
            .collect::<Vec<_>>();
        let mut working_set = ThumbnailWorkingSet::default();

        working_set.sync(&assets, 0..100, 100..150, Some("asset-199"));

        assert_eq!(working_set.len(), MAX_THUMBNAIL_WORKING_SET);
        assert!(working_set.asset_ids.contains("asset-199"));
    }

    #[test]
    fn raw_and_missing_assets_never_get_thumbnail_paths() {
        let raw = asset(2, "nef");
        let mut missing = asset(3, "png");
        missing.missing = true;
        let assets = vec![raw.clone(), missing.clone()];
        let mut working_set = ThumbnailWorkingSet::default();

        working_set.sync(&assets, 0..2, 0..0, None);

        assert!(working_set.thumbnail_path(&raw).is_none());
        assert!(working_set.thumbnail_path(&missing).is_none());
    }

    #[test]
    fn cache_path_is_stable_for_same_asset() {
        let raster = asset(1, "jpg");
        assert_eq!(cache_path(&raster), cache_path(&raster));
    }

    #[test]
    fn cache_path_separates_assets_with_same_source_path() {
        let first = asset(1, "jpg");
        let mut second = asset(2, "jpg");
        second.effective_path = first.effective_path.clone();

        assert_ne!(cache_path(&first), cache_path(&second));
    }

    #[test]
    fn stale_versions_are_removed_for_same_asset() {
        let directory = temp_test_dir("stale");
        let raster = asset(7, "jpg");
        let prefix = format!("{:016x}-", asset_cache_key(&raster.id));
        let keep = directory.join(format!("{prefix}new.png"));
        let stale = directory.join(format!("{prefix}old.png"));
        let other = directory.join("ffffffffffffffff-other.png");
        fs::write(&keep, b"keep").unwrap();
        fs::write(&stale, b"stale").unwrap();
        fs::write(&other, b"other").unwrap();

        remove_stale_versions(&raster, &directory, &keep).unwrap();

        assert!(keep.is_file());
        assert!(!stale.exists());
        assert!(other.is_file());
        let _ = fs::remove_dir_all(directory);
    }

    #[test]
    fn prune_enforces_entry_and_byte_limits() {
        let directory = temp_test_dir("prune");
        for index in 0..5 {
            fs::write(directory.join(format!("{index}.png")), vec![index as u8; 16]).unwrap();
        }
        fs::write(directory.join("ignored.partial.png"), vec![0_u8; 128]).unwrap();

        prune_thumbnail_cache(&directory, 3, 48).unwrap();

        let regular_count = fs::read_dir(&directory)
            .unwrap()
            .filter_map(Result::ok)
            .filter(|entry| {
                entry
                    .file_name()
                    .to_str()
                    .is_some_and(|name| name.ends_with(".png") && !name.contains(".partial."))
            })
            .count();
        assert_eq!(regular_count, 3);
        assert!(directory.join("ignored.partial.png").is_file());
        let _ = fs::remove_dir_all(directory);
    }
}
