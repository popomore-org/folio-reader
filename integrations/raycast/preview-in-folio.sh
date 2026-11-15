#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Preview in Folio
# @raycast.mode silent
# @raycast.packageName Folio
# @raycast.argument1 {"type":"text","placeholder":"Absolute file path (optional)","optional":true}
# @raycast.description Open a local file in Folio’s floating preview window.

set -euo pipefail

if [[ "${FOLIO_PREVIEW_SCHEME:-}" ]]; then
    scheme="$FOLIO_PREVIEW_SCHEME"
elif /usr/bin/open -Ra "Folio" >/dev/null 2>&1; then
    scheme=folio-reader
else
    scheme=folio-reader-preview
fi

target="$scheme://preview"
if [[ -n "${1:-}" ]]; then
    path="$1"
    if [[ "$path" == \~/* ]]; then path="$HOME/${path:2}"; fi
    if [[ "$path" != /* || ! -f "$path" ]]; then
        printf 'Enter the absolute path of a local file.\n' >&2
        exit 1
    fi
    encoded=$(/usr/bin/perl -e '$path = $ARGV[0]; $path =~ s/([^A-Za-z0-9._~-])/sprintf("%%%02X", ord($1))/ge; print $path' "$path")
    target="$target?path=$encoded"
fi

/usr/bin/open "$target"
