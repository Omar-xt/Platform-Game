const std = @import("std");
const sdl = @import("MSDL");

pub const Direction = struct {
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = true,

    pub fn reset(self: @This()) void {
        self.left = false;
        self.right = false;
        self.up = false;
        self.down = true;
    }
};

pub const Collision = struct {
    left: bool = false,
    right: bool = false,
    top: bool = false,
    bottom: bool = false,

    pub fn reset(self: *@This()) void {
        self.left = false;
        self.right = false;
        self.top = false;
        self.bottom = false;
    }
};

pub fn get_carno(rect: sdl.SDL_Rect) c_int {
    const h = std.math.pow(c_int, @divExact(rect.h, 2), 2);
    const bc = std.math.pow(c_int, @divExact(rect.w, 2), 2);
    const ac = std.math.sqrt(@abs(h + bc));

    return ac;
}

pub fn draw_connect_line(ren: ?*sdl.SDL_Renderer, a: sdl.SDL_FRect, b: sdl.SDL_FRect) void {
    const x1: c_int = @intFromFloat(a.x + a.w / 2);
    const y1: c_int = @intFromFloat(a.y + a.h / 2);
    const x2: c_int = @intFromFloat(b.x + b.w / 2);
    const y2: c_int = @intFromFloat(b.y + b.h / 2);
    sdl.MSDL_SetRenderDrawColor(ren, 255, 0, 0, 0) catch unreachable;
    _ = sdl.SDL_RenderDrawLine(ren, x1, y1, x2, y2);
}

pub fn draw_border_circle(ren: ?*sdl.SDL_Renderer, rect: sdl.SDL_FRect, radius: f32, count: usize) void {
    var deg: usize = 0;
    const frac = 360 / count;
    var i: usize = 0;

    var points: [361]sdl.SDL_FPoint = undefined;

    while (deg <= 360) : (deg += frac) {
        const rad = std.math.degreesToRadians(@as(f32, @floatFromInt(deg)));
        const x = @cos(rad) * radius + rect.x + rect.w / 2;
        const y = @sin(rad) * radius + rect.y + rect.h / 2;

        points[i] = sdl.SDL_FPoint{ .x = x, .y = y };

        i += 1;
    }

    _ = sdl.SDL_RenderDrawLinesF(ren, &points, @intCast(count + 1));
}

fn get_angular_pos(rect: std.SDL_FRect, radius: f32, deg: usize) sdl.SDL_FPoint {
    const rad = std.math.degreesToRadians(@as(f32, @floatFromInt(deg)));
    const x = @cos(rad) * radius + rect.x + rect.w / 2;
    const y = @sin(rad) * radius + rect.y + rect.h / 2;
    return .{ .x = x, .y = y };
}
