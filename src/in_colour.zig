// Copyright © 2023 Matthew Winter
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

const std = @import("std");
const zap = @import("zap");

const File = std.fs.File;

/// In Colour
///
/// Provides an easy way to write in colour to the terminal using the standard
/// [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors)
/// to specify Colour and Style Formatting.
///
const Self = @This();

pub const UseColour = enum {
    always,
    never,
    auto,
};

/// Identifies the Buffered Stream we will write to, e.g. `stdout`
out: BufferedStream,

/// Activates colour and style formatting functionality using
/// [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors)
///
enable_ansi_colours: bool,

/// ANSI Codes for Colours and Styles
///
pub const ansi_codes = .{
    .reset = "\x1b[0m",
    .bold = "\x1b[1m",
    .dim = "\x1b[2m",
    .italic = "\x1b[3m",
    .underline = "\x1b[4m",
    .strike = "\x1b[9m",
    .black = "\x1b[30m",
    .red = "\x1b[31m",
    .green = "\x1b[32m",
    .yellow = "\x1b[33m",
    .blue = "\x1b[34m",
    .magenta = "\x1b[35m",
    .cyan = "\x1b[36m",
    .white = "\x1b[37m",
    .bright_black = "\x1b[90m",
    .bright_red = "\x1b[91m",
    .bright_green = "\x1b[92m",
    .bright_yellow = "\x1b[93m",
    .bright_blue = "\x1b[94m",
    .bright_magenta = "\x1b[95m",
    .bright_cyan = "\x1b[96m",
    .bright_white = "\x1b[97m",
};

/// In Colour `init` function
///
/// Provides an easy way to write in colour to the terminal using the standard
/// [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors)
/// to specify Colour and Style Formatting.
///
/// _use_colour_: defines what rule to follow when determining whether we should
/// enable the use of ANSI Escape Codes for colour and style formattiing.
///
/// _no_color_: when `use_colour.auto` set this argument to `true` when the
/// [NO_COLOUR](https://no-color.org/) environment variable is present and not
/// an empty string (regardless of its value) to prevent the use of ANSI Colours.
///
/// Deinitialize using `deinit` to flush buffers and deallocate memory.
pub fn init(file: File, use_colour: UseColour, no_color: bool) Self {
    return .{
        .out = std.io.bufferedWriter(file.writer()),
        .enable_ansi_colours = switch (use_colour) {
            .always => true,
            .never => false,
            .auto => !no_color and std.os.isatty(file.handle),
        },
    };
}

/// Flush the buffer and release any allocated memory.
pub fn deinit(self: *Self) void {
    self.flush();
}

/// Flush the buffer
pub fn flush(self: *Self) void {
    self.out.flush() catch {};
}

/// Write the raw bytes and return a count of the number of bytes written
pub inline fn write(self: *Self, bytes: []const u8) !usize {
    return self.out.writer().write(bytes);
}

/// Render the format string using the provided data before writing to the buffer
///
/// The format string must be comptime-known and may contain placeholders following
/// this format:
/// `{[argument][specifier]:[fill][alignment][width].[precision]}`
pub inline fn format(self: *Self, comptime text: []const u8, data: anytype) !void {
    return std.fmt.format(self.out.writer(), text, data);
}

/// Parses the [mustache](https://mustache.github.io/) logic-less template and
/// renders with the given data before returning an owned slice with the content.
/// Caller must free the memory.
pub fn mustacheFormat(self: *Self, template: []const u8, data: anytype) !usize {
    var mustache = try zap.Mustache.fromData(template);
    defer mustache.deinit();

    const result = mustache.build(data);
    defer result.deinit();

    if (result.str()) |s| {
        return self.out.writer().write(s);
    }
    return 0;
}

/// Buffered Stream Type
pub const BufferedStream: type = struct {
    fn getBufferedStream() type {
        return std.io.BufferedWriter(4096, @TypeOf(File.writer(undefined)));
    }
}.getBufferedStream();
