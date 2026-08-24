mod file_dialog;
mod file_dialog_compat;

mod rfd {
    pub use crate::file_dialog_compat::FileDialog;
}

include!("main.rs");
