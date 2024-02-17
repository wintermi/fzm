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
const cli = @import("cli.zig");

const heap = std.heap;
const io = std.io;
const mem = std.mem;
const process = std.process;
const Allocator = mem.Allocator;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var fzm = cli.init(allocator);
    defer fzm.deinit();

    fzm.name = "fzm";
    fzm.version = mem.trim(u8, @embedFile("./VERSION"), "\n \r\t");
    fzm.description = "A fast and simple Zig version manager, built in Zig";
    fzm.author = "Matthew Winter";
    fzm.copyright = "Copyright © 2023 Matthew Winter";

    try fzm.addCommand(.{ .name = "current", .func = undefined, .description = "Print the current Zig version" });
    try fzm.addCommand(.{ .name = "install", .func = undefined, .description = "Install a new Zig version" });
    try fzm.addCommand(.{ .name = "list", .func = undefined, .description = "List all locally installed Zig versions" });
    try fzm.addCommand(.{ .name = "list-remote", .func = undefined, .description = "List all available remote Zig versions" });
    try fzm.addCommand(.{ .name = "uninstall", .func = undefined, .description = "Uninstall a Zig version" });
    try fzm.addCommand(.{ .name = "use", .func = undefined, .description = "Change Zig version" });

    const got_command = fzm.parseCommand();

    if (got_command) |index| {
        var _command = fzm.getCommand(index);
        _command.func(&fzm) catch |err| switch (err) {
            // BrokenPipe is in most cases expected. It will be triggered just by doing
            // `aniz database | head -n1`. It is not an error for our program so let's
            // ignore it and exit cleanly.
            error.BrokenPipe => {},
            else => return err,
        };

        return;
    }

    fzm.printHelpAndExit();
}
