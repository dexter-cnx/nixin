from pathlib import Path

p = Path('crates/dextryx-frontend-api/src/import_operation.rs')
s = p.read_text()
s = s.replace('''        let duplicate = catalog
            .contains_source(&request.workplace_id, source)
            .unwrap_or(false);
        if duplicate {
''', '''        let duplicate = match catalog.contains_source(&request.workplace_id, source) {
            Ok(value) => value,
            Err(_) => {
                summary.processed += 1;
                summary.failed += 1;
                summary.failed_paths.push(source.clone());
                sink.emit(OperationEvent::Progress(OperationProgress {
                    operation_id: request.operation_id.clone(),
                    completed_units: summary.processed,
                    total_units: Some(total),
                    message: Some(format!("catalog_lookup_failed:{}", source.display())),
                }));
                continue;
            }
        };
        if duplicate {
''')
s = s.replace('''        let managed_root = request.managed_root.as_ref().expect("validated above");
        filesystem
            .create_dir_all(managed_root)
            .map_err(|_| ImportOneError::Failed)?;

''', '''        let managed_root = request.managed_root.as_ref().expect("validated above");
        if !filesystem.exists(managed_root) {
            return Err(ImportOneError::Failed);
        }

''')
s = s.replace('''        let final_path = managed_root.join(format!("{}{}", candidate.asset_id, extension));
        let temp_path = managed_root.join(format!("{}.part", candidate.asset_id));

        let _ = filesystem.remove_file(&temp_path);
        filesystem
            .copy(&candidate.source_path, &temp_path)
            .map_err(|_| ImportOneError::Failed)?;
''', '''        let final_path = managed_root.join(format!("{}{}", candidate.asset_id, extension));
        let temp_path = managed_root.join(format!("{}.part", candidate.asset_id));

        if filesystem.exists(&final_path) {
            return Err(ImportOneError::Failed);
        }

        let _ = filesystem.remove_file(&temp_path);
        if filesystem.copy(&candidate.source_path, &temp_path).is_err() {
            let _ = filesystem.remove_file(&temp_path);
            return Err(ImportOneError::Failed);
        }
''')
p.write_text(s)

p = Path('crates/dextryx-frontend-api/tests/import_operation.rs')
s = p.read_text()
s = s.replace('use std::fs;\n', 'use std::fs;\nuse std::io;\n')
s = s.replace('use dextryx_platform::StdFileSystem;', 'use dextryx_platform::{FileSystemPort, StdFileSystem};')
s = s.replace('''    saved: Vec<ImportedAssetDraft>,
    fail_save: bool,
''', '''    saved: Vec<ImportedAssetDraft>,
    fail_save: bool,
    fail_lookup: bool,
''')
s = s.replace('''    fn contains_source(&self, _workplace_id: &str, source_path: &Path) -> Result<bool, String> {
        Ok(self.known.contains(source_path))
    }
''', '''    fn contains_source(&self, _workplace_id: &str, source_path: &Path) -> Result<bool, String> {
        if self.fail_lookup {
            return Err("lookup failed".into());
        }
        Ok(self.known.contains(source_path))
    }
''')
s = s.replace('''    fs::create_dir_all(&root).unwrap();
    fs::write(&source, b"raw-bytes").unwrap();

    let mut catalog = FakeCatalog {
''', '''    fs::create_dir_all(&root).unwrap();
    fs::create_dir_all(&managed).unwrap();
    fs::write(&source, b"raw-bytes").unwrap();

    let mut catalog = FakeCatalog {
''', 1)
s += r'''

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
'''
p.write_text(s)

p = Path('rust/src/api.rs')
s = p.read_text()
s = s.replace('''fn rgba_to_rgb(rgba: &[u8]) -> Vec<u8> {
    rgba.chunks_exact(4)
        .flat_map(|p| [p[0], p[1], p[2]])
        .collect()
}
''', '''fn rgba_to_rgb(rgba: &[u8]) -> Vec<u8> {
    rgba.as_chunks::<4>()
        .0
        .iter()
        .flat_map(|p| [p[0], p[1], p[2]])
        .collect()
}
''')
p.write_text(s)
