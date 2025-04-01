const std = @import("std");
const c = @cImport({
    @cInclude("soundio/soundio.h");
});

pub fn main() !void {
    std.log.info("soundio version: {s}", .{c.soundio_version_string()});
}
