use std::collections::HashSet;
use std::path::PathBuf;

use crate::{
    AssetId, AuthoritativeCatalogProjection, CatalogAsset, CatalogReadRepository,
    CatalogRepositoryError, SyntheticCatalogRepository, WorkplaceId,
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

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CatalogInvariantError {
    DuplicateWorkplaceId(WorkplaceId),
    DuplicateAssetId(AssetId),
    UnknownActiveWorkplace(WorkplaceId),
    AssetReferencesUnknownWorkplace {
        asset_id: AssetId,
        workplace_id: WorkplaceId,
    },
}

/// Validate invariants that every authoritative catalog implementation and
/// migration snapshot must satisfy before it can become the durable source.
pub fn validate_catalog_projection(
    projection: &AuthoritativeCatalogProjection,
) -> Result<(), CatalogInvariantError> {
    let mut workplace_ids = HashSet::with_capacity(projection.workplaces.len());
    for workplace in &projection.workplaces {
        if !workplace_ids.insert(workplace.id.as_str()) {
            return Err(CatalogInvariantError::DuplicateWorkplaceId(
                workplace.id.clone(),
            ));
        }
    }

    if let Some(active_workplace_id) = projection.active_workplace_id.as_deref() {
        if !workplace_ids.contains(active_workplace_id) {
            return Err(CatalogInvariantError::UnknownActiveWorkplace(
                active_workplace_id.to_string(),
            ));
        }
    }

    let mut asset_ids = HashSet::with_capacity(projection.assets.len());
    for asset in &projection.assets {
        if !asset_ids.insert(asset.id.as_str()) {
            return Err(CatalogInvariantError::DuplicateAssetId(asset.id.clone()));
        }
        if !workplace_ids.contains(asset.workplace_id.as_str()) {
            return Err(CatalogInvariantError::AssetReferencesUnknownWorkplace {
                asset_id: asset.id.clone(),
                workplace_id: asset.workplace_id.clone(),
            });
        }
    }

    Ok(())
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
    use crate::{AssetStorageMode, WorkplaceSummary};

    fn valid_projection() -> AuthoritativeCatalogProjection {
        AuthoritativeCatalogProjection {
            workplaces: vec![WorkplaceSummary {
                id: "workplace-1".to_string(),
                name: "My workplace".to_string(),
            }],
            active_workplace_id: Some("workplace-1".to_string()),
            assets: vec![CatalogAsset {
                id: "asset-1".to_string(),
                workplace_id: "workplace-1".to_string(),
                source_path: PathBuf::from("/external/image.jpg"),
                managed_path: None,
                storage_mode: AssetStorageMode::Linked,
                missing: false,
                import_sequence: 1,
            }],
        }
    }

    #[test]
    fn authoritative_projection_rejects_duplicate_workplace_ids() {
        let mut projection = valid_projection();
        projection.workplaces.push(projection.workplaces[0].clone());

        assert_eq!(
            validate_catalog_projection(&projection),
            Err(CatalogInvariantError::DuplicateWorkplaceId(
                "workplace-1".to_string()
            ))
        );
    }

    #[test]
    fn authoritative_projection_rejects_duplicate_asset_ids() {
        let mut projection = valid_projection();
        projection.assets.push(projection.assets[0].clone());

        assert_eq!(
            validate_catalog_projection(&projection),
            Err(CatalogInvariantError::DuplicateAssetId(
                "asset-1".to_string()
            ))
        );
    }

    #[test]
    fn authoritative_projection_rejects_unknown_active_workplace() {
        let mut projection = valid_projection();
        projection.active_workplace_id = Some("missing-workplace".to_string());

        assert_eq!(
            validate_catalog_projection(&projection),
            Err(CatalogInvariantError::UnknownActiveWorkplace(
                "missing-workplace".to_string()
            ))
        );
    }

    #[test]
    fn authoritative_projection_rejects_asset_with_unknown_workplace() {
        let mut projection = valid_projection();
        projection.assets[0].workplace_id = "missing-workplace".to_string();

        assert_eq!(
            validate_catalog_projection(&projection),
            Err(CatalogInvariantError::AssetReferencesUnknownWorkplace {
                asset_id: "asset-1".to_string(),
                workplace_id: "missing-workplace".to_string(),
            })
        );
    }

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
