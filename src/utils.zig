const std = @import("std");

pub fn decodeQuotationMarks(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    return std.mem.replaceOwned(u8, allocator, str, "&quot;", "\"");
}

/// Strip HTML tags from src, converting <br> to newlines and common entities.
/// Returns a slice of dst; output is always <= input length.
pub fn stripHtml(dst: []u8, src: []const u8) []u8 {
    var di: usize = 0;
    var i: usize = 0;
    while (i < src.len and di < dst.len) {
        if (src[i] == '<') {
            // Convert line breaks to newlines
            if (std.mem.startsWith(u8, src[i..], "<br>") or
                std.mem.startsWith(u8, src[i..], "<br/>") or
                std.mem.startsWith(u8, src[i..], "<br />"))
            {
                dst[di] = '\n';
                di += 1;
            }
            // Skip to end of tag
            while (i < src.len and src[i] != '>') : (i += 1) {}
            if (i < src.len) i += 1;
        } else if (src[i] == '&') {
            const rest = src[i..];
            if (std.mem.startsWith(u8, rest, "&quot;")) {
                dst[di] = '"';
                di += 1;
                i += 6;
            } else if (std.mem.startsWith(u8, rest, "&amp;")) {
                dst[di] = '&';
                di += 1;
                i += 5;
            } else if (std.mem.startsWith(u8, rest, "&lt;")) {
                dst[di] = '<';
                di += 1;
                i += 4;
            } else if (std.mem.startsWith(u8, rest, "&gt;")) {
                dst[di] = '>';
                di += 1;
                i += 4;
            } else if (std.mem.startsWith(u8, rest, "&#39;") or
                std.mem.startsWith(u8, rest, "&apos;"))
            {
                dst[di] = '\'';
                di += 1;
                i += if (src[i + 1] == '#') 5 else 6;
            } else {
                dst[di] = src[i];
                di += 1;
                i += 1;
            }
        } else {
            dst[di] = src[i];
            di += 1;
            i += 1;
        }
    }
    return dst[0..di];
}
