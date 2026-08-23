use std::collections::HashMap;
use std::path::{Path, PathBuf};

pub type AssetId = String;
pub type WorkplaceId = String;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AssetStorageMode {
    Linked,
    Managed,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct WorkplaceSummary {
    pub id: WorkplaceId,
    pub name: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CatalogAsset {
    pub id: AssetId,
    pub workplace_id: WorkplaceId,
    pub source_path: PathBuf,
    pub managed_path: Option<PathBuf>,
    pub storage_mode: AssetStorageMode,
    pub missing: bool,
    pub import_sequence: u64,
}

impl CatalogAsset {
    pub fn effective_path(&self) -> &Path {
        self.managed_path.as_deref().unwrap_or(&self.source_path)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CatalogFilter {
    AllPhotos,
    Missing,
    RecentImports { limit: usize },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CatalogRepositoryError {
    UnknownWorkplace(WorkplaceId),
    UnknownAsset(AssetId),
}

/// Frontend-neutral catalog boundary.
///
/// GPUI, Flutter/FFI, CLI tools, and tests must depend on this contract rather
/// than concrete persistence or UI framework types.
pub trait CatalogRepository {
    fn workplaces(&self) -> Vec<WorkplaceSummary>;
    fn active_workplace_id(&self) -> Option<&str>;
    fn set_active_workplace(
        &mut self,
        workplace_id: &str,
    ) -> Result<(), CatalogRepositoryError>;
    fn assets(&self, workplace_id: &str) -> Result<Vec<CatalogAsset>, CatalogRepositoryError>;
    fn relink_asset(
        &mut self,
        asset_id: &str,
        replacement_path: PathBuf,
    ) -> Result<(), CatalogRepositoryError>;
    fn remove_from_catalog(
        &mut self,
        asset_id: &str,
    ) -> Result<CatalogAsset, CatalogRepositoryError>;
}

pub fn filter_assets(mut assets: Vec<CatalogAsset>, filter: CatalogFilter) -> Vec<CatalogAsset> {
    match filter {
        CatalogFilter::AllPhotos => assets,
        CatalogFilter::Missing => {
            assets.retain(|asset| asset.missing);
            assets
        }
        CatalogFilter::RecentImports { limit } => {
            assets.sort_by_key(|asset| std::cmp::Reverse(asset.import_sequence));
            assets.truncate(limit);
            assets
        }
    }
}

/// Synthetic adapter retained only for architecture/contract tests.
/// It is not a production persistence implementation.
pub struct SyntheticCatalogRepository {
    workplaces: Vec<WorkplaceSummary>,
    active_workplace_id: Option<WorkplaceId>,
    assets: HashMap<AssetId, CatalogAsset>,
}

impl SyntheticCatalogRepository {
    pub fn new(asset_count: usize) -> Self {
        let primary = WorkplaceSummary {
            id: "workplace-my".to_string(),
            name: "My workplace".to_string(),
        };
        let secondary = WorkplaceSummary {
            id: "workplace-secondary".to_string(),
            name: "Secondary workplace".to_string(),
        };

        let mut assets = HashMap::with_capacity(asset_count + 8);
        for ix in 0..asset_count {
            let id = format!("asset-{ix:06}");
            let managed = ix % 5 == 0;
            assets.insert(
                id.clone(),
                CatalogAsset {
                    id,
                    workplace_id: primary.id.clone(),
                    source_path: PathBuf::from(format!("/linked/source/image-{ix:06}.jpg")),
                    managed_path: managed.then(|| {
                        PathBuf::from(format!("/managed/library/image-{ix:06}.jpg"))
                    }),
                    storage_mode: if managed {
                        AssetStorageMode::Managed
                    } else {
                        AssetStorageMode::Linked
                    },
                    missing: ix % 17 == 0,
                    import_sequence: ix as u64,
                },
            );
        }

        for ix in 0..8 {
            let id = format!("secondary-{ix:03}");
            assets.insert(
                id.clone(),
                CatalogAsset {
                    id,
                    workplace_id: secondary.id.clone(),
                    source_path: PathBuf::from(format!("/secondary/image-{ix:03}.jpg")),
                    managed_path: None,
                    storage_mode: AssetStorageMode::Linked,
                    missing: false,
                    import_sequence: ix as u64,
                },
            );
        }

        Self {
            workplaces: vec![primary.clone(), secondary],
            active_workplace_id: Some(primary.id),
            assets,
        }
    }

    fn asset_mut(&mut self, asset_id: &str) -> Result<&mut CatalogAsset, CatalogRepositoryError> {
        self.assets
            .get_mut(asset_id)
            .ok_or_else(|| CatalogRepositoryError::UnknownAsset(asset_id.to_string()))
    }
}

impl CatalogRepository for SyntheticCatalogRepository {
    fn workplaces(&self) -> Vec<WorkplaceSummary> {
        self.workplaces.clone()
    }

    fn active_workplace_id(&self) -> Option<&str> {
        self.active_workplace_id.as_deref()
    }

    fn set_active_workplace(
        &mut self,
        workplace_id: &str,
    ) -> Result<(), CatalogRepositoryError> {
        if !self
            .workplaces
            .iter()
            .any(|workplace| workplace.id == workplace_id)
        {
            return Err(CatalogRepositoryError::UnknownWorkplace(
                workplace_id.to_string(),
            ));
        }
        self.active_workplace_id = Some(workplace_id.to_string());
        Ok(())
    }

    fn assets(&self, workplace_id: &str) -> Result<Vec<CatalogAsset>, CatalogRepositoryError> {
        if !self
            .workplaces
            .iter()
            .any(|workplace| workplace.id == workplace_id)
        {
            return Err(CatalogRepositoryError::UnknownWorkplace(
                workplace_id.to_string(),
            ));
        }

        let mut assets: Vec<_> = self
            .assets
            .values()
            .filter(|asset| asset.workplace_id == workplace_id)
            .cloned()
            .collect();
        assets.sort_by_key(|asset| asset.import_sequence);
        Ok(assets)
    }

    fn relink_asset(
        &mut self,
        asset_id: &str,
        replacement_path: PathBuf,
    ) -> Result<(), CatalogRepositoryError> {
        let asset = self.asset_mut(asset_id)?;
        match asset.storage_mode {
            AssetStorageMode::Linked => asset.source_path = replacement_path,
            AssetStorageMode::Managed => asset.managed_path = Some(replacement_path),
        }
        asset.missing = false;
        Ok(())
    }

    fn remove_from_catalog(
        &mut self,
        asset_id: &str,
    ) -> Result<CatalogAsset, CatalogRepositoryError> {
        self.assets
            .remove(asset_id)
            .ok_or_else(|| CatalogRepositoryError::UnknownAsset(asset_id.to_string()))
    }
}
