#[cfg(target_os = "macos")]
mod macos;

#[cfg(target_os = "macos")]
pub use folio_bridge::{folio_call, folio_free};
