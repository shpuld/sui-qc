// Shpuld's Simple UI lib - sui
// Created 11/2018
//
// sui is a simple QuakeC UI lib for drawing and handling game interfaces.
// The API is made simple and easy to build upon, but cuts have been made
// to keep complexity low.
//


#ifdef MENU
const float IE_KEYDOWN = 0;	/* Specifies that a key was pressed. Second argument is the scan code. Third argument is the unicode (printable) char value. Fourth argument denotes which keyboard(or mouse, if its a mouse 'scan' key) the event came from. Note that some systems may completely separate scan codes and unicode values, with a 0 value for the unspecified argument. */
const float IE_KEYUP = 1;	/* Specifies that a key was released. Arguments are the same as IE_KEYDOWN. On some systems, this may be fired instantly after IE_KEYDOWN was fired. */
const float IE_MOUSEDELTA = 2;	/* Specifies that a mouse was moved (touch screens and tablets typically give IE_MOUSEABS events instead, use _windowed_mouse 0 to test code to cope with either). Second argument is the X displacement, third argument is the Y displacement. Fourth argument is which mouse or touch event triggered the event. */
const float IE_MOUSEABS = 3;	/* Specifies that a mouse cursor or touch event was moved to a specific location relative to the virtual screen space. Second argument is the new X position, third argument is the new Y position. Fourth argument is which mouse or touch event triggered the event. */
const float IE_ACCELEROMETER = 4;
const float IE_FOCUS = 5;	/* Specifies that input focus was given. parama says mouse focus, paramb says keyboard focus. If either are -1, then it is unchanged. */
const float IE_JOYAXIS = 6;	/* Specifies that what value a joystick/controller axis currently specifies. x=axis, y=value. Will be called multiple times, once for each axis of each active controller. */

#define printf(x, ...) print(sprintf(x, __VA_ARGS__))

#endif
float _sui_draw_initialized;


// framing

// pseudo windowing, sets a new "frame" for whatever we're drawing, instead of
// always using screen [0, 0] as min and [screen_width, screen_height] as max.
// also allows for aligning content to frame start/end/center on both axis

struct _frame_t {
	vector pos;
	vector size;
	vector align;
};
const float MAX_FRAMES = 64;
_frame_t _frames[MAX_FRAMES];
float _frame_index;

const float SUI_ALIGN_START = 0;
const float SUI_ALIGN_CENTER = 1;
const float SUI_ALIGN_END = 2;

void() sui_reset_align =
{
	_frames[_frame_index].align = [SUI_ALIGN_START, SUI_ALIGN_START];
};

void(float align) sui_set_x_align =
{
	_frames[_frame_index].align.x = align;
};

void(float align) sui_set_y_align =
{
	_frames[_frame_index].align.y = align;
};

void(vector align) sui_set_align =
{
	_frames[_frame_index].align = align;
};

void(__inout vector point) sui_transform_point =
{
	int idx = _frame_index;
	switch (_frames[idx].align.x) 
	{
		case SUI_ALIGN_START:	point_x += _frames[idx].pos.x; break;
		case SUI_ALIGN_CENTER:	point_x += _frames[idx].pos.x + _frames[idx].size.x * 0.5; break;
		case SUI_ALIGN_END:		point_x += _frames[idx].pos.x + _frames[idx].size.x; break;
		default: break;
	}
	switch (_frames[idx].align.y) 
	{
		case SUI_ALIGN_START:	point_y += _frames[idx].pos.y; break;
		case SUI_ALIGN_CENTER:	point_y += _frames[idx].pos.y + _frames[idx].size.y * 0.5; break;
		case SUI_ALIGN_END:		point_y += _frames[idx].pos.y + _frames[idx].size.y; break;
		default: break;
	}
};

void(__inout vector point, vector size) sui_transform_box =
{
	int idx = _frame_index;
	switch (_frames[idx].align.x) 
	{
		case SUI_ALIGN_START:
			point_x += _frames[idx].pos.x; 
			break;
		case SUI_ALIGN_CENTER:
			point_x += _frames[idx].pos.x + _frames[idx].size.x * 0.5 - size_x * 0.5; 
			break;
		case SUI_ALIGN_END:
			point_x += _frames[idx].pos.x + _frames[idx].size.x - size_x; 
			break;
		default: break;
	}
	switch (_frames[idx].align.y) 
	{
		case SUI_ALIGN_START:
			point_y += _frames[idx].pos.y; 
			break;
		case SUI_ALIGN_CENTER:
			point_y += _frames[idx].pos.y + _frames[idx].size.y * 0.5 - size_y * 0.5; 
			break;
		case SUI_ALIGN_END:
			point_y += _frames[idx].pos.y + _frames[idx].size.y - size_y; 
			break;
		default: break;
	}
};

vector() sui_current_frame_pos = 
{ 
	return _frames[_frame_index].pos;
};

vector() sui_current_frame_size =
{
	 return _frames[_frame_index].size;
};

float _sui_is_clipping;
vector _sui_clip_area_mins;
vector _sui_clip_area_maxs; 
void() sui_clip_to_frame =
{
	vector pos = _frames[_frame_index].pos;
	vector size = _frames[_frame_index].size;
	_sui_is_clipping = TRUE;
	_sui_clip_area_mins = pos;
	_sui_clip_area_maxs = pos + size;
	drawsetcliparea(pos.x, pos.y, size.x, size.y);
};

void() sui_reset_clip =
{
	_sui_is_clipping = FALSE;
	drawresetcliparea();
};

float() sui_is_clipping =
{
	return _sui_is_clipping;
};

void(vector pos, vector size) sui_push_frame =
{
	sui_transform_box(pos, size);
	
	_frame_index += 1;
	if (_frame_index >= MAX_FRAMES)
	{
		printf("^3sui warning: amount of frames = %.0f exceeds MAX_FRAMES = %.0f, consider increasing MAX_FRAMES\n", _frame_index, MAX_FRAMES);
		return;
	}
	
	_frames[_frame_index].pos = pos;
	_frames[_frame_index].size = size;
	_frames[_frame_index].align = [SUI_ALIGN_START, SUI_ALIGN_START]; // TODO allow customizing this
};

void() sui_pop_frame =
{
	if (_frame_index > 0) _frame_index -= 1;
};

void() sui_reset_frame = 
{
	_frame_index = 0;
	sui_reset_align();
};


// actions

// interaction for sui elements, relies a lot on reading globals to see which
// element id is under cursor or held or whatever, not the most elegant
// solution but in this highly imperative world of QuakeC we can live with it

float _holding_click;
vector _cursor_click;
vector _cursor_position;
vector _cursor_relative_click;
vector _cursor_relative_hover;
struct _action_element_t {
	vector pos;
	vector size;
	string id;
	float kb_nav_disabled;
	void(float index, vector click_ratios) action;
};
const float MAX_ACTION_ELEMENTS = 256;
_action_element_t _action_elements[MAX_ACTION_ELEMENTS];
float _action_elements_index;

float _cursor_is_mouse_active;
float _cursor_mouse_activate_accum;


// TODO better naming
float(vector point, vector min, vector max) is_2dpoint_in_bounds =
{
	if (point_x <= min_x || point_y <= min_y) return FALSE;
	if (point_x > max_x || point_y > max_y) return FALSE;
	return TRUE;
};

// TODO better naming
float(vector point, vector pos, vector size) is_2dpoint_in_bbox =
{
	return is_2dpoint_in_bounds(point, pos, pos + size);
};

void() _action_element_count_sanity =
{
	if (_action_elements_index > MAX_ACTION_ELEMENTS)
	{
		// let the user know if they're hitting the bounds
		printf("^3sui warning: amount of action elements = %.0f exceeds MAX_ACTION_ELEMENTS = %.0f, consider increasing MAX_ACTION_ELEMENTS\n", _action_elements_index, MAX_ACTION_ELEMENTS);
	}
};

const float MAX_MOUSE_ACTIONS = 16;
string _hover_actions[MAX_MOUSE_ACTIONS];
string _click_actions[MAX_MOUSE_ACTIONS];
string _hold_actions[MAX_MOUSE_ACTIONS];
string _release_actions[MAX_MOUSE_ACTIONS];
string _last_clicked_actions[MAX_MOUSE_ACTIONS];

float _hover_action_count;
float _click_action_count;
float _hold_action_count;
float _release_action_count;
float _last_clicked_action_count;


// Resets things you might want to persist normally
void() sui_reset_actions =
{
	_hover_action_count = 0;
	_click_action_count = 0;
	_hold_action_count = 0;
	_release_action_count = 0;
	_last_clicked_action_count = 0;
	_holding_click = FALSE;
};

// Per frame reset?
void() sui_reset_click =
{
	_hold_action_count = 0;
	_click_action_count = 0;
	_holding_click = FALSE;
};

float() sui_click_held = { return _holding_click; };


// click: on mouse1 button down AND button op, once

// Returns true if id was the topmost click (what usually is cared about the most)
float(string id) sui_is_clicked =
{
	return _click_action_count > 0 && _click_actions[0] == id;
};

// Returns the index of the clicked id, -1 if wasn't hit at all. 0 is topmost
float(string id) sui_click_index =
{
	for (int i = 0; i < _click_action_count; i++)
	{
		if (_click_actions[i] == id) return i;
	}
	return -1;
};


// hover: mouse is on top of the action element id

float(string id) sui_is_hovered =
{
	return _hover_action_count > 0 && _hover_actions[0] == id;
};

float(string id) sui_hover_index =
{
	for (int i = 0; i < _hover_action_count; i++)
	{
		if (_hover_actions[i] == id) return i;
	}
	return -1;
};


// hold: mouse button was clicked on top of this id and is held down, but not necessarily over this id anymore

float(string id) sui_is_held =
{
	return _hold_action_count > 0 && _hold_actions[0] == id;
};

float(string id) sui_hold_index =
{
	for (int i = 0; i < _hold_action_count; i++)
	{
		if (_hold_actions[i] == id) return i;
	}
	return -1;
};


// last clicked: is this the last action element that was clicked, good for focusing on input boxes for example

float(string id) sui_is_last_clicked =
{
	return _last_clicked_action_count > 0 && _last_clicked_actions[0] == id;
};

float(string id) sui_last_clicked_index =
{
	for (int i = 0; i < _last_clicked_action_count; i++)
	{
		if (_last_clicked_actions[i] == id) return i;
	}
	return -1;
};


// release: a thing was held, but now it was released, once

float(string id) sui_is_released =
{
	return _release_action_count > 0 && _release_actions[0] == id;
};

float(string id) sui_release_index =
{
	for (int i = 0; i < _release_action_count; i++)
	{
		if (_release_actions[i] == id) return i;
	}
	return -1;
};


float(float num) mouse_action_sanity =
{
	if (num >= MAX_MOUSE_ACTIONS)
	{
		printf("^3sui warning: you have exceeded the amount of overlapping action elements with %.0f, MAX_MOUSE_ACTIONS = %.0f\n", num, MAX_MOUSE_ACTIONS);
		return TRUE;
	}
	return FALSE;
};

void() activate_mouse_cursor =
{
	_cursor_is_mouse_active = TRUE;
	_cursor_mouse_activate_accum = 0;
};

void() deactivate_mouse_cursor =
{
	_cursor_is_mouse_active = FALSE;
	_cursor_mouse_activate_accum = 0;
};

// mouse move, mostly just update hovers

void(vector pos, float is_mouse = TRUE) _sui_mouse_move =
{
	vector old_pos = _cursor_position;
	_cursor_position = pos;
	_action_element_count_sanity();
	
	// Reset hover, it'll be back to what it used to be before draw gets called if mouse is still on same element
	_hover_action_count = 0;

	if (is_mouse)
	{
		if (!_cursor_is_mouse_active)
		{
			printf("mouse moved to %v\n", pos);
			_cursor_mouse_activate_accum += vlen(pos - old_pos);
			if (_cursor_mouse_activate_accum > 10)
				activate_mouse_cursor();
			return;
		}
	}
	
	// Iterate front to back, so topmost element gets the click/hover
	for (int i = min(MAX_ACTION_ELEMENTS, _action_elements_index) - 1; i >= 0; i--)
	{
		if (is_2dpoint_in_bbox(_cursor_position, _action_elements[i].pos, _action_elements[i].size))
		{
			if (mouse_action_sanity(_hover_action_count)) break;
			
			if (_hover_action_count == 0) _cursor_relative_hover = _cursor_position - _action_elements[i].pos; 
			_hover_actions[_hover_action_count] = _action_elements[i].id;
			_hover_action_count += 1;
		}
	}
};

// JERK ALERT: hard to pass input params for it without them just being the globals
// ... so it just straight up uses the globals... optimization
float(float is_mouse = TRUE) _sui_mouse1_down =
{
	if (is_mouse)
		activate_mouse_cursor();

	// Cheap but it should work...
	_cursor_click = _cursor_position;
	_cursor_relative_click = _cursor_relative_hover;
	for (int i = 0; i < _hover_action_count; i++)
		_hold_actions[i] = _hover_actions[i];
	_hold_action_count = _hover_action_count;
	_holding_click = TRUE;
	_last_clicked_action_count = 0;

	for (int i = 0; i < _action_elements_index; i++)
	{
		if (is_2dpoint_in_bbox(_cursor_position, _action_elements[i].pos, _action_elements[i].size))
		{
			return TRUE;
		}
	}
	return FALSE;
};

float(float is_mouse = TRUE) _sui_mouse1_up =
{
	if (is_mouse)
		activate_mouse_cursor();

	// Can't be cheap here, we have to get the action fn of the element anyway so..
	_action_element_count_sanity();
	
	// Assume we won't hit anything
	_click_action_count = 0;
	_last_clicked_action_count = 0;
	
	// Iterate front to back, so topmost element gets the click/hover
	for (int i = min(MAX_ACTION_ELEMENTS, _action_elements_index) - 1; i >= 0; i--)
	{
		// If the thing wasn't the same thing we started pressing down on, ignore
		for (int j = 0; j < _hold_action_count; j++)
		{
			if (_hold_actions[j] == _action_elements[i].id) // yes this element was held
			{		
				// Still in bounds?
				if (is_2dpoint_in_bbox(_cursor_position, _action_elements[i].pos, _action_elements[i].size))
				{
					if (mouse_action_sanity(_click_action_count)) break;
					
					// Register click
					_click_actions[_click_action_count] = _action_elements[i].id;
					_last_clicked_actions[_last_clicked_action_count] = _action_elements[i].id;
					_click_action_count += 1;
					_last_clicked_action_count += 1;
				}
			}
		}
	}
	
	// In case someone is keeping state on hold and wants to do stuff on release, even if cursor has moved
	for (int i = 0; i < _hold_action_count; i++)
		_release_actions[i] = _hold_actions[i];

	_release_action_count = _hold_action_count;
	_hold_action_count = 0;
	_holding_click = FALSE;

	if (_release_action_count > 0)
		return TRUE;

	return FALSE;
};

vector _sui_kb_move_dir;
float _sui_hijacked_dirs;
string _sui_default_kb_focus;
const float KB_DIR_UP = 1;
const float KB_DIR_DOWN = 2;
const float KB_DIR_LEFT = 4;
const float KB_DIR_RIGHT = 8;

void(float kb_dir) sui_hijack_kb_nav =
{
	_sui_hijacked_dirs |= kb_dir;
}

void(string id) sui_set_default_kb_focus =
{
	_sui_default_kb_focus = id;
}

float(vector dir) kb_dir_from_vec =
{
	if (vlen(dir) < 0.2) return 0;

	if (fabs(dir.x) > fabs(dir.y))
	{
		if (dir.x > 0) return KB_DIR_RIGHT;
		return KB_DIR_LEFT;
	}
	if (dir.y > 0) return KB_DIR_DOWN;
	return KB_DIR_UP;
}

void() _retarget_kb_cursor =
{
	if (_action_elements_index == 0) return;

	// retarget cursor
	string target = _hover_action_count == 0 ? _sui_default_kb_focus : _hover_actions[0];
	vector default_pos = _action_elements[0].pos + _action_elements[0].size * 0.5;
	for (int i = 0; i < _action_elements_index; i++)
	{
		if (_action_elements[i].id == target)
		{
			_sui_mouse_move(_action_elements[i].pos + _action_elements[i].size * 0.5, FALSE);
			return;
		}
		if (_action_elements[i].id == _sui_default_kb_focus)
		{
			default_pos = _action_elements[i].pos + _action_elements[i].size * 0.5;
		}
	}
	_sui_mouse_move(default_pos, FALSE);
}

void(vector dir) _cursor_kb_move =
{
	deactivate_mouse_cursor();
	_sui_kb_move_dir = dir;
	
	// for sliders and scroll lists
	float kb_dir = kb_dir_from_vec(dir);
	if (_sui_hijacked_dirs & kb_dir_from_vec(dir))
	{
		return;
	}

	// we calculate score for each other action element to see which other element we should move to if any
	// score calculated via direction primarily (dot product), and distance secondarily
	float best_score = 0;
	float best_element_index = -1;
	vector best_pos = _cursor_position;

	for (int i = 0; i < _action_elements_index; i++)
	{
		if (_action_elements[i].kb_nav_disabled)
			continue; // scroll bars etc usually
		if (sui_hover_index(_action_elements[i].id) >= 0)
			continue; // don't try to move to already focused element
		if (_action_elements[i].size.x * _action_elements[i].size.y <= 0)
			continue; // don't try to move to action elements with area zero or less (clipped elements mostly)

		vector boxstart = _action_elements[i].pos;
		vector boxend = _action_elements[i].pos + _action_elements[i].size;

		vector center = (boxstart + boxend) * 0.5;
		vector to_other = center - _cursor_position;
		float dot_score = dir * normalize(to_other);
		if (dot_score < 0)
			continue; // don't try to select elements that are behind

		float box_overlaps = fabs(dir.x) > fabs(dir.y) ?
			_cursor_position.y >= boxstart.y && _cursor_position.y <= boxend.y :
			_cursor_position.x >= boxstart.x && _cursor_position.x <= boxend.x;

		if (box_overlaps)
			dot_score = 1.0;
		else if (dot_score < 0.7)
			continue; // filter min dot more aggressively when box doesn't overlap direction

		float dist_score = 1 / vlen(to_other);
		float score = dot_score + dist_score;

		if (score > best_score)
		{
			best_score = score;
			best_element_index = i;
			best_pos = center;
		} 
	}

	if (best_score > 0)
	{
		_sui_mouse_move(best_pos, FALSE);	
	}
}

void(vector pos, vector size, string id, void(float index, vector click_ratios) action, float is_kb_nav_disabled = FALSE) sui_action_element =
{
	if (!_sui_draw_initialized) 
	{
		print("^1sui error: adding sui elements before sui_pre_draw!\n^1  Always do your sui menus between sui_pre_draw and sui_draw!\n");
	}
	if (_action_elements_index >= MAX_ACTION_ELEMENTS)
	{
		// Silently fail here, sui will let us know another way, increase the count
		// so that the error in click/mousemove handlers prints correct numbers.
		_action_elements_index += 1;
		return;
	}
	
	sui_transform_box(pos, size);
	
	if (_sui_is_clipping)
	{
		vector oldpos = pos;
		pos_x = max(pos_x, _sui_clip_area_mins_x);
		pos_y = max(pos_y, _sui_clip_area_mins_y);
		
		size -= pos - oldpos;
		
		size_x -= bound(0, (pos_x + size_x - _sui_clip_area_maxs_x), size_x);
		size_y -= bound(0, (pos_y + size_y - _sui_clip_area_maxs_y), size_y);
	}
	
	_action_elements[_action_elements_index].pos = pos;
	_action_elements[_action_elements_index].size = size;
	_action_elements[_action_elements_index].id = id;
	_action_elements[_action_elements_index].action = action;
	_action_elements[_action_elements_index].kb_nav_disabled = is_kb_nav_disabled;

	_action_elements_index += 1;
};


// Input related stuff

string _sui_binding_command;
string _sui_binding_command_name;

struct _input_t {
	float char;
	float scan;
};
const float MAX_INPUTS = 64;

_input_t _input_buffer[MAX_INPUTS];
float _input_index;
float _input_length;


// probably good to use it like while (sui_get_input(char, scan)) { ... };
float(__inout float char, __inout float scan) sui_get_input =
{
	if (_input_index >= _input_length) return FALSE;
	
	char = _input_buffer[_input_index].char;
	scan = _input_buffer[_input_index].scan;
	_input_index++;
	
	return TRUE;
};

// if 2 controls want to read the same input for some reason..
void() sui_reread_input =
{
	_input_index = 0;
};

void() sui_clear_input =
{
	_input_length = 0;
	_input_index = 0;
	_sui_kb_move_dir = '0 0 0';
};

vector(float scan) sui_input_dir =
{
	string cmd = getkeybind(scan);
	if (cmd == "+forward" || cmd == "+lookup" || scan == K_UPARROW || scan == K_GP_DPAD_UP)
		return '0 -1 0';
	if (cmd == "+back" || cmd == "+lookdown" || scan == K_DOWNARROW || scan == K_GP_DPAD_DOWN)
		return '0 1 0';
	if (cmd == "+moveleft" || cmd == "+lookleft" || scan == K_LEFTARROW || scan == K_GP_DPAD_LEFT)
		return '-1 0 0';
	if (cmd == "+moveright" || cmd == "+lookright" || scan == K_RIGHTARROW || scan == K_GP_DPAD_RIGHT)
		return '1 0 0';
	
	return '0 0 0';
}

float(float scan) sui_input_is_confirm =
{
	string cmd = getkeybind(scan);
	if (cmd == "+attack" || scan == K_ENTER || scan == K_GP_A)
		return TRUE;
	return FALSE;
}

float(float scan) sui_input_is_back =
{
	string cmd = getkeybind(scan);
	if (cmd == "togglemenu" || scan == K_ESCAPE || scan == K_BACKSPACE || scan == K_GP_B)
		return TRUE;
	return FALSE;
}


float(float char, float scan) _sui_add_input =
{
	// TODO check if input was listened, return FALSE if not
	if (_input_length >= MAX_INPUTS)
	{
		printf("^3sui warning: exceeded amount of per frame inputs count MAX_INPUTS = %.0f\n"
			"^3 - make sure sui_input_event isn't being called without sui_draw being called in update loop\n"
			"^3 - consider increasing MAX_INPUTS\n", MAX_INPUTS);
		return TRUE;
	}
	_input_buffer[_input_length].char = char;
	_input_buffer[_input_length].scan = scan;
	_input_length += 1;
	return TRUE;
};


float _scan_listens[MAX_INPUTS];
float _scan_listen_count;

// Listen to a certain keycode if it was pressed, this way sui know it was requested
float(float keycode) sui_listen_scan =
{
	_scan_listens[_scan_listen_count] = keycode;
	_scan_listen_count += 1;
	for (float i = 0; i < _input_length; i++)
	{
		if (_input_buffer[i].scan == keycode)
			return TRUE;
	}
	return FALSE;
};

float(string command) sui_listen_command =
{
	float num_binds = tokenize(findkeysforcommand(command));
	for (int i = 0; i < num_binds; i++)
	{
		float keycode = stof(argv(i));
		_scan_listens[_scan_listen_count] = keycode;
		_scan_listen_count += 1;
		for (int j = 0; j < _input_length; j++)
		{
			if (_input_buffer[j].scan == keycode)
			return TRUE;
		}
	}
	return FALSE;
};

float() sui_listen_up = 
{
	return sui_listen_scan(K_UPARROW)
		|| sui_listen_scan(K_GP_DPAD_UP)
		|| sui_listen_scan(K_GP_LTHUMB_UP)
		|| sui_listen_command("+forward");
}

float() sui_listen_down = 
{
	return sui_listen_scan(K_DOWNARROW)
		|| sui_listen_scan(K_GP_DPAD_DOWN)
		|| sui_listen_scan(K_GP_LTHUMB_DOWN)
		|| sui_listen_command("+back");
}

float() sui_listen_left = 
{
	return sui_listen_scan(K_LEFTARROW)
		|| sui_listen_scan(K_GP_DPAD_LEFT)
		|| sui_listen_scan(K_GP_LTHUMB_LEFT)
		|| sui_listen_command("+moveleft");
}

float() sui_listen_right = 
{
	return sui_listen_scan(K_RIGHTARROW)
		|| sui_listen_scan(K_GP_DPAD_RIGHT)
		|| sui_listen_scan(K_GP_LTHUMB_RIGHT)
		|| sui_listen_command("+moveright");
}

float() sui_listen_confirm =
{
	return sui_listen_scan(K_ENTER)
		|| sui_listen_scan(K_GP_A)
		|| sui_listen_command("+attack")
		|| sui_listen_command("+jump");
}

float() sui_listen_back =
{
	return sui_listen_scan(K_ESCAPE)
		|| sui_listen_scan(K_GP_B)
		|| sui_listen_command("togglemenu");
}

void() sui_menu_nav =
{
	if (sui_listen_up()) _cursor_kb_move('0 -1 0');
	if (sui_listen_down()) _cursor_kb_move('0 1 0');
	if (sui_listen_left()) _cursor_kb_move('-1 0 0');
	if (sui_listen_right()) _cursor_kb_move('1 0 0');
}

float(float scanx, float chary) sui_block_all =
{
	return TRUE;
}

float(float scanx, float chary) sui_block_none =
{
	return FALSE;
}

float(float scanx, float chary) sui_block_menu_navigation =
{
	vector movedirs = sui_input_dir(scanx);
	if (movedirs != '0 0 0') return TRUE;
	if (sui_input_is_confirm) return TRUE;
	if (sui_input_is_back) return TRUE;
	return FALSE;
}

float(float scanx, float chary) sui_block_listened =
{
	for (int i = 0; i < _scan_listen_count; i++)
	{
		if (_scan_listens[i] == scanx)
		{
			return TRUE;
		}
	}
	return FALSE;
}

// all text that was input between last and current frame
string() sui_listen_text_input =
{
	return "";
};

void(float char, float scan, __inout string text, __inout float cursor) sui_handle_text_input =
{
	float maxlen = 128;
	
	string prev = text;
	string pre_cursor, post_cursor;
	float length = strlen(prev);
	if (char > 31 && char < 128) //an actual input
	{
		if (length >= maxlen) return;
		pre_cursor = substring(prev, 0, cursor);
		post_cursor = substring(prev, cursor, length);
		
		text = sprintf("%s%s%s", pre_cursor, chr2str(char), post_cursor);
		cursor += 1;
	}
	else if (char == 8) // backspace
	{
		if (cursor <= 0) return;
		pre_cursor = substring(prev, 0, cursor - 1);
		post_cursor = substring(prev, cursor, length);
		cursor -= 1;
		cursor = max(0, cursor);
		text = strcat(pre_cursor, post_cursor);
	}
	else if (scan == K_DEL)
	{
		if (cursor >= length) return;
		pre_cursor = substring(prev, 0, cursor);
		post_cursor = substring(prev, cursor + 1, length);
		text = strcat(pre_cursor, post_cursor);
	}
	else if (char == 13 || char == 27) // enter or escape
	{
		// Commit and deselect...
		// Let's try a hack..
		_last_clicked_action_count = 0;
	}
	else if (scan == K_LEFTARROW)
	{
		cursor -= 1;
		cursor = max(0, cursor);
	}
	else if (scan == K_RIGHTARROW)
	{
		cursor += 1;
		cursor = min(strlen(prev), cursor);
	}
};

void(float maxlen, __inout string text, __inout float cursor) sui_cap_input_length =
{
	if (strlen(text) > maxlen)
	{
		text = substring(text, 0, strlen(text));
		cursor = strlen(text);
	}
};

void(string command) _sui_unbind =
{
	tokenize(findkeysforcommand(command));
	string keyname = keynumtostring(stof(argv(0)));
	string altkeyname = keynumtostring(stof(argv(1)));
	localcmd(sprintf("unbind %s\n", keyname));
	localcmd(sprintf("unbind %s\n", altkeyname));
};

void(float scan, string command) _sui_do_keybind =
{
	if (scan == K_ESCAPE) 
	{
		_sui_binding_command = "";
		_sui_binding_command_name = "";
		return;
	}
	if (scan == K_BACKSPACE)
	{
		_sui_unbind(command);
		_sui_binding_command = "";
		_sui_binding_command_name = "";
		return;
	}
	string keyname = keynumtostring(scan);
	_sui_unbind(command);
	localcmd(sprintf("bind %s %s\n", keyname, command));
	_sui_binding_command = "";
	_sui_binding_command_name = "";
};

void(string command, string command_name) sui_start_bind =
{
	_sui_binding_command = command;
	_sui_binding_command_name = command_name;
};


var float(float scanx, float chary) sui_block_input_fn = sui_block_listened;

// void(float evtype, float scanx, float chary, float devid) sui_input_event
//	 same args is CSQC_InputEvent.
//	 return value tells you if sui used the event or not, in case you want to
//	 not let engine handle it if it was used.
// Sets all the internal sui action stuff, call it in CSQC_InputEvent
float(float evtype, float scanx, float chary, float devid) sui_input_event =
{
	float mouse_hit = FALSE;
	switch (evtype)
	{
	case IE_MOUSEABS:
		_sui_mouse_move([scanx, chary]);
		return TRUE;
		break;
	case IE_MOUSEDELTA:
		// Big question mark...
		// maybe make our own delta based sui_cursor here..
		// maybe just ignore delta and let user fake mouseabs with their own
		// delta cursor by passing different params to this func...?
		// for MVP let's just use mouseabs only
		return FALSE;
		break;
	case IE_KEYDOWN:
		vector keydir = sui_input_dir(scanx);
		// We are binding, always swallow
		if (_sui_binding_command != "")
			return TRUE;
		// Swallow only if we hit an action element
		else if (scanx == K_MOUSE1)
			mouse_hit = _sui_mouse1_down();
		// Don't return anything from these, use sui_block_input_fn to deal with rest
		else if (sui_input_is_confirm(scanx))
			_sui_mouse1_down(FALSE);
		else
			_sui_add_input(chary, scanx);
		
		return mouse_hit || sui_block_input_fn(scanx, chary);
		break;
	case IE_KEYUP:
		if (_sui_binding_command != "")
		{
			_sui_do_keybind(scanx, _sui_binding_command);
			return TRUE;
		}
		else if (scanx == K_MOUSE1)
			mouse_hit = _sui_mouse1_up();
		else if (sui_input_is_confirm(scanx))
			_sui_mouse1_up(FALSE);
		return mouse_hit || sui_block_input_fn(scanx, chary);
		break;
	default: 
		break;
	}
	
	return FALSE;
};


// void() sui_pre_draw 
// Resets state for sui actions so that no trouble happens. 
// Call it before your menu code per frame in your draw/updateview.
void(float width, float height) sui_begin =
{
	_scan_listen_count = 0;
	_sui_hijacked_dirs = 0;
	_action_elements_index = 0;
	_sui_draw_initialized = TRUE;
	
	sui_reset_frame();
	sui_push_frame([0, 0], [width, height]);
}

void() sui_draw_bind_overlay;
void() sui_debug_draw_action_elements;

// void() sui_end
// Call after your menu code per frame in your draw/updateview.
void() sui_end =
{
	// Todo: move overlay drawing elsewhere:
	sui_draw_bind_overlay();

	// sui_debug_draw_action_elements();

	if (!_cursor_is_mouse_active)
	{
		_retarget_kb_cursor();
	}
	// Dirty part:
	_sui_draw_initialized = FALSE;
	// reset "once" type actions
	_click_action_count = 0;
	_release_action_count = 0;
	// empty input buffer
	sui_clear_input();
};


// Different draw components:

void(vector pos, vector size, vector color, float alpha, float flags) sui_fill =
{
	sui_transform_box(pos, size);
	
	drawfill(pos, size, color, alpha, flags);
};

void(vector pos, vector size, string pic, vector color, float alpha, float flags) sui_pic =
{
	sui_transform_box(pos, size);
	
	drawpic(pos, pic, size, color, alpha, flags);
};

void(vector pos, vector size, float width, vector color, float alpha, float flags) sui_border_box =
{
	sui_transform_box(pos, size);
	
	// Top line
	drawfill(pos, [size_x, width], color, alpha, flags);
	// Bottom line
	drawfill([pos_x, pos_y + size_y - width], [size_x, width], color, alpha, flags);
	// Left line
	drawfill([pos_x, pos_y + width], [width, size_y - width * 2], color, alpha, flags);
	// Right line
	drawfill([pos_x + size_x - width, pos_y + width], [width, size_y - width * 2], color, alpha, flags);
};


void(vector pos, vector size, string text, vector color, float alpha, float flags) sui_text =
{
	sui_transform_box(pos, [stringwidth(text, 1, size), size_y]);
	
	drawstring(pos, text, size, color, alpha, flags);
};

void(float index, vector click_ratios) sui_noop = {};

void(float value) sui_slider_noop = {};

float(string id, vector pos, vector size, vector minmaxsteps, float value, void(float value) action) sui_slidercontrol =
{
	sui_action_element(pos, size, id, sui_noop);
	float newvalue = value;
	
	sui_transform_box(pos, size);

	// user is clicking and holding the slider
	if (sui_is_held(id))
	{
		float minval = minmaxsteps[0];
		float maxval = minmaxsteps[1];
		float steps = minmaxsteps[2];
		float click_ratio = (_cursor_position_x - pos_x) / size_x;
		click_ratio = bound(0, click_ratio, 1);
		if (steps > 0) click_ratio = rint(click_ratio * steps) / steps;
		newvalue = minval + click_ratio * (maxval - minval);
		if (newvalue != value) action(newvalue);
	}
	else if (sui_is_hovered(id))
	{
		sui_hijack_kb_nav(KB_DIR_LEFT);
		sui_hijack_kb_nav(KB_DIR_RIGHT);

		float step = minmaxsteps[2] > 0
			? (minmaxsteps[1] - minmaxsteps[0]) / minmaxsteps[2]
			: max(0.01, (minmaxsteps[1] - minmaxsteps[0]) / size.x);
		
		if (sui_listen_left())
			newvalue -= step;
		if (sui_listen_right())
			newvalue += step;
		
		newvalue = bound(minmaxsteps[0], newvalue, minmaxsteps[1]);
		if (newvalue != value) action(newvalue);
	}
	return newvalue;
};

void(string id, vector pos, vector size, __inout string text, __inout float cursor) sui_text_input =
{
	sui_action_element(pos, size, id, sui_noop);
	if (sui_is_clicked(id)) cursor = strlen(text);
	if (sui_is_last_clicked(id))
	{
		float char = 0;
		float scan = 0;
		while(sui_get_input(char, scan)) sui_handle_text_input(char, scan, text, cursor);
	}
};


void(string id, vector size, vector contentsize, __inout vector offset, vector scrollbar_widths) sui_scrollbar =
{
	vector maxoffset = contentsize - size;
	maxoffset_x = max(0, maxoffset_x);
	maxoffset_y = max(0, maxoffset_y);
	sui_push_frame([0, 0], size);
	float ofs;
	float length;
	vector barpos, barsize;
	float scan = 0;
	float char = 0;
	string barname;
	if (maxoffset_y > 0 && contentsize_y > 0)
	{
		sui_set_align([SUI_ALIGN_END, SUI_ALIGN_START]);
		sui_push_frame([0, 0], [scrollbar_widths_y, size_y]);
		ofs = (offset_y / contentsize_y) * size_y;
		length = (size_y / contentsize_y) * size_y;
		barpos = [0, ofs];
		barsize = [scrollbar_widths_y, length];
		barname = strcat(id, "vbar");
		
		if (sui_is_held(barname))
		{
			vector anchor = barpos + _cursor_relative_click;
			sui_transform_point(anchor);
			float diff = _cursor_position_y - anchor_y;
			offset_y += (diff * contentsize_y) / size_y; //  * contentsize_y; // (size_y / contentsize_y);
		}

		sui_fill(barpos, barsize, '0.1 0.1 0.1' * (1 - sui_is_hovered(barname)), 0.66, 0);
		sui_action_element(barpos, barsize, barname, sui_noop, TRUE);
		sui_pop_frame();
	} 
	sui_pop_frame();
};

void(string id, vector pos, vector size, vector contentsize, __inout vector offset, vector scrollbar_widths, float scroll_step = 22) sui_scroll_view_begin =
{
	// make space for scrollbars
	sui_push_frame(pos, size - [scrollbar_widths_y, scrollbar_widths_x]);
	sui_action_element([0, 0], size, id, sui_noop, TRUE);
	
	if (sui_hover_index(id) > -1)
	{		
		vector boxmin = '0 0 0';
		vector boxmax = size;
		sui_transform_point(boxmin);
		sui_transform_point(boxmax);
		if ((boxmax.y - _cursor_position.y) <= scroll_step && _sui_kb_move_dir.y > 0) offset_y += scroll_step;
		if ((_cursor_position.y - boxmin.y) <= scroll_step && _sui_kb_move_dir.y < 0) offset_y -= scroll_step;

		float scrollamount = 0;
		float char = 0;
		float scan = 0;
		sui_reread_input();
		while (sui_get_input(char, scan))
		{
			string cmd = getkeybind(scan);
			if (scan == K_MWHEELUP)
				scrollamount -= scroll_step;
			if (scan == K_MWHEELDOWN)
				scrollamount += scroll_step;
			if ((boxmax.y - _cursor_position.y) <= scroll_step * 2 && sui_listen_down())
				scrollamount += scroll_step;
			if ((_cursor_position.y - boxmin.y) <= scroll_step * 2 && sui_listen_up())
				scrollamount -= scroll_step;

		}
		offset_y += scrollamount;
	}
	
	vector maxoffset = contentsize - size;
	maxoffset_x = max(0, maxoffset_x);
	maxoffset_y = max(0, maxoffset_y);
	offset_x = bound(0, offset_x, maxoffset_x);
	offset_y = bound(0, offset_y, maxoffset_y);

	sui_scrollbar(id, size, contentsize, offset, scrollbar_widths);
	
	offset_x = bound(0, offset_x, maxoffset_x);
	offset_y = bound(0, offset_y, maxoffset_y);
	
	sui_clip_to_frame();
	

	sui_push_frame(-1 * offset, contentsize);
};

void() sui_scroll_view_end =
{
	sui_pop_frame();
	sui_reset_clip();
	sui_pop_frame();
};

float _sui_list_item_height;
float _sui_list_first;
float _sui_list_last;
float _sui_list_pos;
int _sui_list_index;
void(string id, vector pos, vector size, vector itemsize, float numitems, __inout vector offset, vector scrollbar_widths) sui_list_view_begin =
{
	vector contentsize = [itemsize_x, itemsize_y * numitems];
	sui_scroll_view_begin(id, pos, size, contentsize, offset, scrollbar_widths, itemsize.y);
	
	_sui_list_item_height = itemsize_y;
	float hidden_above = floor(offset_y / itemsize_y);
	_sui_list_first = max(0, hidden_above); // Index of first elem
	_sui_list_last = min(_sui_list_first + rint(size_y / itemsize_y) + 1, numitems);
	_sui_list_pos = hidden_above * itemsize_y;
	_sui_list_index = _sui_list_first;
};

float(__inout vector pos) sui_list_item =
{
	if (_sui_list_index >= _sui_list_last) return -1;
	pos = _sui_list_index * [0, _sui_list_item_height];
	_sui_list_index += 1;
	return _sui_list_index - 1;
};

void() sui_list_view_end =
{
	sui_scroll_view_end();
};

string(string id, vector pos, vector size, string name, string command) sui_binder =
{
	sui_action_element(pos, size, id, sui_noop);
	if (sui_is_released(id))
	{
		sui_start_bind(command, name);
	}
	
	tokenize(findkeysforcommand(command));
	string keyname = keynumtostring(stof(argv(0)));
	if (keyname == "01") keyname = "unbound";
	
	return keyname;
};

void() sui_draw_bind_overlay =
{
	if (_sui_binding_command != "")
	{
		vector size = sui_current_frame_size();
		sui_fill([0, 0], size, '0 0 0', 0.5, 0);
		sui_set_align([SUI_ALIGN_CENTER, SUI_ALIGN_CENTER]);
		float textsize = 16;
		sui_text([0, -16], [textsize, textsize], "Press a key for", '1 1 1', 1, 0);
		sui_text([0, 0], [textsize, textsize], sprintf("'%s'", _sui_binding_command_name), '1 1 1', 1, 0);
		sui_text([0, 16], [textsize - 4, textsize - 4], "ESC to cancel, BACKSPACE to remove", '1 1 1', 1, 0);
	}
};

void() sui_debug_draw_action_elements =
{
	while (_frame_index > 1)
		sui_pop_frame();
	sui_reset_align();

	for (int i = 0; i < _action_elements_index; i++)
	{
		sui_border_box(_action_elements[i].pos, _action_elements[i].size, 1, '1 0 0', 0.25, 0);
		sui_fill(_action_elements[i].pos + _action_elements[i].size * 0.5 - [1, 1], [2, 2], '0 1 0', 0.5, 0);
		sui_push_frame(_action_elements[i].pos, _action_elements[i].size);
		sui_set_align([SUI_ALIGN_CENTER, SUI_ALIGN_CENTER]);
		sui_text([0, -4], [8, 8], _action_elements[i].id, '1 0 0', 0.75, 0);
		sui_pop_frame();
	}
}


// -------------------- END OF SUI SYSTEM STUFF --------------------