const std = @import("std");
const sdl = @import("MSDL");

name: []const u8,
rows: usize,
cols: usize,
data: []u8,
pixel_size: usize = 40,
offx: i32 = 0,

const Self = @This();
var alloc: std.mem.Allocator = undefined;

pub fn init(name: []const u8, rows: usize, cols: usize, pixel_size: usize, allocator: std.mem.Allocator) !Self {
    alloc = allocator;

    const map = blk: {
        const mfile = std.fs.cwd().openFile("map.json", .{}) catch |err| {
            if (err == error.FileNotFound) {
                const map = try alloc.alloc(u8, cols * rows);
                @memset(map, 0);
                break :blk map;
            }

            return err;
        };
        defer mfile.close();

        const len = try mfile.getEndPos();
        const buf = try alloc.alloc(u8, len);
        defer alloc.free(buf);
        _ = try mfile.readAll(buf);

        const map = try std.json.parseFromSlice(Self, alloc, buf, .{});
        defer map.deinit();

        break :blk try alloc.dupe(u8, map.value.data);
    };

    return Self{
        .name = name,
        .rows = rows,
        .cols = cols,
        .pixel_size = pixel_size,
        .data = map,
    };
}

pub fn deinit(self: Self) void {
    alloc.free(self.data);
}

//-- utils

const RectInfo = struct {
    ind: usize,
    row: usize,
    col: usize,
};

pub fn rect_info(self: Self, rect: sdl.SDL_Rect) RectInfo {
    const row = @as(usize, @intCast(rect.x)) / self.pixel_size;
    const col = @as(usize, @intCast(rect.y)) / self.pixel_size;
    const ind = row + col * self.rows;

    return RectInfo{ .ind = ind, .row = row, .col = col };
}

pub fn frect_info(self: Self, rect: sdl.SDL_FRect) RectInfo {
    const row = @as(usize, @intFromFloat(rect.x)) / self.pixel_size;
    const col = @as(usize, @intFromFloat(rect.y)) / self.pixel_size;
    const ind = row + col * self.rows;

    return RectInfo{ .ind = ind, .row = row, .col = col };
}

pub fn get_brick(self: Self, ind: usize) ?sdl.SDL_FRect {
    if (self.data[ind] == 0 or self.data[ind] == 2) return null;

    const x = ind % self.rows * self.pixel_size;
    const y = @divFloor(ind, self.rows) * self.pixel_size;

    return sdl.SDL_FRect{
        .x = @floatFromInt(@as(i32, @intCast(x)) + self.offx),
        .y = @floatFromInt(y),
        .w = @floatFromInt(self.pixel_size),
        .h = @floatFromInt(self.pixel_size),
    };
}

//-- exact brick no null value
pub fn get_brick_ex(self: Self, ind: usize) sdl.SDL_FRect {
    const x = ind % self.rows * self.pixel_size;
    const y = @divFloor(ind, self.rows) * self.pixel_size;

    return sdl.SDL_FRect{
        .x = @floatFromInt(@as(i32, @intCast(x)) + self.offx),
        .y = @floatFromInt(y),
        .w = @floatFromInt(self.pixel_size),
        .h = @floatFromInt(self.pixel_size),
    };
}

pub fn test_get_brick(self: Self, ind: usize) sdl.SDL_Rect {
    const x = @as(i32, @intCast(ind % self.rows)) * @as(i32, @intCast(self.pixel_size)) + self.offx;
    const y = @divFloor(ind, self.rows);

    return sdl.SDL_Rect{
        .x = @intCast(x),
        .y = @intCast(y * self.pixel_size),
        .w = @intCast(self.pixel_size),
        .h = @intCast(self.pixel_size),
    };
}
