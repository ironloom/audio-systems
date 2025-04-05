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
        if (!self.isAlive and self.ptr == null) return;
        self.isAlive = false;

        const music = self.ptr orelse return;
        music.destroy();
    }
};

pub export const ASSTATUS_OK: u64 = 0;
pub export const ASSTATUS_NULLPTR: u64 = 1;
pub export const ASSTATUS_START_FAILED: u64 = 2;
pub export const ASSTATUS_STOP_FAILED: u64 = 3;
pub export const ASSTATUS_SEEK_ERROR: u64 = 4;
pub export const ASSTATUS_ENGINE_NOT_INITALISED: u64 = 5;
pub export const ASSTATUS_NOT_FOUND: u64 = 404;

pub export fn strASStatus(status: ASStatus) void {
    std.log.info("{s}", .{switch (status) {
        ASSTATUS_OK => "OK",
        ASSTATUS_NULLPTR => "POINTS TO NULLPTR",
        ASSTATUS_START_FAILED => "START FAILED",
        ASSTATUS_STOP_FAILED => "STOP FAILED",
        ASSTATUS_SEEK_ERROR => "SEEK ERROR",
        ASSTATUS_ENGINE_NOT_INITALISED => "ENGINE WASN'T INITALISED",
        ASSTATUS_NOT_FOUND => "INCORRECT HANDLE NOT FOUND",
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

pub export fn deinit() ASStatus {
    if (!initalised)
        return ASSTATUS_ENGINE_NOT_INITALISED;

    for (handle_poiner_pairs.items) |*item| {
        item.destroy();
    }

    handle_poiner_pairs.deinit();
    if (engine) |e| e.destroy();
    zaudio.deinit();

    return ASSTATUS_OK;
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

        elem.destroy();
        _ = handle_poiner_pairs.swapRemove(index);
        return ASSTATUS_OK;
    }
    return ASSTATUS_NOT_FOUND;
}

pub export fn start(handle: Handle) ASStatus {
    if (!initalised)
        return ASSTATUS_ENGINE_NOT_INITALISED;

    const elem = getHandlePtrPair(handle) orelse return ASSTATUS_NOT_FOUND;
    elem.ptr.?.start() catch return ASSTATUS_START_FAILED;
    return ASSTATUS_OK;
}

pub export fn stop(handle: Handle) ASStatus {
    if (!initalised)
        return ASSTATUS_ENGINE_NOT_INITALISED;

    const elem = getHandlePtrPair(handle) orelse return ASSTATUS_NOT_FOUND;
    elem.ptr.?.stop() catch return ASSTATUS_STOP_FAILED;
    return ASSTATUS_OK;
}

pub export fn setVolume(handle: Handle, volume: f32) ASStatus {
    if (!initalised)
        return ASSTATUS_ENGINE_NOT_INITALISED;

    const elem = getHandlePtrPair(handle) orelse return ASSTATUS_NOT_FOUND;
    elem.ptr.?.setVolume(volume);
    return ASSTATUS_OK;
}

pub export fn getVolume(handle: Handle) f32 {
    if (!initalised)
        return 1;

    const elem = getHandlePtrPair(handle) orelse return 1;
    return elem.ptr.?.getVolume();
}

pub export fn restart(handle: Handle) ASStatus {
    if (!initalised)
        return ASSTATUS_ENGINE_NOT_INITALISED;

    const elem = getHandlePtrPair(handle) orelse return ASSTATUS_NOT_FOUND;
    elem.ptr.?.seekToSecond(0) catch return ASSTATUS_SEEK_ERROR;
    return ASSTATUS_OK;
}

pub export fn seekToSecond(handle: Handle, second: f32) ASStatus {
    if (!initalised)
        return ASSTATUS_ENGINE_NOT_INITALISED;

    const elem = getHandlePtrPair(handle) orelse return ASSTATUS_NOT_FOUND;
    elem.ptr.?.seekToSecond(second) catch return ASSTATUS_SEEK_ERROR;
    return ASSTATUS_OK;
}

pub export fn isPlaying(handle: Handle) bool {
    if (!initalised)
        return false;

    const elem = getHandlePtrPair(handle) orelse return false;
    return elem.ptr.?.isPlaying();
}
