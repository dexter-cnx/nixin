use std::collections::{HashMap, HashSet, VecDeque};
use std::path::PathBuf;
use std::sync::Arc;

use gpui::{
    App, Bounds, Context, MouseButton, MouseDownEvent, MouseMoveEvent, MouseUpEvent, PinchEvent,
    Pixels, Point, RenderImage, ScrollDelta, ScrollWheelEvent, Window, WindowBounds, WindowOptions,
    div, img, point, prelude::*, px, rgb, size,
};
use gpui_platform::application;
use rfd::FileDialog;

const VIEWPORT_WIDTH: f32 = 720.0;
const VIEWPORT_HEIGHT: f32 = 480.0;
const MIN_ZOOM: f32 = 0.1;
const MAX_ZOOM: f32 = 8.0;
const SCROLL_LINE_MULTIPLIER: f32 = 20.0;

const S2_ASSET_COUNT: usize = 5_000;
const FILMSTRIP_VIEW_WIDTH: f32 = 900.0;
const FILMSTRIP_ITEM_WIDTH: f32 = 96.0;
const FILMSTRIP_GAP: f32 = 8.0;
const FILMSTRIP_STRIDE: f32 = FILMSTRIP_ITEM_WIDTH + FILMSTRIP_GAP;
const FILMSTRIP_OVERSCAN: usize = 3;
const THUMB_WIDTH: u32 = 88;
const THUMB_HEIGHT: u32 = 54;
const THUMB_MAX_IN_FLIGHT: usize = 4;
const THUMB_CACHE_CAPACITY: usize = 128;

fn build_synthetic_thumbnail(asset_ix: usize) -> image::RgbaImage {
    let mut image = image::RgbaImage::new(THUMB_WIDTH, THUMB_HEIGHT);
    let seed = asset_ix as u32;

    for (x, y, pixel) in image.enumerate_pixels_mut() {
        let r = ((x * 3 + seed * 13) % 255) as u8;
        let g = ((y * 5 + seed * 7) % 255) as u8;
        let b = (((x + y) * 2 + seed * 17) % 255) as u8;
        // GPUI RenderImage expects BGRA-oriented bytes on the pinned renderer path.
        *pixel = image::Rgba([b, g, r, 255]);
    }

    image
}

struct DextryxSpike {
    engine_ready: bool,
    image_path: Option<PathBuf>,
    image_dimensions: Option<(u32, u32)>,
    render_image: Option<Arc<RenderImage>>,
    zoom: f32,
    pan_offset: Point<Pixels>,
    last_mouse_position: Option<Point<Pixels>>,
    selected_asset: usize,

    filmstrip_scroll_x: f32,
    thumbnails: HashMap<usize, Arc<RenderImage>>,
    thumbnail_pending: HashSet<usize>,
    thumbnail_queue: VecDeque<usize>,
    thumbnail_cache_order: VecDeque<usize>,
    thumbnail_in_flight: usize,

    status: String,
}

impl DextryxSpike {
    fn panel_label(text: &'static str) -> impl IntoElement {
        div().text_sm().text_color(rgb(0xb8bcc6)).child(text)
    }

    fn toolbar_button(
        id: &'static str,
        label: impl Into<String>,
        cx: &mut Context<Self>,
        on_click: impl Fn(&mut Self, &mut Context<Self>) + 'static,
    ) -> impl IntoElement {
        div()
            .id(id)
            .px_3()
            .py_1()
            .rounded_md()
            .border_1()
            .border_color(rgb(0x3c414a))
            .bg(rgb(0x24272d))
            .text_sm()
            .child(label.into())
            .active(|this| this.opacity(0.75))
            .on_click(cx.listener(move |this, _, _, cx| on_click(this, cx)))
    }

    fn fit_zoom_for(width: u32, height: u32) -> f32 {
        let scale_x = VIEWPORT_WIDTH / width.max(1) as f32;
        let scale_y = VIEWPORT_HEIGHT / height.max(1) as f32;
        scale_x.min(scale_y).min(1.0)
    }

    fn open_image(&mut self, cx: &mut Context<Self>) {
        let selected = FileDialog::new()
            .set_title("Open image or RAW preview")
            .add_filter(
                "Images / RAW previews",
                &[
                    "jpg", "jpeg", "png", "tif", "tiff", "webp", "arw", "cr2", "cr3", "nef",
                    "dng", "raf", "orf",
                ],
            )
            .pick_file();

        let Some(path) = selected else {
            return;
        };

        match raw_engine::develop_preview(&path) {
            Ok(developed) => {
                let width = developed.width;
                let height = developed.height;
                let mut pixels = developed.data;
                let expected_len = width as usize * height as usize * 4;

                if pixels.len() != expected_len {
                    self.status = format!(
                        "Engine returned invalid RGBA buffer: expected {expected_len} bytes, got {}",
                        pixels.len()
                    );
                    cx.notify();
                    return;
                }

                for pixel in pixels.chunks_exact_mut(4) {
                    pixel.swap(0, 2);
                }

                let Some(buffer) = image::RgbaImage::from_raw(width, height, pixels) else {
                    self.status = "Unable to adopt raw-engine pixel buffer".to_string();
                    cx.notify();
                    return;
                };

                self.image_path = Some(path.clone());
                self.image_dimensions = Some((width, height));
                self.render_image = Some(Arc::new(RenderImage::new(vec![image::Frame::new(buffer)])));
                self.zoom = Self::fit_zoom_for(width, height);
                self.pan_offset = Point::default();
                self.last_mouse_position = None;
                self.status = format!(
                    "{} — {} × {} — raw-engine buffer",
                    path.file_name()
                        .and_then(|name| name.to_str())
                        .unwrap_or("image"),
                    width,
                    height
                );
            }
            Err(error) => self.status = format!("raw-engine preview failed: {error}"),
        }
        cx.notify();
    }

    fn fit(&mut self, cx: &mut Context<Self>) {
        if let Some((width, height)) = self.image_dimensions {
            self.zoom = Self::fit_zoom_for(width, height);
            self.pan_offset = Point::default();
            cx.notify();
        }
    }

    fn one_to_one(&mut self, cx: &mut Context<Self>) {
        self.zoom = 1.0;
        self.pan_offset = Point::default();
        cx.notify();
    }

    fn zoom_by(&mut self, factor: f32, cx: &mut Context<Self>) {
        self.zoom = (self.zoom * factor).clamp(MIN_ZOOM, MAX_ZOOM);
        cx.notify();
    }

    fn is_dragging(&self) -> bool {
        self.last_mouse_position.is_some()
    }

    fn handle_mouse_down(
        &mut self,
        event: &MouseDownEvent,
        _window: &mut Window,
        cx: &mut Context<Self>,
    ) {
        if event.button == MouseButton::Left || event.button == MouseButton::Middle {
            self.last_mouse_position = Some(event.position);
            cx.notify();
        }
    }

    fn handle_mouse_up(
        &mut self,
        _event: &MouseUpEvent,
        _window: &mut Window,
        cx: &mut Context<Self>,
    ) {
        self.last_mouse_position = None;
        cx.notify();
    }

    fn handle_mouse_move(
        &mut self,
        event: &MouseMoveEvent,
        _window: &mut Window,
        cx: &mut Context<Self>,
    ) {
        if let Some(last_position) = self.last_mouse_position {
            self.pan_offset += event.position - last_position;
            self.last_mouse_position = Some(event.position);
            cx.notify();
        }
    }

    fn handle_scroll_wheel(
        &mut self,
        event: &ScrollWheelEvent,
        _window: &mut Window,
        cx: &mut Context<Self>,
    ) {
        if event.modifiers.control || event.modifiers.platform {
            let delta: f32 = match event.delta {
                ScrollDelta::Pixels(pixels) => pixels.y.into(),
                ScrollDelta::Lines(lines) => lines.y * SCROLL_LINE_MULTIPLIER,
            };
            let zoom_factor = if delta > 0.0 {
                1.0 + delta.abs() * 0.01
            } else {
                1.0 / (1.0 + delta.abs() * 0.01)
            };
            self.zoom = (self.zoom * zoom_factor).clamp(MIN_ZOOM, MAX_ZOOM);
        } else {
            let delta = match event.delta {
                ScrollDelta::Pixels(pixels) => pixels,
                ScrollDelta::Lines(lines) => lines.map(|d| px(d * SCROLL_LINE_MULTIPLIER)),
            };
            self.pan_offset += delta;
        }
        cx.notify();
    }

    fn handle_pinch(
        &mut self,
        event: &PinchEvent,
        _window: &mut Window,
        cx: &mut Context<Self>,
    ) {
        self.zoom = (self.zoom * (1.0 + event.delta)).clamp(MIN_ZOOM, MAX_ZOOM);
        cx.notify();
    }

    fn viewport_content(&self) -> impl IntoElement {
        let (Some(image), Some((width, height))) =
            (self.render_image.clone(), self.image_dimensions)
        else {
            return div()
                .size_full()
                .flex()
                .flex_col()
                .gap_2()
                .items_center()
                .justify_center()
                .child("Image viewport")
                .child(
                    div()
                        .text_sm()
                        .text_color(rgb(0x858a94))
                        .child("Open a raster or RAW file to validate direct engine-buffer rendering"),
                )
                .into_any_element();
        };

        let scaled_width = width as f32 * self.zoom;
        let scaled_height = height as f32 * self.zoom;
        let left = px((VIEWPORT_WIDTH - scaled_width) / 2.0) + self.pan_offset.x;
        let top = px((VIEWPORT_HEIGHT - scaled_height) / 2.0) + self.pan_offset.y;

        div()
            .relative()
            .size_full()
            .child(
                div()
                    .absolute()
                    .left(left)
                    .top(top)
                    .w(px(scaled_width))
                    .h(px(scaled_height))
                    .child(img(image).w(px(scaled_width)).h(px(scaled_height))),
            )
            .into_any_element()
    }

    fn max_filmstrip_scroll() -> f32 {
        (S2_ASSET_COUNT as f32 * FILMSTRIP_STRIDE - FILMSTRIP_VIEW_WIDTH).max(0.0)
    }

    fn filmstrip_visible_range(&self) -> std::ops::Range<usize> {
        let first = (self.filmstrip_scroll_x / FILMSTRIP_STRIDE).floor() as usize;
        let visible_count = (FILMSTRIP_VIEW_WIDTH / FILMSTRIP_STRIDE).ceil() as usize + 1;
        let start = first.saturating_sub(FILMSTRIP_OVERSCAN);
        let end = (first + visible_count + FILMSTRIP_OVERSCAN).min(S2_ASSET_COUNT);
        start..end
    }

    fn handle_filmstrip_scroll(
        &mut self,
        event: &ScrollWheelEvent,
        _window: &mut Window,
        cx: &mut Context<Self>,
    ) {
        let delta = match event.delta {
            ScrollDelta::Pixels(pixels) => {
                let x: f32 = pixels.x.into();
                let y: f32 = pixels.y.into();
                if x.abs() > y.abs() { x } else { y }
            }
            ScrollDelta::Lines(lines) => {
                let raw = if lines.x.abs() > lines.y.abs() {
                    lines.x
                } else {
                    lines.y
                };
                raw * 48.0
            }
        };

        self.filmstrip_scroll_x =
            (self.filmstrip_scroll_x - delta).clamp(0.0, Self::max_filmstrip_scroll());
        cx.notify();
    }

    fn schedule_visible_thumbnails(
        &mut self,
        visible: std::ops::Range<usize>,
        cx: &mut Context<Self>,
    ) {
        // Any queued-but-not-started work outside the latest visible/overscan range is stale.
        self.thumbnail_queue.clear();

        for asset_ix in visible {
            if self.thumbnails.contains_key(&asset_ix) || self.thumbnail_pending.contains(&asset_ix) {
                continue;
            }
            self.thumbnail_queue.push_back(asset_ix);
        }

        self.pump_thumbnail_jobs(cx);
    }

    fn pump_thumbnail_jobs(&mut self, cx: &mut Context<Self>) {
        while self.thumbnail_in_flight < THUMB_MAX_IN_FLIGHT {
            let Some(asset_ix) = self.thumbnail_queue.pop_front() else {
                break;
            };

            if self.thumbnails.contains_key(&asset_ix) || self.thumbnail_pending.contains(&asset_ix) {
                continue;
            }

            self.thumbnail_pending.insert(asset_ix);
            self.thumbnail_in_flight += 1;

            let background = cx
                .background_executor()
                .spawn(async move { build_synthetic_thumbnail(asset_ix) });

            cx.spawn(async move |this, cx| {
                let buffer = background.await;
                let _ = this.update(cx, |this, cx| {
                    this.thumbnail_pending.remove(&asset_ix);
                    this.thumbnail_in_flight = this.thumbnail_in_flight.saturating_sub(1);

                    let render_image =
                        Arc::new(RenderImage::new(vec![image::Frame::new(buffer)]));
                    this.thumbnails.insert(asset_ix, render_image);
                    this.thumbnail_cache_order.retain(|ix| *ix != asset_ix);
                    this.thumbnail_cache_order.push_back(asset_ix);

                    while this.thumbnail_cache_order.len() > THUMB_CACHE_CAPACITY {
                        if let Some(oldest) = this.thumbnail_cache_order.pop_front() {
                            this.thumbnails.remove(&oldest);
                        }
                    }

                    this.pump_thumbnail_jobs(cx);
                    cx.notify();
                });
            })
            .detach();
        }
    }

    fn filmstrip_asset(
        &self,
        asset_ix: usize,
        left: f32,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        let selected = self.selected_asset == asset_ix;
        let thumbnail = self.thumbnails.get(&asset_ix).cloned();

        let preview = if let Some(image) = thumbnail {
            div()
                .w(px(THUMB_WIDTH as f32))
                .h(px(THUMB_HEIGHT as f32))
                .overflow_hidden()
                .rounded_sm()
                .child(img(image).w(px(THUMB_WIDTH as f32)).h(px(THUMB_HEIGHT as f32)))
                .into_any_element()
        } else {
            div()
                .w(px(THUMB_WIDTH as f32))
                .h(px(THUMB_HEIGHT as f32))
                .rounded_sm()
                .bg(rgb(0x202329))
                .flex()
                .items_center()
                .justify_center()
                .text_xs()
                .text_color(rgb(0x686d76))
                .child("loading")
                .into_any_element()
        };

        div()
            .id(format!("filmstrip-asset-{asset_ix}"))
            .absolute()
            .left(px(left))
            .top(px(6.0))
            .w(px(FILMSTRIP_ITEM_WIDTH))
            .h(px(78.0))
            .p_1()
            .rounded_md()
            .border_1()
            .border_color(if selected {
                rgb(0xd4d7de)
            } else {
                rgb(0x434750)
            })
            .bg(if selected {
                rgb(0x343840)
            } else {
                rgb(0x25282e)
            })
            .cursor_pointer()
            .flex()
            .flex_col()
            .items_center()
            .gap_1()
            .child(preview)
            .child(
                div()
                    .text_xs()
                    .text_color(rgb(0xb8bcc6))
                    .child(format!("{}", asset_ix + 1)),
            )
            .on_click(cx.listener(move |this, _, _, cx| {
                this.selected_asset = asset_ix;
                this.status = format!("S2 filmstrip selection: Asset {} / {}", asset_ix + 1, S2_ASSET_COUNT);
                cx.notify();
            }))
    }

    fn s2_horizontal_filmstrip(&mut self, cx: &mut Context<Self>) -> impl IntoElement {
        let visible = self.filmstrip_visible_range();
        self.schedule_visible_thumbnails(visible.clone(), cx);

        let mut canvas = div()
            .relative()
            .w(px(FILMSTRIP_VIEW_WIDTH))
            .h(px(90.0));

        for asset_ix in visible {
            let left = asset_ix as f32 * FILMSTRIP_STRIDE - self.filmstrip_scroll_x;
            canvas = canvas.child(self.filmstrip_asset(asset_ix, left, cx));
        }

        div()
            .id("s2-horizontal-filmstrip")
            .w(px(FILMSTRIP_VIEW_WIDTH))
            .h(px(90.0))
            .overflow_hidden()
            .on_scroll_wheel(cx.listener(Self::handle_filmstrip_scroll))
            .child(canvas)
    }
}

impl Render for DextryxSpike {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let engine_status = if self.engine_ready {
            "raw-engine linked"
        } else {
            "raw-engine unavailable"
        };
        let zoom_label = format!("{}%", (self.zoom * 100.0).round() as i32);
        let pan_label = format!(
            "pan {:.0}, {:.0}",
            f32::from(self.pan_offset.x),
            f32::from(self.pan_offset.y)
        );
        let selected_label = format!("Selected: Asset {}", self.selected_asset + 1);
        let thumb_status = format!(
            "thumbs cached {} / in-flight {} / queue {}",
            self.thumbnails.len(),
            self.thumbnail_in_flight,
            self.thumbnail_queue.len()
        );

        div()
            .flex()
            .flex_col()
            .size_full()
            .bg(rgb(0x121316))
            .text_color(rgb(0xe6e8ec))
            .child(
                div()
                    .h(px(44.0))
                    .px_4()
                    .flex()
                    .items_center()
                    .justify_between()
                    .border_b_1()
                    .border_color(rgb(0x2b2e34))
                    .bg(rgb(0x191b1f))
                    .child("Dextryx Images — GPUI spike")
                    .child(div().text_sm().text_color(rgb(0x8d929c)).child(engine_status)),
            )
            .child(
                div()
                    .flex()
                    .flex_1()
                    .child(
                        div()
                            .w(px(220.0))
                            .p_4()
                            .flex()
                            .flex_col()
                            .gap_3()
                            .border_r_1()
                            .border_color(rgb(0x2b2e34))
                            .bg(rgb(0x17191d))
                            .child(Self::panel_label("WORKPLACES"))
                            .child(div().p_3().rounded_md().bg(rgb(0x25282e)).child("My workplace"))
                            .child(Self::panel_label("CATALOG"))
                            .child("All photos")
                            .child("Missing")
                            .child("Recent imports")
                            .child(Self::panel_label("S2 HARNESS"))
                            .child("5,000 assets")
                            .child("horizontal virtualization")
                            .child("4 thumbnail workers")
                            .child("128 thumbnail cache"),
                    )
                    .child(
                        div()
                            .flex()
                            .flex_col()
                            .flex_1()
                            .child(
                                div()
                                    .h(px(42.0))
                                    .px_3()
                                    .flex()
                                    .items_center()
                                    .gap_2()
                                    .border_b_1()
                                    .border_color(rgb(0x2b2e34))
                                    .bg(rgb(0x15171a))
                                    .child(Self::toolbar_button("open-image", "Open Image", cx, |this, cx| this.open_image(cx)))
                                    .child(Self::toolbar_button("fit", "Fit", cx, |this, cx| this.fit(cx)))
                                    .child(Self::toolbar_button("one-to-one", "1:1", cx, |this, cx| this.one_to_one(cx)))
                                    .child(Self::toolbar_button("zoom-out", "−", cx, |this, cx| this.zoom_by(0.8, cx)))
                                    .child(Self::toolbar_button("zoom-in", "+", cx, |this, cx| this.zoom_by(1.25, cx)))
                                    .child(div().ml_2().text_sm().text_color(rgb(0x8d929c)).child(zoom_label))
                                    .child(div().ml_2().text_sm().text_color(rgb(0x686d76)).child(pan_label)),
                            )
                            .child(
                                div()
                                    .flex()
                                    .flex_1()
                                    .items_center()
                                    .justify_center()
                                    .bg(rgb(0x0d0e10))
                                    .child(
                                        div()
                                            .id("image-viewport")
                                            .w(px(VIEWPORT_WIDTH))
                                            .h(px(VIEWPORT_HEIGHT))
                                            .rounded_lg()
                                            .border_1()
                                            .border_color(rgb(0x343840))
                                            .bg(rgb(0x202329))
                                            .overflow_hidden()
                                            .cursor(if self.is_dragging() {
                                                gpui::CursorStyle::ClosedHand
                                            } else {
                                                gpui::CursorStyle::OpenHand
                                            })
                                            .on_scroll_wheel(cx.listener(Self::handle_scroll_wheel))
                                            .on_pinch(cx.listener(Self::handle_pinch))
                                            .on_mouse_down(MouseButton::Left, cx.listener(Self::handle_mouse_down))
                                            .on_mouse_down(MouseButton::Middle, cx.listener(Self::handle_mouse_down))
                                            .on_mouse_up(MouseButton::Left, cx.listener(Self::handle_mouse_up))
                                            .on_mouse_up(MouseButton::Middle, cx.listener(Self::handle_mouse_up))
                                            .on_mouse_move(cx.listener(Self::handle_mouse_move))
                                            .child(self.viewport_content()),
                                    ),
                            )
                            .child(
                                div()
                                    .h(px(132.0))
                                    .border_t_1()
                                    .border_color(rgb(0x2b2e34))
                                    .bg(rgb(0x16181c))
                                    .flex()
                                    .flex_col()
                                    .child(
                                        div()
                                            .h(px(32.0))
                                            .px_3()
                                            .flex()
                                            .items_center()
                                            .justify_between()
                                            .text_sm()
                                            .text_color(rgb(0x8d929c))
                                            .child("S2 horizontal virtualized Filmstrip — scroll / trackpad")
                                            .child(selected_label),
                                    )
                                    .child(
                                        div()
                                            .flex_1()
                                            .px_3()
                                            .flex()
                                            .items_center()
                                            .justify_center()
                                            .child(self.s2_horizontal_filmstrip(cx)),
                                    ),
                            ),
                    )
                    .child(
                        div()
                            .w(px(280.0))
                            .p_4()
                            .flex()
                            .flex_col()
                            .gap_4()
                            .border_l_1()
                            .border_color(rgb(0x2b2e34))
                            .bg(rgb(0x17191d))
                            .child(Self::panel_label("DEVELOP"))
                            .child("Exposure        0.00")
                            .child("Temperature     0.00")
                            .child("Contrast        1.00")
                            .child(Self::panel_label("S1 VIEWPORT — PASS"))
                            .child(div().text_sm().text_color(rgb(0x858a94)).child(self.status.clone()))
                            .child(Self::panel_label("S2 — FINAL VALIDATION"))
                            .child(
                                div()
                                    .text_sm()
                                    .text_color(rgb(0x858a94))
                                    .child("Only the visible Filmstrip range plus 3-item overscan is constructed. Synthetic thumbnail work runs on GPUI's background executor with max 4 in-flight jobs."),
                            )
                            .child(
                                div()
                                    .text_sm()
                                    .text_color(rgb(0x858a94))
                                    .child(thumb_status),
                            )
                            .child(
                                div()
                                    .text_sm()
                                    .text_color(rgb(0x686d76))
                                    .child("Queued off-screen thumbnail work is dropped on the next scroll. Completed thumbnails are bounded by a 128-entry cache."),
                            ),
                    ),
            )
    }
}

fn main() {
    application().run(|cx: &mut App| {
        let bounds = Bounds::centered(None, size(px(1440.0), px(960.0)), cx);
        cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                ..Default::default()
            },
            |_window, cx| {
                cx.new(|_cx| DextryxSpike {
                    engine_ready: raw_engine::check_engine() == 1,
                    image_path: None,
                    image_dimensions: None,
                    render_image: None,
                    zoom: 1.0,
                    pan_offset: point(px(0.0), px(0.0)),
                    last_mouse_position: None,
                    selected_asset: 0,
                    filmstrip_scroll_x: 0.0,
                    thumbnails: HashMap::new(),
                    thumbnail_pending: HashSet::new(),
                    thumbnail_queue: VecDeque::new(),
                    thumbnail_cache_order: VecDeque::new(),
                    thumbnail_in_flight: 0,
                    status: "S1 passed on physical macOS. S2 horizontal filmstrip + bounded async thumbnails ready for validation."
                        .to_string(),
                })
            },
        )
        .expect("failed to open Dextryx GPUI spike window");
        cx.activate(true);
    });
}
