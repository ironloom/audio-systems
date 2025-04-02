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

const PassTrough = struct {
    const Self = @This();

    sf_info: c.SF_INFO,
    infile: ?*c.SNDFILE,

    pub fn create(sf_info: c.SF_INFO, infile: ?*c.SNDFILE) !*Self {
        const ptr = try allocator.create(Self);
        ptr.* = Self{
            .sf_info = sf_info,
            .infile = infile,
        };

        return ptr;
    }

    pub fn destroy(self: *Self) void {
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

    const passtrough: *PassTrough = @ptrCast(@alignCast(outstream.?.*.userdata orelse return));

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
    const outstream = c.soundio_outstream_create(device);
    if (utils.isNull(outstream)) {
        std.log.debug("out of memory", .{});
        return;
    }

    var info: c.SF_INFO = undefined;
    const infile: ?*c.SNDFILE = c.sf_open("./main_menu.mp3", c.SFM_READ, &info);

    if (utils.isNull(infile)) {
        std.log.err("Infile was null", .{});
        return;
    }

    var mypasstrough = try PassTrough.create(
        info,
        infile,
    );
    defer mypasstrough.destroy();

    outstream.?.*.userdata = @as(?*anyopaque, @ptrCast(@alignCast(mypasstrough)));
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
