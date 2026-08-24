use std::path::{Path, PathBuf};

use dextryx_platform::FileSystemPort;

use crate::{
    CancellationToken, OperationEvent, OperationEventSink, OperationFailure, OperationKind,
    OperationProgress, OperationStarted,
};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ImportStorageMode {
    Linked,
    Managed,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ImportCandidate {
    pub asset_id: String,
    pub source_path: PathBuf,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ImportExecutionRequest {
    pub operation_id: String,
    pub workplace_id: String,
    pub storage_mode: ImportStorageMode,
    pub managed_root: Option<PathBuf>,
    pub candidates: Vec<ImportCandidate>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ImportedAssetDraft {
    pub asset_id: String,
    pub workplace_id: String,
    pub source_path: PathBuf,
    pub managed_path: Option<PathBuf>,
    pub file_size: u64,
}

pub trait ImportCatalogPort {
    fn contains_source(&self, workplace_id: &str, source_path: &Path) -> Result<bool, String>;
    fn save_imported_asset(&mut self, asset: ImportedAssetDraft) -> Result<(), String>;
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct ImportExecutionSummary {
    pub processed: u64,
    pub imported: u64,
    pub skipped_duplicates: u64,
    pub failed: u64,
    pub cancelled: bool,
    pub failed_paths: Vec<PathBuf>,
}

pub fn execute_import<F, C, S>(
    request: &ImportExecutionRequest,
    filesystem: &F,
    catalog: &mut C,
    cancellation: &CancellationToken,
    sink: &mut S,
) -> ImportExecutionSummary
where
    F: FileSystemPort,
    C: ImportCatalogPort,
    S: OperationEventSink,
{
    let total = request.candidates.len() as u64;
    sink.emit(OperationEvent::Started(OperationStarted {
        operation_id: request.operation_id.clone(),
        kind: OperationKind::Import,
        total_units: Some(total),
    }));

    let mut summary = ImportExecutionSummary::default();

    if request.storage_mode == ImportStorageMode::Managed && request.managed_root.is_none() {
        sink.emit(OperationEvent::Failed(OperationFailure {
            operation_id: request.operation_id.clone(),
            code: "managed_root_missing".into(),
            message: "Managed originals location is unavailable".into(),
            recoverable: true,
        }));
        summary.failed = total;
        summary.failed_paths = request
            .candidates
            .iter()
            .map(|candidate| candidate.source_path.clone())
            .collect();
        return summary;
    }

    for candidate in &request.candidates {
        if cancellation.is_cancelled() {
            summary.cancelled = true;
            sink.emit(OperationEvent::Cancelled {
                operation_id: request.operation_id.clone(),
            });
            return summary;
        }

        let source = &candidate.source_path;
        let duplicate = match catalog.contains_source(&request.workplace_id, source) {
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
            summary.processed += 1;
            summary.skipped_duplicates += 1;
            sink.emit(OperationEvent::Progress(OperationProgress {
                operation_id: request.operation_id.clone(),
                completed_units: summary.processed,
                total_units: Some(total),
                message: Some(format!("duplicate:{}", source.display())),
            }));
            continue;
        }

        let result = import_one(request, candidate, filesystem, catalog, cancellation);
        summary.processed += 1;
        match result {
            Ok(()) => {
                summary.imported += 1;
                sink.emit(OperationEvent::ItemCompleted {
                    operation_id: request.operation_id.clone(),
                    item_id: candidate.asset_id.clone(),
                });
            }
            Err(ImportOneError::Cancelled) => {
                summary.cancelled = true;
                sink.emit(OperationEvent::Cancelled {
                    operation_id: request.operation_id.clone(),
                });
                return summary;
            }
            Err(ImportOneError::Failed) => {
                summary.failed += 1;
                summary.failed_paths.push(source.clone());
            }
        }

        sink.emit(OperationEvent::Progress(OperationProgress {
            operation_id: request.operation_id.clone(),
            completed_units: summary.processed,
            total_units: Some(total),
            message: Some(source.display().to_string()),
        }));
    }

    if summary.failed > 0 && summary.imported == 0 && summary.skipped_duplicates == 0 {
        sink.emit(OperationEvent::Failed(OperationFailure {
            operation_id: request.operation_id.clone(),
            code: "import_failed".into(),
            message: "Import failed".into(),
            recoverable: true,
        }));
    } else {
        sink.emit(OperationEvent::Completed {
            operation_id: request.operation_id.clone(),
        });
    }

    summary
}

enum ImportOneError {
    Cancelled,
    Failed,
}

fn import_one<F, C>(
    request: &ImportExecutionRequest,
    candidate: &ImportCandidate,
    filesystem: &F,
    catalog: &mut C,
    cancellation: &CancellationToken,
) -> Result<(), ImportOneError>
where
    F: FileSystemPort,
    C: ImportCatalogPort,
{
    if !filesystem
        .is_file(&candidate.source_path)
        .map_err(|_| ImportOneError::Failed)?
    {
        return Err(ImportOneError::Failed);
    }

    let file_size = filesystem
        .metadata_len(&candidate.source_path)
        .map_err(|_| ImportOneError::Failed)?;

    let managed_path = if request.storage_mode == ImportStorageMode::Managed {
        let managed_root = request.managed_root.as_ref().expect("validated above");
        if !filesystem.exists(managed_root) {
            return Err(ImportOneError::Failed);
        }

        let extension = candidate
            .source_path
            .extension()
            .and_then(|value| value.to_str())
            .map(|value| format!(".{value}"))
            .unwrap_or_default();
        let final_path = managed_root.join(format!("{}{}", candidate.asset_id, extension));
        let temp_path = managed_root.join(format!("{}.part", candidate.asset_id));

        if filesystem.exists(&final_path) {
            return Err(ImportOneError::Failed);
        }

        let _ = filesystem.remove_file(&temp_path);
        if filesystem.copy(&candidate.source_path, &temp_path).is_err() {
            let _ = filesystem.remove_file(&temp_path);
            return Err(ImportOneError::Failed);
        }

        if cancellation.is_cancelled() {
            let _ = filesystem.remove_file(&temp_path);
            return Err(ImportOneError::Cancelled);
        }

        if filesystem.rename(&temp_path, &final_path).is_err() {
            let _ = filesystem.remove_file(&temp_path);
            return Err(ImportOneError::Failed);
        }
        Some(final_path)
    } else {
        None
    };

    if cancellation.is_cancelled() {
        if let Some(path) = &managed_path {
            let _ = filesystem.remove_file(path);
        }
        return Err(ImportOneError::Cancelled);
    }

    let draft = ImportedAssetDraft {
        asset_id: candidate.asset_id.clone(),
        workplace_id: request.workplace_id.clone(),
        source_path: candidate.source_path.clone(),
        managed_path: managed_path.clone(),
        file_size,
    };

    if catalog.save_imported_asset(draft).is_err() {
        if let Some(path) = managed_path {
            let _ = filesystem.remove_file(&path);
        }
        return Err(ImportOneError::Failed);
    }

    Ok(())
}
