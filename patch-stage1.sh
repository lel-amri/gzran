#!/bin/sh
set -eu

GIT="${GIT-git}"
GOPLS="${GOPLS-gopls}"
GOFMT="${GOFMT-gofmt}"

go_version="$("$GIT" branch --merged HEAD --list 'upstream/release-branch.go*' | cut -c 29- | LC_ALL=C sort -t . -k 1,1nr -k 2,2nr | head -n 1)"
go_version_major="${go_version%%.*}"
go_version_minor="${go_version#$go_version_major.}"

# Add a go.mod file.
# Move the compress/flate package to internal/flate.
# Move the compress/gzip package to the root.
# Replace all occurences of `"compress/flate"` to `"github.com/lel-amri/zran/internal/flate"`.
# Replace all occurences of `"compress/gzip"` to `"github.com/lel-amri/zran"`.
# Remove references to internal/testenv.

cp -R src/compress/gzip/* .
mkdir internal
mv src/compress/flate internal/flate
mv src/compress/testdata internal/testdata
mkdir testdata 2>/dev/null || :
cp -R src/testdata/* testdata
rm -r src
cat >go.mod <<EOF
module github.com/lel-amri/zran

go $go_version
EOF
find . \( \! -path './.git/*' -type f -name '*.go' \) -exec sed -i -e 's~"compress/gzip"~"github.com/lel-amri/zran"~' -e 's~"compress/flate"~"github.com/lel-amri/zran/internal/flate"~' -e 's~testenv\.Builder()~""~' -e 's~testenv\.HasSrc()~false~' {} +
find . \( \! -path './.git/*' -type f -name '*.go' \) -exec "$GOPLS" imports -w {} \;
