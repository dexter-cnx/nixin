use std::collections::HashSet;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use dextryx_frontend_api::{
    execute_import, CancellationToken, ImportCandidate, ImportCatalogPort, ImportExecutionRequest,
    ImportStorageMode, ImportedAssetDraft, OperationEvent,
};
use dextryx_platform::{FileSystemPort, StdFileSystem};

#[derive(Default)]
struct FakeCatalog {
    known: HashSet<PathBuf>,
    saved: Vec<ImportedAssetDraft>,
    fail_save: bool,
    fail_lookup: bool,
}

impl ImportCatalogPort for FakeCatalog {
    fn contains_source(&self, _workplace_id: &str, source_path: &Path) -> Result<bool, String> {
        if self.fail_lookup {
            return Err("lookup failed".into());
        }
        Ok(self.known.contains(source_path))
    }

    fn save_imported_asset(&mut self, asset: ImportedAssetDraft) -> Result<(), String> {
        if self.fail_save {
            return Err("save failed".into());
        }
        self.known.insert(asset.source_path.clone());
        self.saved.push(asset);
        Ok(())
    }
}

fn temp_root(label: &str) -> PathBuf {
    std::env::temp_dir().join(format!("dextryx-import-{label}-{}", std::process::id()))
}

#[test]
fn linked_import_skips_known_source_and_reports_progress() {
    let root = temp_root("linked");
    let _ = fs::remove_dir_all(&root);
    fs::create_dir_all(&root).unwrap();
    let first = root.join("first.jpg");
    let second = root.join("second.jpg");
    fs::write(&first, b"first").unwrap();
    fs::write(&second, b"second").unwrap();

    let mut catalog = FakeCatalog::default();
    catalog.known.insert(first.clone());
    let mut events = Vec::new();
    let mut sink = |event| events.push(event);
    let request = ImportExecutionRequest {
        operation_id: "import-linked".into(),
        workplace_id: "workplace-my".into(),
        storage_mode: ImportStorageMode::Linked,
        managed_root: None,
        candidates: vec![
            ImportCandidate {
                asset_id: "asset-1".into(),
                source_path: first,
            },
            ImportCandidate {
                asset_id: "asset-2".into(),
                source_path: second.clone(),
            },
        ],
    };

    let summary = execute_import(
        &request,
        &StdFileSystem,
        &mut catalog,
        &CancellationToken::new(),
        &mut sink,
    );

    assert_eq!(summary.processed, 2);
    assert_eq!(summary.skipped_duplicates, 1);
    assert_eq!(summary.imported, 1);
    assert_eq!(catalog.saved.len(), 1);
    assert_eq!(catalog.saved[0].source_path, second);
    assert!(matches!(
        events.last(),
        Some(OperationEvent::Completed { .. })
    ));
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn managed_copy_is_removed_when_catalog_save_fails() {
    let root = temp_root("rollback");
    let managed = root.join("managed");
    let source = root.join("source.nef");
    let _ = fs::remove_dir_all(&root);
    fs::create_dir_all(&root).unwrap();
    fs::create_dir_all(&managed).unwrap();
    fs::write(&source, b"raw-bytes").unwrap();

    let mut catalog = FakeCatalog {
        fail_save: true,
        ..Default::default()
    };
    let mut events = Vec::new();
    let mut sink = |event| events.push(event);
    let request = ImportExecutionRequest {
        operation_id: "import-managed".into(),
        workplace_id: "workplace-my".into(),
        storage_mode: ImportStorageMode::Managed,
        managed_root: Some(managed.clone()),
        candidates: vec![ImportCandidate {
            asset_id: "asset-managed".into(),
            source_path: source,
        }],
    };

    let summary = execute_import(
        &request,
        &StdFileSystem,
        &mut catalog,
        &CancellationToken::new(),
        &mut sink,
    );

    assert_eq!(summary.failed, 1);
    assert_eq!(summary.imported, 0);
    assert!(!managed.join("asset-managed.nef").exists());
    assert!(!managed.join("asset-managed.part").exists());
    assert!(matches!(events.last(), Some(OperationEvent::Failed(_))));
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn cancelled_operation_stops_before_mutating_catalog_or_filesystem() {
    let root = temp_root("cancel");
    let managed = root.join("managed");
    let source = root.join("source.cr3");
    let _ = fs::remove_dir_all(&root);
    fs::create_dir_all(&root).unwrap();
    fs::write(&source, b"raw").unwrap();

    let token = CancellationToken::new();
    token.cancel();
    let mut catalog = FakeCatalog::default();
    let mut events = Vec::new();
    let mut sink = |event| events.push(event);
    let request = ImportExecutionRequest {
        operation_id: "import-cancel".into(),
        workplace_id: "workplace-my".into(),
        storage_mode: ImportStorageMode::Managed,
        managed_root: Some(managed.clone()),
        candidates: vec![ImportCandidate {
            asset_id: "asset-cancel".into(),
            source_path: source,
        }],
    };

    let summary = execute_import(&request, &StdFileSystem, &mut catalog, &token, &mut sink);

    assert!(summary.cancelled);
    assert_eq!(summary.processed, 0);
    assert!(catalog.saved.is_empty());
    assert!(!managed.exists());
    assert!(matches!(
        events.last(),
        Some(OperationEvent::Cancelled { .. })
    ));
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn managed_import_refuses_missing_root_without_recreating_it() {
    let root = temp_root("missing-root");
    let managed = root.join("disconnected-volume");
    let source = root.join("source.nef");
    let _ = fs::remove_dir_all(&root);
    fs::create_dir_all(&root).unwrap();
    fs::write(&source, b"raw-bytes").unwrap();

    let mut catalog = FakeCatalog::default();
    let mut events = Vec::new();
    let mut sink = |event| events.push(event);
    let request = ImportExecutionRequest {
        operation_id: "import-missing-root".into(),
        workplace_id: "workplace-my".into(),
        storage_mode: ImportStorageMode::Managed,
        managed_root: Some(managed.clone()),
        candidates: vec![ImportCandidate {
            asset_id: "asset-missing-root".into(),
            source_path: source,
        }],
    };

    let summary = execute_import(
        &request,
        &StdFileSystem,
        &mut catalog,
        &CancellationToken::new(),
        &mut sink,
    );

    assert_eq!(summary.failed, 1);
    assert_eq!(summary.imported, 0);
    assert!(!managed.exists());
    assert!(catalog.saved.is_empty());
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn managed_import_never_overwrites_existing_destination() {
    let root = temp_root("collision");
    let managed = root.join("managed");
    let source = root.join("source.nef");
    let destination = managed.join("asset-collision.nef");
    let _ = fs::remove_dir_all(&root);
    fs::create_dir_all(&managed).unwrap();
    fs::write(&source, b"new-original").unwrap();
    fs::write(&destination, b"existing-original").unwrap();

    let mut catalog = FakeCatalog::default();
    let mut events = Vec::new();
    let mut sink = |event| events.push(event);
    let request = ImportExecutionRequest {
        operation_id: "import-collision".into(),
        workplace_id: "workplace-my".into(),
        storage_mode: ImportStorageMode::Managed,
        managed_root: Some(managed.clone()),
        candidates: vec![ImportCandidate {
            asset_id: "asset-collision".into(),
            source_path: source,
        }],
    };

    let summary = execute_import(
        &request,
        &StdFileSystem,
        &mut catalog,
        &CancellationToken::new(),
        &mut sink,
    );

    assert_eq!(summary.failed, 1);
    assert_eq!(fs::read(&destination).unwrap(), b"existing-original");
    assert!(!managed.join("asset-collision.part").exists());
    assert!(catalog.saved.is_empty());
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn duplicate_lookup_error_fails_item_without_mutation() {
    let root = temp_root("lookup-error");
    let source = root.join("source.jpg");
    let _ = fs::remove_dir_all(&root);
    fs::create_dir_all(&root).unwrap();
    fs::write(&source, b"image").unwrap();

    let mut catalog = FakeCatalog {
        fail_lookup: true,
        ..Default::default()
    };
    let mut events = Vec::new();
    let mut sink = |event| events.push(event);
    let request = ImportExecutionRequest {
        operation_id: "import-lookup-error".into(),
        workplace_id: "workplace-my".into(),
        storage_mode: ImportStorageMode::Linked,
        managed_root: None,
        candidates: vec![ImportCandidate {
            asset_id: "asset-lookup-error".into(),
            source_path: source.clone(),
        }],
    };

    let summary = execute_import(
        &request,
        &StdFileSystem,
        &mut catalog,
        &CancellationToken::new(),
        &mut sink,
    );

    assert_eq!(summary.processed, 1);
    assert_eq!(summary.failed, 1);
    assert_eq!(summary.imported, 0);
    assert_eq!(summary.failed_paths, vec![source]);
    assert!(catalog.saved.is_empty());
    assert!(matches!(events.last(), Some(OperationEvent::Failed(_))));
    fs::remove_dir_all(root).unwrap();
}

struct PartialCopyFileSystem;

impl FileSystemPort for PartialCopyFileSystem {
    fn exists(&self, path: &Path) -> bool {
        StdFileSystem.exists(path)
    }

    fn is_file(&self, path: &Path) -> io::Result<bool> {
        StdFileSystem.is_file(path)
    }

    fn metadata_len(&self, path: &Path) -> io::Result<u64> {
        StdFileSystem.metadata_len(path)
    }

    fn create_dir_all(&self, path: &Path) -> io::Result<()> {
        StdFileSystem.create_dir_all(path)
    }

    fn copy(&self, _from: &Path, to: &Path) -> io::Result<u64> {
        fs::write(to, b"partial")?;
        Err(io::Error::other("simulated copy failure"))
    }

    fn remove_file(&self, path: &Path) -> io::Result<()> {
        StdFileSystem.remove_file(path)
    }

    fn rename(&self, from: &Path, to: &Path) -> io::Result<()> {
        StdFileSystem.rename(from, to)
    }
}

#[test]
fn managed_copy_failure_removes_partial_staging_file() {
    let root = temp_root("partial-copy");
    let managed = root.join("managed");
    let source = root.join("source.cr3");
    let _ = fs::remove_dir_all(&root);
    fs::create_dir_all(&managed).unwrap();
    fs::write(&source, b"raw").unwrap();

    let mut catalog = FakeCatalog::default();
    let mut events = Vec::new();
    let mut sink = |event| events.push(event);
    let request = ImportExecutionRequest {
        operation_id: "import-partial-copy".into(),
        workplace_id: "workplace-my".into(),
        storage_mode: ImportStorageMode::Managed,
        managed_root: Some(managed.clone()),
        candidates: vec![ImportCandidate {
            asset_id: "asset-partial".into(),
            source_path: source,
        }],
    };

    let summary = execute_import(
        &request,
        &PartialCopyFileSystem,
        &mut catalog,
        &CancellationToken::new(),
        &mut sink,
    );

    assert_eq!(summary.failed, 1);
    assert!(!managed.join("asset-partial.part").exists());
    assert!(!managed.join("asset-partial.cr3").exists());
    assert!(catalog.saved.is_empty());
    fs::remove_dir_all(root).unwrap();
}
