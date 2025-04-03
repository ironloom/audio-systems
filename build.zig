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

    const libsndfile = b.addStaticLibrary(.{
        .name = "libsndfile",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    libsndfile.addIncludePath(path("/libsndfile/include/"));
    libsndfile.addIncludePath(path("/libsndfile/src/"));
    libsndfile.addCSourceFiles(.{
        .files = &.{
            "./libsndfile/src/sfendian.h",
            "./libsndfile/src/sf_unistd.h",
            "./libsndfile/src/common.h",
            "./libsndfile/src/common.c",
            "./libsndfile/src/file_io.c",
            "./libsndfile/src/command.c",
            "./libsndfile/src/pcm.c",
            "./libsndfile/src/ulaw.c",
            "./libsndfile/src/alaw.c",
            "./libsndfile/src/float32.c",
            "./libsndfile/src/double64.c",
            "./libsndfile/src/ima_adpcm.c",
            "./libsndfile/src/ms_adpcm.c",
            "./libsndfile/src/gsm610.c",
            "./libsndfile/src/dwvw.c",
            "./libsndfile/src/vox_adpcm.c",
            "./libsndfile/src/interleave.c",
            "./libsndfile/src/strings.c",
            "./libsndfile/src/dither.c",
            "./libsndfile/src/cart.c",
            "./libsndfile/src/broadcast.c",
            "./libsndfile/src/audio_detect.c",
            "./libsndfile/src/ima_oki_adpcm.c",
            "./libsndfile/src/ima_oki_adpcm.h",
            "./libsndfile/src/alac.c",
            "./libsndfile/src/chunk.c",
            "./libsndfile/src/ogg.h",
            "./libsndfile/src/ogg.c",
            "./libsndfile/src/chanmap.h",
            "./libsndfile/src/chanmap.c",
            "./libsndfile/src/id3.h",
            "./libsndfile/src/id3.c",
            "./libsndfile/src/sndfile.c",
            "./libsndfile/src/aiff.c",
            "./libsndfile/src/au.c",
            "./libsndfile/src/avr.c",
            "./libsndfile/src/caf.c",
            "./libsndfile/src/dwd.c",
            "./libsndfile/src/flac.c",
            "./libsndfile/src/g72x.c",
            "./libsndfile/src/htk.c",
            "./libsndfile/src/ircam.c",
            "./libsndfile/src/macos.c",
            "./libsndfile/src/mat4.c",
            "./libsndfile/src/mat5.c",
            "./libsndfile/src/nist.c",
            "./libsndfile/src/paf.c",
            "./libsndfile/src/pvf.c",
            "./libsndfile/src/raw.c",
            "./libsndfile/src/rx2.c",
            "./libsndfile/src/sd2.c",
            "./libsndfile/src/sds.c",
            "./libsndfile/src/svx.c",
            "./libsndfile/src/txw.c",
            "./libsndfile/src/voc.c",
            "./libsndfile/src/wve.c",
            "./libsndfile/src/w64.c",
            "./libsndfile/src/wavlike.h",
            "./libsndfile/src/wavlike.c",
            "./libsndfile/src/wav.c",
            "./libsndfile/src/xi.c",
            "./libsndfile/src/mpc2k.c",
            "./libsndfile/src/rf64.c",
            "./libsndfile/src/ogg_vorbis.c",
            "./libsndfile/src/ogg_speex.c",
            "./libsndfile/src/ogg_pcm.c",
            "./libsndfile/src/ogg_opus.c",
            "./libsndfile/src/ogg_vcomment.h",
            "./libsndfile/src/ogg_vcomment.c",
            "./libsndfile/src/nms_adpcm.c",
            "./libsndfile/src/mpeg.c",
            "./libsndfile/src/mpeg_decode.c",
            "./libsndfile/src/mpeg_l3_encode.c",
            "./libsndfile/src/GSM610/config.h",
            "./libsndfile/src/GSM610/gsm.h",
            "./libsndfile/src/GSM610/gsm610_priv.h",
            "./libsndfile/src/GSM610/add.c",
            "./libsndfile/src/GSM610/code.c",
            "./libsndfile/src/GSM610/decode.c",
            "./libsndfile/src/GSM610/gsm_create.c",
            "./libsndfile/src/GSM610/gsm_decode.c",
            "./libsndfile/src/GSM610/gsm_destroy.c",
            "./libsndfile/src/GSM610/gsm_encode.c",
            "./libsndfile/src/GSM610/gsm_option.c",
            "./libsndfile/src/GSM610/long_term.c",
            "./libsndfile/src/GSM610/lpc.c",
            "./libsndfile/src/GSM610/preprocess.c",
            "./libsndfile/src/GSM610/rpe.c",
            "./libsndfile/src/GSM610/short_term.c",
            "./libsndfile/src/GSM610/table.c",
            "./libsndfile/src/G72x/g72x.h",
            "./libsndfile/src/G72x/g72x_priv.h",
            "./libsndfile/src/G72x/g721.c",
            "./libsndfile/src/G72x/g723_16.c",
            "./libsndfile/src/G72x/g723_24.c",
            "./libsndfile/src/G72x/g723_40.c",
            "./libsndfile/src/G72x/g72x.c",
            "./libsndfile/src/ALAC/ALACAudioTypes.h",
            "./libsndfile/src/ALAC/ALACBitUtilities.h",
            "./libsndfile/src/ALAC/EndianPortable.h",
            "./libsndfile/src/ALAC/aglib.h",
            "./libsndfile/src/ALAC/dplib.h",
            "./libsndfile/src/ALAC/matrixlib.h",
            "./libsndfile/src/ALAC/alac_codec.h",
            "./libsndfile/src/ALAC/shift.h",
            "./libsndfile/src/ALAC/ALACBitUtilities.c",
            "./libsndfile/src/ALAC/ag_dec.c",
            "./libsndfile/src/ALAC/ag_enc.c",
            "./libsndfile/src/ALAC/dp_dec.c",
            "./libsndfile/src/ALAC/dp_enc.c",
            "./libsndfile/src/ALAC/matrix_dec.c",
            "./libsndfile/src/ALAC/matrix_enc.c",
            "./libsndfile/src/ALAC/alac_decoder.c",
            "./libsndfile/src/ALAC/alac_encoder.c",
            "./libsndfile/src/common.c",
            "./libsndfile/src/sndfile.c",
        },
        .flags = &.{
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
        },
    });
    libsndfile.addConfigHeader(b.addConfigHeader(
        .{
            .include_path = "config.h",
            .style = .{
                .cmake = path("/libsndfile/src/config.h.cmake"),
            },
        },
        .{
            .PACKAGE_NAME = "sndfile",
            .CPACK_PACKAGE_VERSION_MAJOR = "1",
            .CPACK_PACKAGE_VERSION_MINOR = "2",
            .CPACK_PACKAGE_VERSION_PATCH = "2",
            .CPACK_PACKAGE_VERSION_STAGE = "",
            .CPACK_PACKAGE_VERSION_FULL = "1.2.2",
            .HAVE_EXTERNAL_XIPH_LIBS = "OFF",
            .PACKAGE_BUGREPORT = "",
            .PACKAGE_URL = "https://libsndfile.github.io/libsndfile/",
            .SIZEOF_DOUBLE_CODE = "#define SIZEOF_DOUBLE 64",
            .SIZEOF_FLOAT_CODE = "#define SIZEOF_FLOAT 32",
            .SIZEOF_INT_CODE = "#define SIZEOF_INT 32",
            .SIZEOF_INT64_T_CODE = "#define SIZEOF_INT64_T 64",
            .SIZEOF_LOFF_T_CODE = "#define SIZEOF_LOFF_T 64",
            .SIZEOF_LONG_CODE = "#define SIZEOF_LONG 32",
            .SIZEOF_LONG_LONG_CODE = "#define SIZEOF_LONG_LONG 64",
            .SIZEOF_OFF64_T_CODE = "#define SIZEOF_OFF64_T 64",
            .SIZEOF_OFF_T_CODE = "#define SIZEOF_OFF_T 32",
            .SIZEOF_SHORT_CODE = "#define SIZEOF_SHORT 16",
            .SIZEOF_SIZE_T_CODE = "#define SIZEOF_SIZE_T 64",
            .SIZEOF_SSIZE_T_CODE = "#define SIZEOF_SSIZE_T 32",
            .SIZEOF_VOIDP_CODE = "#define SIZEOF_VOIDP 64",
            .SIZEOF_WCHAR_T_CODE = "#define SIZEOF_WCHAR_T 16",
            .PROJECT_VERSION = "1.2.2",
            .INLINE_CODE = "#define INLINE_KEYWORD __inline",
        },
    ));

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    lib_mod.linkLibrary(libsndfile);
    lib_mod.addIncludePath(path("/libsndfile/include/"));

    // lib_mod.linkSystemLibrary("sndfile", .{
    //     .needed = true,
    //     .use_pkg_config = .yes,
    // });

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

    try b.modules.put(b.dupe("audio_systems"), lib_mod);

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
