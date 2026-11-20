extends SceneTree
## Test automatisé de bout en bout (headless) : cantine, gâteau/cuillère, poster, creusage,
## patrouille du garde, jardin, boutique, couvre-feu, punition, évasion.
## Usage : godot --headless --path . -s tools/test_play.gd

var g: Node
var main: Node
var fails: int = 0


func _w(sec: float) -> void:
	var t: float = 0.0
	while t < sec:
		if g.speed > 0.5 and not g.digging and not g.sleeping:
			g.speed = 1.0 / Engine.time_scale
		await create_timer(0.1).timeout
		t += 0.1


func _check(name: String, cond: bool, extra: String = "") -> void:
	print(("OK   " if cond else "FAIL ") + name + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1


func _goto(p: Vector3) -> void:
	main.player.teleport(p, 0.0)
	await _w(0.35)


func _near(id: String) -> bool:
	for i in 12:
		if main.near_id == id:
			return true
		await _w(0.1)
	return false


func _init() -> void:
	await process_frame
	g = root.get_node("Game")
	Engine.time_scale = 4.0
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await _w(0.5)
	main.hud.show_title(false)
	await main._begin_play()
	await _w(0.5)
	_check("partie lancée", main.state == "play")

	# --- patrouille du garde
	var gp0: Vector3 = main.guard.global_position
	var far: float = 0.0
	for i in 60:
		await _w(0.5)
		far = maxf(far, main.guard.global_position.distance_to(gp0))
	_check("le garde patrouille loin de son bureau", far > 6.0, "distance max %.1f m" % far)

	# --- déjeuner à la cantine
	g.minutes = 779.5
	await _w(1.5)
	_check("phase repas", g.phase == "meal" and g.kind == "lunch")
	_check("plateau avec gâteau au comptoir", main.world.counter["root"].visible and main.world.counter["cake"].visible)
	await _goto(Vector3(23.6, 0.05, -21.0))
	_check("proche du comptoir", await _near("tray_counter"), main.near_id)
	main._on_action_down()
	await _w(0.3)
	_check("plateau pris", g.has_tray and g.tray_cake)
	await _goto(Vector3(14.0, 0.05, -24.2))
	_check("proche d'une table", await _near("eat"), main.near_id)
	main._on_action_down()
	await _w(6.0)
	_check("cuillère trouvée dans le gâteau", g.has_spoon)
	main._on_action_down()
	await _w(8.0)
	_check("repas terminé (corvée faite)", g.duty_done and not g.has_tray)

	# --- jardin : arroser = argent
	g.minutes = 800.0
	await _w(0.5)
	var money0: int = g.money
	await _goto(Vector3(-24.0, 0.05, -25.4))
	var wid: String = ""
	for i in 12:
		if main.near_id.begins_with("water_"):
			wid = main.near_id
			break
		await _w(0.1)
	_check("proche d'un parterre", wid != "", main.near_id)
	main._on_action_down()
	await _w(5.0)
	_check("arrosage rapporte 6 €", g.money >= money0 + 6, "argent %d" % g.money)

	# --- boutique
	g.money = 100
	await _goto(Vector3(-5.2, 0.05, -31.6))
	_check("proche de Marco", await _near("npc_marco"), main.near_id)
	main._on_action_down()
	await _w(0.3)
	_check("dialogue ouvert", main.hud.is_dialog_open())
	main._on_dialog_choice("buy_pelle")
	await _w(0.2)
	_check("pelle achetée", g.has_pelle and g.money == 40, "argent %d" % g.money)
	main._on_dialog_choice("close")
	await _w(0.3)
	_check("dialogue fermé", not main.hud.is_dialog_open() and not main.busy)

	# --- cellule : poster, cuillère, creusage (la nuit, garde endormi)
	g.minutes = 1300.0
	await _w(1.0)
	await _goto(Vector3(1.2, 0.05, 0.3))
	_check("couvre-feu : porte de cellule fermée", main._door_closed)
	_check("proche du poster", await _near("poster"), main.near_id)
	main._on_action_down()
	await _w(1.0)
	_check("poster tiré", g.poster_moved)
	main._on_spoon()
	_check("cuillère équipée", g.spoon_equipped)
	_check("proche du trou", await _near("hole"), main.near_id)
	main._on_action_down()
	g.speed = 1.0 / Engine.time_scale
	await _w(8.0)
	_check("creusage en cours", g.dig > 5.0, "tunnel %.1f%%" % g.dig)
	main._on_action_up()
	await _w(0.3)
	_check("creusage arrêté", not g.digging)

	# --- punition
	var strikes0: int = g.strikes
	main._trigger_caught("suspicion")
	for i in 100:
		if g.strikes > strikes0 and not main.in_caught:
			break
		await _w(0.5)
	print("  etat: in_caught=", main.in_caught, " guard busy=", main.guard.is_busy(), " pos=", main.guard.global_position)
	_check("coup de matraque, joueur ramené en cellule", g.strikes == strikes0 + 1 and main.world.in_cell(main.player.pos()), "coups %d" % g.strikes)
	_check("poster remis, cuillère rangée", not g.poster_moved and not g.spoon_equipped)

	# --- couvre-feu hors cellule
	await _goto(Vector3(2.2, 0.05, -20.0))
	strikes0 = g.strikes
	for i in 100:
		if g.strikes > strikes0 and not main.in_caught:
			break
		await _w(0.5)
	_check("couvre-feu violé = punition", g.strikes == strikes0 + 1, "coups %d" % g.strikes)

	# --- évasion
	g.strikes = 0
	main.in_caught = false
	main.state = "play"
	g.running = true
	main.player.input_enabled = true
	main.player.locked = false
	await _goto(Vector3(1.2, 0.05, 0.3))
	g.poster_moved = true
	main.cell.set_poster_moved(true, false)
	g.spoon_equipped = true
	g.dig = 99.5
	g.minutes = 1300.0
	main.guard.set_mode("doze")
	await _w(1.0)
	_check("proche du trou (évasion)", await _near("hole"), main.near_id)
	main._on_action_down()
	g.speed = 1.0 / Engine.time_scale
	await _w(8.0)
	_check("évasion réussie", main.state == "end")
	print("FAILS: ", fails)
	quit(1 if fails > 0 else 0)
