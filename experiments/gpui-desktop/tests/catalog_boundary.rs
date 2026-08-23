use dextryx_core::{CatalogFilter, CatalogRepository, SyntheticCatalogRepository, filter_assets};

#[test]
fn gpui_frontend_consumes_shared_catalog_contract() {
    let repo = SyntheticCatalogRepository::new(5_000);
    let workplace_id = repo.active_workplace_id().unwrap();
    let assets = repo.assets(workplace_id).unwrap();
    let missing = filter_assets(assets, CatalogFilter::Missing);

    assert_eq!(missing.len(), 5_000usize.div_ceil(17));
}

#[test]
fn shared_core_preserves_active_workplace_semantics() {
    let mut repo = SyntheticCatalogRepository::new(10);
    let workplaces = repo.workplaces();

    repo.set_active_workplace(&workplaces[1].id).unwrap();

    assert_eq!(repo.active_workplace_id(), Some("workplace-secondary"));
    assert_eq!(repo.assets("workplace-secondary").unwrap().len(), 8);
}
