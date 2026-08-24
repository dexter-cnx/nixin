mod app_state;
mod file_dialog;

use app_state::{
    AppCommand, DesktopAppState, FILMSTRIP_ITEM_WIDTH, FILMSTRIP_STRIDE, FILMSTRIP_VIEW_WIDTH,
};
use file_dialog::RfdFileDialogAdapter;
use gpui::{
    div, prelude::*, px, rgb, size, App, Bounds, Context, Render, ScrollDelta, ScrollWheelEvent,
    Window, WindowBounds, WindowOptions,
};
use gpui_platform::application;

struct DesktopShell {
    state: DesktopAppState,
    file_dialog: RfdFileDialogAdapter,
}

impl DesktopShell {
    fn command_button(
        id: &'static str,
        label: &'static str,
        command: AppCommand,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        div()
            .id(id)
            .px_3()
            .py_2()
            .rounded_md()
            .border_1()
            .border_color(rgb(0x3c414a))
            .bg(rgb(0x24272d))
            .text_sm()
            .cursor_pointer()
            .child(label)
            .active(|this| this.opacity(0.75))
            .on_click(cx.listener(move |this, _, _, cx| {
                this.state.apply(command.clone());
                this.state.refresh_catalog();
                cx.notify();
            }))
    }

    fn refresh_button(cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .id("refresh-catalog")
            .px_3()
            .py_2()
            .rounded_md()
            .border_1()
            .border_color(rgb(0x3c414a))
            .bg(rgb(0x24272d))
            .text_sm()
            .cursor_pointer()
            .child("Refresh")
            .active(|this| this.opacity(0.75))
            .on_click(cx.listener(|this, _, _, cx| {
                this.state.refresh_catalog();
                cx.notify();
            }))
    }

    fn import_button(cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .id("import")
            .px_3()
            .py_2()
            .rounded_md()
            .border_1()
            .border_color(rgb(0x3c414a))
            .bg(rgb(0x24272d))
            .text_sm()
            .cursor_pointer()
            .child("Import")
            .active(|this| this.opacity(0.75))
            .on_click(cx.listener(|this, _, _, cx| {
                this.state.begin_import(&this.file_dialog);
                cx.notify();
            }))
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
                if x.abs() > y.abs() {
                    x
                } else {
                    y
                }
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

        self.state.scroll_filmstrip(delta);
        cx.notify();
    }

    fn filmstrip(&mut self, cx: &mut Context<Self>) -> impl IntoElement {
        let visible = self
            .state
            .filmstrip_visible_range()
            .map(|index| (index, self.state.assets[index].clone()))
            .collect::<Vec<_>>();
        let selected_id = self.state.selected_asset_id.clone();
        let scroll_x = self.state.filmstrip_scroll_x;

        let mut canvas = div().relative().w(px(FILMSTRIP_VIEW_WIDTH)).h(px(92.0));
        for (index, asset) in visible {
            let left = index as f32 * FILMSTRIP_STRIDE - scroll_x;
            let asset_id = asset.id.clone();
            let selected = selected_id.as_deref() == Some(asset.id.as_str());
            let filename = asset
                .effective_path
                .file_name()
                .and_then(|name| name.to_str())
                .unwrap_or("asset")
                .to_string();
            let storage = match asset.storage {
                dextryx_frontend_api::AssetStorageDto::Linked => "linked",
                dextryx_frontend_api::AssetStorageDto::Managed => "managed",
            };
            let detail = if asset.missing {
                format!("{storage} • missing")
            } else {
                storage.to_string()
            };

            canvas = canvas.child(
                div()
                    .id(format!("filmstrip-asset-{index}"))
                    .absolute()
                    .left(px(left))
                    .top(px(6.0))
                    .w(px(FILMSTRIP_ITEM_WIDTH))
                    .h(px(78.0))
                    .p_2()
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
                    .justify_center()
                    .gap_1()
                    .child(
                        div()
                            .text_xs()
                            .text_color(rgb(0xe6e8ec))
                            .overflow_hidden()
                            .child(filename),
                    )
                    .child(div().text_xs().text_color(rgb(0x8d929c)).child(detail))
                    .on_click(cx.listener(move |this, _, _, cx| {
                        this.state.select_asset(&asset_id);
                        cx.notify();
                    })),
            );
        }

        div()
            .id("authoritative-filmstrip")
            .w(px(FILMSTRIP_VIEW_WIDTH))
            .h(px(92.0))
            .overflow_hidden()
            .on_scroll_wheel(cx.listener(Self::handle_filmstrip_scroll))
            .child(canvas)
    }
}

impl Render for DesktopShell {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let section = self.state.section_label();
        let query = self.state.query_label();
        let status = self.state.status.clone();
        let import_count = self.state.selected_import_paths.len();
        let workplace = self
            .state
            .active_workplace_name()
            .unwrap_or("No authoritative Workplace")
            .to_string();
        let asset_count = self.state.assets.len();
        let selected = self.state.selected_asset().cloned();
        let selected_title = selected
            .as_ref()
            .and_then(|asset| asset.effective_path.file_name())
            .and_then(|name| name.to_str())
            .unwrap_or("No asset selected")
            .to_string();
        let selected_path = selected
            .as_ref()
            .map(|asset| asset.effective_path.display().to_string())
            .unwrap_or_else(|| "Select an asset from the Filmstrip".to_string());

        div()
            .flex()
            .flex_col()
            .size_full()
            .bg(rgb(0x121316))
            .text_color(rgb(0xe6e8ec))
            .child(
                div()
                    .h(px(46.0))
                    .px_4()
                    .flex()
                    .items_center()
                    .justify_between()
                    .border_b_1()
                    .border_color(rgb(0x2b2e34))
                    .bg(rgb(0x191b1f))
                    .child("Dextryx Images")
                    .child(
                        div()
                            .text_sm()
                            .text_color(rgb(0x8d929c))
                            .child(format!("M3 • {section}")),
                    ),
            )
            .child(
                div()
                    .flex()
                    .flex_1()
                    .child(
                        div()
                            .w(px(236.0))
                            .p_4()
                            .flex()
                            .flex_col()
                            .gap_2()
                            .border_r_1()
                            .border_color(rgb(0x2b2e34))
                            .bg(rgb(0x17191d))
                            .child(
                                div()
                                    .text_xs()
                                    .text_color(rgb(0x8d929c))
                                    .child("WORKSPACE"),
                            )
                            .child(Self::command_button(
                                "workspace-library",
                                "Library",
                                AppCommand::ShowLibrary,
                                cx,
                            ))
                            .child(Self::command_button(
                                "workspace-develop",
                                "Develop",
                                AppCommand::ShowDevelop,
                                cx,
                            ))
                            .child(
                                div()
                                    .mt_3()
                                    .text_xs()
                                    .text_color(rgb(0x8d929c))
                                    .child("CATALOG"),
                            )
                            .child(Self::command_button(
                                "catalog-all",
                                "All photos",
                                AppCommand::ShowAllPhotos,
                                cx,
                            ))
                            .child(Self::command_button(
                                "catalog-missing",
                                "Missing",
                                AppCommand::ShowMissing,
                                cx,
                            ))
                            .child(Self::command_button(
                                "catalog-recent",
                                "Recent imports",
                                AppCommand::ShowRecentImports,
                                cx,
                            ))
                            .child(Self::refresh_button(cx)),
                    )
                    .child(
                        div()
                            .flex()
                            .flex_col()
                            .flex_1()
                            .child(
                                div()
                                    .h(px(48.0))
                                    .px_4()
                                    .flex()
                                    .items_center()
                                    .gap_2()
                                    .border_b_1()
                                    .border_color(rgb(0x2b2e34))
                                    .bg(rgb(0x15171a))
                                    .child(Self::import_button(cx))
                                    .child(
                                        div()
                                            .text_sm()
                                            .text_color(rgb(0x8d929c))
                                            .child(format!("Catalog: {query}")),
                                    )
                                    .child(
                                        div()
                                            .text_sm()
                                            .text_color(rgb(0x686d76))
                                            .child(format!("Selected for import: {import_count}")),
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
                                            .w(px(820.0))
                                            .h(px(420.0))
                                            .p_6()
                                            .rounded_lg()
                                            .border_1()
                                            .border_color(rgb(0x343840))
                                            .bg(rgb(0x202329))
                                            .flex()
                                            .flex_col()
                                            .gap_3()
                                            .child(div().text_lg().child(selected_title))
                                            .child(
                                                div()
                                                    .text_sm()
                                                    .text_color(rgb(0x8d929c))
                                                    .child(format!(
                                                        "{workplace} • {asset_count} authoritative asset(s)"
                                                    )),
                                            )
                                            .child(
                                                div()
                                                    .text_sm()
                                                    .text_color(rgb(0xb8bcc6))
                                                    .child(selected_path),
                                            )
                                            .child(
                                                div()
                                                    .mt_3()
                                                    .text_sm()
                                                    .text_color(rgb(0xb8bcc6))
                                                    .child(status),
                                            ),
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
                                            .child("Authoritative Filmstrip — scroll / trackpad")
                                            .child(format!("{asset_count} asset(s)")),
                                    )
                                    .child(
                                        div()
                                            .flex_1()
                                            .px_3()
                                            .flex()
                                            .items_center()
                                            .justify_center()
                                            .child(self.filmstrip(cx)),
                                    ),
                            ),
                    ),
            )
    }
}

fn main() {
    application().run(|cx: &mut App| {
        let bounds = Bounds::centered(None, size(px(1280.0), px(820.0)), cx);
        cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                ..Default::default()
            },
            |_window, cx| {
                cx.new(|_cx| {
                    let mut state = DesktopAppState::default();
                    state.refresh_catalog();
                    DesktopShell {
                        state,
                        file_dialog: RfdFileDialogAdapter,
                    }
                })
            },
        )
        .expect("failed to open Dextryx Images desktop window");
        cx.activate(true);
    });
}
