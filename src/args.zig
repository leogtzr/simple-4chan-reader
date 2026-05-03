const std = @import("std");

pub const Args = struct {
    board: []const u8,
    thread: ?u64 = null,
};

pub fn parseArgs(init: std.process.Init) !Args {
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var board: ?[]const u8 = null;
    var thread: ?u64 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-board") or std.mem.eql(u8, arg, "--board")) {
            i += 1;
            if (i >= args.len) return error.MissingBoard;
            board = args[i];
        } else if (std.mem.eql(u8, arg, "-thread") or std.mem.eql(u8, arg, "--thread")) {
            i += 1;
            if (i >= args.len) return error.MissingThread;
            thread = std.fmt.parseInt(u64, args[i], 10) catch return error.InvalidThreadNumber;
        }
    }

    return Args{
        .board = board orelse return error.MissingBoard,
        .thread = thread,
    };
}
