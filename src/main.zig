//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const au_systems = @import("audio_systems");
const std = @import("std");

pub fn main() !void {
    var err: au_systems.ASStatus = 0;
    au_systems.init();
    defer au_systems.deinit();

    const handle = au_systems.new("./music/doom.mp3");
    defer _ = au_systems.remove(handle);

    if (handle == 0) @panic("Handle cannot be 0");

    err = au_systems.start(handle);
    defer _ = au_systems.stop(handle);

    if (err != 0) {
        au_systems.strASStatus(err);
        return;
    }

    while (au_systems.isPlaying(handle)) {
        std.time.sleep(10 * std.time.ns_per_s);
        _ = au_systems.restart(handle);
    }
}
