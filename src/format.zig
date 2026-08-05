const std = @import("std");

/// The note content format is intentionally small and strict:
///
///     # 2026-09-05          <- title line (the note's date)
///
///     ## inbox             <- required section, a list of checkboxes
///     - [ ] buy milk
///
/// Any additional `## <name>` sections are user-defined ("customizable
/// nodes") and are preserved as-is.
pub const inbox_heading = "## inbox";

pub const ValidateError = error{
    /// No leading `# ` title heading was found.
    MissingTitle,
    /// No `## inbox` list section was found.
    MissingInbox,
};

/// Builds the initial content for a brand new note file.
pub fn template(arena: std.mem.Allocator, date_str: []const u8) ![]u8 {
    return std.fmt.allocPrint(arena, "# {s}\n\n{s}\n", .{ date_str, inbox_heading });
}

/// Returns `content` with `item` appended as a checkbox to the inbox section,
/// creating the section at the end of the file if it does not exist. Items are
/// appended tightly so the list stays a single CommonMark list.
pub fn addInboxItem(
    arena: std.mem.Allocator,
    content: []const u8,
    item: []const u8,
) ![]u8 {
    const bullet = try std.fmt.allocPrint(arena, "- [ ] {s}", .{item});

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(arena);

    var saw_inbox = false;
    var in_inbox = false;
    var inserted = false;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        if (std.mem.eql(u8, trimmed, inbox_heading)) {
            saw_inbox = true;
            in_inbox = true;
        } else if (in_inbox and std.mem.startsWith(u8, trimmed, "## ")) {
            in_inbox = false;
            if (!inserted) {
                try ensureOneTrailingNewline(arena, &out);
                try out.appendSlice(arena, bullet);
                try out.append(arena, '\n');
                inserted = true;
            }
        }

        try out.appendSlice(arena, line);
        try out.append(arena, '\n');
    }

    if (!inserted) {
        try ensureOneTrailingNewline(arena, &out);
        if (!saw_inbox) {
            // Add a blank line, then a brand new inbox section for the item.
            try out.append(arena, '\n');
            try out.appendSlice(arena, inbox_heading);
            try out.append(arena, '\n');
        }
        try out.appendSlice(arena, bullet);
        try out.append(arena, '\n');
    }

    return out.toOwnedSlice(arena);
}

/// Rewrites the tail of `list` so it ends with exactly one newline and no
/// stray spaces, ready for the next line to be appended on its own line.
fn ensureOneTrailingNewline(
    arena: std.mem.Allocator,
    list: *std.ArrayList(u8),
) !void {
    while (list.items.len != 0) {
        const last = list.items[list.items.len - 1];
        if (last == ' ' or last == '\t' or last == '\r') {
            list.items.len -= 1;
        } else {
            break;
        }
    }
    while (list.items.len != 0 and list.items[list.items.len - 1] == '\n') {
        list.items.len -= 1;
    }
    try list.append(arena, '\n');
}

/// Verifies that `content` matches the supported note format.
pub fn validate(content: []const u8) ValidateError!void {
    var saw_title = false;
    var saw_inbox = false;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        if (!saw_title) {
            if (!std.mem.startsWith(u8, trimmed, "# ")) return error.MissingTitle;
            saw_title = true;
        }

        if (std.mem.eql(u8, trimmed, inbox_heading)) saw_inbox = true;
    }

    if (!saw_title) return error.MissingTitle;
    if (!saw_inbox) return error.MissingInbox;
}
