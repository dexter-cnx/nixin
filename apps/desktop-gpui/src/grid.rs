use std::ops::Range;

pub const GRID_COLUMNS: usize = 4;
pub const GRID_ITEM_WIDTH: f32 = 184.0;
pub const GRID_ITEM_HEIGHT: f32 = 104.0;
pub const GRID_GAP: f32 = 12.0;
pub const GRID_ROW_STRIDE: f32 = GRID_ITEM_HEIGHT + GRID_GAP;
pub const GRID_VIEW_HEIGHT: f32 = 348.0;
pub const GRID_OVERSCAN_ROWS: usize = 2;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct GridViewport {
    pub scroll_y: f32,
}

impl GridViewport {
    pub fn max_scroll(&self, asset_count: usize) -> f32 {
        let rows = asset_count.div_ceil(GRID_COLUMNS);
        (rows as f32 * GRID_ROW_STRIDE - GRID_VIEW_HEIGHT).max(0.0)
    }

    pub fn scroll_by(&mut self, delta: f32, asset_count: usize) {
        self.scroll_y = (self.scroll_y - delta).clamp(0.0, self.max_scroll(asset_count));
    }

    pub fn visible_range(&self, asset_count: usize) -> Range<usize> {
        if asset_count == 0 {
            return 0..0;
        }

        let first_row = (self.scroll_y / GRID_ROW_STRIDE).floor() as usize;
        let visible_rows = (GRID_VIEW_HEIGHT / GRID_ROW_STRIDE).ceil() as usize + 1;
        let start_row = first_row.saturating_sub(GRID_OVERSCAN_ROWS);
        let end_row = (first_row + visible_rows + GRID_OVERSCAN_ROWS)
            .min(asset_count.div_ceil(GRID_COLUMNS));
        let start = start_row * GRID_COLUMNS;
        let end = (end_row * GRID_COLUMNS).min(asset_count);
        start..end
    }

    pub fn ensure_index_visible(&mut self, index: usize, asset_count: usize) {
        if index >= asset_count {
            self.scroll_y = 0.0;
            return;
        }

        let row = index / GRID_COLUMNS;
        let item_start = row as f32 * GRID_ROW_STRIDE;
        let item_end = item_start + GRID_ITEM_HEIGHT;
        let viewport_end = self.scroll_y + GRID_VIEW_HEIGHT;

        if item_start < self.scroll_y {
            self.scroll_y = item_start;
        } else if item_end > viewport_end {
            self.scroll_y = item_end - GRID_VIEW_HEIGHT;
        }

        self.scroll_y = self.scroll_y.clamp(0.0, self.max_scroll(asset_count));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn visible_range_is_bounded_for_large_catalogs() {
        let mut viewport = GridViewport::default();
        let first = viewport.visible_range(5_000);
        assert!(first.len() < 40);
        assert_eq!(first.start, 0);

        viewport.scroll_by(-25_000.0, 5_000);
        let scrolled = viewport.visible_range(5_000);
        assert!(scrolled.len() < 40);
        assert!(scrolled.start > 0);
        assert!(viewport.scroll_y <= viewport.max_scroll(5_000));
    }

    #[test]
    fn ensure_index_visible_tracks_selection() {
        let mut viewport = GridViewport::default();
        viewport.ensure_index_visible(1_200, 5_000);
        let visible = viewport.visible_range(5_000);
        assert!(visible.contains(&1_200));

        viewport.ensure_index_visible(2, 5_000);
        assert_eq!(viewport.scroll_y, 0.0);
    }
}
