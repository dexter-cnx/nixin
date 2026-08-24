use dextryx_frontend_api::AssetQuery;

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
    pub status: String,
}

impl Default for DesktopAppState {
    fn default() -> Self {
        Self {
            section: WorkspaceSection::Library,
            asset_query: AssetQuery::All,
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
                self.status = "Import command routed to application boundary next".to_string();
            }
        }
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
}
