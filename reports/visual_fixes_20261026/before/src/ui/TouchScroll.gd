extends ScrollContainer
## Capture a deliberate drag before child buttons consume it; taps and wheel stay native.
var _pointer := -2
var _origin := Vector2.ZERO
var _offset := 0.0
var _dragging := false
var _recent_until := 0
var _velocity := 0.0

func _ready() -> void:
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	vertical_scroll_mode = SCROLL_MODE_AUTO
	scroll_deadzone = 10
	follow_focus = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_v_scroll_bar().custom_minimum_size.x = 5

func gesture_active() -> bool:
	return _pointer != -2 or _dragging or Time.get_ticks_msec() < _recent_until

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin(event.index,event.position)
		elif event.index == _pointer:
			_end()
	elif event is InputEventScreenDrag and event.index == _pointer:
		_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == -1:return
		if event.pressed:_begin(-1,event.position)
		elif _pointer == -1:_end()
	elif event is InputEventMouseMotion and _pointer == -1:
		_drag(event.position)

func _begin(pointer: int, at: Vector2) -> void:
	if _pointer != -2 or not get_global_rect().has_point(at):return
	var top := get_viewport().gui_get_hovered_control()
	if top != null and top.get_global_rect().has_point(at) and top != self and not is_ancestor_of(top):return
	_pointer = pointer
	_origin = at
	_offset = scroll_vertical
	_velocity = 0.0
	_dragging = false

func _drag(at: Vector2) -> void:
	var delta := (at.y-_origin.y)/maxf(.01,get_global_transform().get_scale().y)
	if not _dragging and absf(delta)<10:return
	if not _dragging:
		_dragging = true
		propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	var before := scroll_vertical
	scroll_vertical = roundi(_offset-delta)
	_velocity = lerpf(_velocity,float(scroll_vertical-before)*60.0,.45)
	_recent_until = Time.get_ticks_msec()+180
	get_viewport().set_input_as_handled()

func _end() -> void:
	if _dragging:
		_recent_until = Time.get_ticks_msec()+180
		propagate_notification(Control.NOTIFICATION_SCROLL_END)
		get_viewport().set_input_as_handled()
	_pointer = -2
	_dragging = false

func _process(delta: float) -> void:
	if _pointer != -2 or absf(_velocity)<3:return
	var before := scroll_vertical
	scroll_vertical += roundi(_velocity*delta)
	_velocity = move_toward(_velocity,0,1800*delta)
	if before == scroll_vertical:_velocity = 0
