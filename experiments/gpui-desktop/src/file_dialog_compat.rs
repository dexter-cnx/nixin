use std::path::PathBuf;

use dextryx_platform::{FileDialogPort, FileDialogRequest};

use crate::file_dialog::RfdFileDialogAdapter;

#[derive(Clone, Debug, Default)]
pub struct FileDialog {
    title: String,
    extensions: Vec<String>,
}

impl FileDialog {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn set_title(mut self, title: impl Into<String>) -> Self {
        self.title = title.into();
        self
    }

    pub fn add_filter(mut self, _name: &str, extensions: &[&str]) -> Self {
        self.extensions = extensions.iter().map(|value| (*value).to_string()).collect();
        self
    }

    pub fn pick_file(self) -> Option<PathBuf> {
        let request = FileDialogRequest::single_file(self.title, self.extensions);
        RfdFileDialogAdapter
            .pick_paths(&request)
            .into_iter()
            .next()
    }
}
