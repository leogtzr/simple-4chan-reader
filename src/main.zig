const std = @import("std");
const args = @import("args.zig");
const types = @import("types.zig");
const http = @import("http.zig");

const ParseError = args.ParseError;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    const parsedArgs = args.parseArgs(init) catch |err| switch (err) {
        ParseError.ShowHelp => return,
        else => {
            std.log.err("Error: {}", .{err});
            std.debug.print("\n", .{});
            args.printUsage();
            return;
        },
    };

    if (parsedArgs.thread) |thread_no| {
        // allocate the URL dynamically and discard it.
        const url = try std.fmt.allocPrint(allocator, "https://a.4cdn.org/{s}/thread/{d}.json", .{ parsedArgs.board, thread_no });
        defer allocator.free(url);

        const json = try http.fetchJson(allocator, io, url);
        defer allocator.free(json);
        // std.debug.print("=== JSON COMPLETO ===\n{s}\n=== FIN JSON ===\n\n", .{json});

        const parsed = try std.json.parseFromSlice(types.ThreadResponse, allocator, json, .{ .ignore_unknown_fields = true }); // ← importante
        defer parsed.deinit();

        std.debug.print("Thread /{s}/ — No. {d}\n\n", .{ parsedArgs.board, thread_no });

        for (parsed.value.posts) |post| {
            std.debug.print(">> No. {d}  {s}\n", .{ post.no, post.name orelse "Anonymous" });
            if (post.sub) |sub| std.debug.print("Título: {s}\n", .{sub});
            if (post.com) |com| std.debug.print("{s}\n\n", .{com});
        }
    } else {
        const url = try std.fmt.allocPrint(allocator, "https://a.4cdn.org/{s}/catalog.json", .{parsedArgs.board});
        defer allocator.free(url);

        const json = try http.fetchJson(allocator, io, url);
        defer allocator.free(json);

        //std.debug.print("Catálogo de /{s}/ cargado ({d} bytes)\n", .{ parsedArgs.board, json.len });
        const parsed = try std.json.parseFromSlice([]types.CatalogPage, allocator, json, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        std.debug.print("Catálogo de /{s}/ - {d} páginas\n\n", .{ parsedArgs.board, parsed.value.len });

        for (parsed.value) |page| {
            std.debug.print("Página {d} ({d} threads)\n", .{ page.page, page.threads.len });
            for (page.threads[0..@min(10, page.threads.len)]) |thread| { // muestra solo los primeros 10
                std.debug.print("  >> {d} | {d} replies | {s} | {s}\n", .{
                    thread.no,
                    thread.replies,
                    thread.sub orelse thread.com orelse "(sin título)",
                    thread.filename orelse "(no image)",
                });
            }
        }
    }
}
