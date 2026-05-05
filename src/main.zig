const std = @import("std");
const args_mod = @import("args.zig");
const types = @import("types.zig");
const http = @import("http.zig");
const utils = @import("utils.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [32 * 1024]u8 = undefined;
    var stderr_buffer: [8 * 1024]u8 = undefined;

    var writers = utils.getStdWriters(io, &stdout_buffer, &stderr_buffer);
    defer writers.stdout.flush() catch {};
    defer writers.stderr.flush() catch {};

    const parsedArgs = args_mod.parseArgs(init) catch |err| switch (err) {
        args_mod.ParseError.ShowHelp => return,
        else => {
            try writers.stderr.interface.print("Error al parsear argumentos: {}", .{err});
            return;
        },
    };

    // try writers.stdout.interface.print("Args: {}\n", .{parsedArgs.list_boards});

    if (parsedArgs.list_boards) {
        // try writers.stdout.interface.print("Printing boards ...\n", .{});
        const url = "https://a.4cdn.org/boards.json";

        const json = try http.fetchJson(allocator, io, url);
        defer allocator.free(json);

        const parsed = try std.json.parseFromSlice(types.BoardsResponse, allocator, json, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        try writers.stdout.interface.print("{d} boards disponibles:\n\n", .{parsed.value.boards.len});
        for (parsed.value.boards) |b| {
            const cleanMetaDescription = try utils.decodeQuotationMarks(allocator, b.meta_description);
            defer allocator.free(cleanMetaDescription);
            try writers.stdout.interface.print("/{s}/\t{s}\n", .{ b.board, cleanMetaDescription });
        }

        return;
    }

    const board = parsedArgs.board orelse unreachable;

    if (parsedArgs.thread) |thread_no| {
        // allocate the URL dynamically and discard it.
        const url = try std.fmt.allocPrint(allocator, "https://a.4cdn.org/{s}/thread/{d}.json", .{ parsedArgs.board.?, thread_no });
        defer allocator.free(url);

        const json = try http.fetchJson(allocator, io, url);
        defer allocator.free(json);

        const parsed = try std.json.parseFromSlice(types.ThreadResponse, allocator, json, .{ .ignore_unknown_fields = true }); // ← importante
        defer parsed.deinit();

        try writers.stdout.interface.print("Thread /{s}/ — No. {d}\n\n", .{ board, thread_no });

        for (parsed.value.posts) |post| {
            try writers.stdout.interface.print(">> No. {d}  {s}\n", .{ post.no, post.name orelse "Anonymous" });
            if (post.sub) |sub| try writers.stdout.interface.print("Título: {s}\n", .{sub});
            if (post.com) |com| try writers.stdout.interface.print("{s}\n\n", .{com});
        }
    } else {
        const url = try std.fmt.allocPrint(allocator, "https://a.4cdn.org/{s}/catalog.json", .{parsedArgs.board.?});
        defer allocator.free(url);

        const json = try http.fetchJson(allocator, io, url);
        defer allocator.free(json);

        const parsed = try std.json.parseFromSlice([]types.CatalogPage, allocator, json, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        try writers.stdout.interface.print("Catálogo de /{s}/ - {d} páginas\n\n", .{ parsedArgs.board.?, parsed.value.len });

        for (parsed.value) |page| {
            try writers.stdout.interface.print("Página {d} ({d} threads)\n", .{ page.page, page.threads.len });
            for (page.threads[0..@min(10, page.threads.len)]) |thread| { // muestra solo los primeros 10
                try writers.stdout.interface.print("  >> {d} | {d} replies | {s} | {s}\n", .{
                    thread.no,
                    thread.replies,
                    thread.sub orelse thread.com orelse "(sin título)",
                    thread.filename orelse "(no image)",
                });
            }
        }
    }
}
