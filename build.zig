const std = @import("std");

const ALLOCATOR = std.heap.smp_allocator;

inline fn fromRoot(comptime str: []const u8) []const u8 {
    return (comptime std.fs.path.dirname(@src().file) orelse ".") ++ str;
}

inline fn path(comptime str: []const u8) std.Build.LazyPath {
    return std.Build.LazyPath{ .cwd_relative = "." ++ str };
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

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

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "audio_systems",
        .root_module = exe_mod,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
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
