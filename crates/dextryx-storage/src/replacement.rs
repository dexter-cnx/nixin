use std::fs;
use std::path::Path;

/// Replace one snapshot destination with a prepared temporary file.
///
/// On Unix targets, `rename` replaces an existing destination within the same
/// filesystem namespace without first deleting it. This removes the explicit
/// destination-missing window that existed in the earlier remove-then-rename
/// qualification path.
///
/// This primitive is intentionally not treated as proof of full durable commit:
/// parent-directory sync, crash recovery, single-writer coordination, and
/// Windows replacement semantics remain separate qualification requirements.
#[cfg(unix)]
pub fn replace_snapshot(temp: &Path, destination: &Path) -> std::io::Result<()> {
    fs::rename(temp, destination)
}

/// Windows is not yet qualified for destination replacement in this M4 slice.
/// Returning `Unsupported` prevents callers from silently falling back to a
/// remove-then-rename sequence that would recreate the destination-missing gap.
#[cfg(windows)]
pub fn replace_snapshot(_temp: &Path, _destination: &Path) -> std::io::Result<()> {
    Err(std::io::Error::new(
        std::io::ErrorKind::Unsupported,
        "atomic catalog replacement is not qualified on Windows",
    ))
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::path::PathBuf;
    use std::time::{SystemTime, UNIX_EPOCH};

    use super::*;

    fn temp_dir(test_name: &str) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!(
            "dextryx-replacement-{test_name}-{}-{nonce}",
            std::process::id()
        ))
    }

    #[cfg(unix)]
    #[test]
    fn replacement_overwrites_existing_destination_without_predelete() {
        let dir = temp_dir("overwrite");
        fs::create_dir_all(&dir).unwrap();
        let destination = dir.join("catalog.snapshot");
        let temp = dir.join("catalog.snapshot.next");
        fs::write(&destination, b"old").unwrap();
        fs::write(&temp, b"new").unwrap();

        replace_snapshot(&temp, &destination).unwrap();

        assert_eq!(fs::read(&destination).unwrap(), b"new");
        assert!(!temp.exists());
        let _ = fs::remove_dir_all(dir);
    }

    #[cfg(unix)]
    #[test]
    fn failed_replacement_keeps_existing_destination() {
        let dir = temp_dir("failed");
        fs::create_dir_all(&dir).unwrap();
        let destination = dir.join("catalog.snapshot");
        let missing_temp = dir.join("missing.next");
        fs::write(&destination, b"old").unwrap();

        assert!(replace_snapshot(&missing_temp, &destination).is_err());
        assert_eq!(fs::read(&destination).unwrap(), b"old");
        let _ = fs::remove_dir_all(dir);
    }
}
