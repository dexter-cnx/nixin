mod cutover;
mod file_candidate;
pub use cutover::*;
pub use file_candidate::*;

use dextryx_core::{
    validate_catalog_projection, AuthoritativeCatalogPersistence, AuthoritativeCatalogProjection,
    CatalogAsset, CatalogInvariantError, CatalogMutation, CatalogMutationError,
    CatalogMutationResult, CatalogReadRepository, CatalogRepositoryError, CatalogSnapshotRepository,
    WorkplaceSummary,
};

/// Non-durable M4 qualification adapter.
///
/// This adapter exists only to prove migration and mutation semantics against
/// the shared frontend-neutral contracts. It is not an approved production
/// authority and must not be wired into GPUI as durable persistence.
pub struct CandidateCatalogStore {
    projection: AuthoritativeCatalogProjection,
}

impl CandidateCatalogStore {
    pub fn from_projection(
        projection: AuthoritativeCatalogProjection,
    ) -> Result<Self, CatalogInvariantError> {
        validate_catalog_projection(&projection)?;
        Ok(Self { projection })
    }

    pub fn projection(&self) -> &AuthoritativeCatalogProjection {
        &self.projection
    }

    fn asset_mut(&mut self, asset_id: &str) -> Result<&mut CatalogAsset, CatalogRepositoryError> {
        self.projection
            .assets
            .iter_mut()
            .find(|asset| asset.id == asset_id)
            .ok_or_else(|| CatalogRepositoryError::UnknownAsset(asset_id.to_string()))
    }

    /// Qualification-only semantic mutation helper.
    ///
    /// This does not claim durable-authority behavior and therefore reports only
    /// repository/domain failures. The authoritative trait wrapper below lifts
    /// those failures into `CatalogMutationError`.
    pub fn apply_mutation(
        &mut self,
        mutation: CatalogMutation,
    ) -> Result<CatalogMutationResult, CatalogRepositoryError> {
        match mutation {
            CatalogMutation::SetActiveWorkplace { workplace_id } => {
                if !self
                    .projection
                    .workplaces
                    .iter()
                    .any(|workplace| workplace.id == workplace_id)
                {
                    return Err(CatalogRepositoryError::UnknownWorkplace(workplace_id));
                }
                self.projection.active_workplace_id = Some(workplace_id.clone());
                Ok(CatalogMutationResult::ActiveWorkplaceChanged { workplace_id })
            }
            CatalogMutation::RelinkAsset {
                asset_id,
                replacement_path,
            } => {
                let asset = self.asset_mut(&asset_id)?;
                match asset.storage_mode {
                    dextryx_core::AssetStorageMode::Linked => asset.source_path = replacement_path,
                    dextryx_core::AssetStorageMode::Managed => {
                        asset.managed_path = Some(replacement_path)
                    }
                }
                asset.missing = false;
                Ok(CatalogMutationResult::AssetRelinked { asset_id })
            }
            CatalogMutation::RemoveFromCatalog { asset_id } => {
                let index = self
                    .projection
                    .assets
                    .iter()
                    .position(|asset| asset.id == asset_id)
                    .ok_or_else(|| CatalogRepositoryError::UnknownAsset(asset_id.clone()))?;
                let asset = self.projection.assets.remove(index);
                Ok(CatalogMutationResult::AssetRemovedFromCatalog { asset })
            }
        }
    }
}

impl CatalogReadRepository for CandidateCatalogStore {
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

impl CatalogSnapshotRepository for CandidateCatalogStore {
    fn all_assets_for_snapshot(&self) -> Result<Vec<CatalogAsset>, CatalogRepositoryError> {
        Ok(self.projection.assets.clone())
    }
}

impl AuthoritativeCatalogPersistence for CandidateCatalogStore {
    fn apply_mutation(
        &mut self,
        mutation: CatalogMutation,
    ) -> Result<CatalogMutationResult, CatalogMutationError> {
        CandidateCatalogStore::apply_mutation(self, mutation).map_err(Into::into)
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::*;
    use dextryx_core::{AssetStorageMode, WorkplaceSummary};

    #[test]
    fn rejects_invalid_seed_projection() {
        let projection = AuthoritativeCatalogProjection {
            workplaces: vec![WorkplaceSummary {
                id: "workplace-1".to_string(),
                name: "My workplace".to_string(),
            }],
            active_workplace_id: Some("workplace-1".to_string()),
            assets: vec![CatalogAsset {
                id: "asset-1".to_string(),
                workplace_id: "missing".to_string(),
                source_path: PathBuf::from("/external/image.jpg"),
                managed_path: None,
                storage_mode: AssetStorageMode::Linked,
                missing: false,
                import_sequence: 1,
            }],
        };

        assert!(matches!(
            CandidateCatalogStore::from_projection(projection),
            Err(CatalogInvariantError::AssetReferencesUnknownWorkplace { .. })
        ));
    }
}
