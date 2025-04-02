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

    const zutils_dep = b.dependency("zigutils", .{});
    const zutils_mod = zutils_dep.module("zigutils");

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    lib_mod.linkSystemLibrary("sndfile", .{ .needed = true });

    lib_mod.addImport("zigutils", zutils_mod);

    const cflags = [_][]const u8{
        "-std=c11",
        "-fvisibility=hidden",
        "-Werror=strict-prototypes",
        "-Werror=old-style-definition",
        "-Werror=missing-prototypes",
        "-Wno-nullability-extension",
        "-D_REENTRANT",
        "-D_POSIX_C_SOURCE=200809L",
        "-Wno-missing-braces",
        "-Wno-deprecated-declarations",
        "-Wno-unused-variable",
        "-Wno-unused-but-set-variable",
    };
    const csources = [_][]const u8{
        fromRoot("/libsoundio/src/soundio.c"),
        fromRoot("/libsoundio/src/util.c"),
        fromRoot("/libsoundio/src/os.c"),
        fromRoot("/libsoundio/src/dummy.c"),
        fromRoot("/libsoundio/src/channel_layout.c"),
        fromRoot("/libsoundio/src/ring_buffer.c"),
    };

    lib_mod.addConfigHeader(b.addConfigHeader(
        .{
            .include_path = "config.h",
            .style = .{
                .cmake = path("/libsoundio/src/config.h.in"),
            },
        },
        .{
            .LIBSOUNDIO_VERSION_MAJOR = "2",
            .LIBSOUNDIO_VERSION_MINOR = "0",
            .LIBSOUNDIO_VERSION_PATCH = "0",
            .LIBSOUNDIO_VERSION = "2.0.0",
        },
    ));

    lib_mod.addIncludePath(path("/libsoundio"));
    lib_mod.addIncludePath(path("/libsoundio/src"));
    lib_mod.addCSourceFiles(.{
        .flags = &cflags,
        .files = &csources,
    });

    lib_mod.addCMacro("ZIG_BUILD", "NULL");

    if (b.lazyDependency("system_sdk", .{})) |system_sdk| switch (target.result.os.tag) {
        .windows => if (target.result.cpu.arch.isX86() and (target.result.abi.isGnu() or target.result.abi.isMusl())) {
            lib_mod.addLibraryPath(system_sdk.path("windows/lib/x86_64-windows-gnu"));
            lib_mod.linkSystemLibrary("ole32", .{ .needed = true });

            lib_mod.addCMacro("SOUNDIO_HAVE_WASAPI", "NULL");
            lib_mod.addCSourceFile(.{ .file = path("/libsoundio/src/wasapi.c") });
        },
        .macos => {
            lib_mod.addLibraryPath(system_sdk.path("macos12/usr/lib"));
            lib_mod.addFrameworkPath(system_sdk.path("macos12/System/Library/Frameworks"));

            lib_mod.linkFramework("CoreFoundation", .{ .needed = true });
            lib_mod.linkFramework("CoreAudio", .{ .needed = true });
            lib_mod.linkFramework("AudioUnit", .{ .needed = true });
            lib_mod.linkFramework("AudioToolbox", .{ .needed = true });

            lib_mod.addCMacro("SOUNDIO_HAVE_COREAUDIO", "NULL");
            lib_mod.addCSourceFile(.{
                .file = path("/libsoundio/src/coreaudio.c"),
            });
        },
        .linux => {
            if (target.result.cpu.arch.isX86()) {
                lib_mod.addLibraryPath(system_sdk.path("linux/lib/x86_64-linux-gnu"));
            } else if (target.result.cpu.arch == .aarch64) {
                lib_mod.addLibraryPath(system_sdk.path("linux/lib/aarch64-linux-gnu"));
            }

            lib_mod.addCMacro("SOUNDIO_HAVE_ALSA", "NULL");
            lib_mod.addCSourceFile(.{ .file = path("/libsoundio/src/alsa.c") });
        },
        else => {},
    };

    try b.modules.put(b.dupe("keyboard_input"), lib_mod);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("audio_systems", lib_mod);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "audio_systems",
        .root_module = lib_mod,
    });
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "audio_systems",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
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
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
fn buildSNDFile(b: *std.Build, args: struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    dep_path: std.Build.LazyPath,
}) *std.Build.Step.Run {
    const sndfile_path = args.dep_path.getPath(b); // LazyPath to string

    const libsnd_configure = b.addSystemCommand(&.{
        "cmake",
        "-G",
        "Ninja",
        "-B",
        ".zig-cache/libsndfile",
        "-S",
        sndfile_path,
        b.fmt("-DCMAKE_BUILD_TYPE={s}", .{switch (args.optimize) {
            .Debug => "Debug",
            .ReleaseFast => "Release",
            .ReleaseSafe => "RelWithDebInfo",
            .ReleaseSmall => "MinSizeRel",
        }}),
        "-DENABLE_EXTERNAL_LIBS=OFF",
        "-DENABLE_MPEG=OFF",
    });
    // static link in Windows
    if (args.target.result.os.tag == .windows)
        libsnd_configure.addArgs(&.{
            "-DBUILD_SHARED_LIBS=OFF",
        });

    const libsnd_build = b.addSystemCommand(&.{
        "cmake",
        "--build",
        ".zig-cache/libsndfile",
    });
    if (args.target.result.abi == .msvc) {
        libsnd_build.addArgs(&.{
            "--config",
            b.fmt("{s}", .{switch (args.optimize) {
                .Debug => "Debug",
                else => "Release",
            }}),
        });
    }
    libsnd_build.step.dependOn(&libsnd_configure.step);
    return libsnd_build;
}
