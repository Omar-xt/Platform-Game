const std = @import("std");
const sdl = @import("MSDL");
const Vec2 = @import("math.zig").Vec2;
const utils = @import("utils.zig");
const Animation = @import("Animation.zig");
const AnimationCreator = @import("AnimationCreator.zig");

const Self = @This();

x: f32 = 100,
y: f32 = 100,

speed: f32 = 5,
velocity: Vec2,

life: bool = true,
power: f32 = 50,

anim: ?Animation = null,
anim_rect: sdl.SDL_FRect = .{ .x = 0, .y = 0, .w = 100, .h = 100 },

rect: sdl.SDL_FRect = .{ .x = 100, .y = 100, .w = 40, .h = 40 },

alloc: std.mem.Allocator,

pub fn init(x: f32, y: f32, size: Vec2, alloc: std.mem.Allocator) Self {
    return Self{
        .x = x,
        .y = y,
        .velocity = .{ .x = 5, .y = 0 },
        .rect = sdl.SDL_FRect{ .x = x, .y = y, .w = size.x, .h = size.y },
        .alloc = alloc,
    };
}

// pub fn load_texture(self: *Self, path: []const u8, ren: ?*sdl.SDL_Renderer) !void {
//     var acn = try AnimationCreator.init_from_directory(path, 41, ren);
//     self.anim = try acn.get_animation(1, 1, 41, ren);
// }

//-- render
pub fn draw(self: *Self, ren: ?*sdl.SDL_Renderer) !void {
    try sdl.MSDL_SetRenderDrawColor(ren, 0, 0, 255, 255);
    _ = sdl.SDL_RenderFillRectF(ren, &self.rect);
}

//-- update
pub fn update(self: *Self, ren: ?*sdl.SDL_Renderer) !void {
    self.update_pos();
    self.update_rect();

    if (self.anim) |*anim| {
        anim.render(ren, self.anim_rect);
    }
}

fn update_pos(self: *Self) void {
    self.x += self.velocity.x;
    self.y += self.velocity.y;
}

fn update_rect(self: *Self) void {
    self.rect.x = self.x;
    self.rect.y = self.y;

    self.anim_rect.x = self.x - self.anim_rect.w / 2;
    self.anim_rect.y = self.y - self.anim_rect.h / 2;
}
