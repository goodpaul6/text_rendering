// Text rendering experiments
package main

import "core:fmt"

import rl "vendor:raylib"
import tt "vendor:stb/truetype"

scale_for_height_px :: proc(font: ^tt.fontinfo, height_px: f32) -> [2]f32 {
    scale := tt.ScaleForPixelHeight(font, height_px)
    dpi := rl.GetWindowScaleDPI()

    scale_x := dpi.x * scale
    scale_y := dpi.y * scale

    return {scale_x, scale_y}
}

// Returns the bitmap box of the codepoint glyph
render_codepoint_to_image :: proc (
    font: ^tt.fontinfo, 
    dest_image: ^rl.Image, 
    dest_pos: [2]f32,
    scale: [2]f32,
    codepoint: rune,
    allocator := context.temp_allocator
) -> [4]i32 {
    ix0, iy0, ix1, iy1: i32

    tt.GetCodepointBitmapBox(
        font, 
        codepoint, 
        scale.x,
        scale.y,
        &ix0, &iy0, &ix1, &iy1,
    )

    w := ix1 - ix0
    h := iy1 - iy0

    data := make([]byte, w * h, allocator)

    tt.MakeCodepointBitmap(
        font, raw_data(data), 
        out_w=w, out_h=h, out_stride=w, 
        scale_x=scale.x, scale_y=scale.y,
        codepoint=codepoint,
    )

    image := rl.Image{
        data = raw_data(data),
        width = w,
        height = h,
        mipmaps = 1,
        format = .UNCOMPRESSED_GRAYSCALE
    }

    rl.ImageDraw(
        dest_image, image,
        srcRec={0, 0, f32(w), f32(h)},
        dstRec={dest_pos.x, dest_pos.y, f32(w), f32(h)},
        tint=rl.WHITE,
    )

    return {ix0, iy0, ix1, iy1}
}

gen_font_atlas_texture :: proc(font: ^tt.fontinfo) -> rl.Texture {
    atlas_image := rl.GenImageColor(512, 512, rl.BLACK)
    defer rl.UnloadImage(atlas_image)

    ascent, descent, line_gap: i32
    tt.GetFontVMetrics(font, &ascent, &descent, &line_gap)

    scale := scale_for_height_px(font, 64)

    h_size := render_codepoint_to_image(font, &atlas_image, {0, 0}, scale, 'H')
    e_size := render_codepoint_to_image(font, &atlas_image, {h_size.x, f32(ascent) * scale.y}, scale, 'e')

    return rl.LoadTextureFromImage(atlas_image)
}

main :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_HIGHDPI})

    rl.InitWindow(640, 360, "Text Rendering")
    defer rl.CloseWindow()

    font_data :: #load("../opal/fonts/Inter-Regular.ttf")

    font := tt.fontinfo{}
    tt.InitFont(&font, raw_data(font_data), 0)

    atlas_texture := gen_font_atlas_texture(&font)
    defer rl.UnloadTexture(atlas_texture)

    for !rl.WindowShouldClose() {
        if rl.IsWindowResized() {
            rl.UnloadTexture(atlas_texture)
            atlas_texture = gen_font_atlas_texture(&font)
        }

        rl.ClearBackground(rl.BLACK)

        rl.BeginDrawing()

        rl.DrawTexture(atlas_texture, 10, 10, rl.WHITE)

        rl.EndDrawing()
    }
}
