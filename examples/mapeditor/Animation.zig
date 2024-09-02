const std = @import("std");
const sdl = @import("MSDL");
const sdlImg = @cImport({
    @cInclude("SDL_image.h");
});
const Anim_type = @import("AnimationCreator.zig").Anim_Type;

const Self = @This();

cx: c_int,
cy: c_int,
count: usize,
sp_width: c_int,
sp_height: c_int,
texture: ?*sdl.SDL_Texture = null,
textures: ?[]?*sdl.SDL_Texture = null,
rect: sdl.SDL_Rect,
center: sdl.SDL_FPoint = .{ .x = 0, .y = 0 },
anim_type: Anim_type = .SpriteSheet,
flip: sdl.SDL_RendererFlip = sdl.SDL_FLIP_NONE,

timer: usize = 0,

pub fn init(cx: c_int, cy: c_int, sp_width: c_int, sp_height: c_int, count: usize, texture: ?*sdl.SDL_Texture) Self {
    const rect = sdl.SDL_Rect{ .x = cx, .y = cy, .w = sp_width, .h = sp_height };

    return Self{
        .cx = cx,
        .cy = cy,
        .sp_width = sp_width,
        .sp_height = sp_height,
        .rect = rect,
        .count = count,
        .texture = texture,
    };
}

pub fn set_flip(self: *Self, flip: bool) void {
    self.flip = if (flip) sdl.SDL_FLIP_HORIZONTAL else sdl.SDL_FLIP_NONE;
}

const mul: usize = 5;

pub fn render(self: *Self, ren: ?*sdl.SDL_Renderer, pl: sdl.SDL_FRect) void {
    switch (self.anim_type) {
        .SpriteSheet => self.render_sp_animation(ren, pl),
        .Sequence => self.render_seq_animation(ren, pl),
    }
}

fn render_sp_animation(self: *Self, ren: ?*sdl.SDL_Renderer, pl: sdl.SDL_FRect) void {
    self.timer += 1;

    if (self.timer % mul == 0) {
        self.rect.x += self.sp_width;
    }

    if (self.timer >= self.count * mul) {
        self.timer = 1;
        self.rect.x = 0;
    }

    _ = sdl.SDL_RenderCopyExF(
        ren,
        self.texture,
        &self.rect,
        &pl,
        0,
        &self.center,
        self.flip,
    );
}

var counter: usize = 0;

fn render_seq_animation(self: *Self, ren: ?*sdl.SDL_Renderer, pl: sdl.SDL_FRect) void {
    self.timer += 1;

    if (self.timer % mul == 0) {
        // self.rect.x += self.sp_width;
        counter += 1;
    }

    if (self.timer >= self.count * mul) {
        self.timer = 1;
        counter = 0;
    }

    _ = sdl.SDL_RenderCopyExF(
        ren,
        self.textures.?[counter],
        &self.rect,
        &pl,
        0,
        &self.center,
        self.flip,
    );
}
