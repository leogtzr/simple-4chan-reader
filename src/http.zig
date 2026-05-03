const std = @import("std");
const Io = std.Io;

pub fn fetchJson(allocator: std.mem.Allocator, io: Io, url: []const u8) ![]u8 {
    var client: std.http.Client = .{
        .allocator = allocator,
        .io = io,
    };
    defer client.deinit();

    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(allocator);

    var allocating_writer = std.Io.Writer.Allocating.init(allocator);
    defer allocating_writer.deinit();

    const response = try client.fetch(.{
        .location = .{ .url = url },
        .response_writer = &allocating_writer.writer,
    });

    if (response.status.class() != .success) {
        std.log.err("HTTP error: {d}", .{@intFromEnum(response.status)});
        return error.HttpError;
    }

    try body.appendSlice(allocator, allocating_writer.written());
    return body.toOwnedSlice(allocator);
}
