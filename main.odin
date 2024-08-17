// Text rendering experiments
package main

import rl "vendor:raylib"
import tt "vendor:stb/truetype"

import "core:fmt"

main :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_HIGHDPI, .MSAA_4X_HINT})

    rl.InitWindow(640, 360, "Text Rendering")
    defer rl.CloseWindow()

    font_data :: #load("C:/Windows/Fonts/arial.ttf")
    
    font := dyn_font_make(font_data)
    defer dyn_font_destroy(&font)

    font.height_px = 96

    for !rl.WindowShouldClose() {
        if rl.IsWindowResized() {
            // The DPI may have changed, so invalidate the atlas
            font_atlas_clear(&font.atlas)
        }

        rl.ClearBackground(rl.BLACK)

        rl.BeginDrawing()

        render_size := [2]f32{f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight())}

        text := "United Martians Will Alwayz Prevail"

        rect := dyn_font_measure_text(&font, text)
        dyn_font_draw_text(&font, "United Martians Will Alwayz Prevail", {
            render_size.x / 2 - rect.width / 2,
            render_size.y / 2 - rect.height / 2,
        }, rl.RED)

        rl.EndDrawing()

        free_all(context.temp_allocator)
    }
}
