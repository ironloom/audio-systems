const std = @import("std");

inline fn fromRoot(comptime str: []const u8) []const u8 {
    return (comptime std.fs.path.dirname(@src().file) orelse ".") ++ str;
}

inline fn path(comptime str: []const u8) std.Build.LazyPath {
    return std.Build.LazyPath{ .cwd_relative = "." ++ str };
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zutils_dep = b.dependency("zigutils", .{ .target = target, .optimize = optimize });
    const zutils_mod = zutils_dep.module("zigutils");

    const zaudio_dep = b.dependency("zaudio", .{ .target = target, .optimize = optimize });
    const zaudio_mod = zaudio_dep.module("root");

    const uuid_dep = b.dependency("uuid", .{ .target = target, .optimize = optimize });
    const uuid_mod = uuid_dep.module("uuid");

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    lib_mod.addImport("zigutils", zutils_mod);
    lib_mod.addImport("zaudio", zaudio_mod);
    lib_mod.addImport("uuid", uuid_mod);

    lib_mod.linkLibrary(zaudio_dep.artifact("miniaudio"));
    lib_mod.linkLibrary(uuid_dep.artifact("uuid"));

    if (b.lazyDependency("system_sdk", .{})) |system_sdk| switch (target.result.os.tag) {
        .windows => if (target.result.cpu.arch.isX86() and (target.result.abi.isGnu() or target.result.abi.isMusl())) {
            lib_mod.addLibraryPath(system_sdk.path("windows/lib/x86_64-windows-gnu"));
            lib_mod.linkSystemLibrary("ole32", .{ .needed = true });
        },
        .macos => {
            lib_mod.addLibraryPath(system_sdk.path("macos12/usr/lib"));
            lib_mod.addFrameworkPath(system_sdk.path("macos12/System/Library/Frameworks"));
        },
        .linux => {
            if (target.result.cpu.arch.isX86()) {
                lib_mod.addLibraryPath(system_sdk.path("linux/lib/x86_64-linux-gnu"));
            } else if (target.result.cpu.arch == .aarch64) {
                lib_mod.addLibraryPath(system_sdk.path("linux/lib/aarch64-linux-gnu"));
            }
        },
        else => {},
    };

    try b.modules.put(b.dupe("audio_systems"), lib_mod);

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "audio_systems",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const demo_exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    demo_exe_module.addImport("audio_systems", lib_mod);

    const demo_exe = b.addExecutable(.{
        .name = "audio_systems",
        .root_module = demo_exe_module,
    });
    b.installArtifact(demo_exe);

    const run_cmd = b.addRunArtifact(demo_exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = demo_exe_module,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
