use nsh_core::prelude::*;
use nsh_platform_macos::{
    App, AppOptions, AppView, NativeComponent, Root,
    objc2::{MainThreadMarker, rc::Retained},
    objc2_app_kit::{NSColor, NSImage, NSImageView, NSView},
    objc2_foundation::{NSRect, NSString},
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::{
    collections::HashMap,
    ffi::c_void,
    rc::Rc,
    sync::{
        Arc, LazyLock, Mutex, Weak,
        atomic::{AtomicPtr, AtomicU32, Ordering},
    },
};
use tokio::sync::watch;

mod workspace;

type Callback = extern "C" fn(*mut c_void, *const u8, usize);

#[derive(Clone, Debug, Default, Deserialize, PartialEq)]
#[serde(default, rename_all = "camelCase")]
struct Snapshot {
    dark: bool,
    sidebar: bool,
    git_available: bool,
    showing_git: bool,
    details: String,
    title: String,
    trailing_icon: Option<String>,
    rows: Vec<Row>,
    disabled: bool,
    cursor: Option<String>,
    keyboard_focus: bool,
    show_author: bool,
}

#[derive(Clone, Debug, Default, Deserialize, PartialEq)]
#[serde(default, rename_all = "camelCase")]
struct Row {
    id: String,
    title: String,
    icon: String,
    tip: String,
    depth: u8,
    selected: bool,
    active: bool,
    dirty: bool,
    expanded: Option<bool>,
    message: bool,
    detail: String,
    author: String,
    date: String,
    revision: String,
}

#[derive(Default, Serialize)]
struct Action {
    name: &'static str,
    id: Option<String>,
    alternate: bool,
    point: Option<[f32; 2]>,
}

#[derive(Clone, Copy)]
enum Region {
    Status,
    Tabs,
    Outline,
    Folders,
    GitHeader,
    GitChanges,
    GitHistory,
}

struct Channel {
    region: Region,
    state: watch::Sender<Snapshot>,
    context: AtomicPtr<c_void>,
    callback: Callback,
}

impl Channel {
    fn action(self: &Arc<Self>, name: &'static str) {
        self.send(Action {
            name,
            ..Action::default()
        });
    }

    fn send(self: &Arc<Self>, action: Action) {
        let Ok(bytes) = serde_json::to_vec(&action) else {
            return;
        };
        let weak = Arc::downgrade(self);
        let _submitted = run_on_main_thread(move || {
            if let Some(channel) = weak.upgrade() {
                let context = channel.context.load(Ordering::Relaxed);
                if !context.is_null() {
                    (channel.callback)(context, bytes.as_ptr(), bytes.len());
                }
            }
        });
    }
}

static NEXT_ID: AtomicU32 = AtomicU32::new(1);
static CHANNELS: LazyLock<Mutex<HashMap<u32, Weak<Channel>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

struct Surface {
    id: u32,
    channel: Arc<Channel>,
    app: Rc<AppView>,
}

#[unsafe(no_mangle)]
pub extern "C" fn folio_ui_create(
    region: u32,
    context: *mut c_void,
    callback: Callback,
) -> *mut c_void {
    let Some(main) = MainThreadMarker::new() else {
        return std::ptr::null_mut();
    };
    let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
    let region = match region {
        0 => Region::Status,
        1 => Region::Tabs,
        2 => Region::Outline,
        3 => Region::Folders,
        4 => Region::GitHeader,
        5 => Region::GitChanges,
        6 => Region::GitHistory,
        _ => return std::ptr::null_mut(),
    };
    let channel = Arc::new(Channel {
        region,
        state: watch::channel(Snapshot::default()).0,
        context: AtomicPtr::new(context),
        callback,
    });
    CHANNELS
        .lock()
        .unwrap()
        .insert(id, Arc::downgrade(&channel));
    let app = AppView::new(
        main,
        AppOptions {
            transparent: true,
            ..AppOptions::default()
        },
    );
    app.register_component(
        "folio.symbol",
        Rc::new(move |_| Box::new(Symbol::new(main))),
    );
    app.load(App::Rust(Root::new::<WorkspaceRegion>(move || {
        WorkspaceRegionProps { id }
    })));
    Box::into_raw(Box::new(Surface { id, channel, app })).cast()
}

/// All handles are owned by the Swift view coordinator and accessed on the main thread.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn folio_ui_view(handle: *mut c_void) -> *mut c_void {
    let surface = unsafe { &*handle.cast::<Surface>() };
    (&*surface.app.view() as *const _ as *mut c_void).cast()
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn folio_ui_update(handle: *mut c_void, bytes: *const u8, len: usize) {
    let surface = unsafe { &*handle.cast::<Surface>() };
    let Ok(state) =
        serde_json::from_slice::<Snapshot>(unsafe { std::slice::from_raw_parts(bytes, len) })
    else {
        return;
    };
    surface.channel.state.send_if_modified(|current| {
        if *current == state {
            return false;
        }
        *current = state;
        true
    });
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn folio_ui_destroy(handle: *mut c_void) {
    let surface = unsafe { Box::from_raw(handle.cast::<Surface>()) };
    surface
        .channel
        .context
        .store(std::ptr::null_mut(), Ordering::Relaxed);
    CHANNELS.lock().unwrap().remove(&surface.id);
    surface.app.stop();
}

#[derive(Clone, PartialEq, Props)]
struct WorkspaceRegionProps {
    id: u32,
}

#[component]
fn WorkspaceRegion(WorkspaceRegionProps { id }: WorkspaceRegionProps) -> impl IntoElement {
    let Some(channel) = CHANNELS.lock().unwrap().get(&id).and_then(Weak::upgrade) else {
        // AppKit may remove a surface before its engine mounts the root.
        return view().into_element();
    };
    let mut watch = channel.state.subscribe();
    let state = signal(watch.borrow_and_update().clone());
    spawn(async move {
        while watch.changed().await.is_ok() {
            state.set(watch.borrow_and_update().clone());
        }
    });

    match channel.region {
        Region::Status => workspace::status_bar(state, channel).into_element(),
        Region::Tabs => workspace::tab_bar(state, channel).into_element(),
        Region::Outline => workspace::outline(state, channel).into_element(),
        Region::Folders => workspace::folders(state, channel).into_element(),
        Region::GitHeader => workspace::git_header(state, channel).into_element(),
        Region::GitChanges => workspace::git_changes(state, channel).into_element(),
        Region::GitHistory => workspace::git_history(state, channel).into_element(),
    }
}

struct Symbol(Retained<NSImageView>);

impl Symbol {
    fn new(main: MainThreadMarker) -> Self {
        let image = NSImageView::initWithFrame(main.alloc(), NSRect::ZERO);
        image.setContentTintColor(Some(&NSColor::secondaryLabelColor()));
        Self(image)
    }
}

impl NativeComponent for Symbol {
    fn view(&self) -> Retained<NSView> {
        Retained::into_super(Retained::into_super(self.0.clone()))
    }

    fn set_prop(&mut self, name: &str, value: Option<&Value>) {
        if name == "name" {
            let image = value.and_then(Value::as_str).and_then(|name| {
                NSImage::imageWithSystemSymbolName_accessibilityDescription(
                    &NSString::from_str(name),
                    None,
                )
            });
            self.0.setImage(image.as_deref());
        }
    }
}

fn symbol(name: impl IntoReactive<Value>, size: f32) -> impl IntoElement {
    native("folio.symbol")
        .prop("name", name)
        .w(px(size))
        .h(px(size))
        .pointer_events(nsh_core::PointerEvents::None)
        .accessible(false)
}
