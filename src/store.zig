const std = @import("std");
const date_mod = @import("date.zig");
const format = @import("format.zig");

/// Name of the store directory inside the user's home directory.
pub const dir_name = ".notes";

/// The notes store: a flat directory where every note is a single file.
pub const Store = struct {
    gpa: std.mem.Allocator,
    /// Absolute path to ~/.notes
    root: []u8,

    pub fn init(gpa: std.mem.Allocator, home: []const u8) !Store {
        return .{
            .gpa = gpa,
            .root = try std.fs.path.join(gpa, &.{ home, dir_name }),
        };
    }

    pub fn deinit(self: *Store) void {
        self.gpa.free(self.root);
    }

    /// Absolute path to the note file: ~/.notes/YYYY-MM-DD.md
    pub fn dayFile(self: *const Store, arena: std.mem.Allocator, date: date_mod.Date) ![]u8 {
        return std.fs.path.join(arena, &.{
            self.root,
            try std.fmt.allocPrint(arena, "{s}.md", .{try date.str(arena)}),
        });
    }

    /// Creates ~/.notes (if missing) and opens today's file, seeding it with the
    /// format template the first time. Returns the file's absolute path.
    pub fn ensureDayFile(
        self: *const Store,
        io: std.Io,
        arena: std.mem.Allocator,
        date: date_mod.Date,
    ) ![]u8 {
        try std.Io.Dir.createDirPath(.cwd(), io, self.root);

        const file_path = try self.dayFile(arena, date);
        const file = try std.Io.Dir.createFileAbsolute(io, file_path, .{
            .read = true,
            .truncate = false,
        });
        defer file.close(io);

        if (try file.length(io) == 0) {
            const date_str = try date.str(arena);
            try file.writeStreamingAll(io, try format.template(arena, date_str));
        }

        return file_path;
    }

    /// Appends the absolute path of every `*.md` file in the store root to `list`.
    pub fn collectMarkdown(
        self: *const Store,
        io: std.Io,
        gpa: std.mem.Allocator,
        list: *std.ArrayList([]u8),
    ) !void {
        const dir = std.Io.Dir.openDirAbsolute(io, self.root, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => return, // no notes yet
            else => return err,
        };
        defer dir.close(io);

        var it = dir.iterate();
        while (try it.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".md")) continue;

            const full = try std.fs.path.join(gpa, &.{ self.root, entry.name });
            try list.append(gpa, full);
        }
    }
};
