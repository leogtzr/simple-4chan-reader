const std = @import("std");

pub const Post = struct {
    no: u64,
    now: []const u8,
    name: ?[]const u8 = null,
    sub: ?[]const u8 = null,
    com: ?[]const u8 = null,
    filename: ?[]const u8 = null,
    ext: ?[]const u8 = null,
    tim: ?u64 = null,
    time: ?u64 = null,
    resto: ?u64 = null,
    replies: ?u32 = null,
    images: ?u32 = null,
    capcode: ?[]const u8 = null,
    trip: ?[]const u8 = null,
};

pub const ThreadResponse = struct {
    posts: []Post,
};

pub const CatalogThread = struct {
    no: u64,
    replies: u32,
    now: ?[]const u8 = null,
    name: ?[]const u8 = null,
    sub: ?[]const u8 = null,
    com: ?[]const u8 = null,
    filename: ?[]const u8 = null,
    ext: ?[]const u8 = null,
    tim: ?u64 = null,
    time: ?u64 = null,
    fsize: ?u64 = null,
    md5: ?[]const u8 = null,
    w: ?u32 = null,
    h: ?u32 = null,
    tn_w: ?u32 = null,
    tn_h: ?u32 = null,
    images: ?u32 = null,
    resto: ?u64 = null,
    sticky: ?u32 = null,
    closed: ?u32 = null,
    bumplimit: ?u32 = null,
    imagelimit: ?u32 = null,
    semantic_url: ?[]const u8 = null,
    custom_spoiler: ?u32 = null,
    omitted_posts: ?u32 = null,
    omitted_images: ?u32 = null,
    last_modified: ?u64 = null,
    trip: ?[]const u8 = null,
    capcode: ?[]const u8 = null,
    last_replies: ?[]Post = null,
};

pub const CatalogPage = struct {
    page: u32, // ← Este campo faltaba
    threads: []CatalogThread,
};

pub const BoardCooldowns = struct {
    threads: u32,
    replies: u32,
    images: u32,
};

pub const Board = struct {
    board: []const u8,
    title: []const u8,
    ws_board: u32,
    per_page: u32,
    pages: u32,
    max_filesize: u64,
    max_webm_filesize: u64,
    max_comment_chars: u32,
    max_webm_duration: u32,
    bump_limit: u32,
    image_limit: u32,
    cooldowns: BoardCooldowns,
    meta_description: []const u8,
    is_archived: ?u32 = null,
    spoilers: ?u32 = null,
    custom_spoilers: ?u32 = null,
    user_ids: ?u32 = null,
    country_flags: ?u32 = null,
};

pub const BoardsResponse = struct {
    boards: []Board,
};
