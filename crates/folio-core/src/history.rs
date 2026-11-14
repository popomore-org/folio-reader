use crate::{Error, Workspace};
use git2::{Diff, DiffFormat, DiffOptions, ErrorCode, Oid, Repository, Status};
use serde::Serialize;
use std::path::{Path, PathBuf};

const MAX_PATCH: usize = 160_000;
const MAX_COMMITS: usize = 50;
const MAX_SCANNED: usize = 3_000;

#[derive(Debug, Serialize)]
pub struct Commit {
    pub id: String,
    pub summary: String,
    pub author: String,
    pub timestamp: i64,
}

#[derive(Debug, Serialize)]
pub struct GitFile {
    pub staged: Option<String>,
    pub unstaged: Option<String>,
    pub commits: Vec<Commit>,
    pub limited: bool,
}

#[derive(Debug, Serialize)]
pub struct Patch {
    pub text: String,
    pub truncated: bool,
}

impl Workspace {
    /// Return the current file's status and first-parent history at this path.
    /// Returns None when the workspace is outside any working tree.
    pub fn git_file(&self, path: impl AsRef<Path>) -> Result<Option<GitFile>, Error> {
        let Some((repo, path)) = self.git_path(path.as_ref())? else {
            return Ok(None);
        };
        let flags = match repo.status_file(&path) {
            Ok(flags) => flags,
            Err(err) if err.code() == ErrorCode::NotFound => Status::CURRENT,
            Err(err) => return Err(err.into()),
        };
        let staged = status(
            &[
                (Status::CONFLICTED, "Conflict"),
                (Status::INDEX_NEW, "Added"),
                (Status::INDEX_MODIFIED, "Modified"),
                (Status::INDEX_DELETED, "Deleted"),
                (Status::INDEX_RENAMED, "Renamed"),
                (Status::INDEX_TYPECHANGE, "Type changed"),
            ],
            flags,
        );
        let unstaged = status(
            &[
                (Status::CONFLICTED, "Conflict"),
                (Status::IGNORED, "Ignored"),
                (Status::WT_NEW, "Untracked"),
                (Status::WT_MODIFIED, "Modified"),
                (Status::WT_DELETED, "Deleted"),
                (Status::WT_RENAMED, "Renamed"),
                (Status::WT_TYPECHANGE, "Type changed"),
            ],
            flags,
        );
        let mut commits = Vec::new();
        let mut current = head(&repo)?;
        let mut scanned = 0;
        while let Some(commit) = current {
            if scanned == MAX_SCANNED || commits.len() == MAX_COMMITS {
                return Ok(Some(GitFile {
                    staged,
                    unstaged,
                    commits,
                    limited: true,
                }));
            }
            scanned += 1;
            let parent = commit.parent(0).ok();
            let old = parent
                .as_ref()
                .map(|p| tree_entry(p, &path))
                .transpose()?
                .flatten();
            let new = tree_entry(&commit, &path)?;
            if old != new {
                commits.push(Commit {
                    id: commit.id().to_string(),
                    summary: commit
                        .summary()
                        .ok()
                        .flatten()
                        .unwrap_or("(no subject)")
                        .to_owned(),
                    author: commit.author().name().unwrap_or("Unknown").to_owned(),
                    timestamp: commit.time().seconds(),
                });
            }
            current = parent;
        }
        Ok(Some(GitFile {
            staged,
            unstaged,
            commits,
            limited: false,
        }))
    }

    /// A commit SHA selects a commit's patch against its first parent.
    /// Without a commit, staged and unstaged patches are shown separately.
    pub fn git_patch(
        &self,
        path: impl AsRef<Path>,
        commit: Option<&str>,
    ) -> Result<Option<Patch>, Error> {
        let Some((repo, path)) = self.git_path(path.as_ref())? else {
            return Ok(None);
        };
        let mut opts = DiffOptions::new();
        opts.pathspec(path)
            .disable_pathspec_match(true)
            .max_size(8 * 1024 * 1024);
        let mut patch = Patch {
            text: String::new(),
            truncated: false,
        };
        if let Some(id) = commit {
            if id.len() != 40 || !id.bytes().all(|byte| byte.is_ascii_hexdigit()) {
                return Err(Error::InvalidPath);
            }
            let commit = repo.find_commit(Oid::from_str(id)?)?;
            let parent = commit
                .parent(0)
                .ok()
                .map(|parent| parent.tree())
                .transpose()?;
            append(
                &mut patch,
                &repo.diff_tree_to_tree(parent.as_ref(), Some(&commit.tree()?), Some(&mut opts))?,
            )?;
        } else {
            let tree = head(&repo)?.map(|commit| commit.tree()).transpose()?;
            let staged = repo.diff_tree_to_index(tree.as_ref(), None, Some(&mut opts))?;
            if staged.deltas().len() != 0 {
                patch.text.push_str("Staged\n\n");
                append(&mut patch, &staged)?;
            }
            opts.include_untracked(true).show_untracked_content(true);
            let unstaged = repo.diff_index_to_workdir(None, Some(&mut opts))?;
            if !patch.truncated && unstaged.deltas().len() != 0 {
                if !patch.text.is_empty() {
                    patch.text.push('\n');
                }
                patch.text.push_str("Working tree\n\n");
                append(&mut patch, &unstaged)?;
            }
        }
        Ok(Some(patch))
    }

    fn git_path(&self, file: &Path) -> Result<Option<(Repository, PathBuf)>, Error> {
        let full = self.resolve(file)?;
        if !full.is_file() {
            return Err(Error::InvalidPath);
        }
        let Some(parent) = full.parent() else {
            return Err(Error::InvalidPath);
        };
        let repo = match Repository::discover(parent) {
            Ok(repo) => repo,
            Err(err) if err.code() == ErrorCode::NotFound => return Ok(None),
            Err(err) => return Err(err.into()),
        };
        let Some(workdir) = repo.workdir() else {
            return Ok(None);
        };
        let path = full
            .strip_prefix(workdir.canonicalize()?)
            .map_err(|_| Error::OutsideWorkspace)?
            .to_owned();
        Ok(Some((repo, path)))
    }
}

fn head(repo: &Repository) -> Result<Option<git2::Commit<'_>>, Error> {
    match repo.head() {
        Ok(head) => Ok(Some(head.peel_to_commit()?)),
        Err(err) if matches!(err.code(), ErrorCode::UnbornBranch | ErrorCode::NotFound) => Ok(None),
        Err(err) => Err(err.into()),
    }
}

fn tree_entry(commit: &git2::Commit<'_>, path: &Path) -> Result<Option<(Oid, i32)>, Error> {
    match commit.tree()?.get_path(path) {
        Ok(entry) => Ok(Some((entry.id(), entry.filemode()))),
        Err(err) if err.code() == ErrorCode::NotFound => Ok(None),
        Err(err) => Err(err.into()),
    }
}

fn status(choices: &[(Status, &str)], actual: Status) -> Option<String> {
    choices
        .iter()
        .find(|(flag, _)| actual.contains(*flag))
        .map(|(_, name)| (*name).to_owned())
}

fn append(patch: &mut Patch, diff: &Diff<'_>) -> Result<(), Error> {
    let result = diff.print(DiffFormat::Patch, |_, _, line| {
        let prefix = line.origin();
        let content = String::from_utf8_lossy(line.content());
        if patch.text.len() + content.len() + 1 > MAX_PATCH {
            patch.truncated = true;
            return false;
        }
        if matches!(prefix, '+' | '-' | ' ') {
            patch.text.push(prefix);
        }
        patch.text.push_str(&content);
        true
    });
    if !patch.truncated {
        result?;
    }
    Ok(())
}
