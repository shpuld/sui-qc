# SUI Template for FTEQW
SUI is a simple QuakeC (MenuQC) UI system for FTE QuakeWorld game engine.

This repository includes a working empty template with SUI already set up with a decent project structure already using Menu QC and CS QC.

Source code for SUI itself can be found in `src/sui_sys.qc` and its usage can be found `src/m_main.qc` for example.

You need FTEQCC (FTE QuakeC Compiler) to compile the source, and FTE QuakeWorld engine to run it.

## Key goals

SUI makes it easier to draw more user interfaces that games typically need, with things like scrollable views, text inputs, sliders, drag and drop elements, etc. 

SUI is meant to be operated in a very imperative manner, there no objects in the menu system, no class hierarchy. SUI itself doesn't do state management for UI, to display menus you draw them per frame and to remove elements you just stop drawing them. It does some magic to connect user actions like clicks and keypresses to your elements and then you bind the elements that need state (what position a slider is in?) to the data (a state object passed as a pointer into menu draw routines, globals, whatever you want).

## Documentation

### Builtin SUI draw elements

Use these to draw your stuff. Simple wrappers for MenuQC/CSQC 2d drawing builtins for SUI. Easy to make your own if you look at the source and how these work.

`void(vector pos, vector size, vector color, float alpha, float flags) sui_fill`

Draws a colored box. See `drawfill` builtin for what the flags do.

`void(vector pos, vector size, string pic, vector color, float alpha, float flags) sui_pic`

Draws an image using shader `pic`. See `drawpic` builtin for what the flags do.

`void(vector pos, vector size, float width, vector color, float alpha, float flags) sui_border_box`

A box that consists of only borders that are `width` thick. See `drawfill` builtin for what the flags do.

`void(vector pos, vector size, string text, vector color, float alpha, float flags) sui_text`

Draws text, `size` sets the font size (character width and character height) and not the entire text element size. See `drawstring` builtin for details.

### Frames

SUI keeps a stack of frames to make it easier to group things together, can be used to build windows/components much more easily. When you create a new frame (without setting alignment), any SUI positions at `[0, 0]` will now be at the top-left of the frame instead of the top-left corner of the screen.

`void(vector pos, vector size) sui_push_frame`

Create a new frame at `pos` with `size`. Sets alignment to the top-left corner of the frame.

`void() sui_pop_frame`

Pops the current frame, so the previous frame in the stack becomes active now, and the alignment you set in the previous frame is also resumed.

`void() sui_reset_frame`

Resets the frame stack and alignment completely. You really shouldn't need this.

`vector() sui_current_frame_pos`

Returns the top-left of the current frame.

`vector() sui_current_frame_size`

Returns the size of the current frame.

`void() sui_clip_to_frame`

Makes it so that anything drawn outside of current frame bounds will be clipped (not-drawn) instead. Clipping will remain on even after popping a frame so make sure to reset it after you're done using it.

`void() sui_reset_clip`

Disables clipping to frame.

`float() sui_is_clipping`

Returns TRUE or FALSE depending on if clipping is currently enabled.

### Aligning

You can set the anchor point in the current frame to make it easy to draw in corners/edges/center without needing to keep track of the size of the frame yourself. Aligning is done per-axis with constants `SUI_ALIGN_START`, `SUI_ALIGN_CENTER` and `SUI_ALIGN_END`. Things with size make sure to line their center or right/bottom edge when you use `SUI_ALIGN_CENTER` or `SUI_ALIGN_END`.

`void(vector align) sui_set_align`

Takes a 2-dimensional vector that contains the SUI_ALIGN_ constants, X component is for horizontal align and Y component is for vertical align. Sets the alignment in the current frame.

`void(float align) sui_set_x_align`

`void(float align) sui_set_y_align`

Same as above, but for setting one axis individually. 

`void(__inout vector point) sui_transform_point`

Mostly used internally and you won't probably need this, but can be useful if you need to get the actual screen coordinates of a transformed point (where a point is after taking in account the frame position and alignment). It takes the vector as an argument and mutates it to the transformed value.

`void(__inout vector point, vector size) sui_transform_box`

Same as earlier, but sets the point to the top-left corner of the box. If align is set to center/bottom/right, the transformed point will depend on the size too.

### Interactions

SUI keeps track of which things are clicked/held/released/focused/etc on by using action elements with unique string ids.

`void(vector pos, vector size, string id, void(float index, vector click_ratios) action) sui_action_element`

Creates a clickable area at `pos` with `size`. The `id` should be unique per frame.  The `action` function can be used for instant effects that you want on click and want the relative position of where the element was clicked on, but most often you can use `sui_noop` for bypassing this and using the other click/hold/hover/release checks for mapping actions to this element.

`float() sui_click_held`

Returns TRUE if left mouse button is being held down.

`float(string id) sui_is_clicked`
Returns TRUE if element with id was the topmost element being clicked (mouse button pressed down over this element and released also over this element) in the previous input/draw cycle.

`float(string id) sui_click_index`

If you need to check multiple overlapping elements that were clicked and not just the topmost one. Returns -1 if the element with id was not clicked, and 0 if it was the topmost click, 1 if it was the 2nd most topmost click, etc.

`float(string id) sui_is_hovered`

Returns TRUE if element with id was the topmost element being hovered in the previous input/draw cycle.

`float(string id) sui_hover_index`

Same as `sui_click_index` but for hover.

`float(string id) sui_is_held`

Same as `sui_is_clicked` but for holding (mouse button pressed down on this element and still holding down the mouse button even if not over it anymore).

`float(string id) sui_hold_index`

Same as `sui_click_index` but for holding.

`float(string id) sui_is_last_clicked`

Returns TRUE if this element was the last element that was clicked. Useful for checking focus on input boxes for example.

`float(string id) sui_last_clicked_index`

Same as `sui_click_index` but for last clicked.

`float(string id) sui_is_released`

Returns TRUE when a hold on element with id was released.

`float(string id) sui_release_index`

Same as `sui_click_index` but for releasing.

## Builtin interactable elements

`float(string id, vector pos, vector size, vector minmaxsteps, float value, void(float value) action) sui_slidercontrol`

Draws a horizontal slider (see the volume sliders in Settings of the template). The `id` is the unique string id for the action element of the slider. `minmaxsteps` has the minimum float value in X component, maximum float value in Y component, and the amount of steps in the Z component (0 means no steps). `value` is the current value of the slider (meaning you have to store the value elsewhere and give it as an argument every time). `action` is used if you want to bind some function to be ran every time the value is changed. The function returns the new or unchanged value. This only does the control part of the slider, you'll have to do the drawing separately.

`void(string id, vector pos, vector size, __inout string text, __inout float cursor) sui_text_input`

Creates a text input that you can click on to focus and type in. You have to provide it the string it mutates and the float it mutates to keep track of the cursor.

`void(string id, vector size, vector contentsize, __inout vector offset, vector scrollbar_widths) sui_scrollbar`

Documentation coming soon.

`void(string id, vector pos, vector size, vector contentsize, __inout vector offset, vector scrollbar_widths) sui_scroll_view_begin`

Documentation coming soon.

`void() sui_scroll_view_end`

Documentation coming soon.

`void(string id, vector pos, vector size, vector itemsize, float numitems, __inout vector offset, vector scrollbar_widths) sui_list_view_begin`

Documentation coming soon, you can find usage of it in the Settings menu of the template.

`float(__inout vector pos) sui_list_item`

Documentation coming soon, you can find usage of it in the Settings menu of the template.

`void() sui_list_view_end`

Documentation coming soon, you can find usage of it in the Settings menu of the template.

`string(string id, vector pos, vector size, string name, string command) sui_binder`

Creates a keybinder action element. `name` is the human readable name of the thing you want to bind, and `command` is the command you want to bind to. Clicking on this action element will activate bind-mode for the command. Do not use these if you're not doing `sui_draw_bind_overlay` somewhere, or things will be very confusing.

`void() sui_draw_bind_overlay`

Draws the overlay that tells you to press a key for the command etc. if binding is active.
