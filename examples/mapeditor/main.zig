const std = @import("std");
const sdl = @import("MSDL");
const m = @import("mapeditor");
const Map = @import("mapeditor").Map;
const Player = @import("player.zig");
const entity = @import("entity.zig");
const Camera = @import("Camera.zig");
const AnimationCreator = @import("AnimationCreator.zig");

var window: ?*sdl.SDL_Window = null;
var renderer: ?*sdl.SDL_Renderer = null;

const pixel_size = 40;
var rows: usize = 3;
var cols: usize = 2;
const SCREEN_WIDTH = 1400;
const SCREEN_HEIGHT = 800;

pub fn main() !void {
    sdl.init(&window, &renderer, SCREEN_WIDTH, SCREEN_HEIGHT);
    defer sdl.deinit(&window, &renderer);

    const alloc = std.heap.page_allocator;

    var editor = try m.editor.init(rows, cols, alloc);
    defer editor.deinit();
    defer editor.save() catch unreachable;

    const player_path = "assets/sprite-sheet.png";
    const flame_path = "assets/flame/flame10/PNG/";

    var player = try Player.init(.{ .x = 100, .y = 100 }, .{ .x = 40, .y = 80 }, alloc, player_path, renderer);
    player.set_window(SCREEN_HEIGHT, SCREEN_HEIGHT);
    try player.load_fire(flame_path);

    const enemy_path = "assets/Onre/";
    var enemys = std.ArrayList(entity).init(alloc);

    // const flame_path = "assets/flame/flame10/PNG/";
    // var acn = try AnimationCreator.init_from_folder(flame_path, 41, renderer, alloc);
    // var flame_anim = try acn.get_animation(1, 1, 41, renderer);

    for (editor.map.data, 0..) |val, ind| {
        if (val != @intFromEnum(m.editor.Mode.DrawEnemy)) continue;

        const rect = editor.map.get_brick_ex(ind);
        const enemy = try entity.init(rect.x, rect.y, .{ .x = 40, .y = 80 }, editor.map, enemy_path, renderer, alloc);
        try enemys.append(enemy);
    }

    // Todo: y does not work
    var camera = Camera.init(&player, .{ .x = 600, .y = 0 }, enemys.items, &editor);

    const keep_open = true;
    main_loop: while (keep_open) {
        try sdl.MSDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
        try sdl.MSDL_RenderClear(renderer);

        var e: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&e) > 0) {
            //-- event
            try editor.run_event_loop(e);
            try player.run_event_loop(e);
            //---
            switch (e.type) {
                sdl.SDL_QUIT => break :main_loop,
                sdl.SDL_KEYDOWN => {
                    if (e.key.keysym.scancode == sdl.SDL_SCANCODE_ESCAPE) {
                        break :main_loop;
                    }
                },
                else => {},
            }
        }
        try editor.draw_map(renderer);
        editor.draw_grid(renderer);

        try player.draw(renderer);
        try player.update(&editor);

        player.detect_collision(enemys.items);

        var ind: usize = 0;
        while (ind < enemys.items.len) : (ind += 1) {
            const enemy = &enemys.items[ind];
            try enemy.update(player.fires.items);
            try enemy.scan_player(player.frect);
            try enemy.draw(renderer);

            if (!enemy.life) {
                _ = enemys.swapRemove(ind);
            }
        }

        camera.update();

        if (!player.life) break;

        // const center = sdl.SDL_Point{ .x = 20, .y = 20 };
        // const rect = sdl.SDL_Rect{
        //     .x = @intFromFloat(player.frect.x),
        //     .y = @intFromFloat(player.frect.y),
        //     .w = @intFromFloat(player.frect.w),
        //     .h = @intFromFloat(player.frect.h),
        // };

        // _ = sdl.SDL_RenderCopy(renderer, hero_run.texture, null, null);

        sdl.SDL_RenderPresent(renderer);

        std.time.sleep(@divFloor(1e9, 60));
    }
}

test "hi" {
    const alloc = std.testing.allocator;

    var editor = try m.editor.init(rows, cols, alloc);
    defer editor.deinit();

    const brick = editor.map.test_get_brick(20);

    std.debug.print("gg {any}\n", .{brick});

    const flame_path = "assets/flame/flame10/PNG/";
    try AnimationCreator.init_from_folder2(flame_path, 41, renderer, alloc);
    // var flame_anim = try acn.get_animation(1, 1, 41, renderer);
}
