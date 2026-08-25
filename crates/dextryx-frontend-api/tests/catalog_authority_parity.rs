use std::path::PathBuf;

use dextryx_core::{
    snapshot_catalog_repository, AssetStorageMode, AuthoritativeCatalogPersistence,
    AuthoritativeCatalogProjection, CatalogAsset, CatalogMutation, WorkplaceSummary,
};
use dextryx_frontend_api::{parse_catalog_projection, AssetQuery, AssetStorageDto};
use dextryx_storage::CandidateCatalogStore;

const SHARED_PARITY_FIXTURE: &str =
    include_str!("../../../test/fixtures/catalog_authority_parity_v1.tsv");

fn parity_projection() -> AuthoritativeCatalogProjection {
    AuthoritativeCatalogProjection {
        workplaces: vec![
            WorkplaceSummary {
                id: "workplace-my".to_string(),
                name: "My workplace".to_string(),
            },
            WorkplaceSummary {
                id: "workplace-travel".to_string(),
                name: "Travel\t2026".to_string(),
            },
        ],
        active_workplace_id: Some("workplace-travel".to_string()),
        assets: vec![
            CatalogAsset {
                id: "asset-managed".to_string(),
                workplace_id: "workplace-my".to_string(),
                source_path: PathBuf::from("/external/managed.nef"),
                managed_path: Some(PathBuf::from("/managed/library/managed.nef")),
                storage_mode: AssetStorageMode::Managed,
                missing: false,
                import_sequence: 0,
            },
            CatalogAsset {
                id: "asset-linked-a".to_string(),
                workplace_id: "workplace-travel".to_string(),
                source_path: PathBuf::from("/external/a.jpg"),
                managed_path: None,
                storage_mode: AssetStorageMode::Linked,
                missing: false,
                import_sequence: 1,
            },
            CatalogAsset {
                id: "asset-linked-b".to_string(),
                workplace_id: "workplace-travel".to_string(),
                source_path: PathBuf::from("/external/b.jpg"),
                managed_path: None,
                storage_mode: AssetStorageMode::Linked,
                missing: true,
                import_sequence: 2,
            },
        ],
    }
}

#[test]
fn rust_parser_accepts_shared_dart_authority_fixture() {
    let app = parse_catalog_projection(SHARED_PARITY_FIXTURE)
        .expect("shared catalog authority fixture must parse");

    let workplaces = app.list_workplaces();
    assert_eq!(workplaces.len(), 2);
    assert_eq!(workplaces[0].id, "workplace-my");
    assert_eq!(workplaces[1].id, "workplace-travel");
    assert_eq!(workplaces[1].name, "Travel\t2026");
    assert!(workplaces[1].is_active);

    let managed = app
        .list_assets("workplace-my", AssetQuery::All)
        .expect("managed workplace must be readable");
    assert_eq!(managed.len(), 1);
    assert_eq!(managed[0].id, "asset-managed");
    assert_eq!(managed[0].storage, AssetStorageDto::Managed);
    assert_eq!(
        managed[0].effective_path,
        PathBuf::from("/managed/library/managed.nef")
    );

    let travel = app
        .list_assets("workplace-travel", AssetQuery::All)
        .expect("travel workplace must be readable");
    assert_eq!(travel.len(), 2);
    assert_eq!(travel[0].id, "asset-linked-a");
    assert_eq!(travel[1].id, "asset-linked-b");
    assert_eq!(travel[0].storage, AssetStorageDto::Linked);
    assert!(travel[1].missing);
}

#[test]
fn candidate_storage_preserves_parity_and_mutation_semantics() {
    let expected = parity_projection();
    let mut store = CandidateCatalogStore::from_projection(expected.clone())
        .expect("shared parity projection must qualify");

    assert_eq!(
        snapshot_catalog_repository(&store).expect("candidate snapshot must qualify"),
        expected
    );

    store
        .apply_mutation(CatalogMutation::SetActiveWorkplace {
            workplace_id: "workplace-my".to_string(),
        })
        .expect("active workplace mutation must succeed");
    store
        .apply_mutation(CatalogMutation::RelinkAsset {
            asset_id: "asset-linked-b".to_string(),
            replacement_path: PathBuf::from("/replacement/b.jpg"),
        })
        .expect("relink mutation must succeed");
    store
        .apply_mutation(CatalogMutation::RemoveFromCatalog {
            asset_id: "asset-linked-a".to_string(),
        })
        .expect("remove mutation must succeed");

    let after = snapshot_catalog_repository(&store).expect("post-mutation snapshot must qualify");
    assert_eq!(after.active_workplace_id.as_deref(), Some("workplace-my"));
    assert!(after.assets.iter().all(|asset| asset.id != "asset-linked-a"));
    let relinked = after
        .assets
        .iter()
        .find(|asset| asset.id == "asset-linked-b")
        .expect("relinked asset must remain in catalog");
    assert_eq!(relinked.source_path, PathBuf::from("/replacement/b.jpg"));
    assert!(!relinked.missing);
}
