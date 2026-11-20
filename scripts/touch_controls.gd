class_name TouchControls
extends Control
## Contrôles façon Roblox : joystick flottant à gauche, glisser à droite pour regarder.
## Multi-touch réel (ScreenTouch / ScreenDrag) ; la souris réelle sert pour le bureau et les tests.
## Les événements souris émulés depuis le tactile (device == -1) sont ignorés ici.

signal jump_pressed

const JOY_RADIUS: float = 95.0
const MOUSE_ID: int = -100
const LOOK_SENS: float = 0.0042

var enabled: bool = false
var move: Vector2 = Vector2.ZERO  # x = droite, y = avant (-1 = avancer)
var blockers: Array = []  # Control : zones d'interface qui captent le doigt

var _joy_id: int = -999
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_pos: Vector2 = Vector2.ZERO
var _look_id: int = -999
var _look: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_enabled(v: bool) -> void:
	enabled = v
	if not v:
		_joy_id = -999
		_look_id = -999
		move = Vector2.ZERO
		_look = Vector2.ZERO
		queue_redraw()


## Renvoie (et remet à zéro) le déplacement de regard accumulé, en radians (x = lacet, y = tangage).
func consume_look() -> Vector2:
	var l: Vector2 = _look
	_look = Vector2.ZERO
	return l


func _over_ui(pos: Vector2) -> bool:
	for b in blockers:
		var c: Control = b
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


func _down(id: int, pos: Vector2) -> void:
	if _over_ui(pos):
		return
	var w: float = get_viewport_rect().size.x
	if pos.x < w * 0.45:
		if _joy_id == -999:
			_joy_id = id
			_joy_origin = pos
			_joy_pos = pos
			move = Vector2.ZERO
			queue_redraw()
	elif _look_id == -999:
		_look_id = id


func _moved(id: int, pos: Vector2, rel: Vector2) -> void:
	if id == _joy_id:
		_joy_pos = pos
		var off: Vector2 = pos - _joy_origin
		if off.length() > JOY_RADIUS:
			_joy_origin += off.normalized() * (off.length() - JOY_RADIUS)
			off = pos - _joy_origin
		move = off / JOY_RADIUS
		if move.length() < 0.12:
			move = Vector2.ZERO
		queue_redraw()
	elif id == _look_id:
		_look += Vector2(-rel.x, -rel.y) * LOOK_SENS


func _up(id: int) -> void:
	if id == _joy_id:
		_joy_id = -999
		move = Vector2.ZERO
		queue_redraw()
	elif id == _look_id:
		_look_id = -999


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index)
	elif event is InputEventScreenDrag:
		_moved(event.index, event.position, event.relative)
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down(MOUSE_ID, event.position)
		else:
			_up(MOUSE_ID)
	elif event is InputEventMouseMotion and event.device != -1:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_moved(MOUSE_ID, event.position, event.relative)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		jump_pressed.emit()


func _process(_delta: float) -> void:
	if not enabled or _joy_id != -999:
		return
	# clavier (bureau / tests)
	var k := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		k.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		k.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		k.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		k.x += 1.0
	move = k.normalized() if k != Vector2.ZERO else Vector2.ZERO


func _draw() -> void:
	if not enabled:
		return
	if _joy_id != -999:
		draw_circle(_joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.12))
		draw_arc(_joy_origin, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0)
		draw_circle(_joy_pos, 38.0, Color(1, 1, 1, 0.45))
	else:
		var h: float = get_viewport_rect().size.y
		var c := Vector2(150.0, h - 150.0)
		draw_arc(c, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 3.0)
		draw_circle(c, 34.0, Color(1, 1, 1, 0.15))
