const std = @import("std");
const sdl = @import("MSDL");

pub const Vec2 = struct {
    x: f32 = 0,
    y: f32 = 0,
};

pub fn get_distance(a: sdl.SDL_FRect, b: sdl.SDL_FRect) f32 {
    const x1 = (a.x + a.w / 2);
    const y1 = (a.y + a.h / 2);
    const x2 = (b.x + b.w / 2);
    const y2 = (b.y + b.h / 2);

    const d1 = std.math.pow(f32, x2 - x1, 2);
    const d2 = std.math.pow(f32, y2 - y1, 2);

    return std.math.sqrt(d1 + d2);
}
