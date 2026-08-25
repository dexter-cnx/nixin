use std::collections::hash_map::DefaultHasher;
use std::collections::HashSet;
use std::fs;
use std::hash::{Hash, Hasher};
use std::ops::Range;
use std::path::PathBuf;
use std::time::UNIX_EPOCH;

#[cfg(target_os = "macos")]
use std::process::Command;

use dextryx_frontend_api::AssetSummaryDto;

pub const MAX_THUMBNAIL_WORKING_SET: usize = 64;
const MAX_THUMBNAIL_GENERATION_ATTEMPTS_PER_SYNC: usize = 2;
const THUMBNAIL_MAX_EDGE: u32 = 320;

const SUPPORTED_RASTER_EXTENSIONS: &[&str] =
    &["jpg", "jpeg", "png", "gif", "webp", "tif", "tiff", "bmp"];

#[derive(Clone, Debug, Default)]
pub struct ThumbnailWorkingSet {
    asset_ids: HashSet<String>,
}

impl ThumbnailWorkingSet {
    pub fn sync(
        &mut self,
        assets: &[AssetSummaryDto],
        grid_range: Range<usize>,
        filmstrip_range: Range<usize>,
        selected_asset_id: Option<&str>,
    ) {
        self.asset_ids.clear();
        let mut ordered_ids = Vec::new();

        if let Some(selected_asset_id) = selected_asset_id {
            if self.insert(selected_asset_id) {
                ordered_ids.push(selected_asset_id.to_string());
            }
        }

        for index in grid_range.chain(filmstrip_range) {
            if self.asset_ids.len() >= MAX_THUMBNAIL_WORKING_SET {
                break;
            }
            if let Some(asset) = assets.get(index) {
                if self.insert(&asset.id) {
                    ordered_ids.push(asset.id.clone());
                }
            }
        }

        let mut attempts = 0;
        for asset_id in ordered_ids {
            if attempts >= MAX_THUMBNAIL_GENERATION_ATTEMPTS_PER_SYNC {
                break;
            }
            let Some(asset) = assets.iter().find(|asset| asset.id == asset_id) else {
                continue;
            };
            if asset.missing || !is_supported_raster(asset) || thumbnail_exists(asset) {
                continue;
            }
            attempts += 1;
            let _ = prepare_thumbnail(asset);
        }
    }

    pub fn thumbnail_path(&self, asset: &AssetSummaryDto) -> Option<PathBuf> {
        if asset.missing || !self.asset_ids.contains(&asset.id) || !is_supported_raster(asset) {
            return None;
        }

        let path = cache_path(asset)?;
        path.is_file().then_some(path)
    }

    #[cfg(test)]
    fn len(&self) -> usize {
        self.asset_ids.len()
    }

    fn insert(&mut self, asset_id: &str) -> bool {
        if self.asset_ids.len() >= MAX_THUMBNAIL_WORKING_SET {
            return false;
        }
        self.asset_ids.insert(asset_id.to_string())
    }
}

fn is_supported_raster(asset: &AssetSummaryDto) -> bool {
    asset
        .effective_path
        .extension()
        .and_then(|extension| extension.to_str())
        .map(|extension| extension.to_ascii_lowercase())
        .is_some_and(|extension| SUPPORTED_RASTER_EXTENSIONS.contains(&extension.as_str()))
}

fn thumbnail_exists(asset: &AssetSummaryDto) -> bool {
    cache_path(asset).is_some_and(|path| path.is_file())
}

#[cfg(target_os = "macos")]
fn prepare_thumbnail(asset: &AssetSummaryDto) -> Result<(), String> {
    let Some(cache_path) = cache_path(asset) else {
        return Ok(());
    };
    let Some(parent) = cache_path.parent() else {
        return Ok(());
    };
    fs::create_dir_all(parent).map_err(|error| error.to_string())?;

    let partial = cache_path.with_extension("partial.png");
    let status = Command::new("/usr/bin/sips")
        .arg("-Z")
        .arg(THUMBNAIL_MAX_EDGE.to_string())
        .arg("-s")
        .arg("format")
        .arg("png")
        .arg(&asset.effective_path)
        .arg("--out")
        .arg(&partial)
        .status()
        .map_err(|error| error.to_string())?;

    if !status.success() {
        let _ = fs::remove_file(&partial);
        return Err(format!("sips failed with status {status}"));
    }

    fs::rename(&partial, &cache_path).map_err(|error| error.to_string())?;
    Ok(())
}

#[cfg(not(target_os = "macos"))]
fn prepare_thumbnail(_asset: &AssetSummaryDto) -> Result<(), String> {
    Ok(())
}

fn cache_path(asset: &AssetSummaryDto) -> Option<PathBuf> {
    if !is_supported_raster(asset) {
        return None;
    }

    let metadata = fs::metadata(&asset.effective_path).ok();
    let mut hasher = DefaultHasher::new();
    asset.effective_path.hash(&mut hasher);
    if let Some(metadata) = metadata {
        metadata.len().hash(&mut hasher);
        if let Ok(modified) = metadata.modified() {
            modified
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_nanos()
                .hash(&mut hasher);
        }
    }
    let key = hasher.finish();

    Some(
        std::env::temp_dir()
            .join("dextryx-images")
            .join("thumbnails-v1")
            .join(format!("{key:016x}.png")),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use dextryx_frontend_api::AssetStorageDto;

    fn asset(index: usize, extension: &str) -> AssetSummaryDto {
        AssetSummaryDto {
            id: format!("asset-{index}"),
            workplace_id: "workplace-1".to_string(),
            effective_path: PathBuf::from(format!("/tmp/{index}.{extension}")),
            storage: AssetStorageDto::Linked,
            missing: false,
            import_sequence: index as u64,
        }
    }

    #[test]
    fn working_set_is_bounded_and_keeps_selection() {
        let assets = (0..200)
            .map(|index| asset(index, "jpg"))
            .collect::<Vec<_>>();
        let mut working_set = ThumbnailWorkingSet::default();

        working_set.sync(&assets, 0..100, 100..150, Some("asset-199"));

        assert_eq!(working_set.len(), MAX_THUMBNAIL_WORKING_SET);
        assert!(working_set.asset_ids.contains("asset-199"));
    }

    #[test]
    fn raw_and_missing_assets_never_get_thumbnail_paths() {
        let raw = asset(2, "nef");
        let mut missing = asset(3, "png");
        missing.missing = true;
        let assets = vec![raw.clone(), missing.clone()];
        let mut working_set = ThumbnailWorkingSet::default();

        working_set.sync(&assets, 0..2, 0..0, None);

        assert!(working_set.thumbnail_path(&raw).is_none());
        assert!(working_set.thumbnail_path(&missing).is_none());
    }

    #[test]
    fn cache_path_is_stable_for_same_asset() {
        let raster = asset(1, "jpg");
        assert_eq!(cache_path(&raster), cache_path(&raster));
    }
}
