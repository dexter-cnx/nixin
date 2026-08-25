use super::{validate_catalog_projection, CatalogInvariantError};
use crate::{
    AuthoritativeCatalogProjection, CatalogAsset, CatalogReadRepository, CatalogRepositoryError,
    ProjectionCatalogReadAdapter, SyntheticCatalogRepository,
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CatalogSnapshotError {
    Repository(CatalogRepositoryError),
    Invariant(CatalogInvariantError),
}

/// Qualification-only extension that must enumerate every persisted asset,
/// including records whose Workplace relationship is corrupt.
///
/// There is intentionally no blanket or default implementation. Production
/// persistence candidates must explicitly prove that their full-store scan is
/// independent of the valid Workplace list before they can be qualified for
/// durable-authority cutover.
pub trait CatalogSnapshotRepository: CatalogReadRepository {
    fn all_assets_for_snapshot(&self) -> Result<Vec<CatalogAsset>, CatalogRepositoryError>;
}

impl CatalogSnapshotRepository for ProjectionCatalogReadAdapter {
    fn all_assets_for_snapshot(&self) -> Result<Vec<CatalogAsset>, CatalogRepositoryError> {
        Ok(self.projection().assets.clone())
    }
}

/// Synthetic repository support is retained only for architecture tests.
/// Production candidates must provide an explicit full-store implementation.
impl CatalogSnapshotRepository for SyntheticCatalogRepository {
    fn all_assets_for_snapshot(&self) -> Result<Vec<CatalogAsset>, CatalogRepositoryError> {
        let mut assets = Vec::new();
        for workplace in self.workplaces() {
            assets.extend(self.assets(&workplace.id)?);
        }
        Ok(assets)
    }
}

/// Materialize one complete catalog snapshot through the qualification port.
///
/// Candidate persistence adapters must be able to produce a valid snapshot
/// before and after mutations. Asset enumeration is deliberately independent
/// of the valid Workplace list so dangling relationships cannot disappear from
/// the migration/cutover qualification gate.
pub fn snapshot_catalog_repository<R>(
    repository: &R,
) -> Result<AuthoritativeCatalogProjection, CatalogSnapshotError>
where
    R: CatalogSnapshotRepository + ?Sized,
{
    let projection = AuthoritativeCatalogProjection {
        workplaces: repository.workplaces(),
        active_workplace_id: repository.active_workplace_id().map(str::to_string),
        assets: repository
            .all_assets_for_snapshot()
            .map_err(CatalogSnapshotError::Repository)?,
    };
    validate_catalog_projection(&projection).map_err(CatalogSnapshotError::Invariant)?;
    Ok(projection)
}

#[cfg(test)]
mod tests {
    use std::path::{Path, PathBuf};

    use super::*;
    use crate::{
        AssetStorageMode, AuthoritativeCatalogPersistence, CatalogMutation, CatalogMutationResult,
        WorkplaceSummary,
    };

    #[test]
    fn synthetic_authority_qualifies_before_and_after_mutations() {
        let mut repository = SyntheticCatalogRepository::new(4);

        let initial = snapshot_catalog_repository(&repository).unwrap();
        assert_eq!(initial.active_workplace_id.as_deref(), Some("workplace-my"));

        repository
            .apply_mutation(CatalogMutation::SetActiveWorkplace {
                workplace_id: "workplace-secondary".to_string(),
            })
            .unwrap();
        let after_active = snapshot_catalog_repository(&repository).unwrap();
        assert_eq!(
            after_active.active_workplace_id.as_deref(),
            Some("workplace-secondary")
        );

        repository
            .apply_mutation(CatalogMutation::RelinkAsset {
                asset_id: "asset-000000".to_string(),
                replacement_path: PathBuf::from("/replacement/image.jpg"),
            })
            .unwrap();
        let after_relink = snapshot_catalog_repository(&repository).unwrap();
        let relinked = after_relink
            .assets
            .iter()
            .find(|asset| asset.id == "asset-000000")
            .unwrap();
        assert_eq!(
            relinked.effective_path(),
            Path::new("/replacement/image.jpg")
        );
        assert!(!relinked.missing);

        let removed = repository
            .apply_mutation(CatalogMutation::RemoveFromCatalog {
                asset_id: "asset-000001".to_string(),
            })
            .unwrap();
        assert!(matches!(
            removed,
            CatalogMutationResult::AssetRemovedFromCatalog { .. }
        ));
        let after_remove = snapshot_catalog_repository(&repository).unwrap();
        assert!(after_remove
            .assets
            .iter()
            .all(|asset| asset.id != "asset-000001"));
    }

    #[test]
    fn qualification_rejects_orphan_asset_hidden_from_workplace_queries() {
        let repository = ProjectionCatalogReadAdapter::new(AuthoritativeCatalogProjection {
            workplaces: vec![WorkplaceSummary {
                id: "workplace-1".to_string(),
                name: "My workplace".to_string(),
            }],
            active_workplace_id: Some("workplace-1".to_string()),
            assets: vec![CatalogAsset {
                id: "orphan-asset".to_string(),
                workplace_id: "missing-workplace".to_string(),
                source_path: PathBuf::from("/external/orphan.jpg"),
                managed_path: None,
                storage_mode: AssetStorageMode::Linked,
                missing: false,
                import_sequence: 1,
            }],
        });

        assert_eq!(
            snapshot_catalog_repository(&repository),
            Err(CatalogSnapshotError::Invariant(
                CatalogInvariantError::AssetReferencesUnknownWorkplace {
                    asset_id: "orphan-asset".to_string(),
                    workplace_id: "missing-workplace".to_string(),
                }
            ))
        );
    }
}
