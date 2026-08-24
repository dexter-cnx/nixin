use std::ops::Range;
use std::path::{Path, PathBuf};

use dextryx_frontend_api::{read_catalog_projection, AssetQuery, AssetSummaryDto, WorkplaceDto};
use dextryx_platform::{FileDialogPort, FileDialogRequest};

const IMAGE_EXTENSIONS: &[&str] = &[
    "arw", "cr2", "cr3", "nef", "dng", "raf", "orf", "jpg", "jpeg", "png", "tif", "tiff", "webp",
];
const PROJECTION_FILENAME: &str = "catalog-read-projection-v1.tsv";
const APPLICATION_SUPPORT_FOLDER: &str = "com.cnxdev.dextryx.images";
const PROJECTION_PATH_ENV: &str = "DEXTRYX_CATALOG_PROJECTION_PATH";
pub const FILMSTRIP_VIEW_WIDTH: f32 = 900.0;
pub const FILMSTRIP_ITEM_WIDTH: f32 = 116.0;
pub const FILMSTRIP_GAP: f32 = 8.0;
pub const FILMSTRIP_STRIDE: f32 = FILMSTRIP_ITEM_WIDTH + FILMSTRIP_GAP;
pub const FILMSTRIP_OVERSCAN: usize = 3;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WorkspaceSection {
    Library,
    Develop,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum AppCommand {
    ShowLibrary,
    ShowDevelop,
    ShowAllPhotos,
    ShowMissing,
    ShowRecentImports,
    BeginImport,
}

#[derive(Clone, Debug)]
pub struct DesktopAppState {
    pub section: WorkspaceSection,
    pub asset_query: AssetQuery,
    pub selected_import_paths: Vec<PathBuf>,
    pub status: String,
    pub workplaces: Vec<WorkplaceDto>,
    pub active_workplace_id: Option<String>,
    pub assets: Vec<AssetSummaryDto>,
    pub selected_asset_id: Option<String>,
    pub filmstrip_scroll_x: f32,
    projection_path: PathBuf,
}

impl Default for DesktopAppState {
    fn default() -> Self {
        Self::with_projection_path(default_projection_path())
    }
}

impl DesktopAppState {
    pub fn with_projection_path(projection_path: PathBuf) -> Self {
        Self {
            section: WorkspaceSection::Library,
            asset_query: AssetQuery::All,
            selected_import_paths: Vec::new(),
            status: "M3 catalog browser not loaded".to_string(),
            workplaces: Vec::new(),
            active_workplace_id: None,
            assets: Vec::new(),
            selected_asset_id: None,
            filmstrip_scroll_x: 0.0,
            projection_path,
        }
    }

    pub fn apply(&mut self, command: AppCommand) {
        match command {
            AppCommand::ShowLibrary => {
                self.section = WorkspaceSection::Library;
                self.status = "Library workspace".to_string();
            }
            AppCommand::ShowDevelop => {
                self.section = WorkspaceSection::Develop;
                self.status = "Develop workspace shell".to_string();
            }
            AppCommand::ShowAllPhotos => {
                self.section = WorkspaceSection::Library;
                self.asset_query = AssetQuery::All;
                self.status = "Catalog: All photos".to_string();
            }
            AppCommand::ShowMissing => {
                self.section = WorkspaceSection::Library;
                self.asset_query = AssetQuery::Missing;
                self.status = "Catalog: Missing".to_string();
            }
            AppCommand::ShowRecentImports => {
                self.section = WorkspaceSection::Library;
                self.asset_query = AssetQuery::Recent { limit: 500 };
                self.status = "Catalog: Recent imports".to_string();
            }
            AppCommand::BeginImport => {
                self.section = WorkspaceSection::Library;
                self.status = "Import selection requested".to_string();
            }
        }
    }

    pub fn refresh_catalog(&mut self) {
        let previous_selection = self.selected_asset_id.clone();
        let app = match read_catalog_projection(&self.projection_path) {
            Ok(app) => app,
            Err(error) => {
                self.workplaces.clear();
                self.active_workplace_id = None;
                self.assets.clear();
                self.selected_asset_id = None;
                self.filmstrip_scroll_x = 0.0;
                self.status = format!("Catalog projection unavailable: {error:?}");
                return;
            }
        };

        let workplaces = app.list_workplaces();
        let active_workplace_id = workplaces
            .iter()
            .find(|workplace| workplace.is_active)
            .map(|workplace| workplace.id.clone())
            .or_else(|| workplaces.first().map(|workplace| workplace.id.clone()));

        let assets = active_workplace_id
            .as_deref()
            .map(|workplace_id| app.list_assets(workplace_id, self.asset_query))
            .transpose();

        match assets {
            Ok(assets) => {
                let assets = assets.unwrap_or_default();
                let count = assets.len();
                let selected_asset_id = previous_selection
                    .filter(|selected| assets.iter().any(|asset| asset.id == *selected))
                    .or_else(|| assets.first().map(|asset| asset.id.clone()));

                self.workplaces = workplaces;
                self.active_workplace_id = active_workplace_id;
                self.assets = assets;
                self.selected_asset_id = selected_asset_id;
                self.filmstrip_scroll_x = self
                    .filmstrip_scroll_x
                    .clamp(0.0, self.max_filmstrip_scroll());
                self.ensure_selected_asset_visible();
                self.status = format!("Authoritative catalog read: {count} asset(s)");
            }
            Err(error) => {
                self.workplaces = workplaces;
                self.active_workplace_id = active_workplace_id;
                self.assets.clear();
                self.selected_asset_id = None;
                self.filmstrip_scroll_x = 0.0;
                self.status = format!("Catalog read failed: {error:?}");
            }
        }
    }

    pub fn begin_import<D: FileDialogPort>(&mut self, dialog: &D) {
        self.apply(AppCommand::BeginImport);

        let request = FileDialogRequest {
            title: "Import images".to_string(),
            extensions: IMAGE_EXTENSIONS
                .iter()
                .map(|ext| (*ext).to_string())
                .collect(),
            allow_multiple: true,
            pick_directories: false,
        };
        let paths = dialog.pick_paths(&request);

        if paths.is_empty() {
            self.selected_import_paths.clear();
            self.status = "Import cancelled".to_string();
            return;
        }

        let count = paths.len();
        self.selected_import_paths = paths;
        self.status = format!("Import selection: {count} item(s) ready for application execution");
    }

    pub fn select_asset(&mut self, asset_id: &str) -> bool {
        if !self.assets.iter().any(|asset| asset.id == asset_id) {
            return false;
        }

        self.selected_asset_id = Some(asset_id.to_string());
        self.ensure_selected_asset_visible();
        self.status = format!("Selected asset: {asset_id}");
        true
    }

    pub fn selected_asset(&self) -> Option<&AssetSummaryDto> {
        let selected_id = self.selected_asset_id.as_deref()?;
        self.assets.iter().find(|asset| asset.id == selected_id)
    }

    pub fn max_filmstrip_scroll(&self) -> f32 {
        (self.assets.len() as f32 * FILMSTRIP_STRIDE - FILMSTRIP_VIEW_WIDTH).max(0.0)
    }

    pub fn scroll_filmstrip(&mut self, delta: f32) {
        self.filmstrip_scroll_x =
            (self.filmstrip_scroll_x - delta).clamp(0.0, self.max_filmstrip_scroll());
    }

    pub fn filmstrip_visible_range(&self) -> Range<usize> {
        let count = self.assets.len();
        if count == 0 {
            return 0..0;
        }

        let first = (self.filmstrip_scroll_x / FILMSTRIP_STRIDE).floor() as usize;
        let visible_count = (FILMSTRIP_VIEW_WIDTH / FILMSTRIP_STRIDE).ceil() as usize + 1;
        let start = first.saturating_sub(FILMSTRIP_OVERSCAN);
        let end = (first + visible_count + FILMSTRIP_OVERSCAN).min(count);
        start..end
    }

    fn ensure_selected_asset_visible(&mut self) {
        let Some(selected_id) = self.selected_asset_id.as_deref() else {
            self.filmstrip_scroll_x = 0.0;
            return;
        };
        let Some(index) = self.assets.iter().position(|asset| asset.id == selected_id) else {
            self.filmstrip_scroll_x = 0.0;
            return;
        };

        let viewport_start = self.filmstrip_scroll_x;
        let viewport_end = viewport_start + FILMSTRIP_VIEW_WIDTH;
        let item_start = index as f32 * FILMSTRIP_STRIDE;
        let item_end = item_start + FILMSTRIP_ITEM_WIDTH;

        if item_start < viewport_start {
            self.filmstrip_scroll_x = item_start;
        } else if item_end > viewport_end {
            self.filmstrip_scroll_x = item_end - FILMSTRIP_VIEW_WIDTH;
        }

        self.filmstrip_scroll_x = self
            .filmstrip_scroll_x
            .clamp(0.0, self.max_filmstrip_scroll());
    }

    pub fn section_label(&self) -> &'static str {
        match self.section {
            WorkspaceSection::Library => "Library",
            WorkspaceSection::Develop => "Develop",
        }
    }

    pub fn query_label(&self) -> &'static str {
        match self.asset_query {
            AssetQuery::All => "All photos",
            AssetQuery::Missing => "Missing",
            AssetQuery::Recent { .. } => "Recent imports",
        }
    }

    pub fn active_workplace_name(&self) -> Option<&str> {
        let active_id = self.active_workplace_id.as_deref()?;
        self.workplaces
            .iter()
            .find(|workplace| workplace.id == active_id)
            .map(|workplace| workplace.name.as_str())
    }
}

fn default_projection_path() -> PathBuf {
    if let Some(path) = std::env::var_os(PROJECTION_PATH_ENV) {
        return PathBuf::from(path);
    }

    let home = std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."));
    projection_path_for_home(&home, cfg!(target_os = "macos"))
}

fn projection_path_for_home(home: &Path, use_flutter_sandbox: bool) -> PathBuf {
    let support_path = |root: &Path| {
        root.join("Library")
            .join("Application Support")
            .join(APPLICATION_SUPPORT_FOLDER)
            .join(PROJECTION_FILENAME)
    };

    if !use_flutter_sandbox {
        return support_path(home);
    }

    let container_suffix = PathBuf::from("Library")
        .join("Containers")
        .join(APPLICATION_SUPPORT_FOLDER)
        .join("Data");
    if home.ends_with(&container_suffix) {
        return support_path(home);
    }

    support_path(&home.join(container_suffix))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    use std::fs;

    #[derive(Default)]
    struct FakeDialog {
        paths: Vec<PathBuf>,
        requests: RefCell<Vec<FileDialogRequest>>,
    }

    impl FileDialogPort for FakeDialog {
        fn pick_paths(&self, request: &FileDialogRequest) -> Vec<PathBuf> {
            self.requests.borrow_mut().push(request.clone());
            self.paths.clone()
        }
    }

    fn asset(index: usize) -> AssetSummaryDto {
        AssetSummaryDto {
            id: format!("asset-{index}"),
            workplace_id: "workplace-1".to_string(),
            effective_path: PathBuf::from(format!("/tmp/{index}.jpg")),
            storage: dextryx_frontend_api::AssetStorageDto::Linked,
            missing: false,
            import_sequence: index as u64,
        }
    }

    #[test]
    fn catalog_commands_use_frontend_api_queries() {
        let mut state = DesktopAppState::default();

        state.apply(AppCommand::ShowMissing);
        assert_eq!(state.asset_query, AssetQuery::Missing);

        state.apply(AppCommand::ShowRecentImports);
        assert_eq!(state.asset_query, AssetQuery::Recent { limit: 500 });

        state.apply(AppCommand::ShowAllPhotos);
        assert_eq!(state.asset_query, AssetQuery::All);
    }

    #[test]
    fn workspace_navigation_stays_in_plain_rust_state() {
        let mut state = DesktopAppState::default();

        state.apply(AppCommand::ShowDevelop);
        assert_eq!(state.section, WorkspaceSection::Develop);

        state.apply(AppCommand::ShowLibrary);
        assert_eq!(state.section, WorkspaceSection::Library);
    }

    #[test]
    fn import_selection_uses_neutral_file_dialog_port() {
        let dialog = FakeDialog {
            paths: vec![PathBuf::from("/tmp/a.nef"), PathBuf::from("/tmp/b.jpg")],
            ..Default::default()
        };
        let mut state = DesktopAppState::default();

        state.begin_import(&dialog);

        assert_eq!(state.selected_import_paths, dialog.paths);
        assert!(state.status.contains("2 item(s)"));
        let requests = dialog.requests.borrow();
        assert_eq!(requests.len(), 1);
        assert!(requests[0].allow_multiple);
        assert!(!requests[0].pick_directories);
        assert!(requests[0].extensions.iter().any(|ext| ext == "nef"));
    }

    #[test]
    fn cancelled_import_selection_does_not_create_application_work() {
        let dialog = FakeDialog::default();
        let mut state = DesktopAppState {
            selected_import_paths: vec![PathBuf::from("/tmp/stale.jpg")],
            ..DesktopAppState::default()
        };

        state.begin_import(&dialog);

        assert!(state.selected_import_paths.is_empty());
        assert_eq!(state.status, "Import cancelled");
    }

    #[test]
    fn refresh_catalog_loads_authoritative_projection_through_frontend_api() {
        let path = std::env::temp_dir().join(format!(
            "nixin-m3-projection-{}-{}.tsv",
            std::process::id(),
            std::thread::current().name().unwrap_or("test")
        ));
        fs::write(
            &path,
            concat!(
                "DXTR_CATALOG_READ\t1\n",
                "ACTIVE\tworkplace-1\n",
                "WORKPLACE\tworkplace-1\tMy workplace\n",
                "ASSET\tasset-1\tworkplace-1\t/external/a.nef\t\tlinked\t0\t1\n",
                "ASSET\tasset-2\tworkplace-1\t/external/b.jpg\t\tlinked\t0\t2\n",
            ),
        )
        .unwrap();

        let mut state = DesktopAppState::with_projection_path(path.clone());
        state.refresh_catalog();

        assert_eq!(state.active_workplace_name(), Some("My workplace"));
        assert_eq!(state.assets.len(), 2);
        assert_eq!(state.selected_asset_id.as_deref(), Some("asset-1"));
        assert!(state.status.contains("2 asset(s)"));

        assert!(state.select_asset("asset-2"));
        state.refresh_catalog();
        assert_eq!(state.selected_asset_id.as_deref(), Some("asset-2"));

        let _ = fs::remove_file(path);
    }

    #[test]
    fn filmstrip_virtualization_bounds_visible_assets() {
        let mut state = DesktopAppState {
            assets: (0..5_000).map(asset).collect(),
            ..DesktopAppState::default()
        };

        let first = state.filmstrip_visible_range();
        assert!(first.len() < 20);
        assert_eq!(first.start, 0);

        state.scroll_filmstrip(-25_000.0);
        let scrolled = state.filmstrip_visible_range();
        assert!(scrolled.len() < 20);
        assert!(scrolled.start > 0);
        assert!(state.filmstrip_scroll_x <= state.max_filmstrip_scroll());
    }

    #[test]
    fn selection_rejects_unknown_asset_ids() {
        let mut state = DesktopAppState {
            assets: vec![asset(1)],
            ..DesktopAppState::default()
        };

        assert!(state.select_asset("asset-1"));
        assert!(!state.select_asset("asset-404"));
        assert_eq!(state.selected_asset_id.as_deref(), Some("asset-1"));
    }

    #[test]
    fn selection_scrolls_into_filmstrip_viewport() {
        let mut state = DesktopAppState {
            assets: (0..100).map(asset).collect(),
            ..DesktopAppState::default()
        };

        assert!(state.select_asset("asset-80"));
        let range = state.filmstrip_visible_range();
        assert!(range.contains(&80));

        assert!(state.select_asset("asset-2"));
        let range = state.filmstrip_visible_range();
        assert!(range.contains(&2));
    }

    #[test]
    fn macos_projection_path_targets_flutter_app_container() {
        let path = projection_path_for_home(Path::new("/Users/dexter"), true);
        assert_eq!(
            path,
            PathBuf::from(
                "/Users/dexter/Library/Containers/com.cnxdev.dextryx.images/Data/Library/Application Support/com.cnxdev.dextryx.images/catalog-read-projection-v1.tsv"
            )
        );
    }

    #[test]
    fn sandboxed_home_does_not_duplicate_flutter_container_path() {
        let home = Path::new("/Users/dexter/Library/Containers/com.cnxdev.dextryx.images/Data");
        let path = projection_path_for_home(home, true);
        assert_eq!(
            path,
            home.join("Library")
                .join("Application Support")
                .join(APPLICATION_SUPPORT_FOLDER)
                .join(PROJECTION_FILENAME)
        );
    }
}
