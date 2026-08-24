use std::path::PathBuf;

use dextryx_frontend_api::AssetQuery;
use dextryx_platform::{FileDialogPort, FileDialogRequest};

const IMAGE_EXTENSIONS: &[&str] = &[
    "arw", "cr2", "cr3", "nef", "dng", "raf", "orf", "jpg", "jpeg", "png", "tif", "tiff", "webp",
];

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

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DesktopAppState {
    pub section: WorkspaceSection,
    pub asset_query: AssetQuery,
    pub selected_import_paths: Vec<PathBuf>,
    pub status: String,
}

impl Default for DesktopAppState {
    fn default() -> Self {
        Self {
            section: WorkspaceSection::Library,
            asset_query: AssetQuery::All,
            selected_import_paths: Vec::new(),
            status: "M1 production GPUI shell ready".to_string(),
        }
    }
}

impl DesktopAppState {
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
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;

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
        let mut state = DesktopAppState::default();
        state.selected_import_paths = vec![PathBuf::from("/tmp/stale.jpg")];

        state.begin_import(&dialog);

        assert!(state.selected_import_paths.is_empty());
        assert_eq!(state.status, "Import cancelled");
    }
}
