use std::path::PathBuf;

use dextryx_core::{
    filter_assets, AssetStorageMode, CatalogAsset, CatalogFilter, CatalogRepository,
    CatalogRepositoryError, WorkplaceSummary,
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct WorkplaceDto {
    pub id: String,
    pub name: String,
    pub is_active: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum AssetStorageDto {
    Linked,
    Managed,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AssetSummaryDto {
    pub id: String,
    pub workplace_id: String,
    pub effective_path: PathBuf,
    pub storage: AssetStorageDto,
    pub missing: bool,
    pub import_sequence: u64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AssetQuery {
    All,
    Missing,
    Recent { limit: usize },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum FrontendApiError {
    UnknownWorkplace(String),
    UnknownAsset(String),
}

impl From<CatalogRepositoryError> for FrontendApiError {
    fn from(value: CatalogRepositoryError) -> Self {
        match value {
            CatalogRepositoryError::UnknownWorkplace(id) => Self::UnknownWorkplace(id),
            CatalogRepositoryError::UnknownAsset(id) => Self::UnknownAsset(id),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum FrontendEvent {
    ActiveWorkplaceChanged { workplace_id: String },
    AssetRelinked { asset_id: String },
    AssetRemovedFromCatalog { asset_id: String },
}

pub struct CatalogApplication<R> {
    repository: R,
}

impl<R> CatalogApplication<R>
where
    R: CatalogRepository,
{
    pub fn new(repository: R) -> Self {
        Self { repository }
    }

    pub fn list_workplaces(&self) -> Vec<WorkplaceDto> {
        let active = self.repository.active_workplace_id();
        self.repository
            .workplaces()
            .into_iter()
            .map(|workplace| map_workplace(workplace, active))
            .collect()
    }

    pub fn list_assets(
        &self,
        workplace_id: &str,
        query: AssetQuery,
    ) -> Result<Vec<AssetSummaryDto>, FrontendApiError> {
        let assets = self.repository.assets(workplace_id)?;
        let filter = match query {
            AssetQuery::All => CatalogFilter::AllPhotos,
            AssetQuery::Missing => CatalogFilter::Missing,
            AssetQuery::Recent { limit } => CatalogFilter::RecentImports { limit },
        };

        Ok(filter_assets(assets, filter)
            .into_iter()
            .map(map_asset)
            .collect())
    }

    pub fn set_active_workplace(
        &mut self,
        workplace_id: &str,
    ) -> Result<FrontendEvent, FrontendApiError> {
        self.repository.set_active_workplace(workplace_id)?;
        Ok(FrontendEvent::ActiveWorkplaceChanged {
            workplace_id: workplace_id.to_string(),
        })
    }

    pub fn relink_asset(
        &mut self,
        asset_id: &str,
        replacement_path: PathBuf,
    ) -> Result<FrontendEvent, FrontendApiError> {
        self.repository.relink_asset(asset_id, replacement_path)?;
        Ok(FrontendEvent::AssetRelinked {
            asset_id: asset_id.to_string(),
        })
    }

    pub fn remove_from_catalog(
        &mut self,
        asset_id: &str,
    ) -> Result<(AssetSummaryDto, FrontendEvent), FrontendApiError> {
        let removed = self.repository.remove_from_catalog(asset_id)?;
        let dto = map_asset(removed);
        let event = FrontendEvent::AssetRemovedFromCatalog {
            asset_id: asset_id.to_string(),
        };
        Ok((dto, event))
    }

    pub fn into_repository(self) -> R {
        self.repository
    }
}

fn map_workplace(workplace: WorkplaceSummary, active: Option<&str>) -> WorkplaceDto {
    WorkplaceDto {
        is_active: active == Some(workplace.id.as_str()),
        id: workplace.id,
        name: workplace.name,
    }
}

fn map_asset(asset: CatalogAsset) -> AssetSummaryDto {
    AssetSummaryDto {
        id: asset.id,
        workplace_id: asset.workplace_id,
        effective_path: asset.effective_path().to_path_buf(),
        storage: match asset.storage_mode {
            AssetStorageMode::Linked => AssetStorageDto::Linked,
            AssetStorageMode::Managed => AssetStorageDto::Managed,
        },
        missing: asset.missing,
        import_sequence: asset.import_sequence,
    }
}
