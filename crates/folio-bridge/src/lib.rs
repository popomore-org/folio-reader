use folio_core::{Revision, Workspace};
use serde::Deserialize;
use serde_json::{Value, json};
use std::ffi::{CStr, CString, c_char};

#[derive(Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
enum Request {
    RenderMarkdown {
        source: String,
    },
    List {
        root: String,
        path: String,
    },
    Read {
        root: String,
        path: String,
    },
    Save {
        root: String,
        path: String,
        revision: Revision,
        source: String,
    },
    Git {
        root: String,
        path: String,
    },
    Changes {
        root: String,
        path: String,
    },
    Patch {
        root: String,
        path: String,
        commit: Option<String>,
    },
}

impl Request {
    fn run(self) -> Result<Value, folio_core::Error> {
        Ok(match self {
            Self::RenderMarkdown { source } => json!(folio_core::render_markdown(&source)),
            Self::List { root, path } => json!(Workspace::open(root)?.list(path)?),
            Self::Read { root, path } => json!(Workspace::open(root)?.read(path)?),
            Self::Save {
                root,
                path,
                revision,
                source,
            } => json!(Workspace::open(root)?.save(path, &revision, &source)?),
            Self::Git { root, path } => json!(Workspace::open(root)?.git_file(path)?),
            Self::Changes { root, path } => json!(Workspace::open(root)?.git_changes(path)?),
            Self::Patch { root, path, commit } => {
                json!(Workspace::open(root)?.git_patch(path, commit.as_deref())?)
            }
        })
    }
}

/// # Safety
/// request must be a non-null pointer to a NUL-terminated string valid for this call.
/// The result must be released exactly once with folio_free.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn folio_call(request: *const c_char) -> *mut c_char {
    let response = std::panic::catch_unwind(|| {
        let request = unsafe { CStr::from_ptr(request) };
        match serde_json::from_slice::<Request>(request.to_bytes()) {
            Ok(request) => match request.run() {
                Ok(value) => json!({ "value": value }),
                Err(error) => json!({ "error": error.to_string() }),
            },
            Err(error) => json!({ "error": error.to_string() }),
        }
    })
    .unwrap_or_else(|_| json!({ "error": "The reader could not complete that operation." }));
    CString::new(response.to_string())
        .expect("JSON escapes NUL bytes")
        .into_raw()
}

/// # Safety
/// result must be null or a live pointer returned by folio_call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn folio_free(result: *mut c_char) {
    if !result.is_null() {
        drop(unsafe { CString::from_raw(result) });
    }
}
