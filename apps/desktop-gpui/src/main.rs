mod app_state;
mod file_dialog;

use app_state::{AppCommand, DesktopAppState};
use file_dialog::RfdFileDialogAdapter;
use gpui::{
    div, prelude::*, px, rgb, size, App, Bounds, Context, Render, Window, WindowBounds,
    WindowOptions,
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
        let asset_rows = self.state.assets.iter().take(8).fold(
            div().flex().flex_col().gap_1(),
            |list, asset| {
                list.child(
                    div()
                        .text_sm()
                        .text_color(rgb(0xb8bcc6))
                        .child(format!(
                            "{}  •  {}",
                            asset.id,
                            asset.effective_path.display()
                        )),
                )
            },
        );

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
                            .child(format!("M2 • {section}")),
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
                                            .h(px(500.0))
                                            .p_6()
                                            .rounded_lg()
                                            .border_1()
                                            .border_color(rgb(0x343840))
                                            .bg(rgb(0x202329))
                                            .flex()
                                            .flex_col()
                                            .gap_3()
                                            .child(div().text_lg().child(workplace))
                                            .child(
                                                div()
                                                    .text_sm()
                                                    .text_color(rgb(0x8d929c))
                                                    .child(format!(
                                                        "Authoritative read projection • {asset_count} asset(s)"
                                                    )),
                                            )
                                            .child(asset_rows)
                                            .child(
                                                div()
                                                    .mt_3()
                                                    .text_sm()
                                                    .text_color(rgb(0xb8bcc6))
                                                    .child(status),
                                            ),
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
