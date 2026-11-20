class_name Npc
extends Node3D
## Personnage non joueur (détenus, cuistot, dealer, jardinier) : modèle procédural,
## idle, marche entre des points, se tourne vers le joueur quand il est proche.
## Le modèle regarde vers +Z.

var npc_name: String = "Détenu"
var role: String = "chat"  # chat | shop | hint | cook
var wander: Array = []  # Array[Vector3] ; vide = reste sur place
var walk_speed: float = 1.1
var chatter: Array = ["...", "Fiche-moi la paix."]

var _rig: Node3D
var _head: Node3D
var _legs: Array = []
var _arms: Array = []
var _t: float = 0.0
var _target: Vector3
var _moving: bool = false
var _wait: float = 0.0
var _yaw_goal: float = 0.0
var _look_at: Vector3 = Vector3.ZERO
var _has_look: bool = false
var _rng := RandomNumberGenerator.new()


func setup(n: String, r: String, shirt: Color, skin: Color, hair: Color, extra: String = "") -> void:
	npc_name = n
	role = r
	_rng.randomize()
	_build(shirt, skin, hair, extra)
	_wait = _rng.randf_range(0.5, 4.0)


func _limb(parent: Node3D, pos: Vector3, radius: float, length: float, m: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	Bld.cyl(pivot, radius, length, Vector3(0, -length * 0.5, 0), m, Vector3.ZERO, radius * 0.85)
	Bld.sph(pivot, radius * 0.85, Vector3(0, -length, 0), m)
	return pivot


func _build(shirt: Color, skin: Color, hair: Color, extra: String) -> void:
	var shirt_m: StandardMaterial3D = Bld.mat(Tex.fabric(shirt, shirt.darkened(0.12), 0), Color.WHITE, 0.9)
	var skin_m: StandardMaterial3D = Bld.mat(null, skin, 0.75)
	var pants_m: StandardMaterial3D = Bld.mat(Tex.fabric(shirt.darkened(0.15), shirt.darkened(0.15), 0), Color.WHITE, 0.9)
	var hair_m: StandardMaterial3D = Bld.mat(null, hair, 0.9)
	var dark_m: StandardMaterial3D = Bld.mat(null, Color(0.08, 0.08, 0.09), 0.6)
	_rig = Node3D.new()
	add_child(_rig)
	for side in [-1.0, 1.0]:
		var l: Node3D = _limb(_rig, Vector3(0.12 * side, 0.9, 0), 0.085, 0.88, pants_m)
		Bld.box(l, Vector3(0.14, 0.08, 0.26), Vector3(0, -0.9, 0.05), dark_m)
		_legs.append(l)
	var wide: float = 1.0
	if extra == "fat":
		wide = 1.45
	Bld.sph(_rig, 0.3, Vector3(0, 1.2, 0), shirt_m, Vector3(0.9 * wide, 1.5, 0.7 * wide))
	_head = Node3D.new()
	_head.position = Vector3(0, 1.72, 0)
	_rig.add_child(_head)
	Bld.sph(_head, 0.15, Vector3.ZERO, skin_m, Vector3(1.0, 1.1, 1.0))
	Bld.sph(_head, 0.155, Vector3(0, 0.06, -0.015), hair_m, Vector3(1.0, 0.7, 1.0))
	for side in [-1.0, 1.0]:
		Bld.sph(_head, 0.022, Vector3(0.06 * side, 0.02, 0.135), dark_m)
	Bld.sph(_head, 0.025, Vector3(0, -0.02, 0.15), skin_m)
	for side in [-1.0, 1.0]:
		var a: Node3D = _limb(_rig, Vector3(0.28 * side * wide, 1.48, 0), 0.06, 0.6, shirt_m)
		Bld.sph(a, 0.05, Vector3(0, -0.62, 0), skin_m)
		_arms.append(a)
	match extra:
		"cook":
			Bld.box(_rig, Vector3(0.5, 0.7, 0.04), Vector3(0, 1.12, 0.28 * wide), Bld.mat(null, Color(0.95, 0.95, 0.92), 0.9))
			Bld.cyl(_head, 0.13, 0.2, Vector3(0, 0.25, 0), Bld.mat(null, Color(0.97, 0.97, 0.95), 0.9))
		"beanie":
			Bld.sph(_head, 0.165, Vector3(0, 0.07, 0), Bld.mat(null, Color(0.15, 0.4, 0.6), 0.9), Vector3(1.0, 0.75, 1.0))
		"hat":
			Bld.cyl(_head, 0.24, 0.02, Vector3(0, 0.15, 0), Bld.mat(null, Color(0.75, 0.62, 0.35), 0.9))
			Bld.cyl(_head, 0.12, 0.12, Vector3(0, 0.2, 0), Bld.mat(null, Color(0.75, 0.62, 0.35), 0.9))
		"beard":
			Bld.sph(_head, 0.12, Vector3(0, -0.1, 0.05), Bld.mat(null, Color(0.85, 0.85, 0.85), 0.9), Vector3(1.0, 0.9, 0.8))
	var tag := Label3D.new()
	tag.text = npc_name
	tag.font_size = 40
	tag.pixel_size = 0.005
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(1, 1, 1, 0.9)
	tag.outline_size = 10
	tag.position = Vector3(0, 2.15, 0)
	tag.no_depth_test = true
	add_child(tag)


func face(p: Vector3) -> void:
	_look_at = p
	_has_look = true


func release() -> void:
	_has_look = false


func _process(delta: float) -> void:
	_t += delta
	var swing: float = 0.0
	if _moving:
		var d: Vector3 = _target - position
		d.y = 0.0
		if d.length() < 0.1:
			_moving = false
			_wait = _rng.randf_range(2.0, 7.0)
		else:
			position += d.normalized() * walk_speed * delta
			_yaw_goal = atan2(d.x, d.z)
			swing = sin(_t * 6.0)
	elif wander.size() > 0:
		_wait -= delta
		if _wait <= 0.0 and not _has_look:
			_target = wander[_rng.randi() % wander.size()]
			_moving = true
	if _has_look and not _moving:
		var dl: Vector3 = _look_at - global_position
		_yaw_goal = atan2(dl.x, dl.z)
	rotation.y = lerp_angle(rotation.y, _yaw_goal, 1.0 - exp(-delta * 6.0))
	for i in 2:
		var s: float = 1.0 if i == 0 else -1.0
		_legs[i].rotation.x = swing * 0.55 * s
		_arms[i].rotation.x = -swing * 0.5 * s + sin(_t * 1.5 + float(i)) * 0.03
	_rig.position.y = absf(swing) * 0.03
	_head.rotation.y = sin(_t * 0.7 + position.x) * 0.25 if not _has_look else 0.0
