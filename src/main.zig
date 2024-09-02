const std = @import("std");
const ttf = @cImport(@cInclude("SDL_ttf.h"));
const sdl = @cImport(@cInclude("SDL.h"));
const msdl = @import("msdl");

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;

var window: ?*sdl.SDL_Window = null;
var renderer: ?*sdl.SDL_Renderer = null;

fn event_loop(keep_running: *bool) void {
    var e: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&e) > 0) {
        switch (e.type) {
            sdl.SDL_QUIT => keep_running.* = false,
            sdl.SDL_KEYDOWN => {
                if (e.key.keysym.scancode == sdl.SDL_SCANCODE_ESCAPE) {
                    keep_running.* = false;
                }
            },

            else => {},
        }
    }
}

pub fn main() !void {
    msdl.init(&window, &renderer);
    defer msdl.deinit(&window, &renderer);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const path = "open-sans/OpenSans-Regular.ttf";
    const font = ttf.TTF_OpenFont(path, 54);

    const cc = sdl.struct_SDL_Color{ .r = 0, .g = 255, .b = 0, .a = 255 };

    const d: sdl.struct_SDL_Color = @bitCast(cc);
    std.debug.print("rgb {}\n", .{d});

    const text = "put your text here";
    const surface = ttf.TTF_RenderText_Blended(font, text, @bitCast(d));

    var text_texture = sdl.SDL_CreateTextureFromSurface(renderer, @ptrCast(surface));

    var w: c_int = 0;
    var h: c_int = 0;
    const size = ttf.TTF_FontHeight(font);
    const ca = ttf.TTF_MeasureText(font, text, 100, &w, &h);

    _ = size;
    _ = ca;
    std.debug.print("cc {}\n", .{h});

    const text_rect = sdl.SDL_Rect{ .x = 0, .y = 0, .w = 400, .h = 74 };

    try msdl.SDL_SetRenderDrawColor(renderer, 0, 0, 255, 255);
    try msdl.SDL_RenderCopy(renderer, text_texture, null, null);

    sdl.SDL_RenderPresent(renderer);

    var text_arr: [100]u8 = undefined;
    // var buf: []u8 = undefined;
    var t_len: usize = 0;

    var keep_open = true;
    while (keep_open) {
        try msdl.SDL_RenderClear(renderer);

        var e: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&e) > 0) {
            switch (e.type) {
                sdl.SDL_QUIT => keep_open = false,
                sdl.SDL_KEYDOWN => {
                    if (e.key.keysym.scancode == sdl.SDL_SCANCODE_ESCAPE) {
                        keep_open = false;
                    }
                },
                sdl.SDL_TEXTINPUT => {
                    const s = e.text.text[0];
                    const ss = [1]u8{s};
                    std.debug.print("Text Input: {s}, {d}\n", .{ ss, s });
                    text_arr[t_len] = s;
                    t_len += 1;
                    std.debug.print("Text arr: {s}\n", .{text_arr[0..t_len]});

                    const buf = try allocator.alloc(u8, t_len + 1);
                    std.mem.copyForwards(u8, buf, text_arr[0..t_len]);
                    buf[t_len] = 0;
                    // const bb: [*c]u8 = @constCast("hi");

                    // (bb + 1) = "!";

                    // pr.print(bb);
                    // var bu: [1]u8 = undefined;

                    // const b = try std.fmt.bufPrint(&bu, "{s}", .{text_arr[0..t_len]});

                    // std.debug.print("Text buf: {s}\n", .{b});

                    const bbb: [*c]u8 = @ptrCast(text_arr[0 .. t_len + 1]);
                    bbb[t_len] = 0;

                    const surf = ttf.TTF_RenderText_Solid(font, bbb, @bitCast(d));
                    text_texture = sdl.SDL_CreateTextureFromSurface(renderer, @ptrCast(surf));

                    try msdl.SDL_RenderCopy(renderer, text_texture, &text_rect, &text_rect);
                },
                else => {},
            }
        }

        try msdl.SDL_RenderCopy(renderer, text_texture, &text_rect, &text_rect);

        sdl.SDL_RenderPresent(renderer);
    }
}

const jj = struct {
    name: []const u8,
    arr: []const u8,
};

// test "json" {
//     const alloc = std.testing.allocator;

//     // var file = try std.fs.cwd().createFile("map.json", .{ .read = true });
//     var file = try std.fs.cwd().createFile("map.json", .{ .read = true });
//     defer file.close();

//     const j = jj{ .name = "hmmm", .arr = &[_]u8{ 1, 2, 3, 4, 5 } };

//     try std.json.stringify(j, .{}, file.writer());

//     file.close();
//     file = try std.fs.cwd().openFile("map.json", .{});

//     var bug: [128]u8 = undefined;
//     const len = try file.readAll(&bug);

//     // std.debug.print("{any}\n", .{bug[0..len]});
//     std.log.warn("len {d}\n", .{len});

//     const par = try std.json.parseFromSlice(jj, alloc, bug[0..len], .{});
//     defer par.deinit();

//     std.debug.print("{s}\n", .{par.value.name});
// }

test "jj" {
    const alloc = std.testing.allocator;

    var file = try std.fs.cwd().createFile("map2.json", .{ .read = true });
    defer file.close();

    const arr = [_]u8{ 1, 2, 3, 4, 5 };

    try std.json.stringify(arr, .{}, file.writer());

    file.close();
    file = try std.fs.cwd().openFile("map2.json", .{});

    const buf = try file.readToEndAlloc(alloc, 512);
    defer alloc.free(buf);

    std.debug.print("buf {any}\n", .{buf});

    const par = try std.json.parseFromSlice([]const u8, alloc, buf, .{});
    defer par.deinit();

    std.debug.print("{any}\n", .{par});
}
