const std = @import("std");

/// Read a whole text file into a fresh gpa-owned buffer.
pub fn readAll(gpa: std.mem.Allocator, io: std.Io, path: []const u8) ![]u8 {
    const file = try std.Io.Dir.openFileAbsolute(io, path, .{ .mode = .read_only });
    defer file.close(io);

    var buffer: [8192]u8 align(@alignOf(usize)) = undefined;
    var reader = file.reader(io, &buffer);
    return reader.interface.allocRemaining(gpa, .unlimited);
}

/// Truncate and overwrite a file with `bytes`.
pub fn writeAll(gpa: std.mem.Allocator, io: std.Io, path: []const u8, bytes: []const u8) !void {
    _ = gpa;

    const file = try std.Io.Dir.createFileAbsolute(io, path, .{ .truncate = true });
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}
