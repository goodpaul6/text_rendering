package main

import rl "vendor:raylib"
import tt "vendor:stb/truetype"

Glyph_Info :: struct {
    // These two together form the key for this glyph
    codepoint: rune,
    height_px: int,

    scale: [2]f32,

    unscaled_advance: f32,

    // Source rect in the atlas
    atlas_rect: rl.Rectangle,

    // These are relative to the <current_point, baseline> as described here:
    // https://github.com/nothings/stb/blob/master/stb_truetype.h#L217
    tt_bounds: [4]f32,
}

Font_Atlas :: struct {
    // Note that the underlying data for this must live longer than this
    // atlas struct.
    info: tt.fontinfo,

    // This is additional space we add between glyphs to prevent artifacts
    padding: [2]f32,

    unscaled_baseline: f32,

    image: rl.Image,

    // We update this on the fly as the cache is updated
    texture: rl.Texture,

    // Current position we're packing characters into.
    // Really dumb packing algorithm: just keep adding characters
    // horizontally and move down when we hit the right edge. If
    // we run out of room, then resize the image and continue.
    pack_pos: [2]f32,

    // As we're packing glyphs, we keep track of the tallest glyph in the current
    // row so that when we reset to the start of the next row, we move pack_pos
    // down enough not to clash with any char on the previous row.
    pack_row_h: f32,

    // TODO(Apaar): Use a map from codepoint + height_px to Glyph_Info here.
    // Can use a fixed array of bytes to create a hashable key.
    glyphs: [dynamic]Glyph_Info,
}

scale_for_height_px :: proc(font: ^tt.fontinfo, height_px: int) -> [2]f32 {
    scale := tt.ScaleForPixelHeight(font, f32(height_px))
    dpi := rl.GetWindowScaleDPI()

    scale_x := dpi.x * scale
    scale_y := dpi.y * scale

    return {scale_x, scale_y}
}

font_atlas_make :: proc(info: tt.fontinfo, init_size: [2]i32, padding: [2]f32) -> Font_Atlas {
    info := info

    // We need this to calculate the baseline as defined here:
    // https://github.com/nothings/stb/blob/master/stb_truetype.h#L201
    x0, y0, x1, y1: i32
    tt.GetFontBoundingBox(&info, &x0, &y0, &x1, &y1)

    image := rl.GenImageColor(init_size.x, init_size.y, {0, 0, 0, 0})

    return {
        info = info,
        padding = padding,

        unscaled_baseline = f32(-y0),

        image = image,

        texture = rl.LoadTextureFromImage(image),
    }
}

font_atlas_destroy :: proc(using atlas: ^Font_Atlas) {
    rl.UnloadTexture(texture)
    rl.UnloadImage(image)
}

// The Glyph_Info returned by this may be invalidated after another call to this function.
// Use this just before rendering the glyph.
//
// TODO(Apaar): Actually, we shouldn't resize the image unless we can't fit all the characters we need
// for a _single_ draw call. Otherwise, we're fine just clearing out the atlas. This would require us
// to get the entire string (or all unique codepoints I guess) we want to render ahead of time.
font_atlas_get_or_render_glyph :: proc(using atlas: ^Font_Atlas, codepoint: rune, height_px: int) -> Glyph_Info {
    for &g in glyphs {
        if g.codepoint == codepoint && g.height_px == height_px {
            return g
        }
    }

    scale := scale_for_height_px(&info, height_px)

    ix0, iy0, ix1, iy1: i32

    tt.GetCodepointBitmapBox(
        &info, 
        codepoint, 
        scale.x,
        scale.y,
        &ix0, &iy0, &ix1, &iy1,
    )

    w := ix1 - ix0
    h := iy1 - iy0

    if pack_pos.x + f32(w) >= f32(image.width) {
        pack_pos.x = 0
        pack_pos.y += pack_row_h + padding.y
        
        pack_row_h = 0 
    }

    if pack_pos.y >= f32(image.height) {
        // Time to resize and continue
        new_image := rl.GenImageColor(image.width * 2, image.height * 2, {0, 0, 0, 0})
        new_texture := rl.LoadTextureFromImage(new_image)

        rl.UnloadImage(image)
        rl.UnloadTexture(texture)

        image = new_image
        texture = new_texture
        clear(&glyphs)

        return font_atlas_get_or_render_glyph(atlas, codepoint, height_px)
    }

    data := make([]byte, w * h, context.temp_allocator)

    tt.MakeCodepointBitmap(
        &info, raw_data(data), 
        out_w=w, out_h=h, out_stride=w, 
        scale_x=scale.x, scale_y=scale.y,
        codepoint=codepoint,
    )

    alpha_data := make([]byte, w * h * 2, context.temp_allocator)

    // Convert the gray value into alpha
    for i: i32 = 0; i < w * h * 2; i += 2 {
        alpha_data[i] = 0xff
        alpha_data[i + 1] = data[i / 2]
    }

    // Note that this image is never Unloaded because the data
    // is allocated via Odin's temp allocator and not raylib's.
    glyph_image := rl.Image{
        data = raw_data(alpha_data),
        width = w,
        height = h,
        mipmaps = 1,
        format = .UNCOMPRESSED_GRAY_ALPHA
    }

    atlas_rect := rl.Rectangle{pack_pos.x, pack_pos.y, f32(w), f32(h)}

    rl.ImageDraw(
        &image, glyph_image,
        srcRec={0, 0, f32(w), f32(h)},
        dstRec=atlas_rect,
        tint=rl.WHITE,
    )

    rl.UpdateTexture(texture, image.data)

    pack_pos.x += f32(w) + padding.x
    pack_row_h = max(pack_row_h, f32(h))

    advance, left_side_bearing: i32

    tt.GetCodepointHMetrics(&info, codepoint, &advance, &left_side_bearing)

    glyph_info := Glyph_Info{
        codepoint = codepoint,
        height_px = height_px,
        scale = scale,
        unscaled_advance = f32(advance),
        atlas_rect = atlas_rect,
        tt_bounds = {f32(ix0), f32(iy0), f32(ix1), f32(iy1)},
    }

    append(&glyphs, glyph_info)

    return glyph_info
}

font_atlas_clear :: proc(using atlas: ^Font_Atlas) {
    prev_info := info
    prev_w := image.width
    prev_h := image.height
    prev_padding := padding

    font_atlas_destroy(atlas)
    atlas^ = font_atlas_make(prev_info, {prev_w, prev_h}, prev_padding)
}
