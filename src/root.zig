const std = @import("std");
const utils = @import("zigutils");
const c = @cImport({
    @cInclude("soundio/soundio.h");
    @cInclude("stdlib.h");
    @cInclude("sndfile.h");
});

const allocator = std.heap.smp_allocator;

const PI = std.math.pi;
var seconds_offset: f32 = 0.0;

const Sound = struct {
    const Self = @This();

    sf_info: c.SF_INFO,
    infile: ?*c.SNDFILE,
    volume: f64 = 0.1,
    paused: bool = true,

    pub fn create(sf_info: c.SF_INFO, infile: ?*c.SNDFILE) !*Self {
        const ptr = try allocator.create(Self);
        ptr.* = Self{
            .sf_info = sf_info,
            .infile = infile,
        };

        return ptr;
    }

    pub fn createFromFile(path: [*c]const u8) !*Self {
        var info: c.SF_INFO = undefined;
        const infile: ?*c.SNDFILE = c.sf_open(path, c.SFM_READ, &info);

        return create(info, infile);
    }

    pub fn destroy(self: *Self) void {
        _ = c.sf_close(self.infile);
        allocator.destroy(self);
    }
};

inline fn handleError(err: c_int, comptime meassage: []const u8) void {
    if (err == 0) return;
    std.log.info("error code: {d}", .{err});
    std.log.info(" - soundIO message: {s}", .{c.soundio_strerror(err)});
    std.log.info(" - user message: {s}", .{meassage});
    std.process.exit(1);
}

fn writeCallback(outstream: [*c]c.SoundIoOutStream, frame_count_min: c_int, frame_count_max: c_int) callconv(.c) void {
    _ = frame_count_min;

    const passtrough: *Sound = @ptrCast(@alignCast(outstream.?.*.userdata orelse return));

    _ = c.soundio_outstream_set_volume(outstream, passtrough.volume);
    _ = c.soundio_outstream_pause(outstream, passtrough.paused);
    if (passtrough.paused) return;

    const layout: [*c]c.SoundIoChannelLayout = &(outstream.?.*.layout);
    const float_sample_rate: f32 = @floatFromInt(outstream.?.*.sample_rate);
    const seconds_per_frame: f32 = 1 / float_sample_rate;

    var areas = utils.NULL([*c]c.SoundIoChannelArea);
    var frames_left = frame_count_max;
    const channels = passtrough.sf_info.channels;

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

        const buffer = allocator.alloc(f32, utils.tousize(frame_count * channels)) catch continue;
        defer allocator.free(buffer);

        const frames: c.sf_count_t = @intCast(frame_count);
        const readcount: usize = utils.tousize(c.sf_readf_float(passtrough.infile, buffer.ptr, frames));

        for (0..readcount) |frame| {
            for (0..@intCast(layout.?.*.channel_count)) |channel| {
                const ptr: [*c]f32 =
                    @ptrFromInt(@intFromPtr(areas[channel].ptr) + @as(usize, @intCast(areas[channel].step)) * frame);
                ptr.* = buffer[frame * utils.tousize(channels) + channel];
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
    // const outstream_1 = c.soundio_outstream_create(device);
    // if (utils.isNull(outstream_1)) {
    //     std.log.debug("out of memory", .{});
    //     return;
    // }

    // var mypasstrough = try PassTrough.createFromFile("main_menu.mp3");
    // defer mypasstrough.destroy();

    // outstream_1.?.*.userdata = @as(?*anyopaque, @ptrCast(@alignCast(mypasstrough)));
    // outstream_1.?.*.format = c.SoundIoFormatFloat32NE;
    // outstream_1.?.*.write_callback = writeCallback;

    // handleError(
    //     c.soundio_outstream_open(outstream_1),
    //     "Failed to open outstream",
    // );

    // if (outstream_1.?.*.layout_error != 0)
    //     std.log.err("unable to set channel layout: {s}", .{c.soundio_strerror(outstream_1.?.*.layout_error)});

    // handleError(
    //     c.soundio_outstream_start(outstream_1),
    //     "Failed to start outstream",
    // );

    const outstream_2 = c.soundio_outstream_create(device);
    if (utils.isNull(outstream_2)) {
        std.log.debug("out of memory", .{});
        return;
    }

    var doom = try Sound.createFromFile("music/doom.mp3");
    defer doom.destroy();

    outstream_2.?.*.userdata = @as(?*anyopaque, @ptrCast(@alignCast(doom)));
    outstream_2.?.*.format = c.SoundIoFormatFloat32NE;
    outstream_2.?.*.write_callback = writeCallback;

    handleError(
        c.soundio_outstream_open(outstream_2),
        "Failed to open outstream",
    );

    if (outstream_2.?.*.layout_error != 0)
        std.log.err("unable to set channel layout: {s}", .{c.soundio_strerror(outstream_2.?.*.layout_error)});

    handleError(
        c.soundio_outstream_start(outstream_2),
        "Failed to start outstream",
    );

    // while (true) {
    //     std.log.debug("asd", .{});
    // }
    c.soundio_wait_events(soundIO);

    defer c.soundio_device_unref(device);
}
