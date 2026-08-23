use std::path::PathBuf;

use dextryx_core::SyntheticCatalogRepository;
use dextryx_frontend_api::{
    AssetQuery, AssetStorageDto, CatalogApplication, FrontendApiError, FrontendEvent,
    OperationEvent, OperationEventSink, OperationFailure, OperationKind, OperationProgress,
    OperationStarted,
};

#[test]
fn lists_workplaces_with_active_marker() {
    let app = CatalogApplication::new(SyntheticCatalogRepository::new(32));
    let workplaces = app.list_workplaces();

    assert_eq!(workplaces.len(), 2);
    assert!(workplaces[0].is_active);
    assert_eq!(workplaces[0].id, "workplace-my");
    assert!(!workplaces[1].is_active);
}

#[test]
fn asset_queries_are_frontend_neutral() {
    let app = CatalogApplication::new(SyntheticCatalogRepository::new(100));

    let all = app.list_assets("workplace-my", AssetQuery::All).unwrap();
    let missing = app
        .list_assets("workplace-my", AssetQuery::Missing)
        .unwrap();
    let recent = app
        .list_assets("workplace-my", AssetQuery::Recent { limit: 10 })
        .unwrap();

    assert_eq!(all.len(), 100);
    assert_eq!(missing.len(), 100usize.div_ceil(17));
    assert_eq!(recent.len(), 10);
    assert_eq!(recent[0].id, "asset-000099");
}

#[test]
fn frontend_dto_hides_domain_storage_shape() {
    let app = CatalogApplication::new(SyntheticCatalogRepository::new(10));
    let assets = app.list_assets("workplace-my", AssetQuery::All).unwrap();

    let managed = assets
        .iter()
        .find(|asset| asset.storage == AssetStorageDto::Managed)
        .unwrap();
    let linked = assets
        .iter()
        .find(|asset| asset.storage == AssetStorageDto::Linked)
        .unwrap();

    assert!(managed.effective_path.starts_with("/managed/library"));
    assert!(linked.effective_path.starts_with("/linked/source"));
}

#[test]
fn mutations_return_neutral_events() {
    let mut app = CatalogApplication::new(SyntheticCatalogRepository::new(10));

    let active = app.set_active_workplace("workplace-secondary").unwrap();
    assert_eq!(
        active,
        FrontendEvent::ActiveWorkplaceChanged {
            workplace_id: "workplace-secondary".to_string(),
        }
    );

    let relink = app
        .relink_asset(
            "secondary-000",
            PathBuf::from("/replacement/secondary-000.jpg"),
        )
        .unwrap();
    assert_eq!(
        relink,
        FrontendEvent::AssetRelinked {
            asset_id: "secondary-000".to_string(),
        }
    );

    let assets = app
        .list_assets("workplace-secondary", AssetQuery::All)
        .unwrap();
    assert_eq!(
        assets[0].effective_path,
        PathBuf::from("/replacement/secondary-000.jpg")
    );
}

#[test]
fn removal_does_not_expose_repository_object() {
    let mut app = CatalogApplication::new(SyntheticCatalogRepository::new(10));

    let (removed, event) = app.remove_from_catalog("asset-000001").unwrap();
    assert_eq!(removed.id, "asset-000001");
    assert_eq!(
        event,
        FrontendEvent::AssetRemovedFromCatalog {
            asset_id: "asset-000001".to_string(),
        }
    );

    let assets = app.list_assets("workplace-my", AssetQuery::All).unwrap();
    assert!(!assets.iter().any(|asset| asset.id == "asset-000001"));
}

#[test]
fn repository_errors_are_mapped_at_api_boundary() {
    let app = CatalogApplication::new(SyntheticCatalogRepository::new(4));

    let error = app.list_assets("unknown", AssetQuery::All).unwrap_err();
    assert_eq!(
        error,
        FrontendApiError::UnknownWorkplace("unknown".to_string())
    );
}

#[test]
fn operation_events_preserve_one_stable_operation_identity() {
    let id = "import-0001".to_string();
    let events = vec![
        OperationEvent::Started(OperationStarted {
            operation_id: id.clone(),
            kind: OperationKind::Import,
            total_units: Some(3),
        }),
        OperationEvent::Progress(OperationProgress {
            operation_id: id.clone(),
            completed_units: 1,
            total_units: Some(3),
            message: Some("image-1.raw".to_string()),
        }),
        OperationEvent::ItemCompleted {
            operation_id: id.clone(),
            item_id: "asset-1".to_string(),
        },
        OperationEvent::Completed {
            operation_id: id.clone(),
        },
    ];

    assert!(events.iter().all(|event| event.operation_id() == id));
}

#[test]
fn operation_sink_can_be_a_plain_rust_closure() {
    let mut received = Vec::new();
    let mut sink = |event| received.push(event);

    sink.emit(OperationEvent::Started(OperationStarted {
        operation_id: "thumb-1".to_string(),
        kind: OperationKind::Thumbnail,
        total_units: Some(1),
    }));
    sink.emit(OperationEvent::Completed {
        operation_id: "thumb-1".to_string(),
    });

    assert_eq!(received.len(), 2);
    assert_eq!(received[0].operation_id(), "thumb-1");
    assert_eq!(received[1].operation_id(), "thumb-1");
}

#[test]
fn operation_failure_is_serializable_in_shape_without_framework_error_types() {
    let event = OperationEvent::Failed(OperationFailure {
        operation_id: "develop-1".to_string(),
        code: "decode_failed".to_string(),
        message: "preview decode failed".to_string(),
        recoverable: true,
    });

    assert_eq!(event.operation_id(), "develop-1");
    match event {
        OperationEvent::Failed(failure) => {
            assert_eq!(failure.code, "decode_failed");
            assert!(failure.recoverable);
        }
        _ => panic!("expected failure event"),
    }
}
