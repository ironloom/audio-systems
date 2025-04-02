const std = @import("std");
const utils = @import("zigutils");
const c = @cImport({
    @cInclude("soundio/soundio.h");
    @cInclude("stdlib.h");
});

const PI = std.math.pi;
var seconds_offset: f32 = 0.0;

inline fn handleError(err: c_int, comptime meassage: []const u8) void {
    if (err == 0) return;
    std.log.info("error code: {d}", .{err});
    std.log.info(" - soundIO message: {s}", .{c.soundio_strerror(err)});
    std.log.info(" - user message: {s}", .{meassage});
    std.process.exit(1);
}

fn writeCallback(outstream: [*c]c.SoundIoOutStream, frame_count_min: c_int, frame_count_max: c_int) callconv(.c) void {
    _ = frame_count_min;

    const layout: [*c]c.SoundIoChannelLayout = &(outstream.?.*.layout);
    const float_sample_rate: f32 = @floatFromInt(outstream.?.*.sample_rate);
    const seconds_per_frame: f32 = 1 / float_sample_rate;

    var areas = utils.NULL([*c]c.SoundIoChannelArea);
    var frames_left = frame_count_max;

    while (frames_left > 0) {
        var frame_count = frames_left;

        handleError(
            c.soundio_outstream_begin_write(
                outstream,
                &areas,
                &frame_count,
            ),
            "Outstream begin write failed",
        );

        if (frame_count == 0) break;

        const pitch: comptime_float = 440.0;
        const radians_per_second: comptime_float = pitch * 2.0 * PI;

        for (0..@intCast(frame_count)) |frame| {
            const sample: f32 = std.math.sin((seconds_offset + @as(f32, @floatFromInt(frame)) * seconds_per_frame) * radians_per_second);
            for (0..@intCast(layout.?.*.channel_count)) |channel| {
                const ptr: [*c]f32 =
                    @ptrFromInt(@intFromPtr(areas[channel].ptr) + @as(usize, @intCast(areas[channel].step)) * frame);
                ptr.* = sample;
            }
        }

        seconds_offset = @rem(seconds_offset + seconds_per_frame * @as(f32, @floatFromInt(frame_count)), @as(comptime_float, 1.0));

        handleError(
            c.soundio_outstream_end_write(outstream),
            "Outstream write end failed!",
        );

        frames_left -= frame_count;
    }
}

pub fn main() !void {
    const soundIO = c.soundio_create();
    defer c.soundio_destroy(soundIO);

    handleError(
        c.soundio_connect(soundIO),
        "Failed to connect soundIO",
    );

    c.soundio_flush_events(soundIO);

    const default_device_index = c.soundio_default_output_device_index(soundIO);
    if (default_device_index < 0) {
        std.log.err("No device found", .{});
        return;
    }

    const device = c.soundio_get_output_device(soundIO, default_device_index);
    if (utils.isNull(device)) {
        std.log.err("Out of memory", .{});
        return;
    }

    std.log.debug("Output device: {s}", .{device.?.*.name});
    const outstream = c.soundio_outstream_create(device);
    outstream.?.*.format = c.SoundIoFormatFloat32NE;
    outstream.?.*.write_callback = writeCallback;

    handleError(
        c.soundio_outstream_open(outstream),
        "Failed to open outstream",
    );

    if (outstream.?.*.layout_error != 0)
        std.log.err("unable to set channel layout: {s}", .{c.soundio_strerror(outstream.?.*.layout_error)});

    handleError(
        c.soundio_outstream_start(outstream),
        "Failed to start outstream",
    );

    while (true) {
        c.soundio_wait_events(soundIO);
    }

    defer c.soundio_device_unref(device);
}
