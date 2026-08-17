use gpui::{
    App, Bounds, Context, Window, WindowBounds, WindowOptions, div, prelude::*, px, rgb, size,
};
use gpui_platform::application;

struct DextryxSpike {
    engine_ready: bool,
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
}

impl Render for DextryxSpike {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        let engine_status = if self.engine_ready {
            "raw-engine linked"
        } else {
            "raw-engine unavailable"
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
                                                    .child("Import / image upload intentionally not wired in spike 0"),
                                            ),
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
                            .child(Self::panel_label("SPIKE BOUNDARY"))
                            .child(
                                div()
                                    .text_sm()
                                    .text_color(rgb(0x858a94))
                                    .child("UI shell only. Flutter production path is untouched."),
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
                })
            },
        )
        .expect("failed to open Dextryx GPUI spike window");

        cx.activate(true);
    });
}
