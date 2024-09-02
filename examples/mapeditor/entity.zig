const std = @import("std");
const sdl = @import("MSDL");
const math = @import("math.zig");
const Vec2 = math.Vec2;
const Map = @import("mapeditor").Map;
const Fire = @import("fire.zig");
const AnimationCreator = @import("AnimationCreator.zig");
const Animation = @import("Animation.zig");

const utils = @import("utils.zig");

const Self = @This();

x: f32 = 100,
y: f32 = 100,

speed: f32 = 5,
velocity: Vec2,

life: bool = true,
health: f32 = 100,
power: f32 = 50,

dir: utils.Direction = .{ .down = false, .right = true },
collision: utils.Collision = .{},

rect: sdl.SDL_FRect = .{ .x = 100, .y = 100, .w = 40, .h = 40 },

checkpoint: ?Checkpoint,
state: State,

alloc: std.mem.Allocator,

player_in_range: bool = false,
scan_range: f32 = 100,

fire_rate: u32 = 5,
fire_timer: u32 = 0,
fires: std.ArrayList(Fire),

//-- helper
const Checkpoint = struct { left: Vec2, right: Vec2 };

const State = struct {
    idle: bool = false,
    run: bool = false,
    punch: bool = false,
    jump: bool = false,
    walk: bool = true,

    animations: std.StringHashMap(*Animation),

    pub fn set_flip(self: *@This(), flip: bool) void {
        var it = self.animations.valueIterator();

        while (it.next()) |anim| {
            anim.*.set_flip(flip);
        }
    }

    pub fn render(self: *@This(), ren: ?*sdl.SDL_Renderer, pl: sdl.SDL_FRect) void {
        const rect = sdl.SDL_FRect{ .x = pl.x - 40, .y = pl.y - 40, .w = pl.w + 80, .h = pl.h + 40 };

        sdl.MSDL_SetRenderDrawColor(ren, 0, 0, 255, 255) catch unreachable;
        _ = sdl.SDL_RenderDrawRectF(ren, &rect);

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
        } else if (self.walk) {
            var an = self.animations.get("walk").?;
            an.render(ren, rect);
        }
    }
};

//-------

pub fn init(posx: f32, posy: f32, size: Vec2, map: ?Map, path: []const u8, ren: ?*sdl.SDL_Renderer, alloc: std.mem.Allocator) !Self {
    const rect = sdl.SDL_FRect{ .x = posx, .y = posy, .w = size.x, .h = size.y };
    const checkpoint = generate_checkpoint(rect, map.?);

    var buf: [128]u8 = undefined;

    const walk_path = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{ path, "Walk.png" });

    var ancw = AnimationCreator.init_from_spritesheet(7, 1, @ptrCast(walk_path), ren);
    const walk = try alloc.create(Animation);
    walk.* = try ancw.get_animation(0, 0, 7, ren);

    var animations = std.StringHashMap(*Animation).init(alloc);
    try animations.put("walk", walk);

    const state = State{ .animations = animations };

    return Self{
        .x = posx,
        .y = posy,
        .rect = rect,
        .velocity = .{ .x = 2, .y = 0 },
        .checkpoint = checkpoint,
        .fires = std.ArrayList(Fire).init(alloc),
        .state = state,
        .alloc = alloc,
    };
}

//-- render
pub fn draw(self: *Self, ren: ?*sdl.SDL_Renderer) !void {
    try sdl.MSDL_SetRenderDrawColor(ren, 0, 0, 255, 255);
    _ = sdl.SDL_RenderFillRectF(ren, &self.rect);

    self.state.render(ren, self.rect);

    for (self.fires.items) |*fire| {
        try fire.draw(ren);
    }

    if (self.player_in_range) {
        try sdl.MSDL_SetRenderDrawColor(ren, 255, 0, 0, 255);
    }

    utils.draw_border_circle(ren, self.rect, self.scan_range, 12);
}

//-- update

pub fn update(self: *Self, fires: ?[]Fire) !void {
    if (!self.player_in_range)
        self.update_pos();

    self.apply_gravity();

    self.update_fire();

    self.check_collision_with_fire(fires);

    self.update_rect();
}

fn update_fire(self: *Self) void {
    var ind: usize = 0;
    while (ind < self.fires.items.len) : (ind += 1) {
        const fire = &self.fires.items[ind];
        try fire.update(null);

        if (!fire.life) _ = self.fires.swapRemove(ind);
    }
}

pub fn scan_player(self: *Self, rect: sdl.SDL_FRect) !void {
    self.player_in_range = false;
    if (math.get_distance(rect, self.rect) < self.scan_range) {
        self.player_in_range = true;
    }

    self.fire_timer += 1;

    if (self.player_in_range and self.fire_timer > 60 / self.fire_rate) {
        self.fire_timer = 0;
        try self.make_fire(rect);
    }
}

//-- fire
fn make_fire(self: *Self, rect: sdl.SDL_FRect) !void {
    var fire = Fire.init(self.x, self.y, .{ .x = 20, .y = 10 }, self.alloc);
    fire.velocity.x = if (self.x > rect.x) -5 else 5;
    fire.power = 10;

    try self.fires.append(fire);
}

fn check_collision_with_fire(self: *Self, fires: ?[]Fire) void {
    if (fires == null) return;

    for (fires.?) |*fire| {
        if (sdl.SDL_HasIntersectionF(&self.rect, &fire.rect) == sdl.SDL_TRUE) {
            fire.life = false;
            self.health -= fire.power;

            if (self.health <= 0) {
                self.life = false;
            }
        }
    }
}

//-- enemy update
fn update_pos(self: *Self) void {
    if (self.checkpoint == null or self.collision.bottom == false) return;

    self.x += self.velocity.x;

    if (self.velocity.x > 0) {
        if (self.x + self.rect.w / 2 > self.checkpoint.?.right.x) {
            self.velocity.x *= -1;
            self.state.set_flip(true);
        }
    } else if (self.velocity.x < 0) {
        if (self.x < self.checkpoint.?.left.x + self.rect.w / 2) {
            self.velocity.x *= -1;
            self.state.set_flip(false);
        }
    }
}

fn update_rect(self: *Self) void {
    self.rect.x = self.x;
    self.rect.y = self.y;
}

fn apply_gravity(self: *Self) void {
    if (self.checkpoint == null) return;

    self.y += self.velocity.y;

    if (self.y + self.rect.h < self.checkpoint.?.left.y) {
        self.velocity.y = self.speed;
    } else {
        self.velocity.y = 0;
        self.collision.bottom = true;
    }
}

//------------

//-- utils
fn generate_checkpoint(rect: sdl.SDL_FRect, map: Map) ?Checkpoint {
    const rect_info = map.frect_info(rect);

    for (rect_info.col..map.cols - 1) |col| {
        const ind = rect_info.row + col * map.rows;

        // std.debug.print("{d}\n", .{ind});

        if (map.data[ind] != 1) continue;

        const brick = map.get_brick(ind);

        // std.debug.print("{any}\n", .{brick});

        if (brick == null) continue;

        var lhs = Vec2{ .x = brick.?.x, .y = brick.?.y };

        var lind: usize = ind - 1;
        while (map.get_brick(lind)) |lbrick| : (lind -= 1) {
            // std.debug.print("{any} : {d}\n", .{ lbrick, lind });
            lhs.x = lbrick.x;
        }

        var rhs = Vec2{ .x = brick.?.x, .y = brick.?.y };

        var rind = ind + 1;
        while (map.get_brick(rind)) |rbrick| : (rind += 1) {
            rhs.x = rbrick.x;
        }

        return Checkpoint{ .left = lhs, .right = rhs };
    }

    return null;
}
