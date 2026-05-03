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
