const std = @import("std");
const dvui = @import("dvui");
const types = @import("types.zig");
const http = @import("http.zig");
const utils = @import("utils.zig");

// ── DVUI App boilerplate ─────────────────────────────────────────────────────

pub const dvui_app: dvui.App = .{
    .config = .{ .options = .{
        .size = .{ .w = 960.0, .h = 680.0 },
        .min_size = .{ .w = 500.0, .h = 300.0 },
        .title = "4chan Reader",
    } },
    .frameFn = appFrame,
    .initFn = appInit,
    .deinitFn = appDeinit,
};
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{ .logFn = dvui.App.logFn };

// ── Allocator ────────────────────────────────────────────────────────────────

// smp_allocator is thread-safe
const alloc = std.heap.smp_allocator;

// ── Simple spinlock mutex (critical sections are tiny, so spinning is fine) ──

const Mutex = struct {
    m: std.atomic.Mutex = .unlocked,

    pub fn lock(self: *Mutex) void {
        while (!self.m.tryLock()) std.atomic.spinLoopHint();
    }

    pub fn unlock(self: *Mutex) void {
        self.m.unlock();
    }
};

// ── State ────────────────────────────────────────────────────────────────────

const View = enum { loading, boards, catalog, thread, err };

var g_mutex: Mutex = .{};
var g_view: View = .loading;
var g_boards: ?std.json.Parsed(types.BoardsResponse) = null;
var g_catalog: ?std.json.Parsed([]types.CatalogPage) = null;
var g_thread_data: ?std.json.Parsed(types.ThreadResponse) = null;
var g_board: [64]u8 = undefined;
var g_board_len: usize = 0;
var g_thread_no: u64 = 0;
var g_error: [512]u8 = undefined;
var g_error_len: usize = 0;
var g_win: *dvui.Window = undefined;
var g_io: std.Io = undefined;

// ── Lifecycle ────────────────────────────────────────────────────────────────

pub fn appInit(win: *dvui.Window) !void {
    g_win = win;
    g_io = dvui.App.main_init.?.io;
    (try std.Thread.spawn(.{}, fetchBoards, .{})).detach();
}

pub fn appDeinit() void {
    g_mutex.lock();
    defer g_mutex.unlock();
    if (g_boards) |*b| b.deinit();
    if (g_catalog) |*c| c.deinit();
    if (g_thread_data) |*t| t.deinit();
}

// ── Background workers ────────────────────────────────────────────────────────

fn setError(comptime fmt: []const u8, args: anytype) void {
    g_mutex.lock();
    const msg = std.fmt.bufPrint(&g_error, fmt, args) catch "error (truncated)";
    g_error_len = msg.len;
    g_view = .err;
    g_mutex.unlock();
    dvui.refresh(g_win, @src(), null);
}

fn fetchBoards() void {
    std.debug.print("debug:x Fetching boards ... ", .{});
    const json = http.fetchJson(alloc, g_io, "https://a.4cdn.org/boards.json") catch |e| {
        setError("Boards fetch: {}", .{e});
        return;
    };
    defer alloc.free(json);

    const parsed = std.json.parseFromSlice(
        types.BoardsResponse,
        alloc,
        json,
        .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
    ) catch |e| {
        setError("Boards parse: {}", .{e});
        return;
    };

    g_mutex.lock();
    if (g_boards) |*old| old.deinit();
    g_boards = parsed;
    g_view = .boards;
    g_mutex.unlock();
    dvui.refresh(g_win, @src(), null);
}

fn fetchCatalog() void {
    g_mutex.lock();
    const blen = g_board_len;
    var board_copy: [64]u8 = undefined;
    @memcpy(board_copy[0..blen], g_board[0..blen]);
    g_mutex.unlock();

    const board = board_copy[0..blen];

    const url = std.fmt.allocPrint(alloc, "https://a.4cdn.org/{s}/catalog.json", .{board}) catch |e| {
        setError("allocPrint: {}", .{e});
        return;
    };
    defer alloc.free(url);

    const json = http.fetchJson(alloc, g_io, url) catch |e| {
        setError("Catalog fetch /{s}/: {}", .{ board, e });
        return;
    };
    defer alloc.free(json);

    const parsed = std.json.parseFromSlice(
        []types.CatalogPage,
        alloc,
        json,
        .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
    ) catch |e| {
        setError("Catalog parse: {}", .{e});
        return;
    };

    g_mutex.lock();
    if (g_catalog) |*old| old.deinit();
    g_catalog = parsed;
    g_view = .catalog;
    g_mutex.unlock();
    dvui.refresh(g_win, @src(), null);
}

fn fetchThread() void {
    g_mutex.lock();
    const blen = g_board_len;
    var board_copy: [64]u8 = undefined;
    @memcpy(board_copy[0..blen], g_board[0..blen]);
    const no = g_thread_no;
    g_mutex.unlock();

    const board = board_copy[0..blen];

    const url = std.fmt.allocPrint(
        alloc,
        "https://a.4cdn.org/{s}/thread/{d}.json",
        .{ board, no },
    ) catch |e| {
        setError("allocPrint: {}", .{e});
        return;
    };
    defer alloc.free(url);

    const json = http.fetchJson(alloc, g_io, url) catch |e| {
        setError("Thread fetch: {}", .{e});
        return;
    };
    defer alloc.free(json);

    const parsed = std.json.parseFromSlice(
        types.ThreadResponse,
        alloc,
        json,
        .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
    ) catch |e| {
        setError("Thread parse: {}", .{e});
        return;
    };

    g_mutex.lock();
    if (g_thread_data) |*old| old.deinit();
    g_thread_data = parsed;
    g_view = .thread;
    g_mutex.unlock();
    dvui.refresh(g_win, @src(), null);
}

// ── Frame function ───────────────────────────────────────────────────────────

pub fn appFrame() !dvui.App.Result {
    g_mutex.lock();
    const view = g_view;
    g_mutex.unlock();

    return switch (view) {
        .loading => blk: {
            var box = dvui.box(@src(), .{ .dir = .vertical }, .{
                .expand = .both,
                .gravity_x = 0.5,
                .gravity_y = 0.5,
            });
            defer box.deinit();
            dvui.label(@src(), "Loading...", .{}, .{});
            break :blk .ok;
        },
        .boards => try renderBoards(),
        .catalog => try renderCatalog(),
        .thread => try renderThread(),
        .err => blk: {
            var err_buf: [512]u8 = undefined;
            g_mutex.lock();
            const elen = @min(g_error_len, err_buf.len);
            @memcpy(err_buf[0..elen], g_error[0..elen]);
            g_mutex.unlock();
            const err_msg = err_buf[0..elen];

            dvui.label(@src(), "Error: {s}", .{err_msg}, .{
                .gravity_x = 0.5,
                .gravity_y = 0.45,
                .color_text = .{ .r = 220, .g = 60, .b = 60, .a = 255 },
            });
            if (dvui.button(@src(), "Back to Boards", .{}, .{
                .gravity_x = 0.5,
                .gravity_y = 0.55,
            })) {
                g_mutex.lock();
                g_view = .boards;
                g_mutex.unlock();
            }
            break :blk .ok;
        },
    };
}

// ── Views ────────────────────────────────────────────────────────────────────

fn renderBoards() !dvui.App.Result {
    // Read g_boards under the lock so the compiler cannot hoist the load
    // above the mutex's acquire barrier.
    g_mutex.lock();
    const opt_parsed = g_boards;
    g_mutex.unlock();
    const parsed = opt_parsed orelse return .ok;
    const boards = parsed.value.boards;

    {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .background = true,
            .style = .window,
        });
        defer hbox.deinit();
        dvui.label(@src(), "4chan — {d} boards", .{boards.len}, .{});
    }

    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    for (boards, 0..) |board, i| {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .id_extra = i,
        });
        defer row.deinit();

        var btn_buf: [32]u8 = undefined;
        const btn_label = std.fmt.bufPrint(&btn_buf, "/{s}/", .{board.board}) catch board.board;

        if (dvui.button(@src(), btn_label, .{}, .{
            .min_size_content = .{ .w = 80.0 },
        })) {
            navigateToCatalog(board.board);
        }

        dvui.label(@src(), "{s}", .{board.title}, .{ .expand = .horizontal });
    }

    return .ok;
}

fn renderCatalog() !dvui.App.Result {
    var board_copy: [64]u8 = undefined;
    g_mutex.lock();
    const opt_parsed = g_catalog;
    const blen = g_board_len;
    @memcpy(board_copy[0..blen], g_board[0..blen]);
    g_mutex.unlock();
    const parsed = opt_parsed orelse return .ok;
    const board = board_copy[0..blen];

    {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .background = true,
            .style = .window,
        });
        defer hbox.deinit();

        if (dvui.button(@src(), "< Boards", .{}, .{})) {
            g_mutex.lock();
            g_view = .boards;
            g_mutex.unlock();
            return .ok;
        }
        dvui.label(@src(), " /{s}/ Catalog", .{board}, .{});
    }

    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    var idx: usize = 0;
    for (parsed.value) |page| {
        for (page.threads) |thread| {
            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .horizontal,
                .id_extra = idx,
            });
            defer row.deinit();

            var btn_buf: [32]u8 = undefined;
            const btn_label = std.fmt.bufPrint(&btn_buf, "{d}", .{thread.no}) catch "?";
            if (dvui.button(@src(), btn_label, .{}, .{
                .min_size_content = .{ .w = 90.0 },
            })) {
                navigateToThread(board, thread.no);
            }

            const raw_title = thread.sub orelse thread.com orelse "(no title)";
            const title_buf = alloc.alloc(u8, raw_title.len) catch null;
            defer if (title_buf) |b| alloc.free(b);
            const display_title = if (title_buf) |b| utils.stripHtml(b, raw_title) else raw_title;
            const max_len = @min(display_title.len, 100);
            dvui.labelNoFmt(@src(), display_title[0..max_len], .{}, .{ .expand = .horizontal });

            dvui.label(@src(), "{d}R|{?d}I", .{ thread.replies, thread.images }, .{
                .min_size_content = .{ .w = 40.0 },
                .color_text = .{ .r = 130, .g = 200, .b = 130, .a = 255 },
            });

            idx += 1;
        }
    }

    return .ok;
}

fn renderThread() !dvui.App.Result {
    var board_copy: [64]u8 = undefined;
    g_mutex.lock();
    const opt_parsed = g_thread_data;
    const blen = g_board_len;
    @memcpy(board_copy[0..blen], g_board[0..blen]);
    const no = g_thread_no;
    g_mutex.unlock();
    const parsed = opt_parsed orelse return .ok;
    const board = board_copy[0..blen];

    {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .background = true,
            .style = .window,
        });
        defer hbox.deinit();

        if (dvui.button(@src(), "< Catalog", .{}, .{})) {
            g_mutex.lock();
            g_view = .catalog;
            g_mutex.unlock();
            return .ok;
        }
        dvui.label(@src(), " /{s}/ — No.{d} ({d} posts)", .{
            board, no, parsed.value.posts.len,
        }, .{});
    }

    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    // Build the HTML-encoded quote pattern for the OP post number once.
    var op_quote_buf: [32]u8 = undefined;
    const op_quote = std.fmt.bufPrint(&op_quote_buf, "&gt;&gt;{d}", .{no}) catch "";

    for (parsed.value.posts, 0..) |post, i| {
        const replies_to_op = if (post.com) |com|
            op_quote.len > 0 and std.mem.indexOf(u8, com, op_quote) != null
        else
            false;

        var card = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .horizontal,
            .id_extra = i,
            .background = true,
            .style = .window,
            .margin = .{ .x = 4, .y = 2, .w = 4, .h = 2 },
            .padding = .{ .x = 6, .y = 4, .w = 6, .h = 4 },
        });
        defer card.deinit();

        // Post header
        {
            var hdr = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
            defer hdr.deinit();
            dvui.label(@src(), "No.{d}", .{post.no}, .{
                .color_text = .{ .r = 180, .g = 140, .b = 60, .a = 255 },
            });
            dvui.label(@src(), "  {s}", .{post.name orelse "Anonymous"}, .{
                .color_text = .{ .r = 100, .g = 170, .b = 100, .a = 255 },
            });
            if (replies_to_op) {
                dvui.label(@src(), "  ^ OP", .{}, .{
                    .color_text = .{ .r = 200, .g = 100, .b = 220, .a = 255 },
                });
            }
        }

        // Subject
        if (post.sub) |sub| {
            dvui.labelNoFmt(@src(), sub, .{}, .{
                .expand = .horizontal,
                .color_text = .{ .r = 140, .g = 140, .b = 220, .a = 255 },
            });
        }

        // Comment (strip HTML tags/entities)
        if (post.com) |com| {
            const buf = alloc.alloc(u8, com.len) catch continue;
            defer alloc.free(buf);
            const stripped = utils.stripHtml(buf, com);

            var tl = dvui.textLayout(@src(), .{}, .{ .expand = .horizontal });
            defer tl.deinit();
            tl.addText(stripped, .{});
        }
    }

    return .ok;
}

// ── Navigation helpers ────────────────────────────────────────────────────────

fn navigateToCatalog(board: []const u8) void {
    g_mutex.lock();
    const blen = @min(board.len, g_board.len);
    @memcpy(g_board[0..blen], board[0..blen]);
    g_board_len = blen;
    g_view = .loading;
    g_mutex.unlock();
    (std.Thread.spawn(.{}, fetchCatalog, .{}) catch return).detach();
}

fn navigateToThread(board: []const u8, thread_no: u64) void {
    g_mutex.lock();
    const blen = @min(board.len, g_board.len);
    @memcpy(g_board[0..blen], board[0..blen]);
    g_board_len = blen;
    g_thread_no = thread_no;
    g_view = .loading;
    g_mutex.unlock();
    (std.Thread.spawn(.{}, fetchThread, .{}) catch return).detach();
}
