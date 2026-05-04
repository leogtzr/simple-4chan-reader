const std = @import("std");

pub const Args = struct {
    board: []const u8,
    thread: ?u64 = null,
};

// Errors:
pub const ParseError = error{
    MissingBoard,
    MissingThread,
    InvalidThreadNumber,
    ShowHelp,
};

pub const Error = ParseError || error{ OutOfMemory, Unexpected };

pub fn printUsage() void {
    std.debug.print(
        \\Uso: 4chnr -board <board> [-thread <número>]
        \\
        \\Opciones:
        \\  -board, --board <board>     Tablero de 4chan (obligatorio)
        \\  -thread, --thread <número>  Número de thread específico
        \\  -h, --help                  Muestra esta ayuda
        \\
        \\Examples:
        \\  4chnr -board pol
        \\  4chnr -board lit -thread 123456789
        \\  4chnr --help
        \\
    , .{});
}

pub fn parseArgs(init: std.process.Init) Error!Args {
    const args_slice = try init.minimal.args.toSlice(init.arena.allocator());

    var board: ?[]const u8 = null;
    var thread: ?u64 = null;
    var show_help = false;

    var i: usize = 1;
    while (i < args_slice.len) : (i += 1) {
        const arg = args_slice[i];
        if (std.mem.eql(u8, arg, "-h") or
            std.mem.eql(u8, arg, "-help") or
            std.mem.eql(u8, arg, "--help"))
        {
            show_help = true;
            continue;
        } else if (std.mem.eql(u8, arg, "-board") or std.mem.eql(u8, arg, "--board")) {
            i += 1;
            if (i >= args_slice.len) return ParseError.MissingBoard;
            board = args_slice[i];
        } else if (std.mem.eql(u8, arg, "-thread") or std.mem.eql(u8, arg, "--thread")) {
            i += 1;
            if (i >= args_slice.len) return ParseError.MissingThread;
            thread = std.fmt.parseInt(u64, args_slice[i], 10) catch return ParseError.InvalidThreadNumber;
        } else {
            std.debug.print("unknown option: '{s}'\n", .{arg});
            return ParseError.ShowHelp;
        }
    }

    if (show_help) {
        printUsage();
        return ParseError.ShowHelp;
    }

    return Args{
        .board = board orelse return ParseError.MissingBoard,
        .thread = thread,
    };
}
