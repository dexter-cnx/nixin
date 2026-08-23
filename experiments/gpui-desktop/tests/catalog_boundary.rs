use dextryx_core::SyntheticCatalogRepository;
use dextryx_frontend_api::{AssetQuery, CatalogApplication, FrontendEvent};

#[test]
fn gpui_frontend_consumes_frontend_application_api() {
    let app = CatalogApplication::new(SyntheticCatalogRepository::new(5_000));
    let missing = app
        .list_assets("workplace-my", AssetQuery::Missing)
        .unwrap();

    assert_eq!(missing.len(), 5_000usize.div_ceil(17));
}

#[test]
fn gpui_mutations_receive_neutral_events() {
    let mut app = CatalogApplication::new(SyntheticCatalogRepository::new(10));
    let event = app.set_active_workplace("workplace-secondary").unwrap();

    assert_eq!(
        event,
        FrontendEvent::ActiveWorkplaceChanged {
            workplace_id: "workplace-secondary".to_string(),
        }
    );
    assert_eq!(
        app.list_assets("workplace-secondary", AssetQuery::All)
            .unwrap()
            .len(),
        8
    );
}
