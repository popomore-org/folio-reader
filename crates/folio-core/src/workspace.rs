use crate::{Document, Error, FileKind, Revision, document};
use serde::Serialize;
use std::{
    fs,
    io::{Read, Write},
    path::{Component, Path, PathBuf},
    sync::Mutex,
};

const MAX_TEXT_BYTES: u64 = 8 * 1024 * 1024;
const MAX_ENTRIES: usize = 5_000;
static WRITE_LOCK: Mutex<()> = Mutex::new(());

#[derive(Debug, Clone)]
pub struct Workspace {
    root: PathBuf,
}

#[derive(Debug, Serialize)]
pub struct Entry {
    pub name: String,
    pub path: String,
    pub directory: bool,
    pub kind: Option<FileKind>,
}

impl Workspace {
    pub fn open(root: impl AsRef<Path>) -> Result<Self, Error> {
        let root = root.as_ref().canonicalize()?;
        if !root.is_dir() {
            return Err(Error::InvalidPath);
        }
        Ok(Self { root })
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Resolve an existing relative path inside this workspace. Symlinks are
    /// allowed to resolve inside the workspace, but are never writable aliases.
    pub fn resolve(&self, path: impl AsRef<Path>) -> Result<PathBuf, Error> {
        let path = path.as_ref();
        if path
            .components()
            .any(|part| !matches!(part, Component::Normal(_)))
        {
            return Err(Error::OutsideWorkspace);
        }
        if path.components().any(|part| part.as_os_str() == ".git") {
            return Err(Error::OutsideWorkspace);
        }
        let resolved = self.root.join(path).canonicalize()?;
        if !resolved.starts_with(&self.root) {
            return Err(Error::OutsideWorkspace);
        }
        if resolved
            .strip_prefix(&self.root)
            .is_ok_and(|path| path.components().any(|part| part.as_os_str() == ".git"))
        {
            return Err(Error::OutsideWorkspace);
        }
        Ok(resolved)
    }

    /// List one directory. Hidden files are excluded. Excessive collections
    /// return an error so a host never presents a silently truncated directory.
    pub fn list(&self, path: impl AsRef<Path>) -> Result<Vec<Entry>, Error> {
        let folder = self.resolve(path)?;
        let mut entries = Vec::new();
        for entry in fs::read_dir(folder)? {
            let entry = entry?;
            let name = entry.file_name();
            let Some(name) = name.to_str().filter(|name| !name.starts_with('.')) else {
                continue;
            };
            let file_type = entry.file_type()?;
            if !file_type.is_dir() && !file_type.is_file() {
                continue;
            }
            if entries.len() == MAX_ENTRIES {
                return Err(Error::TooLarge);
            }
            let path = entry.path();
            let relative = path
                .strip_prefix(&self.root)
                .map_err(|_| Error::OutsideWorkspace)?;
            entries.push(Entry {
                name: name.to_owned(),
                path: relative.to_str().ok_or(Error::InvalidPath)?.to_owned(),
                directory: file_type.is_dir(),
                kind: file_type.is_file().then(|| FileKind::from_path(&path)),
            });
        }
        entries.sort_by_cached_key(|entry| (!entry.directory, entry.name.to_lowercase()));
        Ok(entries)
    }

    pub fn read(&self, path: impl AsRef<Path>) -> Result<Document, Error> {
        let path = path.as_ref();
        let resolved = self.resolve(path)?;
        let metadata = resolved.metadata()?;
        if !metadata.is_file() {
            return Err(Error::InvalidPath);
        }
        let kind = FileKind::from_path(&resolved);
        let mut document = Document::new(kind, metadata.len());
        if kind.has_text() {
            let bytes = read_text_bytes(&resolved)?;
            document.load_text(&bytes, &resolved)?;
            if kind.editable() && resolved == self.root.join(path) {
                document.revision = Some(Revision::of(&bytes));
            }
        }
        Ok(document)
    }

    /// Atomically replace an editable file after checking the revision observed
    /// at read time. Serializes saves through this library in one process.
    /// File ownership, ACLs and extended attributes are not revisioned.
    pub fn save(
        &self,
        path: impl AsRef<Path>,
        expected: &Revision,
        source: &str,
    ) -> Result<Revision, Error> {
        let _guard = WRITE_LOCK
            .lock()
            .unwrap_or_else(|poison| poison.into_inner());
        let path = path.as_ref();
        let target = self.resolve(path)?;
        if target != self.root.join(path) || !FileKind::from_path(&target).editable() {
            return Err(Error::ReadOnly);
        }
        if !target.is_file() {
            return Err(Error::InvalidPath);
        }
        let original = read_text_bytes(&target)?;
        if Revision::of(&original) != *expected {
            return Err(Error::Conflict);
        }
        let (previous, bom) = document::decode_text(&original)?;
        let newline = if previous.contains("\r\n") && !previous.replace("\r\n", "").contains('\n') {
            source.replace("\r\n", "\n").replace('\n', "\r\n")
        } else {
            source.to_owned()
        };
        let mut bytes = Vec::new();
        if bom {
            bytes.extend_from_slice(b"\xEF\xBB\xBF");
        }
        bytes.extend_from_slice(newline.as_bytes());
        if bytes.len() as u64 > MAX_TEXT_BYTES {
            return Err(Error::TooLarge);
        }
        if bytes == original {
            return Ok(expected.clone());
        }
        let parent = target.parent().ok_or(Error::InvalidPath)?;
        let mut file = tempfile::NamedTempFile::new_in(parent)?;
        file.write_all(&bytes)?;
        file.as_file()
            .set_permissions(target.metadata()?.permissions())?;
        file.as_file().sync_all()?;
        if self.resolve(path)? != target || read_text_bytes(&target)? != original {
            return Err(Error::Conflict);
        }
        file.persist(target).map_err(|failure| failure.error)?;
        Ok(Revision::of(&bytes))
    }
}

fn read_text_bytes(path: &Path) -> Result<Vec<u8>, Error> {
    let file = fs::File::open(path)?;
    if !file.metadata()?.is_file() {
        return Err(Error::InvalidPath);
    }
    let mut bytes = Vec::new();
    file.take(MAX_TEXT_BYTES + 1).read_to_end(&mut bytes)?;
    if bytes.len() as u64 > MAX_TEXT_BYTES {
        return Err(Error::TooLarge);
    }
    Ok(bytes)
}
