class_name Player
extends Node3D
## Le prisonnier : corps physique (CharacterBody3D), caméra à la première personne
## avec les mains. Reste à l'origine ; le corps et la caméra se déplacent.

const HEIGHT: float = 1.62
const WALK_SPEED: float = 3.4
const BOOST_SPEED: float = 5.2
const GRAVITY: float = 16.0
const JUMP_V: float = 5.2
const PITCH_LIMIT: float = 1.25

var body: CharacterBody3D
var cam: Camera3D
var hands: Hands
var controls: TouchControls
var input_enabled: bool = false
var cinematic: bool = false
var locked: bool = false  # immobilisé (action en cours)
var boost: bool = false

var yaw: float = 0.0
var pitch: float = 0.0

var _bob: float = 0.0
var _shake: float = 0.0
var _shake_t: float = 0.0
var _face_tween: Tween
var _moving: bool = false


func _ready() -> void:
	body = CharacterBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 1 | 4
	body.floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	body.add_child(cs)
	add_child(body)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.04
	cam.far = 90.0
	cam.current = true
	add_child(cam)
	hands = Hands.new()
	cam.add_child(hands)
	teleport(World.SPAWN, 0.0)


func pos() -> Vector3:
	return body.global_position


func head_pos() -> Vector3:
	return body.global_position + Vector3(0, HEIGHT, 0)


func teleport(p: Vector3, new_yaw: float = 0.0) -> void:
	body.global_position = p
	body.velocity = Vector3.ZERO
	yaw = new_yaw
	pitch = 0.0
	if cam != null:
		_follow(0.0)


## Compatibilité (cinématique) : retour au point de départ dans la cellule.
func snap_to(_name: String = "center") -> void:
	teleport(World.SPAWN, 0.0)


func jump() -> void:
	if input_enabled and not cinematic and not locked and body.is_on_floor():
		body.velocity.y = JUMP_V


## Tourne doucement vers un point (ex. le mur à creuser).
func face_toward(target: Vector3, dur: float = 0.35) -> void:
	var d: Vector3 = target - head_pos()
	var ty: float = atan2(-d.x, -d.z)
	var tp: float = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.5, 0.5)
	if _face_tween != null and _face_tween.is_valid():
		_face_tween.kill()
	var fy: float = yaw
	var fp: float = pitch
	_face_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_face_tween.tween_method(_apply_face.bind(fy, ty, fp, tp), 0.0, 1.0, dur)


func _apply_face(t: float, fy: float, ty: float, fp: float, tp: float) -> void:
	yaw = lerp_angle(fy, ty, t)
	pitch = lerpf(fp, tp, t)


func shake(strength: float, duration: float) -> void:
	_shake = strength
	_shake_t = duration


func _physics_process(delta: float) -> void:
	if cinematic:
		return
	var dir := Vector3.ZERO
	if input_enabled and not locked and controls != null:
		var m: Vector2 = controls.move
		dir = Basis(Vector3.UP, yaw) * Vector3(m.x, 0.0, m.y)
	var spd: float = BOOST_SPEED if boost else WALK_SPEED
	body.velocity.x = lerpf(body.velocity.x, dir.x * spd, 1.0 - exp(-delta * 14.0))
	body.velocity.z = lerpf(body.velocity.z, dir.z * spd, 1.0 - exp(-delta * 14.0))
	if not body.is_on_floor():
		body.velocity.y -= GRAVITY * delta
	elif body.velocity.y < 0.0:
		body.velocity.y = 0.0
	body.move_and_slide()
	_moving = Vector2(body.velocity.x, body.velocity.z).length() > 0.5 and body.is_on_floor()


func _process(delta: float) -> void:
	if cinematic:
		return
	if controls != null and input_enabled and not locked:
		var l: Vector2 = controls.consume_look()
		yaw += l.x
		pitch = clampf(pitch + l.y, -PITCH_LIMIT, PITCH_LIMIT)
	elif controls != null:
		controls.consume_look()
	_follow(delta)


func _follow(delta: float) -> void:
	_bob += delta * (9.0 if _moving else 1.4)
	var p: Vector3 = body.global_position + Vector3(0, HEIGHT, 0)
	p.y += sin(_bob) * (0.035 if _moving else 0.004)
	var roll: float = 0.0
	if _shake_t > 0.0:
		_shake_t -= delta
		var k: float = clampf(_shake_t, 0.0, 1.0)
		p += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * k * 0.1
		roll = randf_range(-1, 1) * _shake * k * 0.2
	cam.position = p
	cam.rotation = Vector3(pitch, yaw, roll)
