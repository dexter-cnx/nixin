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

struct DextryxSpike {
    engine_ready: bool,
    image_path: Option<PathBuf>,
    image_dimensions: Option<(u32, u32)>,
    render_image: Option<Arc<RenderImage>>,
    zoom: f32,
    pan_offset: Point<Pixels>,
    last_mouse_position: Option<Point<Pixels>>,
    status: String,
}

impl DextryxSpike {
    fn panel_label(text: &'static str) -> impl IntoElement {
        div()
            .text_sm()
            .text_color(rgb(0xb8bcc6))
            .child(text)
    }

    fn thumbnail(index: usize) -> impl IntoElement {
        div()
            .w(px(96.0))
            .h(px(72.0))
            .rounded_md()
            .border_1()
            .border_color(rgb(0x434750))
            .bg(rgb(0x25282e))
            .flex()
            .items_center()
            .justify_center()
            .text_sm()
            .text_color(rgb(0x8d929c))
            .child(format!("Asset {index}"))
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

                // GPUI RenderImage currently uploads BGRA pixels. Keep the raw-engine
                // public contract RGBA and swizzle in-place at the UI boundary. This
                // changes channel order without allocating or encoding another image.
                for pixel in pixels.chunks_exact_mut(4) {
                    pixel.swap(0, 2);
                }

                let Some(buffer) = image::RgbaImage::from_raw(width, height, pixels) else {
                    self.status = "Unable to adopt raw-engine pixel buffer".to_string();
                    cx.notify();
                    return;
                };

                let render_image = Arc::new(RenderImage::new(vec![image::Frame::new(buffer)]));

                self.image_path = Some(path.clone());
                self.image_dimensions = Some((width, height));
                self.render_image = Some(render_image);
                self.zoom = Self::fit_zoom_for(width, height);
                self.pan_offset = Point::default();
                self.last_mouse_position = None;
                self.status = format!(
                    "{} — {} × {} — raw-engine RGBA → GPUI RenderImage",
                    path.file_name()
                        .and_then(|name| name.to_str())
                        .unwrap_or("image"),
                    width,
                    height
                );
            }
            Err(error) => {
                self.status = format!("raw-engine preview failed: {error}");
            }
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
                    .child(
                        img(image)
                            .w(px(scaled_width))
                            .h(px(scaled_height)),
                    ),
            )
            .into_any_element()
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
                    .child(
                        div()
                            .text_sm()
                            .text_color(rgb(0x8d929c))
                            .child(engine_status),
                    ),
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
                            .child(
                                div()
                                    .p_3()
                                    .rounded_md()
                                    .bg(rgb(0x25282e))
                                    .child("My workplace"),
                            )
                            .child(Self::panel_label("CATALOG"))
                            .child("All photos")
                            .child("Missing")
                            .child("Recent imports"),
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
                                    .child(Self::toolbar_button("open-image", "Open Image", cx, |this, cx| {
                                        this.open_image(cx)
                                    }))
                                    .child(Self::toolbar_button("fit", "Fit", cx, |this, cx| {
                                        this.fit(cx)
                                    }))
                                    .child(Self::toolbar_button("one-to-one", "1:1", cx, |this, cx| {
                                        this.one_to_one(cx)
                                    }))
                                    .child(Self::toolbar_button("zoom-out", "−", cx, |this, cx| {
                                        this.zoom_by(0.8, cx)
                                    }))
                                    .child(Self::toolbar_button("zoom-in", "+", cx, |this, cx| {
                                        this.zoom_by(1.25, cx)
                                    }))
                                    .child(
                                        div()
                                            .ml_2()
                                            .text_sm()
                                            .text_color(rgb(0x8d929c))
                                            .child(zoom_label),
                                    )
                                    .child(
                                        div()
                                            .ml_2()
                                            .text_sm()
                                            .text_color(rgb(0x686d76))
                                            .child(pan_label),
                                    ),
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
                                    .h(px(124.0))
                                    .p_3()
                                    .flex()
                                    .gap_3()
                                    .items_center()
                                    .border_t_1()
                                    .border_color(rgb(0x2b2e34))
                                    .bg(rgb(0x16181c))
                                    .children((1..=8).map(Self::thumbnail)),
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
                            .child(Self::panel_label("S1 VIEWPORT"))
                            .child(
                                div()
                                    .text_sm()
                                    .text_color(rgb(0x858a94))
                                    .child(self.status.clone()),
                            )
                            .child(
                                div()
                                    .text_sm()
                                    .text_color(rgb(0x858a94))
                                    .child("Drag with left/middle mouse to pan. Trackpad/two-finger scroll pans. Pinch or Cmd/Ctrl-scroll zooms."),
                            ),
                    ),
            )
    }
}

fn main() {
    application().run(|cx: &mut App| {
        let bounds = Bounds::centered(None, size(px(1440.0), px(900.0)), cx);

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
                    status: "S0 passed. S1 direct raw-engine buffer + pan is ready for validation."
                        .to_string(),
                })
            },
        )
        .expect("failed to open Dextryx GPUI spike window");

        cx.activate(true);
    });
}
