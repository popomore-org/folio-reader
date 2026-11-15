use super::{Action, Channel, Row, Snapshot, symbol};
use nsh_core::{AccessibilityRole, prelude::*};
use serde_json::json;
use std::{cell::Cell, rc::Rc, sync::Arc};

mod git;
pub(super) use git::{git_changes, git_header, git_history};

pub(super) fn status_bar(state: Signal<Snapshot>, channel: Arc<Channel>) -> impl IntoElement {
    let sidebar = channel.clone();
    view()
        .w_full()
        .h_full()
        .flex_row()
        .items_center()
        .px(px(7.0))
        .gap(px(9.0))
        .bg(move || surface(state.with(|state| state.dark)))
        .child(action_button(
            move || {
                if state.get().sidebar {
                    "Hide Folder Tree"
                } else {
                    "Show Folder Tree"
                }
            },
            "sidebar.left",
            move || sidebar.action("toggle_sidebar"),
        ))
        .child(
            view()
                .flex_row()
                .items_center()
                .gap(px(5.0))
                .h(px(23.0))
                .px(px(6.0))
                .rounded(px(4.0))
                .justify_center()
                .hover(|style| style.bg(rgb(0x8392a8).opacity(0.18)))
                .label(move || {
                    if state.get().showing_git {
                        "Back to Reading"
                    } else {
                        "Git"
                    }
                })
                .role(AccessibilityRole::Button)
                .on_press(move || channel.action("toggle_git"))
                .disabled(move || !state.get().git_available)
                .child(symbol(json!("arrow.triangle.branch"), 13.0))
                .child(
                    text(move || {
                        if state.get().showing_git {
                            "Back to Reading"
                        } else {
                            "Git"
                        }
                    })
                    .text_size(px(11.0))
                    .text_color(move || secondary(state.with(|state| state.dark))),
                ),
        )
        .child(view().flex_1())
        .child(
            text(move || state.get().details)
                .text_size(px(11.0))
                .text_color(move || secondary(state.with(|state| state.dark))),
        )
}

fn header(state: Signal<Snapshot>) -> View {
    view()
        .w_full()
        .h(px(30.0))
        .flex_none()
        .flex_row()
        .items_center()
        .bg(move || surface(state.with(|state| state.dark)))
}

fn rule(state: Signal<Snapshot>) -> View {
    view()
        .w_full()
        .h(px(1.0))
        .flex_none()
        .bg(move || divider(state.with(|state| state.dark)))
}

fn heading(state: Signal<Snapshot>) -> Text {
    text(move || state.get().title)
        .text_size(px(12.0))
        .font_weight(FontWeight::SEMIBOLD)
        .text_color(move || foreground(state.with(|state| state.dark)))
}

pub(super) fn tab_bar(state: Signal<Snapshot>, channel: Arc<Channel>) -> impl IntoElement {
    let tab_channel = channel.clone();
    view()
        .w_full()
        .h_full()
        .bg(move || surface(state.with(|state| state.dark)))
        .child(
            header(state)
                .child(
                    scroll()
                        .horizontal()
                        .scrollbar(false)
                        .flex_1()
                        .min_w(px(0.0))
                        .h_full()
                        .child(view().h_full().flex_row().child(each(
                            move || state.with(|state| state.rows.clone()),
                            |row| row.id.clone(),
                            move |row, _| tab_row(state, row, tab_channel.clone()),
                        ))),
                )
                .child(when(
                    move || state.get().trailing_icon.is_some(),
                    move || {
                        let channel = channel.clone();
                        view().px(px(4.0)).flex_none().child(
                            hit_area()
                                .w(px(25.0))
                                .h(px(25.0))
                                .label(move || state.get().title)
                                .tooltip(hint(state, move || {
                                    state.with(|state| state.title.clone())
                                }))
                                .on_press(move || channel.action("toggle_split"))
                                .child(symbol(move || json!(state.get().trailing_icon), 14.0)),
                        )
                    },
                )),
        )
        .child(rule(state))
}

fn tab_row(
    state: Signal<Snapshot>,
    row: ReadSignal<Row>,
    channel: Arc<Channel>,
) -> impl IntoElement {
    let selected = element_ref();
    let reveal = selected;
    effect(move || {
        if row.get().selected {
            reveal.reveal(nsh_core::RevealOptions::default().animated(false));
        }
    });
    let select = channel.clone();
    let close = channel.clone();
    let context_menu = move |event: &nsh_core::ContextMenuEvent| {
        menu_action(&channel, "tab_menu", row.get().id, event);
    };
    view()
        .element_ref(&selected)
        .flex_none()
        .max_w(px(218.0))
        .h_full()
        .bg(move || {
            let row = row.get();
            let dark = state.with(|state| state.dark);
            if row.active {
                selection(dark)
            } else if row.selected {
                hover(dark)
            } else {
                Rgba::default().into()
            }
        })
        .child(
            view()
                .flex_1()
                .flex_row()
                .items_center()
                .min_w(px(0.0))
                .pr(px(2.0))
                .child(
                    hit_area()
                        .flex_row()
                        .justify_start()
                        .h_full()
                        .min_w(px(0.0))
                        .pl(px(7.0))
                        .gap(px(5.0))
                        .label(move || row.get().title)
                        .tooltip(hint(state, move || row.get().tip))
                        .on_context_menu(context_menu.clone())
                        .accessibility_state(move || nsh_core::AccessibilityState {
                            selected: row.get().selected,
                            ..Default::default()
                        })
                        .on_press(move || {
                            select.send(Action {
                                name: "select_tab",
                                id: Some(row.get().id),
                                ..Action::default()
                            })
                        })
                        .child(symbol(move || json!(row.get().icon), 14.0))
                        .child(
                            text(move || row.get().title)
                                .text_size(px(12.0))
                                .min_w(px(0.0))
                                .truncate()
                                .text_color(move || {
                                    if row.get().selected {
                                        foreground(state.with(|state| state.dark))
                                    } else {
                                        secondary(state.with(|state| state.dark))
                                    }
                                }),
                        ),
                )
                .child(
                    hit_area()
                        .w(px(24.0))
                        .h(px(24.0))
                        .flex_none()
                        .label(move || format!("Close {}", row.get().title))
                        .on_context_menu(context_menu)
                        .on_press(move || {
                            close.send(Action {
                                name: "close_tab",
                                id: Some(row.get().id),
                                ..Action::default()
                            })
                        })
                        .child(symbol(
                            move || {
                                json!(if row.get().dirty {
                                    "circle.fill"
                                } else {
                                    "xmark"
                                })
                            },
                            9.0,
                        )),
                )
                .child(
                    view()
                        .w(px(1.0))
                        .h_full()
                        .flex_none()
                        .bg(move || divider(state.with(|state| state.dark))),
                ),
        )
        .child(view().w_full().h(px(2.0)).flex_none().bg(move || {
            if row.get().active {
                focus(state.with(|state| state.dark))
            } else {
                Rgba::default().into()
            }
        }))
}

pub(super) fn outline(state: Signal<Snapshot>, channel: Arc<Channel>) -> impl IntoElement {
    view()
        .w_full()
        .h_full()
        .bg(move || surface(state.with(|state| state.dark)))
        .child(header(state).px(px(12.0)).child(heading(state)))
        .child(rule(state))
        .child(when(
            move || state.with(|state| state.rows.is_empty()),
            move || {
                text(move || state.get().details)
                    .p(px(12.0))
                    .text_size(px(12.0))
                    .text_color(move || secondary(state.with(|state| state.dark)))
            },
        ))
        .child(
            scroll()
                .flex_1()
                .min_h(px(0.0))
                .child(view().p(px(10.0)).gap(px(2.0)).child(each(
                    move || state.with(|state| state.rows.clone()),
                    |row| row.id.clone(),
                    move |row, _| {
                        let channel = channel.clone();
                        hit_area()
                            .w_full()
                            .items_start()
                            .min_h(px(22.0))
                            .py(px(4.0))
                            .pl(move || px(row.get().depth as f32 * 9.0))
                            .label(move || row.get().title)
                            .tooltip(hint(state, move || row.get().title))
                            .disabled(move || state.get().disabled)
                            .on_press(move || {
                                channel.send(Action {
                                    name: "heading",
                                    id: Some(row.get().id),
                                    ..Action::default()
                                })
                            })
                            .child(
                                text(move || row.get().title)
                                    .text_size(px(12.0))
                                    .text_color(move || foreground(state.with(|state| state.dark))),
                            )
                    },
                ))),
        )
}

pub(super) fn folders(state: Signal<Snapshot>, channel: Arc<Channel>) -> impl IntoElement {
    let list = element_ref();
    let visible = Rc::new(Cell::new(None));
    let cursor = computed(move || {
        state.with(|state| {
            let id = state.cursor.as_ref()?;
            state.rows.iter().position(|row| &row.id == id)
        })
    });
    let visible_on_focus = visible.clone();
    effect(move || {
        let Some(index) = cursor.get() else { return };
        let visible = visible_on_focus.get();
        if visible.is_none_or(|(first, last)| !(first..=last).contains(&index)) {
            list.scroll_to_index(index as u32, Percentage(0.5), px(0.0), false);
        }
    });
    let add = channel.clone();
    view()
        .w_full()
        .h_full()
        .bg(move || surface(state.with(|state| state.dark)))
        .child(
            header(state)
                .px(px(12.0))
                .child(heading(state))
                .child(view().flex_1())
                .child(action_button(
                    || "Add Folders",
                    "plus",
                    move || add.action("add_folders"),
                )),
        )
        .child(rule(state))
        .child(when(
            move || state.with(|state| state.rows.is_empty()),
            move || {
                text(move || state.get().details)
                    .p(px(12.0))
                    .text_size(px(12.0))
                    .text_color(move || secondary(state.with(|state| state.dark)))
            },
        ))
        .child(
            virtual_list(
                move || state.with(|state| state.rows.len()),
                move |at| {
                    let channel = channel.clone();
                    let row = computed(move || {
                        state.with(|state| state.rows.get(at.index()).cloned().unwrap_or_default())
                    });
                    let row_channel = channel.clone();
                    view().px(px(6.0)).h(px(24.0)).child(
                        when(
                            move || row.get().message,
                            move || {
                                text(move || row.get().title)
                                    .text_size(px(11.0))
                                    .pl(move || px(21.0 + row.get().depth as f32 * 12.0))
                                    .py(px(3.0))
                                    .text_color(move || secondary(state.with(|state| state.dark)))
                            },
                        )
                        .otherwise(move || folder_row(state, row, row_channel.clone())),
                    )
                },
            )
            .keys(move || {
                state.with(|state| {
                    state
                        .rows
                        .iter()
                        .map(|row| row.id.clone())
                        .collect::<Vec<_>>()
                })
            })
            .estimated_item_size(px(24.0))
            .on_viewable_items_change(move |items: &nsh_core::element::ViewableItems| {
                visible.set(items.viewable)
            })
            .element_ref(&list)
            .flex_1()
            .min_h(px(0.0)),
        )
}

fn folder_row(state: Signal<Snapshot>, row: Memo<Row>, channel: Arc<Channel>) -> impl IntoElement {
    let open = channel.clone();
    hit_area()
        .flex_row()
        .justify_start()
        .gap(px(6.0))
        .h(px(23.0))
        .pl(move || px(5.0 + row.get().depth.min(10) as f32 * 12.0))
        .pr(px(4.0))
        .label(move || row.get().title)
        .tooltip(hint(state, move || row.get().tip))
        .accessibility_state(move || nsh_core::AccessibilityState {
            selected: row.get().selected,
            expanded: row.get().expanded,
            ..Default::default()
        })
        .bg(move || {
            if row.get().selected {
                selection(state.with(|state| state.dark))
            } else {
                Rgba::default().into()
            }
        })
        .border(px(1.0))
        .border_color(move || {
            state.with(|model| {
                if model.keyboard_focus && model.cursor.as_ref() == Some(&row.get().id) {
                    focus(model.dark)
                } else {
                    Rgba::default().into()
                }
            })
        })
        .on_press(move |event: &nsh_core::PressEvent| {
            open.send(Action {
                name: "open_row",
                id: Some(row.get().id),
                alternate: event.modifiers.alt,
                ..Action::default()
            });
        })
        .on_context_menu(move |event: &nsh_core::ContextMenuEvent| {
            menu_action(&channel, "folder_menu", row.get().id, event);
        })
        .child(symbol(
            move || {
                json!(row.get().expanded.map(|expanded| if expanded {
                    "chevron.down"
                } else {
                    "chevron.right"
                }))
            },
            9.0,
        ))
        .child(symbol(move || json!(row.get().icon), 14.0))
        .child(
            text(move || row.get().title)
                .text_size(px(12.0))
                .min_w(px(0.0))
                .truncate()
                .text_color(move || foreground(state.with(|state| state.dark))),
        )
        .into_element()
}

fn menu_action(
    channel: &Arc<Channel>,
    name: &'static str,
    id: String,
    event: &nsh_core::ContextMenuEvent,
) {
    channel.send(Action {
        name,
        id: Some(id),
        point: Some([event.page_position.x.0, event.page_position.y.0]),
        ..Action::default()
    });
}

fn hint(state: Signal<Snapshot>, value: impl Fn() -> String + 'static) -> impl IntoTooltip {
    view()
        .px(px(7.0))
        .py(px(4.0))
        .rounded(px(4.0))
        .border(px(1.0))
        .border_color(move || divider(state.with(|state| state.dark)))
        .bg(move || selection(state.with(|state| state.dark)))
        .child(
            text(value)
                .text_size(px(11.0))
                .text_color(move || foreground(state.with(|state| state.dark))),
        )
}

fn hit_area() -> View {
    view()
        .items_center()
        .justify_center()
        .rounded(px(4.0))
        .hover(|style| style.bg(rgb(0x8392a8).opacity(0.18)))
        .role(AccessibilityRole::Button)
}

fn action_button(
    label: impl Fn() -> &'static str + 'static,
    icon: &'static str,
    press: impl Fn() + 'static,
) -> impl IntoElement {
    view()
        .w(px(25.0))
        .h(px(23.0))
        .items_center()
        .justify_center()
        .rounded(px(4.0))
        .hover(|style| style.bg(rgb(0x8392a8).opacity(0.18)))
        .label(label)
        .role(AccessibilityRole::Button)
        .on_press(press)
        .child(symbol(json!(icon), 14.0))
}

fn surface(dark: bool) -> nsh_core::Color {
    rgb(if dark { 0x1d2129 } else { 0xf3f5f8 }).into()
}

fn secondary(dark: bool) -> nsh_core::Color {
    rgb(if dark { 0xb2b9c5 } else { 0x59616c }).into()
}

fn foreground(dark: bool) -> nsh_core::Color {
    rgb(if dark { 0xe4e7ed } else { 0x20242a }).into()
}

fn divider(dark: bool) -> nsh_core::Color {
    rgb(if dark { 0x353d4b } else { 0xd9dee6 }).into()
}

fn selection(dark: bool) -> nsh_core::Color {
    rgb(if dark { 0x303b4c } else { 0xdfe6f0 }).into()
}

fn hover(dark: bool) -> nsh_core::Color {
    rgb(if dark { 0x282f3c } else { 0xe8ecf2 }).into()
}

fn focus(dark: bool) -> nsh_core::Color {
    rgb(if dark { 0x9cb7ee } else { 0x44669b }).into()
}
