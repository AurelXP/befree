class_name Player
extends Node3D
## Caméra du prisonnier : points de vue dans la cellule, regard libre au doigt/souris,
## tap pour interagir, appui prolongé sur le trou pour creuser.

signal tapped(id: String)
signal dig_hold(active: bool)

const LOOK_YAW: float = 1.0
const LOOK_PITCH: float = 0.55
const TAP_MOVE_PX: float = 14.0
const TAP_TIME: float = 0.45

var cam: Camera3D
var hands: Hands
var station: String = "center"
var input_enabled: bool = false
var cinematic: bool = false

var _pos: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = 0.0
var _yaw_off: float = 0.0
var _pitch_off: float = 0.0
var _move_tween: Tween
var _pressed: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_time: float = 0.0
var _dragging: bool = false
var _digging: bool = false
var _shake: float = 0.0
var _shake_t: float = 0.0
var _bob: float = 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.04
	cam.far = 40.0
	cam.current = true
	add_child(cam)
	hands = Hands.new()
	cam.add_child(hands)
	snap_to("center")


func _dir_angles(from: Vector3, to: Vector3) -> Vector2:
	var d: Vector3 = (to - from).normalized()
	return Vector2(asin(clampf(d.y, -1.0, 1.0)), atan2(-d.x, -d.z))


func snap_to(st: String) -> void:
	station = st
	var s: Dictionary = Cell.STATIONS[st]
	_pos = s["pos"]
	var a: Vector2 = _dir_angles(_pos, s["look"])
	_pitch = a.x
	_yaw = a.y
	_yaw_off = 0.0
	_pitch_off = 0.0


## Se déplace vers un point de vue (attendre avec await).
func go_to(st: String, dur: float = 0.7) -> void:
	if st == station and _move_tween == null:
		return
	station = st
	var s: Dictionary = Cell.STATIONS[st]
	var from_pos: Vector3 = _pos
	var from_yaw: float = _yaw + _yaw_off
	var from_pitch: float = _pitch + _pitch_off
	var to_pos: Vector3 = s["pos"]
	var a: Vector2 = _dir_angles(to_pos, s["look"])
	_yaw_off = 0.0
	_pitch_off = 0.0
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_method(_apply_move.bind(from_pos, to_pos, from_yaw, a.y, from_pitch, a.x), 0.0, 1.0, dur)
	await _move_tween.finished
	_move_tween = null


func _apply_move(t: float, fp: Vector3, tp: Vector3, fy: float, ty: float, fpi: float, tpi: float) -> void:
	_pos = fp.lerp(tp, t)
	_yaw = lerp_angle(fy, ty, t)
	_pitch = lerpf(fpi, tpi, t)


func shake(strength: float, duration: float) -> void:
	_shake = strength
	_shake_t = duration


func _process(delta: float) -> void:
	if cinematic:
		return
	_bob += delta
	var p: Vector3 = _pos
	var yaw: float = _yaw + _yaw_off
	var pitch: float = _pitch + _pitch_off
	# respiration légère
	p.y += sin(_bob * 1.4) * 0.004
	var roll: float = 0.0
	if _shake_t > 0.0:
		_shake_t -= delta
		var k: float = clampf(_shake_t, 0.0, 1.0)
		p += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * k * 0.1
		roll = randf_range(-1, 1) * _shake * k * 0.2
	if _digging:
		p += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.0015
	cam.position = p
	cam.rotation = Vector3(pitch, yaw, roll)


func hit_id(screen_pos: Vector2) -> String:
	var origin: Vector3 = cam.project_ray_origin(screen_pos)
	var end: Vector3 = origin + cam.project_ray_normal(screen_pos) * 6.0
	var q := PhysicsRayQueryParameters3D.create(origin, end, 2)
	var r: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return ""
	var c: Object = r["collider"]
	if c != null and c.has_meta("id"):
		return str(c.get_meta("id"))
	return ""


func stop_digging() -> void:
	if _digging:
		_digging = false
		dig_hold.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or cinematic:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_dragging = false
			_press_pos = event.position
			_press_time = Time.get_ticks_msec() / 1000.0
			if station == "wall" and _move_tween == null and Game.poster_moved and Game.spoon_equipped:
				if hit_id(event.position) == "hole":
					_digging = true
					dig_hold.emit(true)
		else:
			if not _pressed:
				return
			_pressed = false
			if _digging:
				_digging = false
				dig_hold.emit(false)
				return
			var dt: float = Time.get_ticks_msec() / 1000.0 - _press_time
			if not _dragging and dt < TAP_TIME:
				tapped.emit(hit_id(event.position))
	elif event is InputEventMouseMotion and _pressed and not _digging:
		if not _dragging and event.position.distance_to(_press_pos) > TAP_MOVE_PX:
			_dragging = true
		if _dragging:
			_yaw_off = clampf(_yaw_off - event.relative.x * 0.0035, -LOOK_YAW, LOOK_YAW)
			_pitch_off = clampf(_pitch_off - event.relative.y * 0.0035, -LOOK_PITCH, LOOK_PITCH)
