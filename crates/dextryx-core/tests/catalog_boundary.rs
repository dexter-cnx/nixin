use std::path::{Path, PathBuf};

use dextryx_core::{
    filter_assets, AssetStorageMode, CatalogFilter, CatalogRepository, SyntheticCatalogRepository,
};

#[test]
fn catalog_filters_preserve_stable_asset_identity() {
    let repo = SyntheticCatalogRepository::new(5_000);
    let workplace_id = repo.active_workplace_id().unwrap();
    let all = repo.assets(workplace_id).unwrap();
    let missing = filter_assets(all.clone(), CatalogFilter::Missing);
    let recent = filter_assets(all.clone(), CatalogFilter::RecentImports { limit: 500 });

    assert_eq!(all.len(), 5_000);
    assert_eq!(missing.len(), 5_000usize.div_ceil(17));
    assert_eq!(recent.len(), 500);

    for asset in missing.iter().chain(recent.iter()) {
        assert!(all.iter().any(|candidate| candidate.id == asset.id));
    }

    assert_eq!(recent.first().unwrap().id, "asset-004999");
    assert_eq!(recent.last().unwrap().id, "asset-004500");
}

#[test]
fn effective_path_prefers_managed_copy() {
    let repo = SyntheticCatalogRepository::new(10);
    let workplace_id = repo.active_workplace_id().unwrap();
    let assets = repo.assets(workplace_id).unwrap();

    let managed = assets
        .iter()
        .find(|asset| asset.storage_mode == AssetStorageMode::Managed)
        .unwrap();
    let linked = assets
        .iter()
        .find(|asset| asset.storage_mode == AssetStorageMode::Linked)
        .unwrap();

    assert_eq!(
        managed.effective_path(),
        managed.managed_path.as_deref().unwrap()
    );
    assert_eq!(linked.effective_path(), linked.source_path.as_path());
}

#[test]
fn relink_preserves_identity_and_storage_semantics() {
    let mut repo = SyntheticCatalogRepository::new(10);
    let workplace_id = repo.active_workplace_id().unwrap().to_string();
    let before = repo.assets(&workplace_id).unwrap();
    let managed = before
        .iter()
        .find(|asset| asset.storage_mode == AssetStorageMode::Managed)
        .unwrap()
        .clone();
    let linked = before
        .iter()
        .find(|asset| asset.storage_mode == AssetStorageMode::Linked)
        .unwrap()
        .clone();

    repo.relink_asset(&managed.id, PathBuf::from("/replacement/managed.jpg"))
        .unwrap();
    repo.relink_asset(&linked.id, PathBuf::from("/replacement/linked.jpg"))
        .unwrap();

    let after = repo.assets(&workplace_id).unwrap();
    let managed_after = after.iter().find(|asset| asset.id == managed.id).unwrap();
    let linked_after = after.iter().find(|asset| asset.id == linked.id).unwrap();

    assert_eq!(managed_after.id, managed.id);
    assert_eq!(linked_after.id, linked.id);
    assert_eq!(
        managed_after.managed_path.as_deref(),
        Some(Path::new("/replacement/managed.jpg"))
    );
    assert_eq!(managed_after.source_path, managed.source_path);
    assert_eq!(
        linked_after.source_path,
        PathBuf::from("/replacement/linked.jpg")
    );
    assert_eq!(linked_after.managed_path, linked.managed_path);
    assert!(!managed_after.missing);
    assert!(!linked_after.missing);
}

#[test]
fn catalog_removal_has_no_physical_delete_operation() {
    let mut repo = SyntheticCatalogRepository::new(10);
    let workplace_id = repo.active_workplace_id().unwrap().to_string();
    let before = repo.assets(&workplace_id).unwrap();
    let target = before[0].clone();
    let physical_path = target.effective_path().to_path_buf();

    let removed = repo.remove_from_catalog(&target.id).unwrap();
    let after = repo.assets(&workplace_id).unwrap();

    assert_eq!(removed.id, target.id);
    assert_eq!(removed.effective_path(), physical_path.as_path());
    assert!(!after.iter().any(|asset| asset.id == target.id));
}

#[test]
fn active_workplace_is_repository_state_not_frontend_state() {
    let mut repo = SyntheticCatalogRepository::new(10);
    let workplaces = repo.workplaces();

    assert_eq!(repo.active_workplace_id(), Some("workplace-my"));
    repo.set_active_workplace(&workplaces[1].id).unwrap();
    assert_eq!(repo.active_workplace_id(), Some("workplace-secondary"));
    assert_eq!(repo.assets("workplace-secondary").unwrap().len(), 8);
}

#[test]
fn all_photos_filter_is_identity_preserving_noop() {
    let repo = SyntheticCatalogRepository::new(32);
    let assets = repo.assets(repo.active_workplace_id().unwrap()).unwrap();
    let ids: Vec<_> = assets.iter().map(|asset| asset.id.clone()).collect();
    let filtered = filter_assets(assets, CatalogFilter::AllPhotos);
    let filtered_ids: Vec<_> = filtered.iter().map(|asset| asset.id.clone()).collect();

    assert_eq!(filtered_ids, ids);
}
