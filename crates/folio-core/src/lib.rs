//! Local reader services. A workspace is the filesystem boundary for every
//! relative path supplied by the host. Operations are synchronous.
mod document;
#[cfg(feature = "git")]
mod history;
mod workspace;

pub use document::{
    Document, FileKind, Heading, Preview, Revision, render_markdown, sanitize_html,
};
#[cfg(feature = "git")]
pub use history::{Commit, GitFile, Patch};
pub use workspace::{Entry, Workspace};

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("This path is outside the selected folder.")]
    OutsideWorkspace,
    #[error("Expected a regular file or folder.")]
    InvalidPath,
    #[error("The file is too large for this preview.")]
    TooLarge,
    #[error("The file could not be decoded as UTF-8.")]
    Encoding,
    #[error("This file type is read-only.")]
    ReadOnly,
    #[error(
        "The file changed on disk. Copy your draft, then reopen the file to review the changes."
    )]
    Conflict,
    #[error("The table could not be read: {0}")]
    Table(#[from] csv::Error),
    #[cfg(feature = "git")]
    #[error("Git: {0}")]
    Git(#[from] git2::Error),
    #[error("{0}")]
    Io(#[from] std::io::Error),
}
