#!/bin/sh
set -eu

GIT="${GIT-git}"
GOPLS="${GOPLS-gopls}"
GOFMT="${GOFMT-gofmt}"

go_version="$("$GIT" branch --merged HEAD --list 'upstream/release-branch.go*' | cut -c 29- | LC_ALL=C sort -t . -k 1,1nr -k 2,2nr | head -n 1)"
go_version_major="${go_version%%.*}"
go_version_minor="${go_version#$go_version_major.}"

# Remove deflate code and associated tests.
# Replace former deflate references with Go stdlib deflate references.
# Remove examples.
# Export dictDecoder fields to allow marshalling with gop encoding.
# Export huffmanDecoder fields to allow marshalling with gop encoding.
# Rename root package from `gzip` to `zran`.

extract_struct_fields() (
    struct_name="$1"
    shift
    awk -v struct_name="$struct_name" '
    BEGIN { state="wait_struct" ; }
    state == "wait_struct" && match($0, "^" struct_name " Struct") { state="list_fields_until_endofstruct" ; next ; }
    state == "list_fields_until_endofstruct" && /^[^\t]/ { exit ; }
    state == "list_fields_until_endofstruct" && /^\t/ { print(substr($0, 2)) ; }
    '
)

export_struct_fields() (
    file_path="$1"
    shift
    struct_name="$1"
    shift
    gopls_symbols="$("$GOPLS" symbols "$file_path")"
    fields="$(printf '%s\n' "$gopls_symbols" | extract_struct_fields "$struct_name")"
    printf '%s\n' "$fields" | while read name kind pos ; do
        capitalized_name="$(printf %s "$name" | sed -e 's/^\(.\)/\u\1/')"
        pos_start="${pos%%-*}"
        "$GOPLS" rename -w "$file_path:$pos_start" "$capitalized_name"
    done
)

get_package_declaration() (
    file_path="$1"
    shift
    LC_ALL=C awk '
    /^[[:space:]]*package[[:space:]]+/ {
        package_stmt_line=FNR ;
        match($0, "^[[:space:]]*package[[:space:]]+") ;
        package_name_start=RLENGTH+1 ;
        match(substr($0, package_name_start), "^[^[:space:]]+") ;
        package_name_end=package_name_start+RLENGTH-1 ;
        printf("%s %d:%d-%d:%d\n", substr($0, package_name_start, package_name_end-package_name_start+1), package_stmt_line, package_name_start, package_stmt_line, package_name_end) ;
        exit ;
    }
    ' "$file_path"
)

rm internal/flate/deflate_test.go internal/flate/deflatefast.go internal/flate/writer_test.go internal/flate/huffman_bit_writer_test.go gzip.go gzip_test.go
cat >internal/flate/deflate.go <<'EOF'
// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package flate

const (
	logWindowSize = 15
	windowSize    = 1 << logWindowSize

	// The LZ77 step produces a sequence of literal tokens and <length, offset>
	// pair tokens. The offset is also known as distance. The underlying wire
	// format limits the range of lengths and offsets. For example, there are
	// 256 legitimate lengths: those in the range [3, 258]. This package's
	// compressor uses a higher minimum match length, enabling optimizations
	// such as finding matches via 32-bit loads and compares.
	maxMatchOffset  = 1 << 15 // The largest match offset
)
EOF
cat >internal/flate/huffman_bit_writer.go <<'EOF'
// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package flate

const (
	// The special code used to mark the end of a block.
	endBlockMarker = 256
)
EOF
find . \( \! -path './.git/*' -type f -name 'example_test.go' \) -delete
mv gunzip.go zran.go
mv gunzip_test.go zran_test.go

find . \( \! -path './.git/*' -type f -name '*.go' \) -exec sed -i -E -e 's/(^|[^.])(NewWriter|HuffmanOnly|BestSpeed|DefaultCompression|BestCompression)/\1stdflate.\2/g' -e 's~(//.*)stdflate\.~\1~g' {} +

find . \( \! -path './.git/*' -type f -name '*.go' \) | while read file_path ; do
    package_declaration="$(get_package_declaration "$file_path")"
    package_name_pos="${package_declaration##* }"
    package_stmt_line="${package_name_pos%%:*}"
    if grep -q 'stdflate\.' "$file_path" ; then
        sed -i -e "$package_stmt_line a\\
import stdflate \"compress/flate\"" "$file_path"
        "$GOPLS" imports -w "$file_path"
    fi
done

find . \( ! -name . -prune -name '*.go' \) | while read file_path ; do
    package_declaration="$(get_package_declaration "$file_path")"
    package_name="${package_declaration% *}"
    package_name_pos="${package_declaration##* }"
    package_stmt_line="${package_name_pos%%:*}"
    package_name_pos_start="${package_name_pos%%-*}"
    new_package_name="$(printf %s "$package_name" | sed -e 's/gzip/zran/g')"
    if [ "$new_package_name" != "$package_name" ] ; then
        LC_ALL=C sed -E -i -e "$package_stmt_line s/^([[:space:]]*package[[:space:]]+)([^[:space:]]*)gzip([^[:space:]]*)/\1\2zran\3/g" "$file_path"
    fi
done

export_struct_fields internal/flate/dict_decoder.go dictDecoder
export_struct_fields internal/flate/inflate.go huffmanDecoder
