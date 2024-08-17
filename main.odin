// Text rendering experiments
package main

import rl "vendor:raylib"
import tt "vendor:stb/truetype"

import "core:fmt"

main :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_HIGHDPI})

    rl.InitWindow(640, 360, "Text Rendering")
    defer rl.CloseWindow()

    font_data :: #load("C:/Windows/Fonts/arial.ttf")
    
    font := dyn_font_make(font_data)
    defer dyn_font_destroy(&font)

    for !rl.WindowShouldClose() {
        if rl.IsWindowResized() {
            // The DPI may have changed, so invalidate the atlas
            font_atlas_clear(&font.atlas)
        }

        rl.ClearBackground(rl.BLACK)

        rl.BeginDrawing()

        dyn_font_draw_text(&font, "United Martians Will Alwayz Prevail", {80, 180}, rl.WHITE)

        rl.EndDrawing()

        free_all(context.temp_allocator)
    }
}
