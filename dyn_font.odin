package main

import rl "vendor:raylib"
import tt "vendor:stb/truetype"

Dyn_Font :: struct {
    // You can change this as needed.
    height_px: int,

    atlas: Font_Atlas,
}

Dyn_Font_Quad :: struct {
    glyph_info: Glyph_Info,
    dest_rect: rl.Rectangle,
}

DYN_FONT_DEFAULT_HEIGHT_PX :: 36
DYN_FONT_ATLAS_SIZE :: [2]i32{512, 512}
DYN_FONT_ATLAS_PADDING :: [2]f32{2, 2}

dyn_font_make :: proc(font_data: []byte) -> Dyn_Font {
    info := tt.fontinfo{}
    tt.InitFont(&info, raw_data(font_data), 0)

    atlas := font_atlas_make(info, DYN_FONT_ATLAS_SIZE, DYN_FONT_ATLAS_PADDING)

    return {
        height_px = DYN_FONT_DEFAULT_HEIGHT_PX,
        atlas = atlas,
    }
}

dyn_font_destroy :: proc(using font: ^Dyn_Font) {
    font_atlas_destroy(&atlas)
}

dyn_font_for_each_text_quad :: proc(using font: ^Dyn_Font, text: string, userdata: $T, fn: proc(T, Dyn_Font_Quad)) {
    x := f32(0)
    y := f32(0)
    prev_ch := rune(0)

    for ch in text {
        gi := font_atlas_get_or_render_glyph(&atlas, ch, height_px)

        if prev_ch != rune(0) {
            kern := f32(tt.GetCodepointKernAdvance(&atlas.info, prev_ch, ch))
            x += kern
        }

        baseline := atlas.unscaled_baseline * gi.scale.y + y

        x0 := x + gi.tt_bounds[0]
        y0 := baseline + gi.tt_bounds[1]
        x1 := x + gi.tt_bounds[2]
        y1 := baseline + gi.tt_bounds[3]

        dest_rect := rl.Rectangle{x0, y0, (x1 - x0), (y1 - y0)}

        fn(userdata, Dyn_Font_Quad{gi, dest_rect})

        x += gi.unscaled_advance * gi.scale.x
        prev_ch = ch
    }
}

dyn_font_measure_text :: proc(using font: ^Dyn_Font, text: string) -> rl.Rectangle {
    // Mins and maxes
    bounds := [4]f32{
        f32(1_000_000), 
        f32(1_000_000),
        f32(-1_000_000),
        f32(-1_000_000),
    }

    update_bounds :: proc(bounds: ^[4]f32, quad: Dyn_Font_Quad) {
        bounds[0] = min(quad.dest_rect.x, bounds[0])
        bounds[1] = min(quad.dest_rect.y, bounds[1])
        bounds[2] = max(quad.dest_rect.x + quad.dest_rect.width, bounds[2])
        bounds[3] = max(quad.dest_rect.y + quad.dest_rect.height, bounds[3])
    }

    dyn_font_for_each_text_quad(font, text, &bounds, update_bounds)

    return {
        x = bounds[0],
        y = bounds[1],
        width = bounds[2] - bounds[0],
        height = bounds[3] - bounds[1],
    }
}

dyn_font_draw_text :: proc(using font: ^Dyn_Font, text: string, pos: [2]f32, tint: rl.Color) {
    Userdata :: struct {
        font: ^Dyn_Font,
        pos: [2]f32,
        tint: rl.Color,
    }

    draw_quad :: proc(using ud: Userdata, quad: Dyn_Font_Quad) {
        rl.DrawTexturePro(
            font.atlas.texture, 
            source=quad.glyph_info.atlas_rect,
            dest={
                pos.x + quad.dest_rect.x,
                pos.y + quad.dest_rect.y,
                quad.dest_rect.width,
                quad.dest_rect.height,
            },
            origin={0, 0},
            rotation=0,
            tint=tint,
        )
    }

    dyn_font_for_each_text_quad(font, text, Userdata{font, pos, tint}, draw_quad)
}
