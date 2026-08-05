const std = @import("std");

/// Spawns `$EDITOR` on `file_path` and blocks until the editor exits, so that
/// any edits are written back to disk before we return.
pub const default_editor = "vim";

pub fn open(io: std.Io, gpa: std.mem.Allocator, editor: []const u8, file_path: []const u8) !void {
    var args: std.ArrayList([]const u8) = .empty;
    defer args.deinit(gpa);

    // EDITOR may carry flags, e.g. "code --wait" or "nvim -f".
    var toks = std.mem.tokenizeScalar(u8, editor, ' ');
    while (toks.next()) |tok| try args.append(gpa, tok);
    try args.append(gpa, file_path);

    var child = try std.process.spawn(io, .{ .argv = args.items });
    _ = try child.wait(io);
}
