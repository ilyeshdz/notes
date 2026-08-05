const std = @import("std");

/// A calendar date broken into its components.
pub const Date = struct {
    year: u16,
    month: u8, // 1-12
    day: u8, // 1-31

    /// Today's date, computed from the real-time clock.
    pub fn today(io: std.Io) Date {
        const now = std.Io.Timestamp.now(io, .real);
        const seconds: u64 = @intCast(@divTrunc(now.nanoseconds, std.time.ns_per_s));
        const epoch = std.time.epoch.EpochSeconds{ .secs = seconds };
        const year_day = epoch.getEpochDay().calculateYearDay();
        const month_day = year_day.calculateMonthDay();

        return .{
            .year = year_day.year,
            .month = @as(u8, @intFromEnum(month_day.month)) + 1,
            .day = @as(u8, month_day.day_index) + 1,
        };
    }

    /// The zero-padded ISO date, e.g. "2026-09-05".
    pub fn str(self: Date, arena: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            arena,
            "{d:0>4}-{d:0>2}-{d:0>2}",
            .{ self.year, self.month, self.day },
        );
    }
};
