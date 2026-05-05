const std = @import("std");
const clap = @import("clap");

pub const Args = struct {
    board: ?[]const u8 = null,
    thread: ?u64 = null,
    archive: bool = false,
    list_boards: bool = false, // mutual exclusive with -b or --board <board_name>
    help: bool = false,
};

// Errors:
pub const ParseError = error{
    MissingBoard,
    MissingThread,
    InvalidThreadNumber,
    InvalidCombination, // to handle the mix of -b and --boards
    ShowHelp,
};

pub const Error = ParseError || error{ OutOfMemory, Unexpected };

fn validateArgs(args: Args) !void {
    if (args.list_boards) {
        if (args.board != null) { // it means that the user has combined both options ...
            std.debug.print("Error: --board and --boards used together\n", .{});
            return ParseError.InvalidCombination;
        }
        if (args.thread != null) {
            std.debug.print("Error: --thread cannot be used with --boards\n", .{});
            return ParseError.InvalidCombination;
        }

        return; // OK ...
    }

    if (args.board == null) {
        std.debug.print("Error: --board <board name> missing\n", .{});
        return ParseError.MissingBoard;
    }
}

pub fn parseArgs(init: std.process.Init) !Args {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help                  Muestra esta ayuda
        \\-b, --board <str>           Tablero de 4chan
        \\-t, --thread <u64>          Número de thread
        \\-a, --archive               Ver threads archivados
        \\    --boards                Listar todos los boards
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, init.minimal.args, .{
        .diagnostic = &diag,
        .allocator = init.arena.allocator(),
    }) catch |err| {
        diag.reportToFile(init.io, .stderr(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        clap.helpToFile(init.io, .stdout(), clap.Help, &params, .{}) catch {};
        return ParseError.ShowHelp;
    }

    const args = Args{
        .board = res.args.board,
        .thread = res.args.thread,
        .archive = res.args.archive != 0,
        .list_boards = res.args.boards != 0,
        .help = res.args.help != 0,
    };

    try validateArgs(args);
    return args;
}
