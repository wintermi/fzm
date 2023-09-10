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
const builtin = @import("builtin");
const clap = @import("clap");
const in_colour = @import("in_colour.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

/// Command Line Application
///
/// Provides the base functionality for building a Command Line Application.
/// Extends the `zig-clap` package to provide sub commands in a simple reusable way.
const Self = @This();

/// Name of the Command Line Applications
name: []const u8,

/// Version of the Command Line Applications
version: []const u8,

/// Description of the Command Line Applications
description: []const u8,

/// Author of the Command Line Applications
author: []const u8,

/// Copyright Statement for the Command Line Applications
copyright: []const u8,

/// Memory Allocator used by the Command Line Applications
allocator: Allocator,

/// List of Sub Commands
commands: ArrayList(Command),

/// Print to stdout
stdout: in_colour,

/// Print to stderr
stderr: in_colour,

/// CPU Architecture
arch: []const u8,

/// Operating System
os: []const u8,

/// Indicator showing that the init is complete
init_done: bool = false,

/// Command Line Application `init` function
///
/// Deinitialize using `deinit` to flush buffers and deallocate memory.
pub fn init(allocator: Allocator) Self {
    var _commands = ArrayList(Command).init(allocator);

    _commands.append(.{
        .name = "help",
        .func = printHelpAndExit,
        .description = "Print this help message and exit",
    }) catch {};

    _commands.append(.{
        .name = "version",
        .func = printVersionAndExit,
        .description = "Print the app version",
    }) catch {};

    return .{
        .name = undefined,
        .version = undefined,
        .description = undefined,
        .author = undefined,
        .copyright = undefined,
        .allocator = allocator,
        .commands = _commands,

        // TODO: Populate `no_color=true` when the 'NO_COLOR' environment variable present and not an empty string (regardless of its value)
        .stdout = in_colour.init(std.io.getStdOut(), .auto, false),
        .stderr = in_colour.init(std.io.getStdErr(), .auto, false),

        .arch = builtin.target.cpu.arch.genericName(),
        .os = @tagName(builtin.target.os.tag),
        .init_done = true,
    };
}

/// Flush buffers and release any allocated memory.
pub fn deinit(self: *Self) void {
    std.debug.assert(self.init_done);

    self.stdout.deinit();
    self.stderr.deinit();
    self.commands.deinit();
}

/// Add a Sub Command to the Command Line Application
pub fn addCommand(self: *Self, command: Command) anyerror!void {
    std.debug.assert(self.init_done);

    try self.commands.append(command);
}

/// Get the Sub Command specified by the provided index
pub fn getCommand(self: *Self, index: usize) Command {
    std.debug.assert(self.init_done);

    if (index >= 0 and index < self.commands.items.len) {
        return self.commands.items[index];
    }
    return undefined;
}

/// Parse the arguments to find which Sub Command was requested
/// Return an optional type containing the `index` of the Sub Command if found
pub fn parseCommand(self: *Self) ?usize {
    var args_iter = try std.process.argsWithAllocator(self.allocator);
    defer args_iter.deinit();

    _ = args_iter.next();

    const args_command = args_iter.next() orelse "help";
    for (self.commands.items, 0..) |command, index| {
        if (std.mem.eql(u8, args_command, command.name)) {
            return index;
        }
    }

    return null;
}

/// Sub Command
///
/// Configuration details required for parsing the sub command
pub const Command = struct {
    name: []const u8,
    func: *const fn (*Self) noreturn,
    description: []const u8,
};

//-----------------------------------------------------------------------------
// Default Help and Version
//-----------------------------------------------------------------------------

/// Print the default app version text
pub fn printVersionAndExit(self: *Self) noreturn {
    @setCold(true);

    const template =
        \\{{{style.reset}}}{{{style.green}}}{{{app.name}}}{{{style.reset}}}, {{{app.version}}} {{{app.os}}}/{{{app.arch}}}
        \\{{{app.copyright}}}
        \\
    ;

    const data = .{
        .style = in_colour.ansi_codes,
        .app = .{
            .name = self.name,
            .version = self.version,
            .os = self.os,
            .arch = self.arch,
            .copyright = self.copyright,
        },
    };

    _ = self.stdout.mustacheFormat(template, data) catch {};

    self.exit(0);
}

/// Print the default help text
pub fn printHelpAndExit(self: *Self) noreturn {
    @setCold(true);

    const template =
        \\{{{style.reset}}}{{{style.green}}}{{{app.name}}}{{{style.reset}}}, {{{app.version}}} {{{app.os}}}/{{{app.arch}}}
        \\{{{app.description}}}
        \\
        \\{{{style.yellow}}}USAGE:{{{style.reset}}}
        \\   {{{style.green}}}{{{app.name}}}{{{style.reset}}} [COMMAND] [arguments...]
        \\
        \\{{{style.yellow}}}COMMANDS:{{{style.reset}}}
        \\
        \\{{{style.yellow}}}COPYRIGHT:{{{style.reset}}}
        \\   {{{app.copyright}}}
        \\
    ;

    const data = .{
        .style = in_colour.ansi_codes,
        .app = .{
            .name = self.name,
            .version = self.version,
            .os = self.os,
            .arch = self.arch,
            .copyright = self.copyright,
            .description = self.description,
        },
    };

    _ = self.stdout.mustacheFormat(template, data) catch {};

    self.exit(0);
}

//-----------------------------------------------------------------------------
// Terminal Output
//-----------------------------------------------------------------------------

/// Flushes `stdout` and `stderr` before exitting with the given code.
pub fn exit(self: *Self, code: u8) noreturn {
    self.flush();
    std.os.exit(code);
}

/// Flush the `stdout` and `stderr` buffers.
pub fn flush(self: *Self) void {
    std.debug.assert(self.init_done);

    self.stdout.flush();
    self.stderr.flush();
}
