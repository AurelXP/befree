class_name Minimap
extends Control
## Mini-carte : bâtiments, joueur (flèche blanche), garde (rouge), PNJ (bleu), points d'intérêt.

var map_rect: Rect2 = World.MAP_RECT
var player_pos: Vector3 = Vector3.ZERO
var player_yaw: float = 0.0
var guard_pos: Vector3 = Vector3.ZERO
var guard_visible: bool = true
var npc_pos: Array = []
var shop_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(150, 164)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_view(p: Vector3, yaw: float, g: Vector3, npcs: Array, shop: Vector3) -> void:
	player_pos = p
	player_yaw = yaw
	guard_pos = g
	npc_pos = npcs
	shop_pos = shop
	queue_redraw()


func _pt(w: Vector3) -> Vector2:
	var s: Vector2 = size
	return Vector2((w.x - map_rect.position.x) / map_rect.size.x * s.x, (w.z - map_rect.position.y) / map_rect.size.y * s.y)


func _rect(r: Rect2) -> Rect2:
	var a: Vector2 = _pt(Vector3(r.position.x, 0, r.position.y))
	var b: Vector2 = _pt(Vector3(r.end.x, 0, r.end.y))
	return Rect2(a, b - a)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.1, 0.08, 0.7))
	draw_rect(_rect(Rect2(-29.0, -50.5, 58.0, 43.0)), Color(0.45, 0.45, 0.42, 0.8))
	draw_rect(_rect(World.GARDEN_RECT), Color(0.2, 0.5, 0.2, 0.9))
	draw_rect(_rect(World.CANTINE_RECT), Color(0.7, 0.4, 0.3, 0.95))
	draw_rect(_rect(World.BLOCK_RECT), Color(0.6, 0.6, 0.65, 0.95))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)
	draw_circle(_pt(shop_pos), 3.0, Color(1.0, 0.85, 0.2))
	for n in npc_pos:
		draw_circle(_pt(n), 2.0, Color(0.5, 0.7, 1.0, 0.8))
	if guard_visible:
		draw_circle(_pt(guard_pos), 4.0, Color(1.0, 0.2, 0.15))
	var pp: Vector2 = _pt(player_pos)
	var f: Vector2 = Vector2(-sin(player_yaw), -cos(player_yaw))
	var r: Vector2 = Vector2(-f.y, f.x)
	draw_colored_polygon(PackedVector2Array([pp + f * 7.0, pp - f * 4.0 + r * 4.0, pp - f * 4.0 - r * 4.0]), Color.WHITE)
