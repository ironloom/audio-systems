const std = @import("std");
const c = @cImport({
    @cInclude("AudioToolbox/AudioToolbox.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
});

const NUMBER_OF_BUFFERS = 3;
const BUFFER_DURATION = 0.5; // Seconds

const Player = struct {
    file: c.AudioFileID = undefined,
    packet_pos: i64 = 0,
    packets_to_read: u32 = 0,
    packet_descs: ?[*]c.AudioStreamPacketDescription = null,
    done: bool = false,
};

fn HandleError(code: c.OSStatus, comptime msg: []const u8) void {
    if (code == c.noErr) return;
    std.log.err("{s}: OSStatus {x}", .{ msg, code });
    std.posix.exit(@intCast(code));
}

fn createCFString(comptime str: []const u8) c.CFStringRef {
    const utf16 = std.unicode.utf8ToUtf16LeStringLiteral(str);
    return c.CFStringCreateWithCharacters(c.kCFAllocatorDefault, utf16.ptr, @intCast(utf16.len));
}

fn cfSafeRelease(obj: anytype) void {
    if (@intFromPtr(obj) != 0) c.CFRelease(obj);
}

fn calculateBufferSize(
    file: c.AudioFileID,
    format: c.AudioStreamBasicDescription,
    seconds: f64,
    out_size: *u32,
    out_packets: *u32,
) void {
    var max_packet: u32 = 0;
    var prop_size: u32 = @sizeOf(u32);

    HandleError(c.AudioFileGetProperty(file, c.kAudioFilePropertyPacketSizeUpperBound, &prop_size, &max_packet), "Get max packet size");

    const max_buffer: u32 = 0x10000;
    const min_buffer: u32 = 0x4000;

    out_size.* = if (format.mFramesPerPacket > 0)
        @intFromFloat(format.mSampleRate / @as(f64, @floatFromInt(format.mFramesPerPacket)) *
            seconds * @as(f64, @floatFromInt(max_packet)))
    else
        @max(max_buffer, max_packet);

    out_size.* = @min(@max(out_size.*, min_buffer), max_buffer);
    out_packets.* = out_size.* / max_packet;
}

fn copyMagicCookie(file: c.AudioFileID, queue: c.AudioQueueRef) void {
    var size: u32 = 0;
    const res = c.AudioFileGetPropertyInfo(file, c.kAudioFilePropertyMagicCookieData, &size, null);

    if (res == c.noErr and size > 0) {
        const cookie = std.heap.c_allocator.alloc(u8, size) catch @panic("OOM");
        defer std.heap.c_allocator.free(cookie);

        HandleError(c.AudioFileGetProperty(file, c.kAudioFilePropertyMagicCookieData, &size, cookie.ptr), "Get magic cookie");

        HandleError(c.AudioQueueSetProperty(queue, c.kAudioQueueProperty_MagicCookie, cookie.ptr, size), "Set magic cookie");
    }
}

fn outputCallback(
    user_data: ?*anyopaque,
    queue: c.AudioQueueRef,
    buffer: c.AudioQueueBufferRef,
) callconv(.C) void {
    const player: *Player = @ptrCast(@alignCast(user_data));
    if (player.done) return;

    var bytes: u32 = 0;
    var packets: u32 = player.packets_to_read;

    HandleError(c.AudioFileReadPackets(player.file, c.FALSE, &bytes, player.packet_descs, player.packet_pos, &packets, buffer.*.mAudioData), "Read packets");

    if (packets > 0) {
        buffer.*.mAudioDataByteSize = bytes;
        HandleError(c.AudioQueueEnqueueBuffer(queue, buffer, if (player.packet_descs != null) packets else 0, player.packet_descs), "Enqueue buffer");
        player.packet_pos += @as(i64, @intCast(packets));
    } else {
        HandleError(c.AudioQueueStop(queue, c.FALSE), "Queue stop");
        player.done = true;
    }
}

pub fn main() !void {
    var player = Player{};

    // Create file URL
    const path_str = createCFString("./main_menu.mp3");
    defer cfSafeRelease(path_str);

    const file_url = c.CFURLCreateWithFileSystemPath(c.kCFAllocatorDefault, path_str, c.kCFURLPOSIXPathStyle, 0);
    defer cfSafeRelease(file_url);

    // Open audio file
    HandleError(c.AudioFileOpenURL(file_url, c.kAudioFileReadPermission, 0, // Auto-detect file type
        &player.file), "Open audio file");
    defer _ = c.AudioFileClose(player.file);

    // Get file format
    var format: c.AudioStreamBasicDescription = undefined;
    var prop_size: u32 = @sizeOf(c.AudioStreamBasicDescription);
    HandleError(c.AudioFileGetProperty(player.file, c.kAudioFilePropertyDataFormat, &prop_size, &format), "Get file format");

    // Create output queue
    var queue: c.AudioQueueRef = undefined;
    HandleError(c.AudioQueueNewOutput(&format, outputCallback, &player, @as(c.CFRunLoopRef, @ptrFromInt(0)), // No run loop
        @as(c.CFStringRef, @ptrFromInt(0)), // No run loop mode
        0, &queue), "Create audio queue");
    defer _ = c.AudioQueueDispose(queue, c.TRUE);

    // Configure buffers
    var buffer_size: u32 = 0;
    calculateBufferSize(player.file, format, BUFFER_DURATION, &buffer_size, &player.packets_to_read);

    // Allocate packet descriptions for VBR
    const is_vbr = format.mBytesPerPacket == 0 or format.mFramesPerPacket == 0;
    player.packet_descs = if (is_vbr)
        @ptrCast(@alignCast(std.c.malloc(@sizeOf(c.AudioStreamPacketDescription) * player.packets_to_read)))
    else
        null;
    defer if (is_vbr) std.c.free(@ptrCast(player.packet_descs));

    copyMagicCookie(player.file, queue);

    // Allocate and prime buffers
    var buffers: [NUMBER_OF_BUFFERS]c.AudioQueueBufferRef = undefined;
    for (&buffers) |*buf| {
        HandleError(c.AudioQueueAllocateBuffer(queue, buffer_size, buf), "Allocate buffer");
        outputCallback(&player, queue, buf.*);
        if (player.done) break;
    }

    // Start playback
    HandleError(c.AudioQueueStart(queue, null), "Start queue");

    // Run until completion
    while (!player.done) {
        _ = c.CFRunLoopRunInMode(c.kCFRunLoopDefaultMode, 0.25, c.FALSE);
    }

    // Allow final buffers to play
    _ = c.CFRunLoopRunInMode(c.kCFRunLoopDefaultMode, 2, c.FALSE);
}
