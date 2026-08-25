use super::{validate_catalog_projection, CatalogInvariantError};
use crate::{AuthoritativeCatalogProjection, CatalogReadRepository, CatalogRepositoryError};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CatalogSnapshotError {
    Repository(CatalogRepositoryError),
    Invariant(CatalogInvariantError),
}

/// Materialize one complete catalog snapshot through the authoritative read port.
///
/// Candidate persistence adapters must be able to produce a valid snapshot
/// before and after mutations. This keeps migration/cutover qualification on
/// the same frontend-neutral contracts used by production reads.
pub fn snapshot_catalog_repository<R>(
    repository: &R,
) -> Result<AuthoritativeCatalogProjection, CatalogSnapshotError>
where
    R: CatalogReadRepository + ?Sized,
{
    let workplaces = repository.workplaces();
    let active_workplace_id = repository.active_workplace_id().map(str::to_string);
    let mut assets = Vec::new();

    for workplace in &workplaces {
        assets.extend(
            repository
                .assets(&workplace.id)
                .map_err(CatalogSnapshotError::Repository)?,
        );
    }

    let projection = AuthoritativeCatalogProjection {
        workplaces,
        active_workplace_id,
        assets,
    };
    validate_catalog_projection(&projection).map_err(CatalogSnapshotError::Invariant)?;
    Ok(projection)
}

#[cfg(test)]
mod tests {
    use std::path::{Path, PathBuf};

    use super::*;
    use crate::{
        AuthoritativeCatalogPersistence, CatalogMutation, CatalogMutationResult,
        SyntheticCatalogRepository,
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
}
