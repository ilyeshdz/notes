const std = @import("std");

pub const usage =
    \\Usage: notes [command] [arguments]
    \\
    \\A zero-setup daily note tool. Notes live directly in ~/.notes as
    \\YYYY-MM-DD.md files, one per day. If ~/.notes is a git repository, edits
    \\are committed automatically.
    \\
    \\Commands:
    \\  (none)       Open today's note in $EDITOR and auto-commit (if git)
    \\  add <text>   Append "<text>" as an inbox item to today's note
    \\  init         Initialize a git repository in ~/.notes
    \\  check        Verify that every note matches the supported format
    \\  help         Show this help
    \\
;

pub const ParseError = error{
    UnknownCommand,
    MissingArgument,
};

pub const Command = union(enum) {
    open,
    add: []const u8,
    init,
    check,
    help,
};

/// Parses argv[1..] into a command. `args` includes the program name as argv[0].
pub fn parse(args: []const []const u8) ParseError!Command {
    if (args.len < 2) return .open;

    const cmd = std.mem.trim(u8, args[1], " \t");
    if (std.mem.eql(u8, cmd, "add")) {
        if (args.len < 3) return error.MissingArgument;
        return .{ .add = args[2] };
    }
    if (std.mem.eql(u8, cmd, "init")) return .init;
    if (std.mem.eql(u8, cmd, "check") or std.mem.eql(u8, cmd, "verify")) return .check;
    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
        return .help;
    }

    return error.UnknownCommand;
}
