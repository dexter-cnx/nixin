use std::path::PathBuf;

use dextryx_frontend_api::{parse_catalog_projection, AssetQuery, AssetStorageDto};

const SHARED_PARITY_FIXTURE: &str =
    include_str!("../../../test/fixtures/catalog_authority_parity_v1.tsv");

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
