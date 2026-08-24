mod import_operation;
pub use import_operation::*;

use std::path::PathBuf;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};

use dextryx_core::{
    filter_assets, AssetStorageMode, CatalogAsset, CatalogFilter, CatalogReadRepository,
    CatalogRepository, CatalogRepositoryError, WorkplaceSummary,
};

pub type OperationId = String;

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

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum OperationKind {
    Import,
    Thumbnail,
    DevelopPreview,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OperationStarted {
    pub operation_id: OperationId,
    pub kind: OperationKind,
    pub total_units: Option<u64>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OperationProgress {
    pub operation_id: OperationId,
    pub completed_units: u64,
    pub total_units: Option<u64>,
    pub message: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OperationFailure {
    pub operation_id: OperationId,
    pub code: String,
    pub message: String,
    pub recoverable: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum OperationEvent {
    Started(OperationStarted),
    Progress(OperationProgress),
    ItemCompleted {
        operation_id: OperationId,
        item_id: String,
    },
    Failed(OperationFailure),
    Cancelled {
        operation_id: OperationId,
    },
    Completed {
        operation_id: OperationId,
    },
}

impl OperationEvent {
    pub fn operation_id(&self) -> &str {
        match self {
            Self::Started(event) => &event.operation_id,
            Self::Progress(event) => &event.operation_id,
            Self::ItemCompleted { operation_id, .. }
            | Self::Cancelled { operation_id }
            | Self::Completed { operation_id } => operation_id,
            Self::Failed(event) => &event.operation_id,
        }
    }
}

pub trait OperationEventSink {
    fn emit(&mut self, event: OperationEvent);
}

impl<F> OperationEventSink for F
where
    F: FnMut(OperationEvent),
{
    fn emit(&mut self, event: OperationEvent) {
        self(event);
    }
}

#[derive(Clone, Debug, Default)]
pub struct CancellationToken {
    cancelled: Arc<AtomicBool>,
}

impl CancellationToken {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::Release);
    }

    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::Acquire)
    }
}

/// Read-only application service for authoritative Workplace/catalog data.
///
/// M2 production frontends depend on this service so the read path cannot gain
/// catalog mutation authority accidentally. The concrete durable adapter sits
/// behind `CatalogReadRepository`.
pub struct CatalogReadApplication<R> {
    repository: R,
}

impl<R> CatalogReadApplication<R>
where
    R: CatalogReadRepository,
{
    pub fn new(repository: R) -> Self {
        Self { repository }
    }

    pub fn list_workplaces(&self) -> Vec<WorkplaceDto> {
        let active = self.repository.active_workplace_id();
        map_workplaces(self.repository.workplaces(), active)
    }

    pub fn list_assets(
        &self,
        workplace_id: &str,
        query: AssetQuery,
    ) -> Result<Vec<AssetSummaryDto>, FrontendApiError> {
        map_assets(self.repository.assets(workplace_id)?, query)
    }
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
        map_workplaces(self.repository.workplaces(), active)
    }

    pub fn list_assets(
        &self,
        workplace_id: &str,
        query: AssetQuery,
    ) -> Result<Vec<AssetSummaryDto>, FrontendApiError> {
        map_assets(self.repository.assets(workplace_id)?, query)
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

fn map_workplaces(workplaces: Vec<WorkplaceSummary>, active: Option<&str>) -> Vec<WorkplaceDto> {
    workplaces
        .into_iter()
        .map(|workplace| map_workplace(workplace, active))
        .collect()
}

fn map_assets(
    assets: Vec<CatalogAsset>,
    query: AssetQuery,
) -> Result<Vec<AssetSummaryDto>, FrontendApiError> {
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

fn map_workplace(workplace: WorkplaceSummary, active: Option<&str>) -> WorkplaceDto {
    WorkplaceDto {
        is_active: active == Some(workplace.id.as_str()),
        id: workplace.id,
        name: workplace.name,
    }
}

fn map_asset(asset: CatalogAsset) -> AssetSummaryDto {
    let effective_path = asset.effective_path().to_path_buf();
    let storage = match asset.storage_mode {
        AssetStorageMode::Linked => AssetStorageDto::Linked,
        AssetStorageMode::Managed => AssetStorageDto::Managed,
    };

    AssetSummaryDto {
        id: asset.id,
        workplace_id: asset.workplace_id,
        effective_path,
        storage,
        missing: asset.missing,
        import_sequence: asset.import_sequence,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use dextryx_core::SyntheticCatalogRepository;

    #[test]
    fn read_application_exposes_authoritative_queries_without_mutation_api() {
        let app = CatalogReadApplication::new(SyntheticCatalogRepository::new(32));
        let workplaces = app.list_workplaces();
        let active = workplaces
            .iter()
            .find(|workplace| workplace.is_active)
            .expect("synthetic adapter should have an active workplace");

        let missing = app
            .list_assets(&active.id, AssetQuery::Missing)
            .expect("active workplace should be readable");

        assert!(!missing.is_empty());
        assert!(missing.iter().all(|asset| asset.missing));
    }
}
