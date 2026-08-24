use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};

use dextryx_frontend_api::{
    execute_import, CancellationToken, ImportCandidate, ImportCatalogPort, ImportExecutionRequest,
    ImportStorageMode, ImportedAssetDraft, OperationEvent,
};
use dextryx_platform::StdFileSystem;

#[derive(Default)]
struct FakeCatalog {
    known: HashSet<PathBuf>,
    saved: Vec<ImportedAssetDraft>,
    fail_save: bool,
}

impl ImportCatalogPort for FakeCatalog {
    fn contains_source(&self, _workplace_id: &str, source_path: &Path) -> Result<bool, String> {
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
    std::env::temp_dir().join(format!(
        "dextryx-import-{label}-{}",
        std::process::id()
    ))
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
    assert!(matches!(events.last(), Some(OperationEvent::Completed { .. })));
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn managed_copy_is_removed_when_catalog_save_fails() {
    let root = temp_root("rollback");
    let managed = root.join("managed");
    let source = root.join("source.nef");
    let _ = fs::remove_dir_all(&root);
    fs::create_dir_all(&root).unwrap();
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

    let summary = execute_import(
        &request,
        &StdFileSystem,
        &mut catalog,
        &token,
        &mut sink,
    );

    assert!(summary.cancelled);
    assert_eq!(summary.processed, 0);
    assert!(catalog.saved.is_empty());
    assert!(!managed.exists());
    assert!(matches!(events.last(), Some(OperationEvent::Cancelled { .. })));
    fs::remove_dir_all(root).unwrap();
}
