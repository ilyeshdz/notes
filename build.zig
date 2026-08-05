const std = @import("std");

const ReleaseTarget = struct {
    os: std.Target.Os.Tag,
    arch: std.Target.Cpu.Arch,
};

/// Every platform `zig build release` produces a binary for.
const release_targets = [_]ReleaseTarget{
    .{ .os = .linux, .arch = .x86_64 },
    .{ .os = .linux, .arch = .aarch64 },
    .{ .os = .linux, .arch = .riscv64 },
    .{ .os = .macos, .arch = .x86_64 },
    .{ .os = .macos, .arch = .aarch64 },
    .{ .os = .windows, .arch = .x86_64 },
    .{ .os = .windows, .arch = .aarch64 },
};

/// Build the `notes` binary. Used by the default `zig build` too.
fn createExe(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Default build: a native binary, installed to zig-out/bin.
    const exe = createExe(b, target, optimize, "notes");
    b.installArtifact(exe);

    // Native `zig build run`.
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    // `zig build test`: currently no tests, but the step exists so CI/act can
    // call it unconditionally.
    const test_step = b.step("test", "Run unit tests");
    const test_run = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    test_step.dependOn(&test_run.step);

    // `zig build release`: build a ReleaseSafe binary for every platform.
    const release_step = b.step("release", "Build a release binary for every supported platform");

    for (release_targets) |rt| {
        const triple = b.fmt("{s}-{s}", .{ @tagName(rt.os), @tagName(rt.arch) });
        const resolved = b.resolveTargetQuery(.{
            .cpu_arch = rt.arch,
            .os_tag = rt.os,
        });
        const filename = if (rt.os == .windows) "notes.exe" else "notes";

        const rel_exe = createExe(b, resolved, .ReleaseSafe, "notes");

        // Install the bare binary to zig-out/release/<triple>/
        const raw = b.addInstallArtifact(rel_exe, .{
            .dest_dir = .{ .override = .{ .custom = b.fmt("release/{s}", .{triple}) } },
            .dest_sub_path = filename,
        });
        raw.step.dependOn(&rel_exe.step);
        release_step.dependOn(&raw.step);

        // Package a tarball for POSIX targets (tar may be absent on Windows).
        if (rt.os != .windows) {
            const install_path = b.getInstallPath(.{ .custom = b.fmt("release/{s}", .{triple}) }, filename);
            const dirname = std.fs.path.dirname(install_path).?;
            const basename = std.fs.path.basename(install_path);

            const tar = b.addSystemCommand(&.{ "tar", "-czf" });
            const tar_out = tar.addOutputFileArg(b.fmt("{s}.tar.gz", .{triple}));
            tar.addArg("-C");
            tar.addArg(dirname);
            tar.addArg(basename);
            tar.step.dependOn(&raw.step);

            const install_tar = b.addInstallFileWithDir(tar_out, .{ .custom = "release" }, b.fmt("{s}.tar.gz", .{triple}));
            release_step.dependOn(&install_tar.step);
        }
    }
}
