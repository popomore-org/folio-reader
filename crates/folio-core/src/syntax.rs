use serde::Serialize;
use std::{ops::Range, path::Path, sync::LazyLock};
use two_face::re_exports::syntect::parsing::{
    ParseState, Scope, ScopeStack, SyntaxReference, SyntaxSet,
};

pub(crate) const MAX_HIGHLIGHT_BYTES: usize = 128 * 1024;
// Bound the number of extra DOM elements in a single preview.
pub(crate) const MAX_NUMBERED_LINES: usize = 20_000;
const MAX_LINE_BYTES: usize = 8192;
const MAX_TOKENS: usize = 16384;

static SYNTAXES: LazyLock<SyntaxSet> = LazyLock::new(two_face::syntax::extra_newlines);
static COLORS: LazyLock<Vec<(Scope, SyntaxToken)>> = LazyLock::new(|| {
    use SyntaxToken::*;
    [
        ("comment", Comment),
        ("string", String),
        ("keyword", Keyword),
        ("storage", Keyword),
        ("constant", Constant),
        ("variable.language", Constant),
        ("entity.name.function", Function),
        ("support.function", Function),
        ("entity.name.type", Type),
        ("entity.name.class", Type),
        ("support.type", Type),
        ("support.class", Type),
        ("entity.name.tag", Tag),
        ("markup.heading", Type),
        ("markup.inserted", Added),
        ("markup.deleted", Removed),
    ]
    .into_iter()
    .map(|(scope, token)| (Scope::new(scope).expect("valid built-in scope"), token))
    .collect()
});

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum SyntaxToken {
    Comment,
    String,
    Keyword,
    Constant,
    Function,
    Type,
    Tag,
    Added,
    Removed,
}

impl SyntaxToken {
    fn class(self) -> &'static str {
        match self {
            Self::Comment => "syntax-comment",
            Self::String => "syntax-string",
            Self::Keyword => "syntax-keyword",
            Self::Constant => "syntax-constant",
            Self::Function => "syntax-function",
            Self::Type => "syntax-type",
            Self::Tag => "syntax-tag",
            Self::Added => "syntax-added",
            Self::Removed => "syntax-removed",
        }
    }
}

/// A colored range in source. Both offsets count UTF-16 code units.
#[derive(Debug, PartialEq, Eq, Serialize)]
pub struct SourceHighlight {
    pub start: usize,
    pub end: usize,
    pub token: SyntaxToken,
}

type Span = (Range<usize>, SyntaxToken);

pub(crate) fn for_file(path: &Path) -> Option<&'static SyntaxReference> {
    let name = path.file_name()?.to_str()?;
    if let Some(syntax) = SYNTAXES.find_syntax_by_extension(name)
        && syntax.name != "Plain Text"
        && !name.eq_ignore_ascii_case("log")
    {
        return Some(syntax);
    }
    let extension = path.extension()?.to_str()?.to_ascii_lowercase();
    let extension = match extension.as_str() {
        "txt" | "text" | "log" => return None,
        "jsonl" => "json",
        "patch" => "diff",
        "zsh" => "sh",
        "mdown" | "mkd" => "md",
        _ => &extension,
    };
    SYNTAXES
        .find_syntax_by_extension(extension)
        .filter(|syntax| syntax.name != "Plain Text")
}

pub(crate) fn for_token(token: &str) -> Option<&'static SyntaxReference> {
    let normalized = token.to_ascii_lowercase();
    let token = match normalized.as_str() {
        "" | "text" | "txt" | "plaintext" | "mermaid" | "vega-lite" => return None,
        "shell" | "bash" | "zsh" => "sh",
        "yml" => "yaml",
        "jsonl" => "json",
        _ => &normalized,
    };
    SYNTAXES
        .find_syntax_by_token(token)
        .filter(|syntax| syntax.name != "Plain Text")
}

/// Return syntax color ranges for a local source buffer. Unsupported or oversized
/// input is left uncolored. This function never reads the path from disk.
pub fn highlight_source(path: &Path, source: &str) -> Vec<SourceHighlight> {
    let Some(spans) = for_file(path).and_then(|syntax| tokenize(syntax, source)) else {
        return Vec::new();
    };
    let mut byte_offset = 0;
    let mut utf16_offset = 0;
    spans
        .into_iter()
        .map(|(range, token)| {
            let start = utf16_offset + source[byte_offset..range.start].encode_utf16().count();
            let end = start + source[range.clone()].encode_utf16().count();
            byte_offset = range.end;
            utf16_offset = end;
            SourceHighlight { start, end, token }
        })
        .collect()
}

pub(crate) fn html_for_file(path: &Path, source: &str) -> Option<String> {
    let mut line_budget = MAX_NUMBERED_LINES;
    html(Some(for_file(path)?), source, &mut line_budget, true)
}

pub(crate) fn html(
    grammar: Option<&SyntaxReference>,
    source: &str,
    line_budget: &mut usize,
    include_trailing_empty_line: bool,
) -> Option<String> {
    let line_ends = source
        .match_indices(['\r', '\n'])
        .filter_map(|(offset, character)| {
            let crlf = character == "\r" && source.as_bytes().get(offset + 1) == Some(&b'\n');
            (!crlf).then_some(offset + 1)
        })
        .chain(
            (include_trailing_empty_line || !source.ends_with(['\r', '\n']))
                .then_some(source.len()),
        );
    let line_count = line_ends.clone().take(*line_budget + 1).count();
    let numbered = line_count <= *line_budget;
    if numbered {
        *line_budget -= line_count;
    }
    let spans = grammar
        .and_then(|syntax| tokenize(syntax, source))
        .unwrap_or_default();
    if !numbered && spans.is_empty() {
        return None;
    }

    use crate::document::escape;
    let mut spans = spans.into_iter().peekable();
    let mut out = String::new();
    let mut end = 0;
    for line_end in line_ends
        .take(if numbered { line_count } else { 0 })
        .chain((!numbered).then_some(source.len()))
    {
        if numbered {
            out.push_str("<span class=\"code-line-number\" aria-hidden=\"true\"></span>");
        }
        // A multiline syntax span is reopened after the next line's number.
        while let Some((range, token)) = spans.peek().filter(|(range, _)| range.start < line_end) {
            let start = range.start.max(end);
            let color_end = range.end.min(line_end);
            out.push_str(&escape(&source[end..start]));
            out.push_str("<span class=\"syntax ");
            out.push_str(token.class());
            out.push_str("\">");
            out.push_str(&escape(&source[start..color_end]));
            out.push_str("</span>");
            end = color_end;
            if range.end > line_end {
                break;
            }
            spans.next();
        }
        out.push_str(&escape(&source[end..line_end]));
        end = line_end;
    }
    Some(out)
}

fn tokenize(syntax: &SyntaxReference, source: &str) -> Option<Vec<Span>> {
    if source.len() > MAX_HIGHLIGHT_BYTES || source.lines().any(|line| line.len() > MAX_LINE_BYTES)
    {
        return None;
    }
    let mut state = ParseState::new(syntax);
    let mut stack = ScopeStack::new();
    let mut spans = Vec::new();
    let mut line_offset = 0;
    for line in source.split_inclusive('\n') {
        let mut start = 0;
        for (end, change) in state.parse_line(line, &SYNTAXES).ok()? {
            push_span(&mut spans, line_offset + start..line_offset + end, &stack);
            stack.apply(&change).ok()?;
            start = end;
        }
        push_span(
            &mut spans,
            line_offset + start..line_offset + line.len(),
            &stack,
        );
        if spans.len() > MAX_TOKENS {
            return None;
        }
        line_offset += line.len();
    }
    Some(spans)
}

fn push_span(spans: &mut Vec<Span>, range: Range<usize>, stack: &ScopeStack) {
    if range.is_empty() {
        return;
    }
    let token = stack.as_slice().iter().rev().find_map(|scope| {
        COLORS
            .iter()
            .find_map(|(prefix, token)| prefix.is_prefix_of(*scope).then_some(*token))
    });
    if let Some(token) = token {
        if let Some((previous, color)) = spans.last_mut()
            && *color == token
            && previous.end == range.start
        {
            previous.end = range.end;
        } else {
            spans.push((range, token));
        }
    }
}
