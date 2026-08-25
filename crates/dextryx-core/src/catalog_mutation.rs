use std::path::PathBuf;

use crate::{
    AssetId, CatalogAsset, CatalogReadRepository, CatalogRepositoryError,
    SyntheticCatalogRepository, WorkplaceId,
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CatalogMutation {
    SetActiveWorkplace {
        workplace_id: WorkplaceId,
    },
    RelinkAsset {
        asset_id: AssetId,
        replacement_path: PathBuf,
    },
    RemoveFromCatalog {
        asset_id: AssetId,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CatalogMutationResult {
    ActiveWorkplaceChanged { workplace_id: WorkplaceId },
    AssetRelinked { asset_id: AssetId },
    AssetRemovedFromCatalog { asset: CatalogAsset },
}

/// Authoritative mutation port below the frontend/application layer.
///
/// Implementations must be explicitly authorized. Projection, cache, and
/// frontend-local stores must never gain this trait through a blanket impl.
/// The same adapter must expose post-mutation state through
/// `CatalogReadRepository` so read-after-write observes one authority.
pub trait AuthoritativeCatalogPersistence: CatalogReadRepository {
    fn apply_mutation(
        &mut self,
        mutation: CatalogMutation,
    ) -> Result<CatalogMutationResult, CatalogRepositoryError>;
}

/// Explicit test/contract implementation only.
///
/// Production persistence adapters must opt in with their own explicit
/// implementation when the durable-authority cutover is approved.
impl AuthoritativeCatalogPersistence for SyntheticCatalogRepository {
    fn apply_mutation(
        &mut self,
        mutation: CatalogMutation,
    ) -> Result<CatalogMutationResult, CatalogRepositoryError> {
        match mutation {
            CatalogMutation::SetActiveWorkplace { workplace_id } => {
                crate::CatalogRepository::set_active_workplace(self, &workplace_id)?;
                Ok(CatalogMutationResult::ActiveWorkplaceChanged { workplace_id })
            }
            CatalogMutation::RelinkAsset {
                asset_id,
                replacement_path,
            } => {
                crate::CatalogRepository::relink_asset(self, &asset_id, replacement_path)?;
                Ok(CatalogMutationResult::AssetRelinked { asset_id })
            }
            CatalogMutation::RemoveFromCatalog { asset_id } => {
                let asset = crate::CatalogRepository::remove_from_catalog(self, &asset_id)?;
                Ok(CatalogMutationResult::AssetRemovedFromCatalog { asset })
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mutations_are_visible_through_the_same_authoritative_read_port() {
        let mut repository = SyntheticCatalogRepository::new(4);

        let result = repository
            .apply_mutation(CatalogMutation::SetActiveWorkplace {
                workplace_id: "workplace-secondary".to_string(),
            })
            .unwrap();
        assert_eq!(
            result,
            CatalogMutationResult::ActiveWorkplaceChanged {
                workplace_id: "workplace-secondary".to_string(),
            }
        );
        assert_eq!(
            repository.active_workplace_id(),
            Some("workplace-secondary")
        );

        repository
            .apply_mutation(CatalogMutation::RelinkAsset {
                asset_id: "asset-000000".to_string(),
                replacement_path: PathBuf::from("/replacement/image.jpg"),
            })
            .unwrap();
        let assets = repository.assets("workplace-my").unwrap();
        let asset = assets
            .iter()
            .find(|asset| asset.id == "asset-000000")
            .unwrap();
        assert_eq!(
            asset.effective_path(),
            std::path::Path::new("/replacement/image.jpg")
        );
        assert!(!asset.missing);

        let removed = repository
            .apply_mutation(CatalogMutation::RemoveFromCatalog {
                asset_id: "asset-000001".to_string(),
            })
            .unwrap();
        assert!(matches!(
            removed,
            CatalogMutationResult::AssetRemovedFromCatalog { .. }
        ));
        assert!(repository
            .assets("workplace-my")
            .unwrap()
            .iter()
            .all(|asset| asset.id != "asset-000001"));
    }
}
