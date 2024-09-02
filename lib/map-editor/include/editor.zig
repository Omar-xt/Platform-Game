const std = @import("std");
const sdl = @import("MSDL");
const Map = @import("Map.zig");

offx: i32 = 0,
rows: usize,
cols: usize,
pixel_size: usize = 40,
map: Map,
alloc: std.mem.Allocator,

grid: std.ArrayList(sdl.SDL_Point),

pub const Self = @This();

const MapData = struct {
    rows: usize,
    cols: usize,
};

fn get_map_data(alloc: std.mem.Allocator) !?MapData {
    const mfile = std.fs.cwd().openFile("map.json", .{}) catch |err| {
        if (err == error.FileNotFound) return null;
        return err;
    };

    defer mfile.close();

    const len = try mfile.getEndPos();
    const buf = try alloc.alloc(u8, len);
    defer alloc.free(buf);
    _ = try mfile.readAll(buf);

    const map = try std.json.parseFromSlice(Map, alloc, buf, .{});
    defer map.deinit();

    return MapData{ .rows = map.value.rows, .cols = map.value.cols };
}

pub fn init(rows: usize, cols: usize, alloc: std.mem.Allocator) !Self {
    var map_data = try get_map_data(alloc);

    if (map_data == null) {
        map_data = MapData{ .rows = rows, .cols = cols };
    }

    const map = try Map.init("open-wg", map_data.?.rows, map_data.?.cols, 40, alloc);

    var grid = std.ArrayList(sdl.SDL_Point).init(alloc);

    try store_points(&grid, rows, cols, 40);

    return Self{
        .rows = map_data.?.rows,
        .cols = map_data.?.cols,
        .map = map,
        .alloc = alloc,
        .grid = grid,
    };
}

pub fn deinit(self: Self) void {
    self.map.deinit();
}

//-- load

pub fn save(self: Self) !void {
    var file = try std.fs.cwd().createFile("map.json", .{});
    defer file.close();

    try std.json.stringify(self.map, .{}, file.writer());
}
//-----

//-- event handel
pub const Mode = enum {
    Erase,
    Draw,
    DrawEnemy,
    View,
};

var mode = Mode.Draw;

pub fn run_event_loop(self: *Self, e: sdl.SDL_Event) !void {
    switch (e.type) {
        sdl.SDL_KEYDOWN => {
            if (e.key.keysym.scancode == sdl.SDL_SCANCODE_D) {
                mode = Mode.Draw;
            } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_V) {
                mode = Mode.View;
            } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_E) {
                mode = Mode.DrawEnemy;
            } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_R) {
                mode = Mode.Erase;
            } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_L) {
                self.offx -= 5;
                self.map.offx -= 5;
            } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_K) {
                self.offx += 5;
                self.map.offx += 5;
            } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_M) {
                try self.add_rows();
            } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_N) {
                try self.remove_rows();
            }
        },
        sdl.SDL_MOUSEBUTTONDOWN, sdl.SDL_MOUSEMOTION => {
            if (e.button.button != sdl.SDL_BUTTON_LEFT) return;

            const m = sdl.MSDL_GetMouseState();
            // std.debug.print("{any}\n", .{m});

            const row = @divFloor((m.x - self.offx), @as(c_int, @intCast(self.pixel_size)));
            const col = @divFloor(m.y, @as(c_int, @intCast(self.pixel_size)));

            if (row < 0 or row >= self.rows) return;
            if (col < 0 or col >= self.cols) return;

            // std.debug.print("{d} : {d}\n", .{ row, col });

            const ind = @as(usize, @intCast(row)) + @as(usize, @intCast(col)) * self.rows;

            self.map.data[ind] = @intFromEnum(mode);
        },
        else => {},
    }
}

fn add_rows(self: *Self) !void {
    var new_map = try self.alloc.alloc(u8, self.map.data.len + self.cols);
    @memset(new_map, 0);

    var ind2: usize = 0;
    var ind: usize = 0;
    while (ind < self.map.data.len) : ({
        ind += 1;
        ind2 += 1;
    }) {
        if (ind != 0 and ind % self.rows == 0) {
            ind2 += 1;
            new_map[ind2] = self.map.data[ind];
            continue;
        }
        new_map[ind2] = self.map.data[ind];
    }

    self.alloc.free(self.map.data);
    self.map.data = new_map;

    self.rows += 1;
    self.map.rows = self.rows;
}

fn remove_rows(self: *Self) !void {
    var new_map = try self.alloc.alloc(u8, self.map.data.len - self.cols);
    @memset(new_map, 0);

    var ind2: usize = 0;
    var ind: usize = 0;
    while (ind <= self.map.data.len - self.cols) : ({
        ind += 1;
        ind2 += 1;
    }) {
        if (ind != 0 and (ind2 + 1) % (self.rows) == 0) {
            ind += 1;
            new_map[ind2] = self.map.data[ind];
            continue;
        }
        new_map[ind2] = self.map.data[ind];
    }

    self.alloc.free(self.map.data);
    self.map.data = new_map;

    self.rows -= 1;
    self.map.rows = self.rows;
}

//-----

//-- render

pub fn draw_map(self: Self, renderer: ?*sdl.SDL_Renderer) !void {
    for (0..self.cols) |y| {
        for (0..self.rows) |x| {
            const ind = x + y * self.rows;

            if (self.map.data[ind] == 0) continue;

            if (mode == .View and self.map.data[ind] == @intFromEnum(Mode.DrawEnemy)) continue;

            var rect = sdl.SDL_Rect{
                .x = @intCast(x * self.pixel_size),
                .y = @intCast(y * self.pixel_size),
                .w = @intCast(self.pixel_size),
                .h = @intCast(self.pixel_size),
            };

            rect.x += self.offx;

            switch (@as(Mode, @enumFromInt(self.map.data[ind]))) {
                .DrawEnemy => try sdl.MSDL_SetRenderDrawColor(renderer, 255, 0, 0, 255),
                else => try sdl.MSDL_SetRenderDrawColor(renderer, 0, 255, 0, 255),
            }
            _ = sdl.SDL_RenderFillRect(renderer, &rect);
        }
    }
}

pub fn draw_grid(self: *Self, ren: ?*sdl.SDL_Renderer) void {
    _ = sdl.SDL_SetRenderDrawColor(ren, 120, 120, 120, 255);

    for (1..self.rows) |x| {
        var px: c_int = @intCast(x * self.pixel_size);
        px += self.offx;
        _ = sdl.SDL_RenderDrawLine(ren, px, 0, px, @intCast(self.cols * self.pixel_size));
    }

    for (1..self.cols) |y| {
        const py: c_int = @intCast(y * self.pixel_size);
        var x2: c_int = @intCast(self.rows * self.pixel_size);
        x2 += self.offx;
        _ = sdl.SDL_RenderDrawLine(ren, self.offx, py, x2, py);
    }
}

pub fn store_points(points: *std.ArrayList(sdl.SDL_Point), rows: usize, cols: usize, pixel_size: usize) !void {
    for (1..rows) |x| {
        const px: c_int = @intCast(x * pixel_size);
        try points.append(sdl.SDL_Point{ .x = px, .y = 0 });
        try points.append(sdl.SDL_Point{ .x = px, .y = @intCast(cols * pixel_size) });
    }

    // for (1..cols) |y| {
    //     const py: c_int = @intCast(y * pixel_size);
    // }
}
