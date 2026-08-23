use std::fs;

use dextryx_platform::{FileDialogRequest, FileSystemPort, StdFileSystem};

#[test]
fn file_dialog_request_is_framework_neutral() {
    let request = FileDialogRequest::single_file(
        "Open image",
        ["jpg", "jpeg", "png", "arw", "cr3", "nef"],
    );

    assert_eq!(request.title, "Open image");
    assert!(!request.allow_multiple);
    assert!(!request.pick_directories);
    assert!(request.extensions.iter().any(|ext| ext == "arw"));
}

#[test]
fn std_filesystem_implements_basic_port_contract() {
    let root = std::env::temp_dir().join(format!(
        "dextryx-platform-test-{}",
        std::process::id()
    ));
    let source = root.join("source.txt");
    let copied = root.join("copied.txt");
    let renamed = root.join("renamed.txt");
    let fs_port = StdFileSystem;

    let _ = fs::remove_dir_all(&root);
    fs_port.create_dir_all(&root).unwrap();
    fs::write(&source, b"dextryx").unwrap();

    assert!(fs_port.exists(&source));
    assert_eq!(fs_port.metadata_len(&source).unwrap(), 7);
    assert_eq!(fs_port.copy(&source, &copied).unwrap(), 7);
    fs_port.rename(&copied, &renamed).unwrap();
    assert!(fs_port.exists(&renamed));
    fs_port.remove_file(&renamed).unwrap();
    assert!(!fs_port.exists(&renamed));

    fs::remove_dir_all(&root).unwrap();
}
