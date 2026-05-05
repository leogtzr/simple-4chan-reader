const std = @import("std");

pub const StdWriters = struct {
    stdout: std.Io.File.Writer,
    stderr: std.Io.File.Writer,
};

pub fn getStdWriters(
    io: std.Io,
    stdout_buf: []u8,
    stderr_buf: []u8,
) StdWriters {
    return .{
        .stdout = std.Io.File.stdout().writer(io, stdout_buf),
        .stderr = std.Io.File.stderr().writer(io, stderr_buf),
    };
}

pub fn decodeQuotationMarks(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    return std.mem.replaceOwned(u8, allocator, str, "&quot;", "\"");
}
