// Text rendering and layout system
package main

import rl "vendor:raylib"

Stateful_Text_Font_ID :: distinct int

STATEFUL_TEXT_NULL_FONT_ID :: Stateful_Text_Font_ID(0)

Stateful_Text_Font :: struct {
    id: Stateful_Text_Font_ID,
    dyn_font: Dyn_Font,

    // We reference the bold and italicized version of the
    // font here. This can be recursive e.g. if you have a
    // bold + italic version you can reference that from
    // both the bold and italic fonts respectively.
    bold_ver: Stateful_Text_Font_ID,
    italic_ver: Stateful_Text_Font_ID,
}

Stateful_Text_Command_Push_State :: struct {}
Stateful_Text_Command_Pop_State :: struct {}

Stateful_Text_Command_Set_Font :: struct {
    id: Stateful_Text_Font_ID,
}

Stateful_Text_Command_Set_Color :: struct {
    color: rl.Color,
}

Stateful_Text_Command_Set_Size :: struct {
    height_px: int,
}

// If you want to disable these as the commands run, push the state before
// and then pop it after
Stateful_Text_Command_Enable_Bold :: struct {}
Stateful_Text_Command_Enable_Italic :: struct {}

Stateful_Text_Command_Newline :: struct{}

Stateful_Text_Command_Text :: struct {
    text: string,
    should_delete_text: bool,
}

Stateful_Text_Command :: union{
    Stateful_Text_Command_Push_State,
    Stateful_Text_Command_Pop_State,
    Stateful_Text_Command_Set_Font,
    Stateful_Text_Command_Set_Color,
    Stateful_Text_Command_Set_Size,
    Stateful_Text_Command_Enable_Bold,
    Stateful_Text_Command_Enable_Italic,
    Stateful_Text_Command_Newline,
    Stateful_Text_Command_Text,
}

Stateful_Text_State :: struct {
    font: Stateful_Text_Font_ID,
    height_px: int,
    color: rl.Color,
}

Stateful_Text :: struct {
    next_font_id: Stateful_Text_Font_ID,

    fonts: [dynamic]Stateful_Text_Font,
    states: [dynamic]Stateful_Text_State,
}


