class_name World
extends Node3D
## La prison entière : bloc cellulaire (Cell), cour, jardin, cantine, PNJ, pièces,
## graphe de chemins (A*) pour le garde, soleil et ciel.

const MAP_RECT: Rect2 = Rect2(-30.0, -51.0, 60.0, 66.0)
const BLOCK_RECT: Rect2 = Rect2(-3.7, -7.5, 7.4, 9.6)
const CANTINE_RECT: Rect2 = Rect2(9.0, -30.0, 18.0, 18.0)
const GARDEN_RECT: Rect2 = Rect2(-27.0, -30.0, 16.0, 16.0)
const SPAWN: Vector3 = Vector3(0.0, 0.05, 0.8)

const BED_POS: Array = [Vector3(-24.0, 0, -27.0), Vector3(-24.0, 0, -17.0), Vector3(-15.5, 0, -27.5), Vector3(-15.5, 0, -16.5)]
const TABLE_POS: Array = [Vector3(14.0, 0, -26.0), Vector3(14.0, 0, -16.0), Vector3(20.0, 0, -26.5), Vector3(20.0, 0, -15.5)]
const COIN_POS: Array = [
	Vector3(-8, 0, -12), Vector3(6, 0, -14), Vector3(-2, 0, -26), Vector3(-6, 0, -40),
	Vector3(10, 0, -36), Vector3(22, 0, -38), Vector3(-22, 0, -22), Vector3(-26, 0, -35),
	Vector3(17, 0, -21), Vector3(5, 0, -46),
]
const NODES: Dictionary = {
	"c_door": Vector3(-0.2, 0, -2.7),
	"c_mid": Vector3(-1.5, 0, -4.8),
	"c_exit": Vector3(2.2, 0, -6.8),
	"y_gate": Vector3(2.2, 0, -10.0),
	"y_mid": Vector3(2.2, 0, -20.0),
	"y_center": Vector3(0.0, 0, -32.0),
	"y_far": Vector3(0.0, 0, -44.0),
	"y_east": Vector3(14.0, 0, -38.0),
	"y_west": Vector3(-14.0, 0, -38.0),
	"g_gate": Vector3(-9.5, 0, -22.0),
	"g_in": Vector3(-17.5, 0, -22.0),
	"k_out": Vector3(6.0, 0, -21.0),
	"k_in": Vector3(12.0, 0, -21.0),
	"k_mid": Vector3(19.0, 0, -21.0),
	"cell_in": Vector3(0.0, 0, -1.2),
}
const EDGES: Array = [
	["c_door", "cell_in"], ["c_door", "c_mid"], ["c_mid", "c_exit"], ["c_exit", "y_gate"],
	["y_gate", "y_mid"], ["y_mid", "y_center"], ["y_center", "y_far"], ["y_center", "y_east"],
	["y_center", "y_west"], ["y_mid", "g_gate"], ["g_gate", "g_in"], ["y_mid", "k_out"],
	["k_out", "k_in"], ["k_in", "k_mid"],
]

var cell: Cell
var sun: DirectionalLight3D
var astar := AStar3D.new()
var npcs: Array = []
var beds: Array = []
var coins: Array = []
var counter: Dictionary = {}
var table_tray: Dictionary = {}
var sign_labels: Array = []

var _ids: Dictionary = {}
var _t: float = 0.0
var _grass_m: StandardMaterial3D
var _paving_m: StandardMaterial3D
var _wall_m: StandardMaterial3D
var _brick_m: StandardMaterial3D
var _wood_m: StandardMaterial3D
var _metal_m: StandardMaterial3D
var _dark_m: StandardMaterial3D


func build() -> void:
	cell = Cell.new()
	add_child(cell)
	cell.build()
	_grass_m = Bld.tiled(Tex.grass(), 2.0, Color.WHITE, 1.0)
	_paving_m = Bld.tiled(Tex.concrete(Color(0.62, 0.62, 0.58), Color(0.4, 0.4, 0.38)), 2.5, Color.WHITE, 0.95)
	_wall_m = Bld.tiled(Tex.concrete(Color(0.58, 0.58, 0.55), Color(0.34, 0.34, 0.33)), 2.0, Color.WHITE, 0.95)
	_brick_m = Bld.tiled(Tex.brick(Color(0.55, 0.36, 0.3)), 1.2, Color.WHITE, 0.95)
	_wood_m = Bld.tiled(Tex.wood(), 0.7, Color.WHITE, 0.8)
	_metal_m = Bld.tiled(Tex.metal(), 0.6, Color.WHITE, 0.5, 0.6)
	_dark_m = Bld.mat(null, Color(0.1, 0.1, 0.11), 0.6, 0.4)
	var first: int = get_child_count()
	Bld.collide = true
	_ground()
	_perimeter()
	_garden()
	_cantine()
	_yard_props()
	_tower()
	Bld.collide = false
	_trays()
	_coins()
	_graph()
	_sun()
	_npcs()
	for i in range(first, get_child_count()):
		mark(get_child(i))


# ------------------------------------------------------------------ construction

func _ground() -> void:
	Bld.box(self, Vector3(64.0, 0.2, 70.0), Vector3(0, -0.12, -20.0), _grass_m)
	Bld.box(self, Vector3(58.0, 0.04, 43.0), Vector3(0, -0.02, -29.0), _paving_m)
	# marquages au sol
	var line_m: StandardMaterial3D = Bld.mat(null, Color(0.9, 0.9, 0.85), 1.0)
	for x in [-27.0, 27.0]:
		Bld.quad(self, Vector2(0.15, 36.0), Vector3(x, 0.006, -29.0), line_m, Vector3(-90, 0, 0))
	Bld.quad(self, Vector2(54.0, 0.15), Vector3(0, 0.006, -48.0), line_m, Vector3(-90, 0, 0))


func _perimeter() -> void:
	Bld.box(self, Vector3(0.6, 5.0, 70.0), Vector3(-30.3, 2.5, -20.0), _wall_m)
	Bld.box(self, Vector3(0.6, 5.0, 70.0), Vector3(30.3, 2.5, -20.0), _wall_m)
	Bld.box(self, Vector3(61.2, 5.0, 0.6), Vector3(0, 2.5, -51.0), _wall_m)
	Bld.box(self, Vector3(61.2, 5.0, 0.6), Vector3(0, 2.5, 14.7), _wall_m)
	# fil barbelé (ruban sombre) au sommet
	var wire_m: StandardMaterial3D = Bld.mat(null, Color(0.12, 0.12, 0.13), 0.5, 0.7)
	Bld.box(self, Vector3(0.08, 0.3, 70.0), Vector3(-30.3, 5.2, -20.0), wire_m)
	Bld.box(self, Vector3(0.08, 0.3, 70.0), Vector3(30.3, 5.2, -20.0), wire_m)
	Bld.box(self, Vector3(61.2, 0.3, 0.08), Vector3(0, 5.2, -51.0), wire_m)
	Bld.box(self, Vector3(61.2, 0.3, 0.08), Vector3(0, 5.2, 14.7), wire_m)


func _fence(a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	var len: float = d.length()
	var mid: Vector3 = (a + b) * 0.5
	var ang: float = atan2(d.x, d.z)
	var holder := Node3D.new()
	holder.position = mid
	holder.rotation.y = ang
	add_child(holder)
	var n: int = maxi(1, int(len / 2.0))
	for i in n + 1:
		var z: float = -len * 0.5 + len * float(i) / float(n)
		Bld.cyl(holder, 0.04, 1.8, Vector3(0, 0.9, z), _metal_m)
	Bld.box(holder, Vector3(0.03, 0.04, len), Vector3(0, 1.75, 0), _metal_m)
	Bld.box(holder, Vector3(0.02, 0.03, len), Vector3(0, 0.9, 0), _metal_m)
	Bld.box(holder, Vector3(0.02, 0.03, len), Vector3(0, 0.15, 0), _metal_m)
	Bld.block(holder, Vector3(0.2, 1.8, len), Vector3(0, 0.9, 0), 4)


func _garden() -> void:
	var gx0: float = GARDEN_RECT.position.x
	var gz0: float = GARDEN_RECT.position.y
	var gx1: float = gx0 + GARDEN_RECT.size.x
	var gz1: float = gz0 + GARDEN_RECT.size.y
	var patch := Bld.box(self, Vector3(GARDEN_RECT.size.x, 0.01, GARDEN_RECT.size.y), Vector3((gx0 + gx1) * 0.5, 0.0, (gz0 + gz1) * 0.5), _grass_m)
	patch.name = "garden_patch"
	_fence(Vector3(gx0, 0, gz0), Vector3(gx1, 0, gz0))
	_fence(Vector3(gx0, 0, gz1), Vector3(gx1, 0, gz1))
	_fence(Vector3(gx0, 0, gz0), Vector3(gx0, 0, gz1))
	_fence(Vector3(gx1, 0, gz0), Vector3(gx1, 0, -23.2))
	_fence(Vector3(gx1, 0, -20.8), Vector3(gx1, 0, gz1))
	var sign := Label3D.new()
	sign.text = "JARDIN"
	sign.font_size = 120
	sign.pixel_size = 0.01
	sign.modulate = Color(0.85, 1.0, 0.7)
	sign.outline_size = 16
	sign.position = Vector3(gx1 + 0.05, 2.5, -22.0)
	sign.rotation_degrees = Vector3(0, 90, 0)
	add_child(sign)
	var soil_m: StandardMaterial3D = Bld.tiled(Tex.dirt(), 0.8, Color.WHITE, 1.0)
	var leaf_m: StandardMaterial3D = Bld.mat(null, Color(0.18, 0.5, 0.15), 0.9)
	var fruit_m: StandardMaterial3D = Bld.mat(null, Color(0.85, 0.12, 0.1), 0.4)
	for i in BED_POS.size():
		var bp: Vector3 = BED_POS[i]
		Bld.box(self, Vector3(2.8, 0.35, 1.4), bp + Vector3(0, 0.17, 0), soil_m)
		var fruits: Array = []
		for k in 5:
			var px: float = bp.x - 1.1 + 0.55 * float(k)
			Bld.cyl(self, 0.02, 0.5, Vector3(px, 0.6, bp.z), leaf_m)
			Bld.sph(self, 0.17, Vector3(px, 0.82, bp.z), leaf_m, Vector3(1, 0.8, 1))
			var f: MeshInstance3D = Bld.sph(self, 0.06, Vector3(px + 0.1, 0.72, bp.z + 0.12), fruit_m)
			f.visible = false
			fruits.append(f)
		Bld.hit(self, "water_%d" % i, Vector3(2.8, 0.6, 1.4), bp + Vector3(0, 0.5, 0), 2.3)
		beds.append({"fruits": fruits, "watered": false})
	# arrosoir décoratif
	Bld.cyl(self, 0.1, 0.2, Vector3(-20.5, 0.1, -19.0), Bld.mat(null, Color(0.2, 0.45, 0.7), 0.5, 0.6))
	# arbre
	_tree(Vector3(-26.0, 0, -22.0))


func _tree(p: Vector3) -> void:
	Bld.cyl(self, 0.18, 2.6, p + Vector3(0, 1.3, 0), Bld.mat(Tex.wood(Color(0.3, 0.2, 0.12)), Color.WHITE, 1.0), Vector3.ZERO, 0.12)
	var leaf: StandardMaterial3D = Bld.mat(Tex.grass(), Color(0.7, 1.0, 0.7), 1.0)
	Bld.sph(self, 1.4, p + Vector3(0, 3.2, 0), leaf, Vector3(1, 0.85, 1))
	Bld.sph(self, 0.9, p + Vector3(0.7, 3.9, 0.3), leaf)


func _cantine() -> void:
	var x0: float = CANTINE_RECT.position.x
	var z0: float = CANTINE_RECT.position.y
	var x1: float = x0 + CANTINE_RECT.size.x
	var z1: float = z0 + CANTINE_RECT.size.y
	var cz: float = (z0 + z1) * 0.5
	var cx: float = (x0 + x1) * 0.5
	var floor_m: StandardMaterial3D = Bld.tiled(Tex.floor_tiles(), 1.0, Color(0.95, 0.95, 0.9), 0.8)
	Bld.box(self, Vector3(18.0, 0.02, 18.0), Vector3(cx, 0.005, cz), floor_m)
	Bld.box(self, Vector3(18.6, 3.2, 0.3), Vector3(cx, 1.6, z0), _brick_m)
	Bld.box(self, Vector3(18.6, 3.2, 0.3), Vector3(cx, 1.6, z1), _brick_m)
	Bld.box(self, Vector3(0.3, 3.2, 18.6), Vector3(x1, 1.6, cz), _brick_m)
	Bld.box(self, Vector3(0.3, 3.2, 7.8), Vector3(x0, 1.6, -26.1), _brick_m)
	Bld.box(self, Vector3(0.3, 3.2, 7.8), Vector3(x0, 1.6, -15.9), _brick_m)
	Bld.box(self, Vector3(0.3, 0.8, 2.4), Vector3(x0, 2.8, -21.0), _brick_m)
	Bld.box(self, Vector3(18.8, 0.3, 18.8), Vector3(cx, 3.35, cz), _wall_m)
	var sign := Label3D.new()
	sign.text = "CANTINE"
	sign.font_size = 120
	sign.pixel_size = 0.01
	sign.modulate = Color(1.0, 0.85, 0.5)
	sign.outline_size = 16
	sign.position = Vector3(x0 - 0.2, 3.0, -21.0)
	sign.rotation_degrees = Vector3(0, -90, 0)
	add_child(sign)
	# fenêtres lumineuses sur le mur nord
	var win_m: StandardMaterial3D = Bld.emissive(Color(0.7, 0.85, 1.0), 0.6)
	for wx in [13.0, 18.0, 23.0]:
		Bld.quad(self, Vector2(2.0, 1.1), Vector3(wx, 1.9, z0 + 0.17), win_m, Vector3(0, 0, 0))
	# comptoir + vitrine
	Bld.box(self, Vector3(1.0, 1.0, 10.0), Vector3(25.4, 0.5, -21.0), _metal_m)
	Bld.box(self, Vector3(1.3, 0.06, 10.2), Vector3(25.3, 1.03, -21.0), _wood_m)
	var menu := Label3D.new()
	menu.text = "MENU DU JOUR\nBouillie ... 0 €\nPain sec ... 0 €\nGâteau ... interdit"
	menu.font_size = 48
	menu.pixel_size = 0.006
	menu.modulate = Color(1, 1, 0.8)
	menu.outline_size = 8
	menu.position = Vector3(x1 - 0.2, 2.3, -21.0)
	menu.rotation_degrees = Vector3(0, -90, 0)
	add_child(menu)
	Bld.hit(self, "tray_counter", Vector3(1.0, 0.5, 3.0), Vector3(24.8, 1.1, -21.0), 2.6)
	# tables + bancs
	for i in TABLE_POS.size():
		var tp: Vector3 = TABLE_POS[i]
		Bld.box(self, Vector3(2.4, 0.06, 1.0), tp + Vector3(0, 0.85, 0), _wood_m)
		for lx in [-1.0, 1.0]:
			Bld.box(self, Vector3(0.08, 0.85, 0.8), tp + Vector3(lx, 0.42, 0), _metal_m)
		for bz in [-0.85, 0.85]:
			Bld.box(self, Vector3(2.2, 0.06, 0.35), tp + Vector3(0, 0.46, bz), _wood_m)
		Bld.block(self, Vector3(2.4, 0.9, 1.0), tp + Vector3(0, 0.45, 0))
		Bld.hit(self, "eat", Vector3(2.4, 0.3, 1.0), tp + Vector3(0, 0.95, 0), 2.6)
	# lumières intérieures
	for lx in [14.0, 22.0]:
		var l := OmniLight3D.new()
		l.position = Vector3(lx, 2.8, cz)
		l.light_color = Color(1.0, 0.92, 0.75)
		l.light_energy = 1.1
		l.omni_range = 11.0
		add_child(l)
		Bld.box(self, Vector3(0.9, 0.06, 0.3), Vector3(lx, 3.15, cz), Bld.emissive(Color(1.0, 0.95, 0.8), 1.2))


func _yard_props() -> void:
	# panier de basket
	Bld.cyl(self, 0.08, 3.2, Vector3(-6.0, 1.6, -48.0), _metal_m)
	Bld.box(self, Vector3(1.4, 0.9, 0.08), Vector3(-6.0, 3.1, -47.6), Bld.mat(null, Color(0.9, 0.9, 0.92), 0.5))
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.2
	tm.outer_radius = 0.24
	ring.mesh = tm
	ring.material_override = Bld.mat(null, Color(0.9, 0.35, 0.1), 0.5)
	ring.position = Vector3(-6.0, 2.85, -47.3)
	add_child(ring)
	# bancs
	for bp in [Vector3(-6.0, 0, -33.2), Vector3(10.0, 0, -34.0), Vector3(-16.0, 0, -44.0)]:
		Bld.box(self, Vector3(2.0, 0.08, 0.5), bp + Vector3(0, 0.45, 0), _wood_m)
		Bld.box(self, Vector3(2.0, 0.5, 0.08), bp + Vector3(0, 0.75, -0.25), _wood_m)
		Bld.block(self, Vector3(2.0, 0.9, 0.5), bp + Vector3(0, 0.45, 0))
	# banc de musculation
	Bld.box(self, Vector3(0.5, 0.4, 1.4), Vector3(18.0, 0.3, -42.0), Bld.mat(null, Color(0.2, 0.2, 0.22), 0.7))
	Bld.cyl(self, 0.03, 2.0, Vector3(18.0, 0.95, -42.4), _metal_m, Vector3(0, 0, 90))
	Bld.cyl(self, 0.22, 0.08, Vector3(17.1, 0.95, -42.4), _dark_m, Vector3(0, 0, 90))
	Bld.cyl(self, 0.22, 0.08, Vector3(18.9, 0.95, -42.4), _dark_m, Vector3(0, 0, 90))
	Bld.block(self, Vector3(2.0, 0.9, 1.4), Vector3(18.0, 0.45, -42.2))
	# caisses empilées
	for cp in [Vector3(-24.0, 0, -44.0), Vector3(-22.6, 0, -44.2), Vector3(-23.3, 0.8, -44.1)]:
		Bld.box(self, Vector3(1.2, 0.8, 1.2), cp + Vector3(0, 0.4, 0), _wood_m)
	# lampadaires
	for lp in [Vector3(-12.0, 0, -36.0), Vector3(12.0, 0, -36.0), Vector3(0.0, 0, -12.0), Vector3(-12.0, 0, -46.0)]:
		Bld.cyl(self, 0.07, 4.5, lp + Vector3(0, 2.25, 0), _metal_m)
		Bld.sph(self, 0.25, lp + Vector3(0, 4.55, 0), Bld.emissive(Color(1.0, 0.9, 0.6), 1.3))
	# arbres dans la cour
	_tree(Vector3(-25.0, 0, -46.0))
	_tree(Vector3(26.0, 0, -36.0))
	# panneau "COUR"
	var cour := Label3D.new()
	cour.text = "COUR DE PROMENADE"
	cour.font_size = 100
	cour.pixel_size = 0.01
	cour.modulate = Color(0.9, 0.9, 1.0)
	cour.outline_size = 14
	cour.position = Vector3(2.2, 3.7, -7.35)
	add_child(cour)
	cour.rotation_degrees = Vector3(0, 180, 0)


func _tower() -> void:
	var tp := Vector3(24.0, 0.0, -47.0)
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			Bld.box(self, Vector3(0.3, 6.0, 0.3), tp + Vector3(lx, 3.0, lz), _wall_m)
	Bld.box(self, Vector3(3.2, 2.0, 3.2), tp + Vector3(0, 7.0, 0), _wall_m)
	Bld.box(self, Vector3(3.6, 0.3, 3.6), tp + Vector3(0, 8.15, 0), _dark_m)
	Bld.quad(self, Vector2(2.4, 0.9), tp + Vector3(-1.61, 7.3, 0), Bld.emissive(Color(0.9, 0.85, 0.5), 0.8), Vector3(0, -90, 0))


func _make_tray(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.visible = false
	parent.add_child(root)
	var tray_m: StandardMaterial3D = Bld.tiled(Tex.metal(Color(0.55, 0.56, 0.58)), 0.4, Color.WHITE, 0.5, 0.6)
	Bld.box(root, Vector3(0.55, 0.025, 0.4), Vector3(0, 0.012, 0), tray_m)
	Bld.box(root, Vector3(0.55, 0.03, 0.015), Vector3(0, 0.025, 0.195), tray_m)
	Bld.box(root, Vector3(0.55, 0.03, 0.015), Vector3(0, 0.025, -0.195), tray_m)
	var food := Node3D.new()
	root.add_child(food)
	var food_m: StandardMaterial3D = Bld.mat(Tex.dirt(), Color(0.85, 0.8, 0.5), 0.9)
	Bld.cyl(food, 0.1, 0.03, Vector3(-0.12, 0.04, 0), Bld.mat(null, Color(0.9, 0.9, 0.88), 0.5))
	Bld.sph(food, 0.075, Vector3(-0.12, 0.06, 0), food_m, Vector3(1, 0.45, 1))
	Bld.cyl(food, 0.035, 0.07, Vector3(0.2, 0.05, -0.1), Bld.tiled(Tex.metal(Color(0.7, 0.7, 0.72)), 0.2, Color.WHITE, 0.4, 0.7), Vector3.ZERO, 0.04)
	Bld.box(food, Vector3(0.11, 0.035, 0.05), Vector3(0.1, 0.045, 0.12), Bld.mat(null, Color(0.78, 0.6, 0.35), 0.9))
	var cake := Node3D.new()
	cake.position = Vector3(0.1, 0.0, 0.0)
	cake.visible = false
	root.add_child(cake)
	Bld.cyl(cake, 0.12, 0.09, Vector3(0, 0.07, 0), Bld.mat(null, Color(0.85, 0.65, 0.3), 0.9))
	Bld.cyl(cake, 0.125, 0.035, Vector3(0, 0.13, 0), Bld.mat(null, Color(0.98, 0.78, 0.85), 0.5))
	Bld.sph(cake, 0.018, Vector3(0, 0.165, 0), Bld.mat(null, Color(0.8, 0.05, 0.1), 0.3))
	Bld.cyl(cake, 0.006, 0.07, Vector3(0.05, 0.19, 0.03), Bld.mat(null, Color(0.95, 0.95, 0.4), 0.8))
	var spoon := Node3D.new()
	spoon.visible = false
	cake.add_child(spoon)
	var sp_m: StandardMaterial3D = Bld.tiled(Tex.metal(Color(0.85, 0.86, 0.9)), 0.1, Color.WHITE, 0.25, 0.9)
	Bld.box(spoon, Vector3(0.012, 0.01, 0.1), Vector3(-0.06, 0.15, 0.05), sp_m, Vector3(-20, 0, 0))
	Bld.sph(spoon, 0.025, Vector3(-0.06, 0.18, -0.01), sp_m, Vector3(0.9, 0.35, 1.3))
	return {"root": root, "food": food, "cake": cake, "spoon": spoon, "food_m": food_m}


func _trays() -> void:
	counter = _make_tray(self)
	counter["root"].position = Vector3(24.9, 1.07, -21.0)
	counter["root"].rotation.y = PI * 0.5
	table_tray = _make_tray(self)


func _coins() -> void:
	var coin_m: StandardMaterial3D = Bld.emissive(Color(1.0, 0.8, 0.2), 0.5)
	coin_m.metallic = 0.8
	for i in COIN_POS.size():
		var n := Node3D.new()
		n.position = COIN_POS[i] + Vector3(0, 0.75, 0)
		add_child(n)
		Bld.cyl(n, 0.16, 0.04, Vector3.ZERO, coin_m, Vector3(90, 0, 0))
		coins.append({"node": n, "active": true})


func _graph() -> void:
	var i: int = 0
	for k in NODES:
		astar.add_point(i, NODES[k])
		_ids[k] = i
		i += 1
	for e in EDGES:
		astar.connect_points(_ids[e[0]], _ids[e[1]])


func _sun() -> void:
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = false
	sun.light_cull_mask = 2
	add_child(sun)


func _npcs() -> void:
	var yard_pts: Array = [
		Vector3(4, 0, -12), Vector3(-4, 0, -12), Vector3(-8, 0, -36), Vector3(0, 0, -40), Vector3(8, 0, -38),
		Vector3(-14, 0, -42), Vector3(14, 0, -40), Vector3(22, 0, -40), Vector3(-20, 0, -47), Vector3(25, 0, -33),
	]
	var cantine_pts: Array = [Vector3(12, 0, -21), Vector3(16, 0, -21), Vector3(22, 0, -19), Vector3(17, 0, -29)]
	var orange: Color = Color(0.95, 0.45, 0.08)
	var skins: Array = [Color(0.85, 0.62, 0.5), Color(0.55, 0.38, 0.28), Color(0.92, 0.75, 0.62), Color(0.4, 0.28, 0.2)]

	var marco: Npc = _spawn("Marco", "shop", Color(0.15, 0.3, 0.45), skins[1], Color(0.1, 0.08, 0.06), "beanie", Vector3(-6.8, 0, -31.6), "npc_marco")
	marco.rotation.y = PI * 0.5
	var jo: Npc = _spawn("Vieux Jo", "hint", Color(0.4, 0.5, 0.3), skins[2], Color(0.8, 0.8, 0.8), "hat", Vector3(-20.5, 0, -22.5), "npc_jo")
	jo.rotation.y = -PI * 0.5
	var cook: Npc = _spawn("Gros Rémi", "cook", Color(0.95, 0.95, 0.93), skins[0], Color(0.3, 0.2, 0.1), "cook", Vector3(26.3, 0, -21.0), "npc_cook")
	cook.rotation.y = -PI * 0.5
	var names: Array = ["Pablo", "Dédé", "Moussa", "Igor", "Tonio", "Sam"]
	var lines: Array = [
		["Fais gaffe à Gaston, il voit tout quand il ne dort pas."],
		["Le déjeuner, c'est le meilleur moment. Le reste, c'est la galère."],
		["On dit qu'il y a un colis pour toi. Moi je dis rien."],
		["Chaque jour la même chose... j'en peux plus."],
		["Marco vend de tout, mais tout est cher."],
		["Si t'as des sous, va voir Marco dans la cour."],
	]
	for i in 6:
		var inside: bool = i >= 4
		var n: Npc = _spawn(names[i], "chat", orange, skins[i % 4], Color(0.1, 0.07, 0.05), "", (cantine_pts if inside else yard_pts)[i % 4], "npc_chat")
		n.wander = cantine_pts if inside else yard_pts
		n.chatter = lines[i]
		n.walk_speed = 0.9 + 0.08 * float(i)


func _spawn(n: String, role: String, shirt: Color, skin: Color, hair: Color, extra: String, pos: Vector3, hit_id: String) -> Npc:
	var npc := Npc.new()
	npc.position = pos
	add_child(npc)
	npc.setup(n, role, shirt, skin, hair, extra)
	Bld.hit(npc, hit_id, Vector3(0.8, 1.8, 0.8), Vector3(0, 0.9, 0), 2.2)
	npcs.append(npc)
	return npc


# ------------------------------------------------------------------ API

## Marque un sous-arbre comme "extérieur" : il reçoit la lumière du soleil (couche 2).
func mark(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).layers |= 2
	for c in n.get_children():
		mark(c)


func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a: int = astar.get_closest_point(from)
	var b: int = astar.get_closest_point(to)
	var out := PackedVector3Array()
	if a != b:
		for p in astar.get_point_path(a, b):
			out.append(p)
	out.append(to)
	return out


func node_pos(name: String) -> Vector3:
	return NODES[name]


func in_cell(p: Vector3) -> bool:
	return p.x > -2.0 and p.x < 2.0 and p.z > -1.95 and p.z < 2.0


func in_block(p: Vector3) -> bool:
	return BLOCK_RECT.has_point(Vector2(p.x, p.z))


func show_counter_tray(with_cake: bool, kind: String) -> void:
	counter["root"].visible = true
	counter["cake"].visible = with_cake
	counter["spoon"].visible = false
	counter["food"].scale = Vector3.ONE
	counter["food"].visible = true
	var m: StandardMaterial3D = counter["food_m"]
	match kind:
		"breakfast":
			m.albedo_color = Color(0.9, 0.85, 0.7)
		"lunch":
			m.albedo_color = Color(0.75, 0.6, 0.35)
		_:
			m.albedo_color = Color(0.6, 0.7, 0.4)


func hide_counter_tray() -> void:
	counter["root"].visible = false


func place_table_tray(at: Vector3, with_cake: bool) -> void:
	table_tray["root"].position = at + Vector3(0, 0.9, 0)
	table_tray["root"].visible = true
	table_tray["cake"].visible = with_cake
	table_tray["spoon"].visible = false
	table_tray["food"].scale = Vector3.ONE
	table_tray["food"].visible = true
	table_tray["food_m"].albedo_color = (counter["food_m"] as StandardMaterial3D).albedo_color


func set_table_food(frac: float) -> void:
	table_tray["food"].scale = Vector3(1, maxf(frac, 0.02), 1)
	table_tray["food"].visible = frac > 0.03


func cut_table_cake() -> void:
	table_tray["cake"].scale = Vector3(1, 0.6, 1)
	table_tray["spoon"].visible = true


func take_cake_spoon() -> void:
	table_tray["spoon"].visible = false
	table_tray["cake"].visible = false


func hide_table_tray() -> void:
	table_tray["root"].visible = false


func water_bed(i: int) -> void:
	beds[i]["watered"] = true
	for f in beds[i]["fruits"]:
		f.visible = true


func is_watered(i: int) -> bool:
	return beds[i]["watered"]


## Nouveau jour : les plantes ont soif et les pièces réapparaissent.
func reset_day() -> void:
	for b in beds:
		b["watered"] = false
		for f in b["fruits"]:
			f.visible = false
	for c in coins:
		c["active"] = true
		c["node"].visible = true


## Ramasse les pièces proches ; renvoie le nombre ramassé.
func collect_coins(p: Vector3) -> int:
	var n: int = 0
	for c in coins:
		if c["active"] and (c["node"] as Node3D).global_position.distance_to(p + Vector3(0, 0.9, 0)) < 1.3:
			c["active"] = false
			c["node"].visible = false
			n += 1
	return n


func set_tod(minutes: float, night: bool) -> void:
	cell.set_tod(minutes, night)
	var h: float = minutes / 60.0
	var day_f: float = clampf(smoothstep(5.0, 7.5, h) - smoothstep(18.0, 21.0, h), 0.0, 1.0)
	var dusk: float = clampf(smoothstep(16.5, 19.0, h) - smoothstep(19.0, 21.0, h), 0.0, 1.0)
	var sky: Color = Color(0.015, 0.02, 0.05).lerp(Color(0.5, 0.7, 0.95), day_f)
	sky = sky.lerp(Color(0.9, 0.5, 0.3), dusk * 0.6)
	cell.env.background_color = sky
	cell.env.fog_light_color = sky * 0.8
	cell.env.fog_density = 0.004
	sun.light_energy = lerpf(0.12, 1.15, day_f)
	sun.light_color = Color(0.6, 0.7, 1.0).lerp(Color(1.0, 0.95, 0.85), day_f).lerp(Color(1.0, 0.6, 0.35), dusk * 0.7)
	sun.rotation_degrees.x = lerpf(-15.0, -62.0, sin(clampf((h - 5.0) / 14.0, 0.0, 1.0) * PI))


func _process(delta: float) -> void:
	_t += delta
	for c in coins:
		if c["active"]:
			(c["node"] as Node3D).rotation.y = _t * 2.5
			(c["node"] as Node3D).position.y = 0.75 + sin(_t * 2.0 + (c["node"] as Node3D).position.x) * 0.06
