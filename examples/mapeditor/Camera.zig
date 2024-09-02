const std = @import("std");
const sdl = @import("MSDL");
const Player = @import("player.zig");
const entity = @import("entity.zig");
const Editor = @import("mapeditor").editor;
const Vec2 = @import("math.zig").Vec2;

const Self = @This();

player: *Player,
anchor: Vec2,
enemys: []entity,
editor: *Editor,

pub fn init(player: *Player, anchor: Vec2, enemys: []entity, editor: *Editor) Self {
    return Self{
        .player = player,
        .anchor = anchor,
        .enemys = enemys,
        .editor = editor,
    };
}

pub fn update(self: *Self) void {
    if (self.player.x > 600 and self.player.velocity.x > 0) {
        self.editor.offx -= @intFromFloat(self.player.speed);
        self.editor.map.offx = self.editor.offx;
        self.player.x -= self.player.velocity.x;

        for (self.enemys) |*enemy| {
            enemy.x -= self.player.velocity.x;

            if (enemy.checkpoint) |*cp| {
                cp.left.x -= self.player.velocity.x;
                cp.right.x -= self.player.velocity.x;
            }
        }
    } else if (self.player.x < 600 and self.player.velocity.x < 0) {
        self.editor.offx += @intFromFloat(self.player.speed);
        self.editor.map.offx = self.editor.offx;
        self.player.x -= self.player.velocity.x;

        for (self.enemys) |*enemy| {
            enemy.x -= self.player.velocity.x;

            if (enemy.checkpoint) |*cp| {
                cp.left.x -= self.player.velocity.x;
                cp.right.x -= self.player.velocity.x;
            }
        }
    }
}
