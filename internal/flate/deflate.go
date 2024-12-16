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
