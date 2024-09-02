const std = @import("std");
const sdl = @import("MSDL");
const sdlImg = @cImport({
    @cInclude("SDL_image.h");
});
const Animation = @import("Animation.zig");

const Self = @This();

row: c_int,
col: c_int,
sp_width: c_int,
sp_height: c_int,
texture: ?*sdl.SDL_Texture = null,
surf: ?[*c]sdl.SDL_Surface = null,
anim_type: Anim_Type = .SpriteSheet,
textures: ?std.ArrayList(?*sdl.SDL_Texture) = null,

//-- helper
pub const Anim_Type = enum {
    SpriteSheet,
    Sequence,
};

//--

pub fn init_from_spritesheet(row: c_int, col: c_int, path: [*c]const u8, ren: ?*sdl.SDL_Renderer) Self {
    const surf = sdlImg.IMG_Load(path);

    return Self{
        .row = row,
        .col = col,
        .surf = @ptrCast(surf),
        .sp_width = @divExact(surf.*.w, row),
        .sp_height = @divExact(surf.*.h, col),
        .texture = sdl.SDL_CreateTextureFromSurface(ren, @ptrCast(surf)),
    };
}

pub fn init_from_folder(path: []const u8, count: c_int, ren: ?*sdl.SDL_Renderer, alloc: std.mem.Allocator) !Self {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    var it = dir.iterate();

    var textures = std.ArrayList(?*sdl.SDL_Texture).init(alloc);

    // var sp_width: c_int = 0;
    // var sp_height: c_int = 0;

    var buf: [128]u8 = undefined;

    while (try it.next()) |entry| {
        const img_path = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{ path, entry.name });
        const surf = sdlImg.IMG_Load(img_path);

        // sp_width = surf.*.w;
        // sp_height = surf.*.h;

        const texture = sdl.SDL_CreateTextureFromSurface(ren, @ptrCast(surf));

        try textures.append(texture);
    }

    return Self{
        .anim_type = .Sequence,
        .row = count,
        .col = 1,
        .sp_width = 1666,
        .sp_height = 1070,
        .textures = textures,
    };
}

pub fn init_from_directory(path: []const u8, count: c_int, ren: ?*sdl.SDL_Renderer) !Self {
    const surface = sdl.SDL_CreateRGBSurface(0, 128 * count, 128, 32, 0, 0, 0, 0);
    const texture = sdl.SDL_CreateTexture(
        ren,
        sdl.SDL_PIXELFORMAT_RGBA8888,
        sdl.SDL_TEXTUREACCESS_TARGET,
        128 * count,
        128,
    );
    _ = sdl.SDL_SetTextureBlendMode(texture, sdl.SDL_BLENDMODE_BLEND);
    _ = sdl.SDL_SetRenderTarget(ren, texture);

    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    var it = dir.iterate();

    var ind: usize = 0;
    var buf: [128]u8 = undefined;
    var rect = sdl.SDL_Rect{ .x = 0, .y = 0, .w = 128, .h = 128 };

    while (try it.next()) |entry| : (ind += 1) {
        const img_path = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{ path, entry.name });
        const surf = sdlImg.IMG_Load(img_path);

        rect.x += 128;

        const tex = sdl.SDL_CreateTextureFromSurface(ren, @ptrCast(surf));
        _ = sdl.SDL_RenderCopy(ren, tex, null, &rect);
    }

    _ = sdl.SDL_SetRenderTarget(ren, null);

    return Self{
        .row = count,
        .col = 1,
        .sp_width = 128,
        .sp_height = 128,
        .texture = texture,
        .surf = surface,
    };
}

pub fn init_from_folder2(path: []const u8, count: c_int, ren: ?*sdl.SDL_Renderer, alloc: std.mem.Allocator) !Self {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    var it = dir.iterate();

    var textures = std.ArrayList(?*sdl.SDL_Texture).init(alloc);
    var paths = std.ArrayList([]u8).init(alloc);
    defer {
        paths.deinit();
    }

    while (try it.next()) |entry| {
        const img_path = try std.fmt.allocPrint(alloc, "{s}{s}", .{ path, entry.name });
        try paths.append(img_path);
    }

    var thread_pool = std.ArrayList(std.Thread).init(alloc);
    defer thread_pool.deinit();

    // const c_count = paths.items.len / 10;

    // for (0..10) |i| {
    //     const a = c_count * i;
    //     const chunk = paths.items[a .. a + c_count];
    //     const t = try std.Thread.spawn(.{}, gg, .{ chunk, &textures, ren });
    //     try thread_pool.append(t);
    // }

    // for (0..1) |_| {
    //     const chunk = paths.items[0..10];
    //     const t = try std.Thread.spawn(.{}, gg, .{ chunk, &textures, ren });
    //     // try thread_pool.append(t);
    //     t.join();
    // }

    // for (thread_pool.items) |thread| {
    //     thread.join();
    // }

    //--

    std.debug.print("ren {any}\n", .{ren});

    const paths2 = paths.items[0..10];
    // const tt = try std.Thread.spawn(.{}, gg, .{ paths2, &textures, ren });
    // tt.join();

    var buf: [128]u8 = undefined;

    for (paths2) |pp| {
        const p = try std.fmt.bufPrintZ(&buf, "{s}", .{pp});
        // std.debug.print("{s}\n", .{p});
        const surf = sdlImg.IMG_Load(p);
        // std.debug.print("{any}\n", .{surf});
        const texture = sdl.SDL_CreateTextureFromSurface(ren, @ptrCast(surf));
        // std.debug.print("{any}\n", .{texture});

        try textures.append(texture);
    }

    //--

    // for (textures.items) |t| {
    //     std.debug.print("{any}\n", .{t});
    // }

    return Self{
        .anim_type = .Sequence,
        .row = count,
        .col = 1,
        .sp_width = 1666,
        .sp_height = 1070,
        .textures = textures,
    };
}

fn gg(paths: [][]const u8, textures: *std.ArrayList(?*sdl.SDL_Texture), ren: ?*sdl.SDL_Renderer) !void {
    var buf: [128]u8 = undefined;

    std.debug.print("ren {any}\n", .{ren});

    for (paths) |path| {
        const p = try std.fmt.bufPrintZ(&buf, "{s}", .{path});
        // std.debug.print("{s}\n", .{p});
        const surf = sdlImg.IMG_Load(p);
        // std.debug.print("{any}\n", .{surf});
        const texture = sdl.SDL_CreateTextureFromSurface(ren, @ptrCast(surf));
        // std.debug.print("{any}\n", .{texture});

        try textures.append(texture);
    }
}

pub fn get_animation(self: *Self, row: c_int, col: c_int, count: c_int, ren: ?*sdl.SDL_Renderer) !Animation {
    return switch (self.anim_type) {
        .SpriteSheet => self.get_sp_animation(row, col, count, ren),
        .Sequence => self.get_seq_animation(row, col, count, ren),
    };
}

fn get_sp_animation(self: *Self, row: c_int, col: c_int, count: c_int, ren: ?*sdl.SDL_Renderer) Animation {
    const rect = sdl.SDL_Rect{
        .x = self.sp_width * row,
        .y = self.sp_height * col,
        .w = self.sp_width * count,
        .h = self.sp_height,
    };

    std.debug.print("sp -- {d}\n", .{self.sp_width});

    const tex2 = sdl.SDL_CreateTexture(
        ren,
        sdl.SDL_PIXELFORMAT_RGBA8888,
        sdl.SDL_TEXTUREACCESS_TARGET,
        self.sp_width * count,
        self.sp_height,
    );

    _ = sdl.SDL_SetTextureBlendMode(tex2, sdl.SDL_BLENDMODE_BLEND);
    _ = sdl.SDL_SetRenderTarget(ren, tex2);
    _ = sdl.SDL_RenderCopy(ren, self.texture, &rect, null);
    _ = sdl.SDL_SetRenderTarget(ren, null);

    // std.debug.print("{any}\n", .{tex2});

    return Animation.init(
        0,
        0,
        self.sp_width,
        self.sp_height,
        @intCast(count),
        tex2,
    );
}

fn get_seq_animation(self: *Self, row: c_int, col: c_int, count: c_int, ren: ?*sdl.SDL_Renderer) !Animation {
    _ = row;
    _ = col;
    _ = ren;

    const rect = sdl.SDL_Rect{ .x = 0, .y = 0, .w = self.sp_width, .h = self.sp_height };

    return Animation{
        .cx = 0,
        .cy = 0,
        .count = @intCast(count),
        .rect = rect,
        .sp_width = self.sp_width,
        .sp_height = self.sp_height,
        .textures = try self.textures.?.toOwnedSlice(),
        .anim_type = .Sequence,
    };
}

fn get_seq_animation2(self: *Self, row: c_int, col: c_int, count: c_int, ren: ?*sdl.SDL_Renderer) !Animation {
    _ = row;
    _ = col;

    const texture = sdl.SDL_CreateTexture(
        ren,
        sdl.SDL_PIXELFORMAT_RGBA8888,
        sdl.SDL_TEXTUREACCESS_TARGET,
        self.sp_width * count,
        self.sp_height,
    );
    _ = texture;

    const rect = sdl.SDL_Rect{ .x = 0, .y = 0, .w = self.sp_width, .h = self.sp_height };

    return Animation{
        .cx = 0,
        .cy = 0,
        .count = @intCast(count),
        .rect = rect,
        .sp_width = self.sp_width,
        .sp_height = self.sp_height,
        .textures = try self.textures.?.toOwnedSlice(),
        .anim_type = .Sequence,
    };
}
