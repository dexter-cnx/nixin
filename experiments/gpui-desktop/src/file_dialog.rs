use std::path::PathBuf;

use dextryx_platform::{FileDialogPort, FileDialogRequest};
use rfd_backend::FileDialog;

#[derive(Clone, Copy, Debug, Default)]
pub struct RfdFileDialogAdapter;

impl FileDialogPort for RfdFileDialogAdapter {
    fn pick_paths(&self, request: &FileDialogRequest) -> Vec<PathBuf> {
        let mut dialog = FileDialog::new().set_title(&request.title);
        if !request.extensions.is_empty() {
            let extensions = request
                .extensions
                .iter()
                .map(String::as_str)
                .collect::<Vec<_>>();
            dialog = dialog.add_filter("Supported files", &extensions);
        }

        if request.pick_directories {
            return dialog.pick_folder().into_iter().collect();
        }

        if request.allow_multiple {
            return dialog.pick_files().unwrap_or_default();
        }

        dialog.pick_file().into_iter().collect()
    }
}
