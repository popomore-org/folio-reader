use super::{
    action_button, foreground, hint, hit_area, rule, secondary, selection, surface, symbol,
};
use crate::macos::{Action, Channel, Snapshot};
use nsh_core::{AccessibilityRole, prelude::*};
use serde_json::json;
use std::sync::Arc;

pub(in crate::macos) fn git_header(
    state: Signal<Snapshot>,
    channel: Arc<Channel>,
) -> impl IntoElement {
    let page = channel.clone();
    view()
        .w_full()
        .h_full()
        .flex_row()
        .items_center()
        .px(px(7.0))
        .gap(px(4.0))
        .bg(move || surface(state.with(|state| state.dark)))
        .child(each(
            move || state.with(|state| state.rows.clone()),
            |row| row.id.clone(),
            move |row, _| {
                let channel = page.clone();
                hit_area()
                    .h(px(25.0))
                    .px(px(9.0))
                    .label(move || row.get().title)
                    .accessibility_state(move || nsh_core::AccessibilityState {
                        selected: row.get().selected,
                        ..Default::default()
                    })
                    .bg(move || selected_background(state, row.get().selected))
                    .on_press(move || {
                        channel.send(Action {
                            name: "git_page",
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
        ))
        .child(view().flex_1())
        .child(when(
            move || state.with(|state| !state.details.is_empty()),
            move || {
                view()
                    .flex_row()
                    .items_center()
                    .gap(px(5.0))
                    .min_w(px(0.0))
                    .child(symbol(json!("arrow.triangle.branch"), 13.0))
                    .child(
                        text(move || state.with(|state| state.details.clone()))
                            .text_size(px(11.0))
                            .truncate()
                            .text_color(move || secondary(state.with(|state| state.dark))),
                    )
            },
        ))
        .child(action_button(
            || "Refresh Git",
            "arrow.clockwise",
            move || channel.action("git_reload"),
        ))
}

pub(in crate::macos) fn git_changes(
    state: Signal<Snapshot>,
    channel: Arc<Channel>,
) -> impl IntoElement {
    scroll().w_full().h_full().child(
        view()
            .p(px(6.0))
            .gap(px(2.0))
            .child(each(
                move || state.with(|state| state.rows.clone()),
                |row| row.id.clone(),
                move |row, _| {
                    let channel = channel.clone();
                    hit_area()
                        .flex_row()
                        .justify_start()
                        .gap(px(8.0))
                        .px(px(7.0))
                        .py(px(5.0))
                        .w_full()
                        .min_h(px(35.0))
                        .label(move || format!("{}, {}", row.get().title, row.get().detail))
                        .bg(move || selected_background(state, row.get().selected))
                        .accessibility_state(move || nsh_core::AccessibilityState {
                            selected: row.get().selected,
                            ..Default::default()
                        })
                        .tooltip(hint(state, move || row.get().tip))
                        .on_press(move || {
                            channel.send(Action {
                                name: "git_change",
                                id: Some(row.get().id),
                                ..Action::default()
                            })
                        })
                        .child(symbol(move || json!(row.get().icon), 14.0))
                        .child(
                            view()
                                .min_w(px(0.0))
                                .flex_1()
                                .gap(px(3.0))
                                .child(
                                    text(move || row.get().title)
                                        .text_size(px(12.0))
                                        .truncate()
                                        .text_color(move || {
                                            foreground(state.with(|state| state.dark))
                                        }),
                                )
                                .child(
                                    text(move || row.get().detail)
                                        .text_size(px(11.0))
                                        .truncate()
                                        .text_color(move || {
                                            secondary(state.with(|state| state.dark))
                                        }),
                                ),
                        )
                },
            ))
            .child(git_footer(state)),
    )
}

pub(in crate::macos) fn git_history(
    state: Signal<Snapshot>,
    channel: Arc<Channel>,
) -> impl IntoElement {
    view()
        .w_full()
        .h_full()
        .child(
            history_columns(
                state,
                || "Summary".into(),
                || "Author".into(),
                || "Date".into(),
                || "Commit".into(),
            )
            .role(AccessibilityRole::Header)
            .flex_none(),
        )
        .child(rule(state))
        .child(
            scroll().flex_1().min_h(px(0.0)).child(
                view()
                    .px(px(4.0))
                    .py(px(3.0))
                    .gap(px(1.0))
                    .child(each(
                        move || state.with(|state| state.rows.clone()),
                        |row| row.id.clone(),
                        move |row, _| {
                            let channel = channel.clone();
                            hit_area()
                                .h(px(24.0))
                                .w_full()
                                .label(move || {
                                    format!("{} · {}", row.get().title, row.get().author)
                                })
                                .bg(move || selected_background(state, row.get().selected))
                                .accessibility_state(move || nsh_core::AccessibilityState {
                                    selected: row.get().selected,
                                    ..Default::default()
                                })
                                .tooltip(hint(state, move || row.get().tip))
                                .on_press(move || {
                                    channel.send(Action {
                                        name: "git_commit",
                                        id: Some(row.get().id),
                                        ..Action::default()
                                    })
                                })
                                .child(history_columns(
                                    state,
                                    move || row.get().title,
                                    move || row.get().author,
                                    move || row.get().date,
                                    move || row.get().revision,
                                ))
                        },
                    ))
                    .child(git_footer(state)),
            ),
        )
}

fn history_columns(
    state: Signal<Snapshot>,
    summary: impl Fn() -> String + 'static,
    author: impl Fn() -> String + Clone + 'static,
    date: impl Fn() -> String + 'static,
    revision: impl Fn() -> String + 'static,
) -> View {
    view()
        .flex_row()
        .w_full()
        .h(px(24.0))
        .items_center()
        .px(px(9.0))
        .gap(px(9.0))
        .child(
            text(summary)
                .flex_1()
                .min_w(px(0.0))
                .truncate()
                .text_size(px(12.0))
                .text_color(move || foreground(state.with(|state| state.dark))),
        )
        .child(when(
            move || state.with(|state| state.show_author),
            move || history_column(state, author.clone(), 116.0),
        ))
        .child(history_column(state, date, 86.0))
        .child(history_column(state, revision, 67.0))
}

fn history_column(
    state: Signal<Snapshot>,
    value: impl Fn() -> String + 'static,
    width: f32,
) -> Text {
    text(value)
        .flex_none()
        .w(px(width))
        .truncate()
        .text_size(px(11.0))
        .text_color(move || secondary(state.with(|state| state.dark)))
}

fn git_footer(state: Signal<Snapshot>) -> impl IntoElement {
    when(
        move || state.with(|state| !state.details.is_empty()),
        move || {
            text(move || state.with(|state| state.details.clone()))
                .p(px(6.0))
                .text_size(px(11.0))
                .text_color(move || secondary(state.with(|state| state.dark)))
        },
    )
}

fn selected_background(state: Signal<Snapshot>, selected: bool) -> nsh_core::Color {
    if selected {
        selection(state.with(|state| state.dark))
    } else {
        Rgba::default().into()
    }
}
