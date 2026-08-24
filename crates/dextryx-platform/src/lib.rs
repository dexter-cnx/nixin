use std::fs;
use std::io;
use std::path::{Path, PathBuf};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FileDialogRequest {
    pub title: String,
    pub extensions: Vec<String>,
    pub allow_multiple: bool,
    pub pick_directories: bool,
}

impl FileDialogRequest {
    pub fn single_file(
        title: impl Into<String>,
        extensions: impl IntoIterator<Item = impl Into<String>>,
    ) -> Self {
        Self {
            title: title.into(),
            extensions: extensions.into_iter().map(Into::into).collect(),
            allow_multiple: false,
            pick_directories: false,
        }
    }
}

pub trait FileDialogPort {
    fn pick_paths(&self, request: &FileDialogRequest) -> Vec<PathBuf>;
}

pub trait FileSystemPort: Send + Sync {
    fn exists(&self, path: &Path) -> bool;
    fn is_file(&self, path: &Path) -> io::Result<bool>;
    fn metadata_len(&self, path: &Path) -> io::Result<u64>;
    fn create_dir_all(&self, path: &Path) -> io::Result<()>;
    fn copy(&self, from: &Path, to: &Path) -> io::Result<u64>;
    fn remove_file(&self, path: &Path) -> io::Result<()>;
    fn rename(&self, from: &Path, to: &Path) -> io::Result<()>;
}

#[derive(Clone, Copy, Debug, Default)]
pub struct StdFileSystem;

impl FileSystemPort for StdFileSystem {
    fn exists(&self, path: &Path) -> bool {
        path.exists()
    }

    fn is_file(&self, path: &Path) -> io::Result<bool> {
        Ok(fs::metadata(path)?.is_file())
    }

    fn metadata_len(&self, path: &Path) -> io::Result<u64> {
        Ok(fs::metadata(path)?.len())
    }

    fn create_dir_all(&self, path: &Path) -> io::Result<()> {
        fs::create_dir_all(path)
    }

    fn copy(&self, from: &Path, to: &Path) -> io::Result<u64> {
        fs::copy(from, to)
    }

    fn remove_file(&self, path: &Path) -> io::Result<()> {
        fs::remove_file(path)
    }

    fn rename(&self, from: &Path, to: &Path) -> io::Result<()> {
        fs::rename(from, to)
    }
}
