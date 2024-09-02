const ttf = @cImport(@cInclude("SDL_ttf.h"));
pub usingnamespace @cImport(@cInclude("SDL.h"));

const MSDL = @This();
const sdl = @This();

pub fn init(window: *?*sdl.SDL_Window, renderer: *?*sdl.SDL_Renderer, width: c_int, height: c_int) void {
    if (sdl.SDL_Init(sdl.SDL_INIT_EVERYTHING) < 0) {
        @panic("SDL Initialization Failed!");
    }
    if (ttf.TTF_Init() < 0) {
        @panic("TTF Initialization Failed!");
    }

    window.* = sdl.SDL_CreateWindow("Omar", sdl.SDL_WINDOWPOS_CENTERED, sdl.SDL_WINDOWPOS_CENTERED, width, height, 0);

    renderer.* = sdl.SDL_CreateRenderer(window.*, -1, sdl.SDL_WINDOW_OPENGL);
}

pub fn deinit(window: *?*sdl.SDL_Window, renderer: *?*sdl.SDL_Renderer) void {
    sdl.SDL_DestroyWindow(window.*);
    window.* = null;
    renderer.* = null;

    sdl.SDL_Quit();
    ttf.TTF_Quit();
}

const sdl_error = error{
    SetRenderDrawColorErr,
    RenderCopyError,
    RenderClearError,
};

pub fn MSDL_SetRenderDrawColor(renderer: ?*sdl.SDL_Renderer, r: u8, g: u8, b: u8, a: u8) !void {
    if (sdl.SDL_SetRenderDrawColor(renderer, r, g, b, a) != 0) return error.SetRenderDrawColorErr;
}

pub fn MSDL_RenderCopy(renderer: ?*sdl.SDL_Renderer, texture: ?*sdl.SDL_Texture, srcrect: [*c]const sdl.SDL_Rect, dstrect: [*c]const sdl.SDL_Rect) !void {
    if (sdl.SDL_RenderCopy(renderer, texture, srcrect, dstrect) != 0)
        return error.RenderCopyError;
}

pub fn MSDL_RenderClear(renderer: ?*sdl.SDL_Renderer) !void {
    if (sdl.SDL_RenderClear(renderer) != 0) return error.RenderClearError;
}

const MouseState = struct {
    x: c_int,
    y: c_int,

    const Self = @This();

    pub fn get_x(self: Self) usize {
        return @intCast(self.x);
    }
    pub fn get_y(self: Self) usize {
        return @intCast(self.y);
    }
};

pub fn MSDL_GetMouseState() MouseState {
    var x: c_int = 0;
    var y: c_int = 0;
    _ = sdl.SDL_GetMouseState(&x, &y);
    return .{ .x = x, .y = y };
}
