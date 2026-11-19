class_name Hands
extends Node3D
## Les mains du prisonnier, en vue subjective (enfants de la caméra).
## Poses : idle, eat, dig, pee, cake, cover. Animations 100 % procédurales.

var pose: String = "idle"
var spoon_visible: bool = false

var _t: float = 0.0
var _hands: Array = []
var _spoon: Node3D
var _reach: float = 0.0
var _glow: OmniLight3D


func _ready() -> void:
	_hands.append(_make_hand(1.0))
	_hands.append(_make_hand(-1.0))
	_build_spoon()
	# petite lueur pour que les mains restent visibles dans le noir
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0, -0.12, -0.05)
	_glow.omni_range = 1.4
	_glow.light_energy = 0.35
	_glow.light_color = Color(1.0, 0.9, 0.8)
	add_child(_glow)


func _make_hand(side: float) -> Dictionary:
	var skin_m: StandardMaterial3D = Bld.mat(Tex.skin(), Color.WHITE, 0.75)
	var sleeve_m: StandardMaterial3D = Bld.mat(Tex.fabric(Color(0.95, 0.45, 0.08), Color(0.95, 0.45, 0.08)), Color.WHITE, 0.95)
	var cuff_m: StandardMaterial3D = Bld.mat(null, Color(0.25, 0.1, 0.03), 0.9)
	var root := Node3D.new()
	add_child(root)
	Bld.box(root, Vector3(0.088, 0.024, 0.098), Vector3(0, 0, -0.049), skin_m)
	# poignet + manche de combinaison orange
	Bld.cyl(root, 0.03, 0.08, Vector3(0, 0, 0.04), skin_m, Vector3(90, 0, 0))
	Bld.cyl(root, 0.048, 0.34, Vector3(0, 0, 0.26), sleeve_m, Vector3(90, 0, 0))
	Bld.cyl(root, 0.05, 0.03, Vector3(0, 0, 0.085), cuff_m, Vector3(90, 0, 0))
	var prox: Array = []
	var dist: Array = []
	var xs: Array = [-0.033, -0.011, 0.011, 0.033]
	var lens: Array = [0.04, 0.047, 0.045, 0.036]
	for i in 4:
		var p := Node3D.new()
		p.position = Vector3(xs[i], 0, -0.098)
		root.add_child(p)
		var l: float = lens[i]
		Bld.caps(p, 0.0095, l + 0.012, Vector3(0, 0, -l * 0.5), skin_m, Vector3(90, 0, 0))
		var d := Node3D.new()
		d.position = Vector3(0, 0, -l)
		p.add_child(d)
		Bld.caps(d, 0.0085, l * 0.8 + 0.01, Vector3(0, 0, -l * 0.4), skin_m, Vector3(90, 0, 0))
		prox.append(p)
		dist.append(d)
	# pouce
	var t1 := Node3D.new()
	t1.position = Vector3(-0.044 * side, -0.003, -0.025)
	t1.rotation_degrees = Vector3(0, 38.0 * side, 0)
	root.add_child(t1)
	Bld.caps(t1, 0.011, 0.05, Vector3(0, 0, -0.022), skin_m, Vector3(90, 0, 0))
	var t2 := Node3D.new()
	t2.position = Vector3(0, 0, -0.045)
	t1.add_child(t2)
	Bld.caps(t2, 0.0095, 0.042, Vector3(0, 0, -0.018), skin_m, Vector3(90, 0, 0))
	return {
		"root": root,
		"prox": prox,
		"dist": dist,
		"thumb": [t1, t2],
		"pos": Vector3(0.2 * side, -0.4, -0.3),
		"rot": Vector3(30, 0, 0),
		"curl": 0.3,
	}


func _build_spoon() -> void:
	_spoon = Node3D.new()
	_spoon.visible = false
	_hands[0]["root"].add_child(_spoon)
	var m: StandardMaterial3D = Bld.tiled(Tex.metal(Color(0.85, 0.86, 0.9)), 0.1, Color.WHITE, 0.25, 0.9)
	Bld.box(_spoon, Vector3(0.012, 0.005, 0.14), Vector3(0, -0.02, -0.12), m)
	Bld.sph(_spoon, 0.026, Vector3(0, -0.02, -0.215), m, Vector3(0.85, 0.3, 1.25))


# ------------------------------------------------------------------ API

func set_pose(p: String) -> void:
	pose = p


func reach() -> void:
	_reach = 0.4


func set_spoon(v: bool) -> void:
	spoon_visible = v


func _targets(i: int) -> Array:
	var sx: float = 1.0 if i == 0 else -1.0
	var breathe: float = sin(_t * 1.4 + float(i)) * 0.004
	var pos: Vector3 = Vector3(0.2 * sx, -0.26 + breathe, -0.40)
	var rot: Vector3 = Vector3(18.0, 8.0 * sx, 0.0)
	var curl: float = 0.25
	match pose:
		"eat":
			if i == 0:
				var e: float = sin(_t * 3.2) * 0.5 + 0.5
				pos = Vector3(0.05, lerpf(-0.28, -0.12, e), lerpf(-0.36, -0.26, e))
				rot = Vector3(lerpf(30.0, 70.0, e), 0.0, 0.0)
				curl = 0.75
		"dig":
			if i == 0:
				var s: float = sin(_t * 13.0)
				pos = Vector3(0.08 + s * 0.008, -0.12 + sin(_t * 13.0 + 1.0) * 0.012, -0.44 - (s * 0.5 + 0.5) * 0.1)
				rot = Vector3(6.0, -6.0, 0.0)
				curl = 0.85
			else:
				pos = Vector3(-0.13, -0.22, -0.38)
				rot = Vector3(10.0, -10.0, 0.0)
				curl = 0.5
		"pee":
			pos = Vector3(0.13 * sx, -0.32, -0.33)
			rot = Vector3(40.0, 0.0, 0.0)
			curl = 0.5
		"cake":
			pos = Vector3(0.1 * sx + sin(_t * 9.0) * 0.006 * sx, -0.2, -0.42)
			rot = Vector3(25.0, 0.0, -20.0 * sx)
			curl = 0.55
		"cover":
			pos = Vector3(0.07 * sx, -0.04, -0.3)
			rot = Vector3(75.0, 0.0, 0.0)
			curl = 0.4
	if i == 0 and _reach > 0.0:
		var r: float = sin(clampf(_reach / 0.4, 0.0, 1.0) * PI)
		pos = pos.lerp(Vector3(0.06, -0.1, -0.62), r)
		rot = rot.lerp(Vector3(6.0, 0.0, 0.0), r)
		curl = lerpf(curl, 0.15, r)
	return [pos, rot, curl]


func _process(delta: float) -> void:
	_t += delta
	_reach = maxf(0.0, _reach - delta)
	var k: float = 1.0 - exp(-delta * 11.0)
	for i in 2:
		var h: Dictionary = _hands[i]
		var tg: Array = _targets(i)
		h["pos"] = h["pos"].lerp(tg[0], k)
		h["rot"] = h["rot"].lerp(tg[1], k)
		h["curl"] = lerpf(h["curl"], tg[2], k)
		var root: Node3D = h["root"]
		root.position = h["pos"]
		root.rotation_degrees = h["rot"]
		var c: float = h["curl"]
		for j in 4:
			h["prox"][j].rotation.x = deg_to_rad(-c * 70.0)
			h["dist"][j].rotation.x = deg_to_rad(-c * 85.0)
		h["thumb"][1].rotation.x = deg_to_rad(-c * 40.0)
	_spoon.visible = spoon_visible
