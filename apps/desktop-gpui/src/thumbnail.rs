use std::collections::HashSet;
use std::ops::Range;
use std::path::PathBuf;

use dextryx_frontend_api::AssetSummaryDto;

pub const MAX_THUMBNAIL_WORKING_SET: usize = 64;

const SUPPORTED_RASTER_EXTENSIONS: &[&str] = &[
    "avif", "jpg", "jpeg", "png", "gif", "webp", "tif", "tiff", "tga", "dds", "bmp", "ico", "hdr",
    "exr", "pbm", "pam", "ppm", "pgm", "ff", "farbfeld", "qoi", "svg",
];

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

        if let Some(selected_asset_id) = selected_asset_id {
            self.insert(selected_asset_id);
        }

        for index in grid_range.chain(filmstrip_range) {
            if self.asset_ids.len() >= MAX_THUMBNAIL_WORKING_SET {
                break;
            }
            if let Some(asset) = assets.get(index) {
                self.insert(&asset.id);
            }
        }
    }

    pub fn thumbnail_path(&self, asset: &AssetSummaryDto) -> Option<PathBuf> {
        if asset.missing || !self.asset_ids.contains(&asset.id) {
            return None;
        }

        let extension = asset
            .effective_path
            .extension()
            .and_then(|extension| extension.to_str())?
            .to_ascii_lowercase();
        if !SUPPORTED_RASTER_EXTENSIONS.contains(&extension.as_str()) {
            return None;
        }

        Some(asset.effective_path.clone())
    }

    #[cfg(test)]
    fn len(&self) -> usize {
        self.asset_ids.len()
    }

    fn insert(&mut self, asset_id: &str) {
        if self.asset_ids.len() < MAX_THUMBNAIL_WORKING_SET {
            self.asset_ids.insert(asset_id.to_string());
        }
    }
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
        assert!(working_set.thumbnail_path(&assets[199]).is_some());
    }

    #[test]
    fn raster_assets_are_loadable_but_raw_and_missing_assets_fall_back() {
        let raster = asset(1, "jpg");
        let raw = asset(2, "nef");
        let mut missing = asset(3, "png");
        missing.missing = true;
        let assets = vec![raster.clone(), raw.clone(), missing.clone()];
        let mut working_set = ThumbnailWorkingSet::default();

        working_set.sync(&assets, 0..3, 0..0, None);

        assert_eq!(
            working_set.thumbnail_path(&raster),
            Some(raster.effective_path)
        );
        assert!(working_set.thumbnail_path(&raw).is_none());
        assert!(working_set.thumbnail_path(&missing).is_none());
    }
}
