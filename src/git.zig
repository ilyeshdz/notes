const std = @import("std");

/// Thin wrapper around git, scoped to the notes store directory.
///
/// If the store is not a git repository, every operation is a no-op, so the
/// notes tool works just as well for people who never want git.
pub const Git = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    /// Absolute path to the notes store (~/.notes)
    root: []const u8,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, root: []const u8) Git {
        return .{ .gpa = gpa, .io = io, .root = root };
    }

    /// True when ~/.notes is a git repository (has a .git directory).
    pub fn isRepo(self: *const Git) bool {
        var arena = std.heap.ArenaAllocator.init(self.gpa);
        defer arena.deinit();
        const git_dir = std.fs.path.join(arena.allocator(), &.{ self.root, ".git" }) catch return false;

        const dir = std.Io.Dir.openDirAbsolute(self.io, git_dir, .{}) catch return false;
        dir.close(self.io);
        return true;
    }

    fn runGit(self: *Git, argv: []const []const u8) !std.process.RunResult {
        return std.process.run(self.gpa, self.io, .{
            .argv = argv,
            .cwd = .{ .path = self.root },
        });
    }

    fn exitedOk(res: *const std.process.RunResult) bool {
        return switch (res.term) {
            .exited => |code| code == 0,
            else => false,
        };
    }

    fn freeResult(self: *Git, res: *const std.process.RunResult) void {
        self.gpa.free(res.stdout);
        self.gpa.free(res.stderr);
    }

    /// Runs `git init` on the store and configures a local identity so that
    /// automatic commits work out of the box.
    pub fn initRepo(self: *Git) !void {
        if (self.isRepo()) {
            std.log.info("git repository already initialized in {s}", .{self.root});
            return;
        }

        var res = try self.runGit(&.{ "git", "init" });
        defer self.freeResult(&res);
        if (!exitedOk(&res)) return error.GitInitFailed;

        std.log.info("initialized git repository in {s}", .{self.root});
        try self.ensureIdentity();
    }

    /// Sets a local user.name/user.email if none is configured, so `git commit`
    /// never prompts interactively.
    fn ensureIdentity(self: *Git) !void {
        if (try self.configGet("user.name")) |name| {
            self.gpa.free(name);
        } else {
            try self.configSet("user.name", "notes");
        }
        if (try self.configGet("user.email")) |email| {
            self.gpa.free(email);
        } else {
            try self.configSet("user.email", "notes@localhost");
        }
    }

    fn configGet(self: *Git, key: []const u8) !?[]u8 {
        var res = try self.runGit(&.{ "git", "config", key });
        defer self.freeResult(&res);

        if (!exitedOk(&res)) return null;
        const value = std.mem.trim(u8, res.stdout, " \t\r\n");
        if (value.len == 0) return null;
        const copy = try self.gpa.dupe(u8, value);
        return copy;
    }

    fn configSet(self: *Git, key: []const u8, value: []const u8) !void {
        var res = try self.runGit(&.{ "git", "config", key, value });
        defer self.freeResult(&res);
    }

    /// Stages and commits everything in the store. No-op when the store is not
    /// a repository; failures (nothing to commit, missing identity, ...) are
    /// logged rather than raised, so note-taking is never interrupted.
    pub fn commit(self: *Git, message: []const u8) !void {
        if (!self.isRepo()) return;

        var add_res = try self.runGit(&.{ "git", "add", "-A" });
        defer self.freeResult(&add_res);
        if (!exitedOk(&add_res)) {
            std.log.warn("git add failed; skipping commit", .{});
            return;
        }

        var commit_res = try self.runGit(&.{ "git", "commit", "-m", message });
        defer self.freeResult(&commit_res);
        switch (commit_res.term) {
            .exited => |code| {
                if (code == 0) {
                    std.log.info("committed: {s}", .{message});
                } else {
                    std.log.warn("git commit exited with {d}: {s}", .{ code, std.mem.trim(u8, commit_res.stderr, " \t\r\n") });
                }
            },
            else => std.log.warn("git commit did not exit cleanly", .{}),
        }
    }
};
