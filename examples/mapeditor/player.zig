const std = @import("std");
const sdl = @import("MSDL");
const Editor = @import("mapeditor").editor;
const Map = @import("mapeditor").Map;
const entity = @import("entity.zig");
const Fire = @import("fire.zig");
const utils = @import("utils.zig");
const AnimationCreator = @import("AnimationCreator.zig");
const Animation = @import("Animation.zig");
const Vec2 = @import("math.zig").Vec2;

const Self = @This();

x: f32 = 100,
y: f32 = 100,
size: c_int = 40,

speed: f32 = 5,
velocity: Vec2,

health: f32 = 100,
life: bool = true,

dir: utils.Direction = .{ .down = true },
collision: utils.Collision = .{},

frect: sdl.SDL_FRect = .{ .x = 100, .y = 100, .w = 40, .h = 40 },

fires: std.ArrayList(Fire),
fire_anim: ?Animation = null,

state: State,

alloc: std.mem.Allocator,

const gravity: c_int = 1;

const brick_size = 40;

var renderer: ?*sdl.SDL_Renderer = null;

var SCREEN_WIDTH: usize = 0;
var SCREEN_HEIGHT: usize = 0;

//-- helper

const State = struct {
    idle: bool = true,
    run: bool = false,
    punch: bool = false,
    jump: bool = false,

    animations: std.StringHashMap(*Animation),

    pub fn set_flip(self: *@This(), flip: bool) void {
        var it = self.animations.valueIterator();

        while (it.next()) |anim| {
            anim.*.set_flip(flip);
        }
    }

    pub fn render(self: *@This(), ren: ?*sdl.SDL_Renderer, pl: sdl.SDL_FRect) void {
        const rect = sdl.SDL_FRect{ .x = pl.x - 10, .y = pl.y, .w = pl.w + 20, .h = pl.h };

        if (self.idle) {
            var an = self.animations.get("idle").?;
            an.render(ren, rect);
        } else if (self.run) {
            var an = self.animations.get("run").?;
            an.render(ren, rect);
        } else if (self.punch) {
            var an = self.animations.get("punch").?;
            an.render(ren, rect);
        } else if (self.jump) {
            var an = self.animations.get("jump").?;
            an.render(ren, rect);
        }
    }
};

//--

pub fn init(pos: Vec2, size: Vec2, alloc: std.mem.Allocator, path: [*c]const u8, ren: ?*sdl.SDL_Renderer) !Self {
    var anc = AnimationCreator.init_from_spritesheet(8, 4, path, ren);

    const hero_run = try alloc.create(Animation);
    hero_run.* = try anc.get_animation(0, 3, 8, ren);

    const hero_punch = try alloc.create(Animation);
    hero_punch.* = try anc.get_animation(2, 0, 4, ren);

    const hero_idle = try alloc.create(Animation);
    hero_idle.* = try anc.get_animation(0, 0, 1, ren);

    const hero_jump = try alloc.create(Animation);
    hero_jump.* = try anc.get_animation(6, 0, 1, ren);

    var animations = std.StringHashMap(*Animation).init(alloc);
    try animations.put("idle", hero_idle);
    try animations.put("run", hero_run);
    try animations.put("punch", hero_punch);
    try animations.put("jump", hero_jump);

    const state = State{ .animations = animations };
    const rect = sdl.SDL_FRect{ .x = pos.x, .y = pos.y, .w = size.x, .h = size.y };

    renderer = ren;
    return Self{
        .velocity = .{ .x = 0, .y = 2 },
        .fires = std.ArrayList(Fire).init(alloc),
        .alloc = alloc,
        .state = state,
        .frect = rect,
    };
}

pub fn load_fire(self: *Self, path: []const u8) !void {
    var acn = try AnimationCreator.init_from_directory(path, 41, renderer);
    self.fire_anim = try acn.get_animation(10, 0, 20, renderer);
}

pub fn set_window(self: *Self, width: usize, height: usize) void {
    _ = self;
    SCREEN_WIDTH = width;
    SCREEN_HEIGHT = height;
}

//-- render
pub fn draw(self: *Self, ren: ?*sdl.SDL_Renderer) !void {
    try sdl.MSDL_SetRenderDrawColor(ren, 0, 0, 255, 255);
    _ = sdl.SDL_RenderFillRectF(ren, &self.frect);

    // self.state.run = true;
    self.state.render(ren, self.frect);

    for (self.fires.items) |*fire| {
        try fire.draw(ren);
    }
}
//------

//-- event loop
pub fn run_event_loop(self: *Self, e: sdl.SDL_Event) !void {
    switch (e.type) {
        sdl.SDL_KEYDOWN => {
            if (e.key.keysym.scancode == sdl.SDL_SCANCODE_LEFT) {
                self.dir.left = true;
                self.velocity.x = -self.speed;

                self.state.idle = false;
                if (!self.state.jump) {
                    self.state.set_flip(true);
                    self.state.run = true;
                } else {
                    self.state.set_flip(true);
                }
            } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_RIGHT) {
                self.dir.right = true;
                self.velocity.x = self.speed;

                self.state.idle = false;
                if (!self.state.jump) {
                    self.state.set_flip(false);
                    self.state.run = true;
                } else {
                    self.state.set_flip(false);
                }
            } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_UP) {
                self.dir.up = true;
                self.dir.down = false;
                self.velocity.y = -15;
                self.collision.bottom = false;

                self.state.run = false;
                self.state.idle = false;
                self.state.jump = true;
            } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_SPACE) {
                try self.make_fire();
                self.state.idle = false;
                self.state.punch = true;
            }
        },
        sdl.SDL_KEYUP => {
            if (e.key.keysym.scancode == sdl.SDL_SCANCODE_LEFT) {
                self.dir.left = false;
                self.velocity.x = 0;
                self.state.run = false;
                self.state.idle = true;
            } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_RIGHT) {
                self.dir.right = false;
                self.velocity.x = 0;
                self.state.run = false;
                self.state.idle = true;
            } else if (e.key.keysym.scancode == sdl.SDL_SCANCODE_UP) {
                self.dir.up = false;
                self.dir.down = true;
            }
        },
        else => {},
    }
}
//-----

//-- update logic
pub fn update(self: *Self, editor: *Editor) !void {
    self.detect_collide(editor.map);

    self.update_animation_state();

    self.update_pos();
    self.update_rect();

    self.update_fire();
}

fn update_animation_state(self: *Self) void {
    if (self.collision.bottom) {
        self.state.jump = false;

        if (self.state.punch) return;

        if (self.dir.left or self.dir.right) {
            self.state.run = true;
        } else self.state.idle = true;
    }
}

fn update_fire(self: *Self) void {
    var ind: usize = 0;
    while (ind < self.fires.items.len) : (ind += 1) {
        var fire = &self.fires.items[ind];
        if (fire.life) {
            try fire.update(renderer);
        } else {
            _ = self.fires.swapRemove(ind);
        }
    }
}

fn update_rect(self: *Self) void {
    self.frect.x = self.x;
    self.frect.y = self.y;
}

fn update_pos(self: *Self) void {
    self.x += self.velocity.x;
    self.y += self.velocity.y;

    if (self.velocity.y < 5) self.velocity.y += gravity;
}

fn detect_collide(self: *Self, map: Map) void {
    self.collision.reset();

    for (0..map.data.len) |ind| {
        const brick = map.get_brick(ind);

        //-- checking one step future
        const px = self.x + self.velocity.x;

        var a = sdl.SDL_FRect{ .x = px, .y = self.y, .w = self.frect.w, .h = self.frect.h };

        if (brick != null and self.horizontal_collision(a, brick.?)) {
            utils.draw_connect_line(renderer, self.frect, brick.?);
        }

        //-- reseting x according to horizontal collision and checking one step future for y
        a.x = self.x;
        a.y = self.y + self.velocity.y;

        if (brick != null and self.vertical_collision(a, brick.?)) {
            utils.draw_connect_line(renderer, self.frect, brick.?);
            return;
        }
    }
}

fn horizontal_collision(self: *Self, a: sdl.SDL_FRect, b: sdl.SDL_FRect) bool {
    var collision = false;

    if (a.y + a.h > b.y and a.x + a.w >= b.x and a.x <= b.x + b.w and a.y < b.y + b.h) collision = true;

    if (!collision) return false;

    if (self.velocity.x > 0) {
        self.velocity.x = 0;
        self.x = b.x - b.w;
    }

    if (self.velocity.x < 0) {
        self.velocity.x = 0;
        self.x = b.x + b.w;
    }

    return collision;
}

fn vertical_collision(self: *Self, a: sdl.SDL_FRect, b: sdl.SDL_FRect) bool {
    var collision = false;

    if (a.y + a.h >= b.y and a.x + a.w > b.x and a.x < b.x + b.w and a.y <= b.y + b.h) collision = true;

    if (!collision) return false;

    if (self.velocity.y > 0) {
        self.velocity.y = 0;
        self.y = b.y - a.h;
        self.collision.bottom = true;
    }

    if (self.velocity.y < 0) {
        self.velocity.y = 0;
        self.y = b.y + b.h;
    }

    return collision;
}

//-- fire component

fn make_fire(self: *Self) !void {
    var fire = Fire.init(self.x, self.y, .{ .x = 20, .y = 10 }, self.alloc);
    fire.anim = self.fire_anim;
    try self.fires.append(fire);
}

//-- collision with enemy
pub fn detect_collision(self: *Self, enemys: []entity) void {
    for (enemys) |enemy| {
        for (enemy.fires.items) |*fire| {
            if (sdl.SDL_HasIntersectionF(&self.frect, &fire.rect) == sdl.SDL_TRUE) {
                self.health -= fire.power;

                fire.life = false;

                if (self.health <= 0) self.life = false;
            }
        }
    }
}
