class_name Cell
extends Node3D
## La cellule, le couloir, le mobilier et les lumières.

## Points de vue de la caméra : position + point regardé.
const STATIONS: Dictionary = {
	"center": {"pos": Vector3(0.0, 1.55, 0.7), "look": Vector3(0.0, 1.35, -3.0)},
	"table": {"pos": Vector3(0.85, 1.5, -0.3), "look": Vector3(1.45, 0.9, -0.9)},
	"toilet": {"pos": Vector3(1.15, 1.55, 0.95), "look": Vector3(1.55, 0.45, 1.7)},
	"wall": {"pos": Vector3(1.35, 1.45, 0.2), "look": Vector3(2.0, 1.3, 0.2)},
	"bed": {"pos": Vector3(-0.45, 1.4, 0.6), "look": Vector3(-1.5, 0.55, 0.4)},
	"window": {"pos": Vector3(-0.6, 1.6, -0.5), "look": Vector3(-2.0, 2.0, -0.6)},
}

var env: Environment
var lamp_light: OmniLight3D
var lamp_mat: StandardMaterial3D
var window_light: OmniLight3D
var window_mat: StandardMaterial3D
var guard_lamp: OmniLight3D
var door: Node3D
var poster_pivot: Node3D
var hole_node: Node3D
var hole_mat: StandardMaterial3D
var rubble: Array = []
var tray: Node3D
var food: Node3D
var food_mat: StandardMaterial3D
var cake: Node3D
var cake_spoon: Node3D
var dust: CPUParticles3D
var desk_news: MeshInstance3D

var _poster_tween: Tween
var _door_tween: Tween


func build() -> void:
	_build_environment()
	_build_shell()
	_build_bars()
	_build_furniture()
	_build_poster_and_hole()
	_build_tray()
	_build_corridor()
	_build_lights()


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.8)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.11, 0.13)
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_shell() -> void:
	var wall_m: StandardMaterial3D = Bld.tiled(Tex.brick(Color(0.5, 0.38, 0.32)), 1.0, Color(0.85, 0.88, 0.85), 0.95)
	var conc_m: StandardMaterial3D = Bld.tiled(Tex.concrete(), 1.2, Color.WHITE, 0.95)
	var floor_m: StandardMaterial3D = Bld.tiled(Tex.floor_tiles(), 1.0, Color.WHITE, 0.8)
	# cellule
	Bld.box(self, Vector3(4.4, 0.2, 4.4), Vector3(0, -0.1, 0), floor_m)
	Bld.box(self, Vector3(4.4, 0.2, 4.4), Vector3(0, 2.9, 0), conc_m)
	Bld.box(self, Vector3(0.2, 3.0, 4.6), Vector3(-2.1, 1.4, 0), wall_m, Vector3.ZERO, "wall_w")
	Bld.box(self, Vector3(0.2, 3.0, 4.6), Vector3(2.1, 1.4, 0), wall_m, Vector3.ZERO, "wall_e")
	Bld.box(self, Vector3(4.0, 3.0, 0.2), Vector3(0, 1.4, 2.1), wall_m, Vector3.ZERO, "wall_n")
	Bld.box(self, Vector3(4.4, 0.55, 0.2), Vector3(0, 2.65, -2.1), conc_m)
	# plinthe sombre
	var base_m: StandardMaterial3D = Bld.mat(null, Color(0.18, 0.2, 0.19), 0.9)
	Bld.box(self, Vector3(0.04, 0.25, 4.0), Vector3(-1.98, 0.12, 0), base_m)
	Bld.box(self, Vector3(0.04, 0.25, 4.0), Vector3(1.98, 0.12, 0), base_m)
	Bld.box(self, Vector3(4.0, 0.25, 0.04), Vector3(0, 0.12, 1.98), base_m)


func _build_bars() -> void:
	var bar_m: StandardMaterial3D = Bld.tiled(Tex.metal(Color(0.28, 0.3, 0.33)), 0.5, Color.WHITE, 0.45, 0.7)
	for i in 21:
		var x: float = -2.0 + 0.2 * float(i)
		if x > -0.45 and x < 0.45:
			continue
		Bld.cyl(self, 0.022, 2.45, Vector3(x, 1.2, -2.0), bar_m)
	for y in [0.15, 1.05, 2.3]:
		Bld.box(self, Vector3(1.55, 0.05, 0.06), Vector3(-1.225, y, -2.0), bar_m)
		Bld.box(self, Vector3(1.55, 0.05, 0.06), Vector3(1.225, y, -2.0), bar_m)
	# porte (pivote vers le couloir)
	door = Node3D.new()
	door.position = Vector3(-0.5, 0.0, -2.0)
	add_child(door)
	for i in 5:
		Bld.cyl(door, 0.022, 2.4, Vector3(0.225 * float(i), 1.2, 0), bar_m)
	for y in [0.1, 1.05, 2.3]:
		Bld.box(door, Vector3(0.95, 0.06, 0.06), Vector3(0.45, y, 0), bar_m)
	Bld.box(door, Vector3(0.05, 2.4, 0.06), Vector3(0.0, 1.2, 0), bar_m)
	Bld.box(door, Vector3(0.05, 2.4, 0.06), Vector3(0.9, 1.2, 0), bar_m)
	var lock_m: StandardMaterial3D = Bld.mat(null, Color(0.12, 0.12, 0.13), 0.4, 0.8)
	Bld.box(door, Vector3(0.12, 0.2, 0.1), Vector3(0.82, 1.0, 0), lock_m)
	# guichet pour les plateaux
	Bld.box(self, Vector3(0.6, 0.04, 0.3), Vector3(1.3, 0.95, -2.12), lock_m)


func _build_furniture() -> void:
	var metal_m: StandardMaterial3D = Bld.tiled(Tex.metal(), 0.6, Color.WHITE, 0.5, 0.6)
	var white_m: StandardMaterial3D = Bld.tiled(Tex.metal(Color(0.8, 0.8, 0.78)), 0.6, Color.WHITE, 0.4, 0.3)
	var wood_m: StandardMaterial3D = Bld.tiled(Tex.wood(), 0.6, Color.WHITE, 0.8)
	var dark_m: StandardMaterial3D = Bld.mat(null, Color(0.08, 0.08, 0.09), 0.6, 0.3)

	# --- lit ---
	var bed := Node3D.new()
	bed.position = Vector3(-1.45, 0, 0.4)
	add_child(bed)
	for lx in [-0.45, 0.45]:
		for lz in [-0.92, 0.92]:
			Bld.cyl(bed, 0.04, 0.4, Vector3(lx, 0.2, lz), metal_m)
	Bld.box(bed, Vector3(1.0, 0.05, 2.0), Vector3(0, 0.42, 0), metal_m)
	Bld.box(bed, Vector3(0.9, 0.16, 1.9), Vector3(0, 0.53, 0), Bld.tiled(Tex.fabric(Color(0.75, 0.73, 0.65), Color(0.45, 0.5, 0.62), 6), 0.4, Color.WHITE, 1.0))
	Bld.sph(bed, 0.28, Vector3(0, 0.67, 0.72), Bld.mat(Tex.fabric(Color(0.85, 0.85, 0.82), Color(0.85, 0.85, 0.82)), Color.WHITE, 1.0), Vector3(1.2, 0.45, 0.8), "pillow")
	Bld.box(bed, Vector3(0.94, 0.07, 1.2), Vector3(0, 0.64, -0.3), Bld.tiled(Tex.fabric(Color(0.32, 0.36, 0.3), Color(0.28, 0.32, 0.27), 0), 0.4, Color.WHITE, 1.0), Vector3(0, 0, 0), "blanket")
	Bld.hit(self, "bed", Vector3(1.0, 0.5, 2.0), Vector3(-1.45, 0.55, 0.4))

	# --- toilettes ---
	Bld.cyl(self, 0.2, 0.42, Vector3(1.55, 0.21, 1.62), white_m, Vector3.ZERO, 0.17)
	Bld.cyl(self, 0.23, 0.1, Vector3(1.55, 0.45, 1.62), white_m)
	Bld.cyl(self, 0.17, 0.02, Vector3(1.55, 0.5, 1.62), dark_m)
	Bld.box(self, Vector3(0.42, 0.5, 0.16), Vector3(1.55, 0.72, 1.9), white_m)
	Bld.cyl(self, 0.03, 0.03, Vector3(1.55, 0.99, 1.9), metal_m)
	Bld.hit(self, "toilet", Vector3(0.55, 0.8, 0.6), Vector3(1.55, 0.45, 1.75))

	# --- lavabo ---
	Bld.box(self, Vector3(0.5, 0.12, 0.35), Vector3(0.6, 0.95, 1.8), white_m)
	Bld.box(self, Vector3(0.4, 0.04, 0.26), Vector3(0.6, 1.02, 1.8), dark_m)
	Bld.cyl(self, 0.018, 0.16, Vector3(0.6, 1.12, 1.92), metal_m)
	Bld.cyl(self, 0.012, 0.12, Vector3(0.6, 1.2, 1.86), metal_m, Vector3(90, 0, 0))
	Bld.box(self, Vector3(0.3, 0.45, 0.04), Vector3(0.6, 1.7, 1.97), Bld.tiled(Tex.metal(Color(0.6, 0.62, 0.65)), 0.4, Color.WHITE, 0.2, 0.9), Vector3.ZERO, "mirror")
	Bld.hit(self, "sink", Vector3(0.6, 0.5, 0.45), Vector3(0.6, 1.0, 1.8))

	# --- table + tabouret ---
	Bld.box(self, Vector3(0.65, 0.05, 1.1), Vector3(1.6, 0.85, -0.9), wood_m)
	Bld.box(self, Vector3(0.05, 0.85, 0.05), Vector3(1.35, 0.42, -1.4), metal_m)
	Bld.box(self, Vector3(0.05, 0.85, 0.05), Vector3(1.35, 0.42, -0.4), metal_m)
	Bld.box(self, Vector3(0.05, 0.5, 0.9), Vector3(1.95, 0.55, -0.9), metal_m)
	Bld.cyl(self, 0.19, 0.06, Vector3(0.95, 0.48, -0.9), wood_m)
	for a in 3:
		var ang: float = float(a) * TAU / 3.0
		Bld.cyl(self, 0.02, 0.48, Vector3(0.95 + cos(ang) * 0.12, 0.24, -0.9 + sin(ang) * 0.12), metal_m)

	# --- étagère avec quelques affaires ---
	Bld.box(self, Vector3(0.9, 0.04, 0.25), Vector3(-0.2, 1.4, 1.87), wood_m)
	var cup_m: StandardMaterial3D = Bld.tiled(Tex.metal(Color(0.7, 0.7, 0.72)), 0.3, Color.WHITE, 0.4, 0.7)
	Bld.cyl(self, 0.04, 0.09, Vector3(-0.45, 1.47, 1.87), cup_m, Vector3.ZERO, 0.05)
	Bld.cyl(self, 0.04, 0.09, Vector3(-0.3, 1.47, 1.87), cup_m, Vector3.ZERO, 0.05)
	Bld.box(self, Vector3(0.14, 0.2, 0.1), Vector3(0.05, 1.52, 1.87), Bld.tiled(Tex.fabric(Color(0.55, 0.15, 0.12), Color(0.55, 0.15, 0.12)), 0.2, Color.WHITE, 0.8))
	Bld.box(self, Vector3(0.12, 0.16, 0.09), Vector3(0.2, 1.5, 1.87), Bld.tiled(Tex.fabric(Color(0.15, 0.3, 0.5), Color(0.15, 0.3, 0.5)), 0.2, Color.WHITE, 0.8))

	# --- seau + papier toilette ---
	Bld.cyl(self, 0.17, 0.3, Vector3(-0.4, 0.15, 1.65), metal_m, Vector3.ZERO, 0.2)

	# --- comptage des jours sur le mur du fond ---
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = Tex.tally()
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.roughness = 1.0
	Bld.quad(self, Vector3(0.9, 0.45, 1.0), Vector3(-1.0, 1.15, 1.99), tm, Vector3(0, 180, 0), "tally")
	Bld.hit(self, "tally", Vector3(0.9, 0.5, 0.1), Vector3(-1.0, 1.15, 1.95))

	# --- fenêtre grillagée (mur ouest) ---
	window_mat = Bld.emissive(Color(0.5, 0.6, 0.9), 1.5)
	Bld.quad(self, Vector3(0.9, 0.5, 1.0), Vector3(-1.985, 2.05, -0.6), window_mat, Vector3(0, 90, 0), "window_glass")
	var wbar_m: StandardMaterial3D = Bld.mat(null, Color(0.1, 0.1, 0.12), 0.5, 0.6)
	for i in 5:
		Bld.cyl(self, 0.015, 0.52, Vector3(-1.95, 2.05, -0.6 - 0.36 + 0.18 * float(i)), wbar_m)
	Bld.box(self, Vector3(0.06, 0.04, 0.95), Vector3(-1.95, 2.3, -0.6), wbar_m)
	Bld.box(self, Vector3(0.06, 0.04, 0.95), Vector3(-1.95, 1.8, -0.6), wbar_m)
	Bld.hit(self, "window", Vector3(0.2, 0.6, 1.0), Vector3(-1.95, 2.05, -0.6))


func _build_poster_and_hole() -> void:
	# trou (derrière le poster)
	hole_node = Node3D.new()
	hole_node.position = Vector3(1.985, 1.3, 0.2)
	add_child(hole_node)
	hole_mat = StandardMaterial3D.new()
	hole_mat.albedo_texture = Tex.hole()
	hole_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hole_mat.roughness = 1.0
	var q: MeshInstance3D = Bld.quad(hole_node, Vector2(0.7, 0.7), Vector3.ZERO, hole_mat, Vector3(0, -90, 0), "hole_quad")
	q.name = "hole_quad"
	hole_node.scale = Vector3(0.3, 0.3, 0.3)
	Bld.hit(self, "hole", Vector3(0.1, 0.7, 0.7), Vector3(1.95, 1.3, 0.2))

	# gravats
	var dirt_m: StandardMaterial3D = Bld.tiled(Tex.dirt(), 0.3, Color(0.7, 0.68, 0.62), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 22:
		var s: float = rng.randf_range(0.03, 0.09)
		var b: MeshInstance3D = Bld.box(self, Vector3(s, s * 0.7, s), Vector3(1.9 - rng.randf() * 0.5, s * 0.35, 0.2 + rng.randf_range(-0.45, 0.45)), dirt_m, Vector3(rng.randf() * 90.0, rng.randf() * 90.0, rng.randf() * 90.0))
		b.visible = false
		rubble.append(b)

	# poster
	poster_pivot = Node3D.new()
	poster_pivot.position = Vector3(1.97, 1.7, 0.2)
	add_child(poster_pivot)
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = Tex.poster()
	pm.roughness = 0.7
	Bld.quad(poster_pivot, Vector2(0.8, 1.1), Vector3(0, -0.05, 0), pm, Vector3(0, -90, 0), "poster_quad")
	Bld.box(poster_pivot, Vector3(0.01, 0.025, 0.04), Vector3(0.005, 0.5, 0), Bld.mat(null, Color(0.9, 0.9, 0.5)))
	Bld.hit(poster_pivot, "poster", Vector3(0.1, 1.1, 0.8), Vector3(-0.03, -0.05, 0))

	# poussière quand on creuse
	dust = CPUParticles3D.new()
	dust.position = Vector3(1.9, 1.3, 0.2)
	dust.emitting = false
	dust.amount = 28
	dust.lifetime = 0.9
	dust.direction = Vector3(-1, -0.2, 0)
	dust.spread = 35.0
	dust.initial_velocity_min = 0.25
	dust.initial_velocity_max = 0.6
	dust.gravity = Vector3(0, -2.2, 0)
	var dm := BoxMesh.new()
	dm.size = Vector3(0.012, 0.012, 0.012)
	dust.mesh = dm
	dust.material_override = Bld.mat(null, Color(0.62, 0.58, 0.5), 1.0)
	add_child(dust)


func _build_tray() -> void:
	tray = Node3D.new()
	tray.position = Vector3(1.6, 0.88, -0.9)
	tray.visible = false
	add_child(tray)
	var metal_m: StandardMaterial3D = Bld.tiled(Tex.metal(Color(0.55, 0.56, 0.58)), 0.4, Color.WHITE, 0.5, 0.6)
	Bld.box(tray, Vector3(0.4, 0.025, 0.55), Vector3(0, 0.012, 0), metal_m)
	Bld.box(tray, Vector3(0.4, 0.03, 0.015), Vector3(0, 0.025, 0.275), metal_m)
	Bld.box(tray, Vector3(0.4, 0.03, 0.015), Vector3(0, 0.025, -0.275), metal_m)
	food = Node3D.new()
	tray.add_child(food)
	food_mat = Bld.mat(Tex.dirt(), Color(0.85, 0.8, 0.5), 0.9)
	Bld.cyl(food, 0.1, 0.03, Vector3(0, 0.04, 0.1), Bld.mat(null, Color(0.9, 0.9, 0.88), 0.5))
	Bld.sph(food, 0.075, Vector3(0, 0.06, 0.1), food_mat, Vector3(1, 0.45, 1), "food_blob")
	Bld.cyl(food, 0.035, 0.07, Vector3(-0.12, 0.05, -0.12), Bld.tiled(Tex.metal(Color(0.7, 0.7, 0.72)), 0.2, Color.WHITE, 0.4, 0.7), Vector3.ZERO, 0.04)
	Bld.box(food, Vector3(0.11, 0.035, 0.05), Vector3(0.1, 0.045, -0.15), Bld.mat(null, Color(0.78, 0.6, 0.35), 0.9))
	Bld.hit(tray, "tray", Vector3(0.45, 0.2, 0.6), Vector3(0, 0.08, 0))

	# gâteau (avec une cuillère cachée dedans)
	cake = Node3D.new()
	cake.position = Vector3(-0.02, 0.0, -0.05)
	cake.visible = false
	tray.add_child(cake)
	Bld.cyl(cake, 0.13, 0.09, Vector3(0, 0.07, 0), Bld.mat(null, Color(0.85, 0.65, 0.3), 0.9))
	Bld.cyl(cake, 0.135, 0.035, Vector3(0, 0.13, 0), Bld.mat(null, Color(0.98, 0.78, 0.85), 0.5))
	Bld.sph(cake, 0.018, Vector3(0, 0.165, 0), Bld.mat(null, Color(0.8, 0.05, 0.1), 0.3))
	Bld.cyl(cake, 0.006, 0.07, Vector3(0.05, 0.19, 0.03), Bld.mat(null, Color(0.95, 0.95, 0.4), 0.8))
	cake_spoon = Node3D.new()
	cake_spoon.visible = false
	cake.add_child(cake_spoon)
	var sp_m: StandardMaterial3D = Bld.tiled(Tex.metal(Color(0.85, 0.86, 0.9)), 0.1, Color.WHITE, 0.25, 0.9)
	Bld.box(cake_spoon, Vector3(0.012, 0.01, 0.1), Vector3(-0.06, 0.15, 0.05), sp_m, Vector3(-20, 0, 0))
	Bld.sph(cake_spoon, 0.025, Vector3(-0.06, 0.18, -0.01), sp_m, Vector3(0.9, 0.35, 1.3))
	Bld.hit(cake, "cake", Vector3(0.32, 0.25, 0.32), Vector3(0, 0.12, 0))


func _build_corridor() -> void:
	var wall_m: StandardMaterial3D = Bld.tiled(Tex.concrete(Color(0.5, 0.52, 0.5), Color(0.28, 0.3, 0.29)), 1.2, Color.WHITE, 0.95)
	var floor_m: StandardMaterial3D = Bld.tiled(Tex.floor_tiles(), 1.0, Color(0.9, 0.9, 0.9), 0.8)
	var wood_m: StandardMaterial3D = Bld.tiled(Tex.wood(Color(0.38, 0.25, 0.14)), 0.6, Color.WHITE, 0.8)
	Bld.box(self, Vector3(7.4, 0.2, 5.4), Vector3(0, -0.1, -4.7), floor_m)
	Bld.box(self, Vector3(7.4, 0.2, 5.4), Vector3(0, 3.1, -4.7), wall_m)
	Bld.box(self, Vector3(0.2, 3.3, 5.4), Vector3(-3.7, 1.5, -4.7), wall_m)
	Bld.box(self, Vector3(0.2, 3.3, 5.4), Vector3(3.7, 1.5, -4.7), wall_m)
	Bld.box(self, Vector3(7.6, 3.3, 0.2), Vector3(0, 1.5, -7.5), wall_m)
	# bureau du garde (sur le côté) + objets
	Bld.box(self, Vector3(1.6, 0.06, 0.8), Vector3(2.1, 0.8, -3.5), wood_m)
	Bld.box(self, Vector3(0.06, 0.8, 0.7), Vector3(1.35, 0.4, -3.5), wood_m)
	Bld.box(self, Vector3(0.06, 0.8, 0.7), Vector3(2.85, 0.4, -3.5), wood_m)
	Bld.box(self, Vector3(1.5, 0.5, 0.04), Vector3(2.1, 0.55, -3.15), wood_m)
	# lampe de bureau
	Bld.cyl(self, 0.1, 0.02, Vector3(2.6, 0.84, -3.6), Bld.mat(null, Color(0.1, 0.1, 0.1), 0.5, 0.5))
	Bld.cyl(self, 0.01, 0.35, Vector3(2.6, 1.0, -3.6), Bld.mat(null, Color(0.1, 0.1, 0.1), 0.5, 0.5))
	Bld.cyl(self, 0.12, 0.1, Vector3(2.55, 1.22, -3.55), Bld.emissive(Color(1.0, 0.85, 0.5), 1.2), Vector3(0, 0, 25), 0.04)
	# boîte de donuts
	Bld.box(self, Vector3(0.3, 0.08, 0.22), Vector3(1.7, 0.87, -3.55), Bld.mat(null, Color(0.95, 0.6, 0.7), 0.8))
	for i in 3:
		Bld.cyl(self, 0.045, 0.025, Vector3(1.62 + 0.08 * float(i), 0.925, -3.55), Bld.mat(null, Color(0.75, 0.5, 0.25), 0.7))
	# journal posé sur le bureau
	var nm := StandardMaterial3D.new()
	nm.albedo_texture = Tex.newspaper()
	nm.roughness = 0.9
	desk_news = Bld.quad(self, Vector2(0.4, 0.55), Vector3(2.1, 0.835, -3.4), nm, Vector3(-90, 0, 12), "desk_news")
	# tabouret du garde
	Bld.cyl(self, 0.26, 0.07, Vector3(0.6, 0.5, -3.45), wood_m)
	for a in 4:
		var ang: float = float(a) * TAU / 4.0 + 0.4
		Bld.cyl(self, 0.025, 0.5, Vector3(0.6 + cos(ang) * 0.17, 0.25, -3.45 + sin(ang) * 0.17), Bld.mat(null, Color(0.15, 0.15, 0.17), 0.6, 0.5))
	# armoire de casiers au fond
	var lock_m: StandardMaterial3D = Bld.tiled(Tex.metal(Color(0.3, 0.38, 0.35)), 0.5, Color.WHITE, 0.5, 0.5)
	for i in 6:
		Bld.box(self, Vector3(0.5, 1.9, 0.4), Vector3(-2.6 + 0.52 * float(i), 0.95, -7.2), lock_m)
	# autres cellules (vides) en face, ambiance
	var bars_m: StandardMaterial3D = Bld.mat(null, Color(0.12, 0.13, 0.15), 0.5, 0.7)
	for i in 12:
		Bld.cyl(self, 0.02, 2.6, Vector3(-3.4 + 0.2 * float(i), 1.3, -7.0), bars_m)


func _build_lights() -> void:
	# plafonnier de la cellule
	lamp_mat = Bld.emissive(Color(1.0, 0.92, 0.72), 1.4)
	Bld.cyl(self, 0.16, 0.08, Vector3(0, 2.84, 0), lamp_mat)
	lamp_light = OmniLight3D.new()
	lamp_light.position = Vector3(0, 2.6, 0)
	lamp_light.light_color = Color(1.0, 0.9, 0.7)
	lamp_light.light_energy = 1.4
	lamp_light.omni_range = 7.0
	add_child(lamp_light)
	# lumière de la fenêtre
	window_light = OmniLight3D.new()
	window_light.position = Vector3(-1.3, 2.0, -0.6)
	window_light.omni_range = 5.0
	add_child(window_light)
	# lumière du couloir / bureau du garde
	guard_lamp = OmniLight3D.new()
	guard_lamp.position = Vector3(2.0, 1.4, -3.3)
	guard_lamp.light_color = Color(1.0, 0.82, 0.5)
	guard_lamp.light_energy = 1.2
	guard_lamp.omni_range = 5.5
	add_child(guard_lamp)
	var corr := OmniLight3D.new()
	corr.position = Vector3(-1.0, 2.7, -5.0)
	corr.light_color = Color(0.75, 0.85, 1.0)
	corr.light_energy = 0.9
	corr.omni_range = 6.0
	add_child(corr)


## Heure -> éclairage (jour / nuit).
func set_tod(minutes: float, night: bool) -> void:
	var h: float = minutes / 60.0
	var day_f: float = clampf(smoothstep(5.0, 7.5, h) - smoothstep(18.0, 21.0, h), 0.0, 1.0)
	var dusk: float = clampf(smoothstep(16.5, 19.0, h) - smoothstep(19.0, 21.0, h), 0.0, 1.0)
	var col: Color = Color(0.4, 0.5, 0.9).lerp(Color(1.0, 0.94, 0.8), day_f)
	col = col.lerp(Color(1.0, 0.55, 0.3), dusk * 0.7)
	window_light.light_color = col
	window_light.light_energy = lerpf(0.45, 2.0, day_f)
	window_mat.albedo_color = col
	window_mat.emission = col
	window_mat.emission_energy_multiplier = lerpf(0.5, 2.0, day_f)
	env.ambient_light_energy = lerpf(0.12, 0.5, day_f)
	lamp_light.visible = not night
	lamp_mat.emission_energy_multiplier = 0.0 if night else 1.4
	guard_lamp.light_energy = 0.6 if night else 1.2


func set_dig(progress: float) -> void:
	var p: float = clampf(progress / 100.0, 0.0, 1.0)
	var s: float = lerpf(0.3, 1.0, p)
	hole_node.scale = Vector3(s, s, s)
	var n: int = int(p * float(rubble.size()))
	for i in rubble.size():
		rubble[i].visible = i < n


func set_poster_moved(moved: bool, animate: bool = true) -> void:
	if _poster_tween != null and _poster_tween.is_valid():
		_poster_tween.kill()
	var target_pos: Vector3 = Vector3(1.97, 1.7, 0.95) if moved else Vector3(1.97, 1.7, 0.2)
	var target_rot: Vector3 = Vector3(35, 0, 0) if moved else Vector3.ZERO
	if not animate:
		poster_pivot.position = target_pos
		poster_pivot.rotation_degrees = target_rot
		return
	_poster_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_poster_tween.tween_property(poster_pivot, "position", target_pos, 0.5)
	_poster_tween.tween_property(poster_pivot, "rotation_degrees", target_rot, 0.5)


func show_tray(kind: String, with_cake: bool) -> void:
	tray.visible = true
	tray.position = Vector3(1.6, 0.88, -2.3)
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(tray, "position", Vector3(1.6, 0.88, -0.9), 0.9)
	food.scale = Vector3.ONE
	food.visible = true
	match kind:
		"breakfast":
			food_mat.albedo_color = Color(0.9, 0.85, 0.7)
		"lunch":
			food_mat.albedo_color = Color(0.75, 0.6, 0.35)
		_:
			food_mat.albedo_color = Color(0.6, 0.7, 0.4)
	cake.visible = with_cake
	cake.scale = Vector3.ONE
	cake_spoon.visible = false


func set_food(frac: float) -> void:
	food.scale = Vector3(1, maxf(frac, 0.02), 1)
	food.visible = frac > 0.03


func cake_cut() -> void:
	cake.scale = Vector3(1, 0.6, 1)
	cake_spoon.visible = true


func hide_tray() -> void:
	var t: Tween = create_tween()
	t.tween_property(tray, "position", Vector3(1.6, 0.88, -2.3), 0.8).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void: tray.visible = false)


func open_door(open: bool) -> void:
	if _door_tween != null and _door_tween.is_valid():
		_door_tween.kill()
	_door_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_door_tween.tween_property(door, "rotation_degrees:y", 95.0 if open else 0.0, 0.7)


func set_digging_fx(on: bool) -> void:
	dust.emitting = on
