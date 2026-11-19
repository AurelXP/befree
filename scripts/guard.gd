class_name Guard
extends Node3D
## Gaston, le garde (très) enrobé, sa matraque et ses habitudes.
## Le modèle regarde vers +Z (donc vers la cellule quand il est assis à son poste).

signal arrived
signal swing_hit
signal attack_done

enum S { WATCH, READ, SNACK, DOZE, WARN, ATTACK }

const SEAT: Vector3 = Vector3(0.6, 0.0, -3.45)
const DOOR_SPOT: Vector3 = Vector3(0.0, 0.0, -2.75)
const SIT_DROP: float = -0.45
const WALK_SPEED: float = 1.3

var mode: String = "cycle"  # cycle | stand | doze
var state: int = S.WATCH
var gaze: Vector3 = Vector3(0, 1.5, 0.7)

var rig: Node3D
var head: Node3D
var thigh: Array = []
var shin: Array = []
var arm_r: Node3D
var fore_r: Node3D
var arm_l: Node3D
var fore_l: Node3D
var belly: MeshInstance3D
var torso: MeshInstance3D
var eyes: Array = []
var paper: Node3D
var donut: Node3D
var zzz: Label3D
var bubble: Label3D

var _t: float = 0.0
var _state_time: float = 0.0
var _state_dur: float = 6.0
var _target: Vector3 = SEAT
var _walking: bool = false
var _busy: bool = false
var _sit: float = 1.0
var _sit_goal: float = 1.0
var _yaw_goal: float = 0.0
var _swing: float = 0.0
var _bubble_tween: Tween

var _p_head_pitch: float = 0.0
var _p_head_yaw: float = 0.0
var _p_rsh: float = 0.0
var _p_rel: float = 0.0
var _p_lsh: float = 0.0
var _p_lel: float = 0.0


func _ready() -> void:
	build()
	position = SEAT
	_pick_state(S.WATCH)


func build() -> void:
	var skin_m: StandardMaterial3D = Bld.mat(Tex.skin(), Color(1.0, 0.92, 0.9), 0.7)
	var shirt_m: StandardMaterial3D = Bld.mat(Tex.fabric(Color(0.3, 0.42, 0.68), Color(0.3, 0.42, 0.68)), Color.WHITE, 0.9)
	var pants_m: StandardMaterial3D = Bld.mat(Tex.fabric(Color(0.12, 0.14, 0.24), Color(0.12, 0.14, 0.24)), Color.WHITE, 0.9)
	var dark_m: StandardMaterial3D = Bld.mat(null, Color(0.06, 0.06, 0.07), 0.5, 0.2)
	var cap_m: StandardMaterial3D = Bld.mat(Tex.fabric(Color(0.1, 0.13, 0.25), Color(0.1, 0.13, 0.25)), Color.WHITE, 0.8)
	var gold_m: StandardMaterial3D = Bld.mat(null, Color(0.9, 0.75, 0.25), 0.3, 0.8)
	var pink_m: StandardMaterial3D = Bld.mat(null, Color(0.95, 0.62, 0.58), 0.7)

	rig = Node3D.new()
	add_child(rig)

	# jambes
	for side in [-1.0, 1.0]:
		var th: Node3D = _limb(rig, Vector3(0.22 * side, 0.95, 0), 0.17, 0.45, pants_m)
		var sh: Node3D = _limb(th, Vector3(0, -0.45, 0), 0.15, 0.5, pants_m)
		Bld.box(sh, Vector3(0.22, 0.12, 0.36), Vector3(0, -0.52, 0.08), dark_m)
		thigh.append(th)
		shin.append(sh)

	# tronc : gros ventre
	torso = Bld.sph(rig, 0.55, Vector3(0, 1.45, 0), shirt_m, Vector3(1.2, 1.0, 1.0), "torso")
	belly = Bld.sph(rig, 0.62, Vector3(0, 1.2, 0.3), shirt_m, Vector3(1.12, 1.0, 1.0), "belly")
	Bld.sph(rig, 0.52, Vector3(0, 1.0, -0.05), pants_m, Vector3(1.15, 0.7, 1.0))
	Bld.cyl(rig, 0.66, 0.07, Vector3(0, 0.98, 0.15), dark_m)
	Bld.box(rig, Vector3(0.14, 0.1, 0.03), Vector3(0, 0.98, 0.8), gold_m)
	# boutons qui tiennent à peine + bout de ventre à l'air
	Bld.sph(rig, 0.1, Vector3(0, 1.05, 0.78), skin_m, Vector3(1.8, 0.7, 0.5))
	for by in [1.35, 1.52, 1.7]:
		var z: float = 0.28 + sqrt(maxf(0.0, 0.62 * 0.62 - (by - 1.2) * (by - 1.2))) - 0.02
		Bld.sph(rig, 0.025, Vector3(0, by, z), gold_m)
	# badge
	Bld.box(rig, Vector3(0.1, 0.12, 0.02), Vector3(-0.3, 1.78, 0.52), gold_m, Vector3(0, -20, 0))

	# tête
	head = Node3D.new()
	head.position = Vector3(0, 1.98, 0.08)
	rig.add_child(head)
	Bld.sph(head, 0.27, Vector3(0, 0.05, 0), skin_m, Vector3(1.1, 1.0, 1.05))
	Bld.sph(head, 0.2, Vector3(0, -0.17, 0.1), skin_m, Vector3(1.3, 0.8, 1.0))
	Bld.sph(head, 0.14, Vector3(0.17, -0.03, 0.15), pink_m)
	Bld.sph(head, 0.14, Vector3(-0.17, -0.03, 0.15), pink_m)
	Bld.sph(head, 0.065, Vector3(0, 0.0, 0.3), pink_m)
	Bld.sph(head, 0.06, Vector3(0.3, 0.02, 0), skin_m)
	Bld.sph(head, 0.06, Vector3(-0.3, 0.02, 0), skin_m)
	for side in [-1.0, 1.0]:
		var eye: MeshInstance3D = Bld.sph(head, 0.045, Vector3(0.1 * side, 0.1, 0.24), Bld.mat(null, Color(0.97, 0.97, 0.95), 0.3))
		Bld.sph(eye, 0.022, Vector3(0, 0, 0.034), dark_m)
		eyes.append(eye)
		Bld.box(head, Vector3(0.12, 0.025, 0.03), Vector3(0.1 * side, 0.17, 0.26), Bld.mat(null, Color(0.25, 0.15, 0.08), 0.9), Vector3(0, 0, -12 * side))
	Bld.box(head, Vector3(0.26, 0.05, 0.07), Vector3(0, -0.08, 0.29), Bld.mat(null, Color(0.25, 0.15, 0.08), 0.9))
	# casquette
	Bld.sph(head, 0.29, Vector3(0, 0.2, 0), cap_m, Vector3(1.05, 0.6, 1.05))
	Bld.box(head, Vector3(0.42, 0.02, 0.2), Vector3(0, 0.16, 0.3), dark_m, Vector3(8, 0, 0))
	Bld.box(head, Vector3(0.08, 0.07, 0.02), Vector3(0, 0.24, 0.31), gold_m)

	# bras
	for side in [-1.0, 1.0]:
		var a: Node3D = _limb(rig, Vector3(0.72 * side, 1.75, 0.05), 0.15, 0.5, shirt_m)
		a.rotation_degrees.z = 12.0 * side
		var f: Node3D = _limb(a, Vector3(0, -0.5, 0), 0.12, 0.42, skin_m)
		Bld.sph(f, 0.1, Vector3(0, -0.45, 0), skin_m)
		if side > 0:
			arm_r = a
			fore_r = f
		else:
			arm_l = a
			fore_l = f
	# matraque dans la main droite
	var baton: Node3D = Node3D.new()
	baton.position = Vector3(0, -0.45, 0)
	baton.rotation_degrees = Vector3(90, 0, 0)
	fore_r.add_child(baton)
	Bld.cyl(baton, 0.032, 0.62, Vector3(0, 0.2, 0), dark_m)
	Bld.cyl(baton, 0.036, 0.16, Vector3(0, -0.14, 0), Bld.mat(null, Color(0.85, 0.85, 0.85), 0.6))
	# beignet dans la main gauche
	donut = Node3D.new()
	donut.position = Vector3(0, -0.5, 0.08)
	donut.visible = false
	fore_l.add_child(donut)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.025
	tm.outer_radius = 0.07
	var dmi := MeshInstance3D.new()
	dmi.mesh = tm
	dmi.material_override = Bld.mat(null, Color(0.95, 0.6, 0.72), 0.6)
	donut.add_child(dmi)

	# journal tenu devant le visage
	paper = Node3D.new()
	paper.position = Vector3(0, 1.78, 1.0)
	paper.rotation_degrees = Vector3(-12, 0, 0)
	paper.visible = false
	rig.add_child(paper)
	var nm := StandardMaterial3D.new()
	nm.albedo_texture = Tex.newspaper()
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	nm.roughness = 0.9
	Bld.quad(paper, Vector2(0.75, 1.0), Vector3.ZERO, nm)

	# Zzz et bulle de dialogue
	zzz = Label3D.new()
	zzz.text = "Zzz..."
	zzz.font_size = 56
	zzz.pixel_size = 0.006
	zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zzz.modulate = Color(0.8, 0.9, 1.0)
	zzz.outline_size = 10
	zzz.position = Vector3(0.35, 2.75, 0.2)
	zzz.visible = false
	rig.add_child(zzz)
	bubble = Label3D.new()
	bubble.font_size = 56
	bubble.pixel_size = 0.006
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.modulate = Color(1.0, 0.9, 0.35)
	bubble.outline_size = 14
	bubble.no_depth_test = true
	bubble.position = Vector3(0, 3.0, 0)
	bubble.visible = false
	rig.add_child(bubble)


## Un membre : pivot en haut, cylindre vers le bas + articulation arrondie.
func _limb(parent: Node3D, pos: Vector3, radius: float, length: float, m: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	Bld.cyl(pivot, radius, length, Vector3(0, -length * 0.5, 0), m, Vector3.ZERO, radius * 0.88)
	Bld.sph(pivot, radius * 0.88, Vector3(0, -length, 0), m)
	return pivot


# ------------------------------------------------------------------ API

## Perception : x = vue, y = ouïe (0..1).
func awareness() -> Vector2:
	if _busy:
		return Vector2(0.0, 0.0)
	match state:
		S.WATCH:
			return Vector2(1.0, 1.0)
		S.READ:
			return Vector2(0.15, 0.6)
		S.SNACK:
			return Vector2(0.15, 0.55)
		S.WARN:
			return Vector2(0.6, 0.6)
		S.DOZE:
			return Vector2(0.04, 0.15)
	return Vector2(0.0, 0.0)


func is_looking() -> bool:
	return not _busy and (state == S.WATCH or state == S.WARN)


func say(text: String, duration: float = 2.5) -> void:
	bubble.text = text
	bubble.visible = true
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_interval(duration)
	_bubble_tween.tween_callback(func() -> void: bubble.visible = false)


func set_mode(m: String) -> void:
	if _busy:
		return
	mode = m
	if m == "stand":
		_target = DOOR_SPOT
	else:
		_target = SEAT
	_walking = position.distance_to(_target) > 0.05
	if _walking:
		_sit_goal = 0.0
	else:
		_arrive()
	_pick_state(S.DOZE if m == "doze" else S.WATCH)


func walk_to(p: Vector3) -> void:
	_target = p
	_walking = true
	_sit_goal = 0.0
	await arrived


## Séquence de coup de matraque : entre dans la cellule, frappe, ressort.
func attack(cell: Cell, victim: Vector3) -> void:
	_busy = true
	state = S.ATTACK
	zzz.visible = false
	paper.visible = false
	donut.visible = false
	say("ÇA SUFFIT !", 1.6)
	cell.open_door(true)
	await get_tree().create_timer(0.6).timeout
	await walk_to(Vector3(0.1, 0.0, -1.8))
	var stop: Vector3 = Vector3(clampf(victim.x, -1.0, 1.0), 0.0, clampf(victim.z - 1.15, -1.5, 0.8))
	await walk_to(stop)
	var d: Vector3 = victim - position
	_yaw_goal = atan2(d.x, d.z)
	await get_tree().create_timer(0.35).timeout
	_swing = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "_swing", -1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_swing", 1.0, 0.16).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void: swing_hit.emit())
	tw.tween_interval(0.5)
	await tw.finished
	_swing = 0.0
	say("Tiens-toi tranquille !", 2.0)
	await walk_to(Vector3(0.1, 0.0, -1.8))
	await walk_to(DOOR_SPOT)
	cell.open_door(false)
	_busy = false
	attack_done.emit()


# ------------------------------------------------------------------ interne

func _arrive() -> void:
	if _target.is_equal_approx(SEAT):
		_sit_goal = 1.0
	else:
		_sit_goal = 0.0
	_yaw_goal = 0.0


func _pick_state(s: int) -> void:
	state = s
	_state_time = 0.0
	match s:
		S.WATCH:
			_state_dur = randf_range(5.0, 9.0)
		S.READ:
			_state_dur = randf_range(6.0, 11.0)
		S.SNACK:
			_state_dur = randf_range(4.0, 6.5)
		S.WARN:
			_state_dur = 1.1
		S.DOZE:
			_state_dur = randf_range(20.0, 35.0)
	paper.visible = (s == S.READ)
	donut.visible = (s == S.SNACK)
	zzz.visible = (s == S.DOZE)


func _next_state() -> void:
	if mode == "stand":
		_pick_state(S.WATCH)
		return
	if mode == "doze":
		if state == S.DOZE:
			_pick_state(S.WARN)
			_state_dur = 2.2
		else:
			_pick_state(S.DOZE)
		return
	match state:
		S.WATCH:
			var r: float = randf()
			if r < 0.5:
				_pick_state(S.READ)
			elif r < 0.75:
				_pick_state(S.SNACK)
			else:
				_pick_state(S.WATCH)
		S.READ, S.SNACK:
			_pick_state(S.WARN)
		S.WARN:
			_pick_state(S.WATCH)
		_:
			_pick_state(S.WATCH)


func _process(delta: float) -> void:
	_t += delta
	var k: float = 1.0 - exp(-delta * 7.0)

	# état comportemental
	if not _busy and not _walking:
		_state_time += delta
		if _state_time >= _state_dur:
			_next_state()

	# déplacement
	var swing_legs: float = 0.0
	if _walking:
		var d: Vector3 = _target - position
		d.y = 0.0
		if d.length() < 0.05:
			position = _target
			_walking = false
			_arrive()
			arrived.emit()
		else:
			position += d.normalized() * WALK_SPEED * delta
			_yaw_goal = atan2(d.x, d.z)
			swing_legs = sin(_t * 7.0)
	rotation.y = lerp_angle(rotation.y, _yaw_goal, 1.0 - exp(-delta * 6.0))
	_sit = lerpf(_sit, _sit_goal, 1.0 - exp(-delta * 4.0))

	# posture
	var t_head_pitch: float = 0.0
	var t_rsh: float = 0.0
	var t_rel: float = 0.0
	var t_lsh: float = 0.0
	var t_lel: float = 0.0
	var breath_speed: float = 1.8
	var eye_open: float = 1.0
	if _walking:
		t_rsh = deg_to_rad(-25.0)
		t_rel = deg_to_rad(-40.0)
		t_lsh = swing_legs * 0.5
	else:
		match state:
			S.WATCH:
				t_rsh = deg_to_rad(-55.0) + sin(_t * 5.0) * 0.12
				t_rel = deg_to_rad(-55.0) + sin(_t * 5.0) * 0.1
				t_lsh = deg_to_rad(-25.0)
				t_lel = deg_to_rad(-50.0)
			S.READ:
				t_head_pitch = deg_to_rad(30.0)
				t_rsh = deg_to_rad(-72.0)
				t_rel = deg_to_rad(-62.0)
				t_lsh = deg_to_rad(-72.0)
				t_lel = deg_to_rad(-62.0)
			S.SNACK:
				t_head_pitch = deg_to_rad(12.0) + sin(_t * 6.0) * 0.06
				t_rsh = deg_to_rad(-25.0)
				t_rel = deg_to_rad(-40.0)
				t_lsh = deg_to_rad(-80.0) - maxf(0.0, sin(_t * 3.0)) * 0.25
				t_lel = deg_to_rad(-105.0)
			S.WARN:
				t_head_pitch = deg_to_rad(-4.0)
				t_rsh = deg_to_rad(-40.0)
				t_rel = deg_to_rad(-45.0)
				t_lsh = deg_to_rad(-25.0)
				t_lel = deg_to_rad(-50.0)
			S.DOZE:
				t_head_pitch = deg_to_rad(48.0)
				t_rsh = deg_to_rad(-8.0)
				t_lsh = deg_to_rad(-12.0)
				t_lel = deg_to_rad(-20.0)
				breath_speed = 1.1
				eye_open = 0.1
			S.ATTACK:
				pass
	# regard vers le joueur
	var yaw_t: float = 0.0
	if state == S.WATCH or state == S.WARN or _walking:
		var gd: Vector3 = gaze - global_position
		yaw_t = clampf(wrapf(atan2(gd.x, gd.z) - rotation.y, -PI, PI), -0.7, 0.7)
	_p_head_pitch = lerpf(_p_head_pitch, t_head_pitch, k)
	_p_head_yaw = lerpf(_p_head_yaw, yaw_t, k)
	_p_rsh = lerpf(_p_rsh, t_rsh, k)
	_p_rel = lerpf(_p_rel, t_rel, k)
	_p_lsh = lerpf(_p_lsh, t_lsh, k)
	_p_lel = lerpf(_p_lel, t_lel, k)

	head.rotation = Vector3(_p_head_pitch, _p_head_yaw, 0.0)
	arm_r.rotation.x = _p_rsh
	fore_r.rotation.x = _p_rel
	arm_l.rotation.x = _p_lsh
	fore_l.rotation.x = _p_lel
	if state == S.ATTACK:
		# _swing : -1 = matraque levée, +1 = coup donné
		var s: float = clampf(_swing, -1.0, 1.0)
		var raise: float = deg_to_rad(-165.0)
		var hit: float = deg_to_rad(-35.0)
		arm_r.rotation.x = lerpf(deg_to_rad(-55.0), raise, clampf(-s, 0.0, 1.0)) if s <= 0.0 else lerpf(raise, hit, s)
		fore_r.rotation.x = deg_to_rad(-30.0)
		arm_l.rotation.x = deg_to_rad(-20.0)
		fore_l.rotation.x = deg_to_rad(-40.0)

	# jambes / assise
	var walk_f: float = 1.0 - _sit
	for i in 2:
		var side: float = 1.0 if i == 0 else -1.0
		thigh[i].rotation.x = -PI * 0.5 * _sit + swing_legs * 0.55 * side * walk_f
		shin[i].rotation.x = PI * 0.5 * _sit + maxf(0.0, -swing_legs * side) * 0.5 * walk_f
	rig.position.y = SIT_DROP * _sit + absf(swing_legs) * 0.035
	rig.rotation.z = swing_legs * 0.035

	# respiration
	var br: float = sin(_t * breath_speed)
	belly.scale = Vector3(1.12 + br * 0.015, 1.0 + br * 0.03, 1.0 + br * 0.025)
	torso.scale = Vector3(1.2, 1.0 + br * 0.015, 1.0)
	for e in eyes:
		e.scale.y = eye_open
	if zzz.visible:
		zzz.position.y = 2.75 + sin(_t * 1.5) * 0.08
