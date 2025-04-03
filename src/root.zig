const std = @import("std");
const utils = @import("zigutils");
const zaudio = @import("zaudio");
const uuid = @import("uuid");

/// The handle type returned by the system. This is done, so the package can be
/// used as a dynamic library across languages.
/// **NOTE**: A correct handle won't have `0` value. `0` indicates an invalid handle.
pub const Handle = u64;
pub const ASStatus = u64;

const allocator = std.heap.smp_allocator;
const HandlePointerPair = struct {
    var counter: u64 = 0;

    const Self = @This();

    handle: Handle,
    ptr: ?*zaudio.Sound = null,
    isAlive: bool = true,

    pub fn create(rel_path: [:0]const u8) !Self {
        if (counter == std.math.maxInt(u64))
            counter = 0;

        counter += 1;

        return Self{
            .handle = counter,
            .ptr = if (engine) |e|
                try e.createSoundFromFile(rel_path, .{
                    .flags = .{
                        .stream = true,
                    },
                })
            else
                null,
        };
    }

    pub fn destroy(self: *Self) void {
        if (!self.isAlive) return;
        self.isAlive = false;

        const music = self.ptr orelse return;
        music.destroy();
    }
};

const HANDLE_OK = 0;
const HANDLE_NULLPTR = 1;
const HANDLE_START_FAILED = 2;
const HANDLE_STOP_FAILED = 3;
const HANDLE_SEEK_ERROR = 4;
const HANDLE_NOT_FOUND = 404;
pub export fn strASStatus(status: ASStatus) void {
    std.log.info("{s}", .{switch (status) {
        HANDLE_OK => "OK",
        HANDLE_NULLPTR => "HANDLE POINTS TO NULLPTR",
        HANDLE_START_FAILED => "HANDLE START FAILED",
        HANDLE_STOP_FAILED => "HANDLE STOP FAILED",
        HANDLE_SEEK_ERROR => "HANDLE SEEK ERROR",
        HANDLE_NOT_FOUND => "INCORRECT HANLDE (NOT FOUND)",
        else => "UNKNOWN",
    }});
}

var initalised: bool = false;
var engine: ?*zaudio.Engine = null;
var handle_poiner_pairs: std.ArrayList(HandlePointerPair) = undefined;

fn getHandlePtrPair(handle: Handle) ?HandlePointerPair {
    for (handle_poiner_pairs.items, 0..) |elem, index| {
        if (handle != elem.handle) continue;
        if (!elem.isAlive) {
            _ = handle_poiner_pairs.swapRemove(index);
            return null;
        }

        return elem;
    }
    return null;
}

pub export fn init() void {
    zaudio.init(allocator);
    engine = zaudio.Engine.create(null) catch return;
    handle_poiner_pairs = .init(allocator);

    initalised = true;
}

pub export fn deinit() void {
    if (!initalised)
        return;

    zaudio.deinit();
    if (engine) |e| e.destroy();
    handle_poiner_pairs.deinit();
}

pub export fn create(filepath: [*:0]const u8) Handle {
    if (!initalised)
        return 0;

    const spanned: [:0]u8 = std.mem.span(@constCast(filepath));

    const new_pair = HandlePointerPair.create(spanned) catch return 0;
    handle_poiner_pairs.append(new_pair) catch return 0;

    return new_pair.handle;
}

pub export fn destroy(handle: Handle) ASStatus {
    for (handle_poiner_pairs.items, 0..) |elem, index| {
        if (handle != elem.handle) continue;

        _ = handle_poiner_pairs.swapRemove(index);
        return HANDLE_OK;
    }
    return HANDLE_NOT_FOUND;
}

pub export fn start(handle: Handle) ASStatus {
    const elem = getHandlePtrPair(handle) orelse return HANDLE_NOT_FOUND;
    elem.ptr.?.start() catch return HANDLE_START_FAILED;
    return HANDLE_OK;
}

pub export fn stop(handle: Handle) ASStatus {
    const elem = getHandlePtrPair(handle) orelse return HANDLE_NOT_FOUND;
    elem.ptr.?.stop() catch return HANDLE_STOP_FAILED;
    return HANDLE_OK;
}

pub export fn setVolume(handle: Handle, volume: f32) ASStatus {
    const elem = getHandlePtrPair(handle) orelse return HANDLE_NOT_FOUND;
    elem.ptr.?.setVolume(volume);
    return HANDLE_OK;
}

pub export fn getVolume(handle: Handle) f32 {
    const elem = getHandlePtrPair(handle) orelse return 1;
    return elem.ptr.?.getVolume();
}

pub export fn restart(handle: Handle) ASStatus {
    const elem = getHandlePtrPair(handle) orelse return HANDLE_NOT_FOUND;
    elem.ptr.?.seekToSecond(0) catch return HANDLE_SEEK_ERROR;
    return HANDLE_OK;
}

pub export fn seekToSecond(handle: Handle, second: f32) ASStatus {
    const elem = getHandlePtrPair(handle) orelse return HANDLE_NOT_FOUND;
    elem.ptr.?.seekToSecond(second) catch return HANDLE_SEEK_ERROR;
    return HANDLE_OK;
}

pub export fn isPlaying(handle: Handle) bool {
    const elem = getHandlePtrPair(handle) orelse return false;
    return elem.ptr.?.isPlaying();
}
