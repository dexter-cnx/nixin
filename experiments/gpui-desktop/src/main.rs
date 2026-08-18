use std::path::PathBuf;

use gpui::{
    App, Bounds, Context, ObjectFit, Window, WindowBounds, WindowOptions, div, img, prelude::*, px,
    rgb, size,
};
use gpui_platform::application;
use rfd::FileDialog;

struct DextryxSpike {
    engine_ready: bool,
    image_path: Option<PathBuf>,
    image_dimensions: Option<(u32, u32)>,
    fit_to_view: bool,
    zoom: f32,
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

    fn open_image(&mut self, cx: &mut Context<Self>) {
        let selected = FileDialog::new()
            .set_title("Open image")
            .add_filter("Images", &["jpg", "jpeg", "png", "tif", "tiff", "webp"])
            .pick_file();

        let Some(path) = selected else {
            return;
        };

        match image::image_dimensions(&path) {
            Ok(dimensions) => {
                self.image_path = Some(path.clone());
                self.image_dimensions = Some(dimensions);
                self.fit_to_view = true;
                self.zoom = 1.0;
                self.status = format!(
                    "{} — {} × {}",
                    path.file_name()
                        .and_then(|name| name.to_str())
                        .unwrap_or("image"),
                    dimensions.0,
                    dimensions.1
                );
            }
            Err(error) => {
                self.status = format!("Unable to read image: {error}");
            }
        }
        cx.notify();
    }

    fn fit(&mut self, cx: &mut Context<Self>) {
        self.fit_to_view = true;
        cx.notify();
    }

    fn one_to_one(&mut self, cx: &mut Context<Self>) {
        self.fit_to_view = false;
        self.zoom = 1.0;
        cx.notify();
    }

    fn zoom_by(&mut self, factor: f32, cx: &mut Context<Self>) {
        self.fit_to_view = false;
        self.zoom = (self.zoom * factor).clamp(0.1, 8.0);
        cx.notify();
    }

    fn viewport_image(&self) -> impl IntoElement {
        let Some(path) = self.image_path.clone() else {
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
                        .child("Open a raster image to begin S1 validation"),
                )
                .into_any_element();
        };

        let image = if self.fit_to_view {
            img(path)
                .size_full()
                .object_fit(ObjectFit::Contain)
                .into_any_element()
        } else if let Some((width, height)) = self.image_dimensions {
            img(path)
                .w(px(width as f32 * self.zoom))
                .h(px(height as f32 * self.zoom))
                .object_fit(ObjectFit::Fill)
                .into_any_element()
        } else {
            img(path)
                .size_full()
                .object_fit(ObjectFit::Contain)
                .into_any_element()
        };

        div()
            .size_full()
            .flex()
            .items_center()
            .justify_center()
            .overflow_hidden()
            .child(image)
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

        let zoom_label = if self.fit_to_view {
            "Fit".to_string()
        } else {
            format!("{}%", (self.zoom * 100.0).round() as i32)
        };

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
                                            .w(px(720.0))
                                            .h(px(480.0))
                                            .rounded_lg()
                                            .border_1()
                                            .border_color(rgb(0x343840))
                                            .bg(rgb(0x202329))
                                            .overflow_hidden()
                                            .child(self.viewport_image()),
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
                                    .child("Raster open/render + Fit/1:1/zoom are wired. Pan and raw-engine pixel-buffer rendering remain next."),
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
                    fit_to_view: true,
                    zoom: 1.0,
                    status: "S0 passed on physical macOS. Ready for raster S1.".to_string(),
                })
            },
        )
        .expect("failed to open Dextryx GPUI spike window");

        cx.activate(true);
    });
}
