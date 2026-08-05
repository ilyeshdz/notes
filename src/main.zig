const std = @import("std");

const cli = @import("cli.zig");
const date_mod = @import("date.zig");
const editor_mod = @import("editor.zig");
const format = @import("format.zig");
const git_mod = @import("git.zig");
const store_mod = @import("store.zig");
const text = @import("text.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const arena = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);
    const command = cli.parse(args) catch |err| switch (err) {
        error.UnknownCommand, error.MissingArgument => {
            try std.Io.File.stderr().writeStreamingAll(io, cli.usage);
            std.process.exit(2);
        },
    };

    const home = init.environ_map.get("HOME") orelse {
        std.log.err("HOME is not set, cannot locate the notes directory.", .{});
        std.process.exit(1);
    };

    var editor: []const u8 = editor_mod.default_editor;
    if (init.environ_map.get("EDITOR")) |e| {
        if (std.mem.trim(u8, e, " \t").len != 0) editor = e;
    }

    var store = try store_mod.Store.init(gpa, home);
    defer store.deinit();
    var repo = git_mod.Git.init(gpa, io, store.root);

    switch (command) {
        .help => try std.Io.File.stdout().writeStreamingAll(io, cli.usage),

        .init => try repo.initRepo(),

        .open => {
            const today = date_mod.Date.today(io);
            const file_path = try store.ensureDayFile(io, arena, today);

            try editor_mod.open(io, gpa, editor, file_path);

            const date_str = try today.str(arena);
            const msg = try std.fmt.allocPrint(arena, "notes: update {s}", .{date_str});
            try repo.commit(msg);
        },

        .add => |item| {
            const today = date_mod.Date.today(io);
            const file_path = try store.ensureDayFile(io, arena, today);

            const content = try text.readAll(gpa, io, file_path);
            defer gpa.free(content);

            const updated = try format.addInboxItem(arena, content, item);
            try text.writeAll(gpa, io, file_path, updated);

            const msg = try std.fmt.allocPrint(arena, "notes: add {s}", .{item});
            try repo.commit(msg);
        },

        .check => {
            var files: std.ArrayList([]u8) = .empty;
            defer {
                for (files.items) |p| gpa.free(p);
                files.deinit(gpa);
            }
            try store.collectMarkdown(io, gpa, &files);

            var bad: usize = 0;
            for (files.items) |path| {
                const content = text.readAll(gpa, io, path) catch |err| {
                    std.log.err("cannot read {s}: {s}", .{ path, @errorName(err) });
                    bad += 1;
                    continue;
                };
                defer gpa.free(content);

                format.validate(content) catch {
                    std.log.warn("unsupported format: {s}", .{path});
                    bad += 1;
                };
            }

            if (bad == 0) {
                std.log.info("{d} note(s) match the supported format", .{files.items.len});
            } else {
                std.log.err("{d} note(s) do not match the supported format", .{bad});
            }
        },
    }
}
