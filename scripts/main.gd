extends Node3D
## Chef d'orchestre : assemble la prison, le garde, le joueur et l'interface,
## et applique les règles (routine, cantine, jardin, boutique, couvre-feu, suspicion, tunnel).

const CURFEW_TIME: float = 16.0
const INSPECT_DELAY: float = 12.0
const PRICES: Dictionary = {"pelle": 60, "socks": 30, "bribe": 45, "coffee": 8}

const FLAVOR: Dictionary = {
	"bed": "Un matelas dur comme du béton. Mais c'est TON matelas.",
	"sink": "L'eau est glacée. Tu te rafraîchis le visage.",
	"window": "Trop petite, trop haute, trop de barreaux. Pas par là.",
	"tally": "Chaque trait, un jour de perdu. Ça va changer.",
}

var world: World
var cell: Cell
var guard: Guard
var player: Player
var hud: Hud
var cine: Cinematic
var sfx: Sfx

var state: String = "menu"  # menu | intro | play | over | end
var busy: bool = false
var in_caught: bool = false

var near_id: String = ""
var near_node: Node3D = null
var aux_active: bool = false

var _action_id: int = 0
var _tod_t: float = 0.0
var _mode_t: float = 0.0
var _near_t: float = 0.0
var _sus_t: float = 0.0
var _seen: bool = false
var _hole_seen: bool = false
var _dig_marks: int = 0
var _warned: bool = false
var _starting: bool = false
var _dig_active: bool = false
var _curfew_t: float = CURFEW_TIME
var _curfew_warned: bool = false
var _inspect_t: float = -1.0
var _door_closed: bool = false
var _exit_closed: bool = false
var _dialog_npc: Npc = null
var _dialog_role: String = ""


func _ready() -> void:
	world = World.new()
	add_child(world)
	world.build()
	cell = world.cell
	guard = Guard.new()
	add_child(guard)
	guard.path_fn = world.path
	for k in ["c_door", "y_mid", "y_center", "g_in", "k_in", "y_far", "k_mid", "y_east", "y_west", "y_gate"]:
		guard.patrol_points.append(world.node_pos(k))
	world.mark(guard)
	player = Player.new()
	add_child(player)
	world.mark(player.hands)
	hud = Hud.new()
	add_child(hud)
	player.controls = hud.touch
	cine = Cinematic.new()
	add_child(cine)
	cine.setup(cell, guard, player, hud)
	sfx = Sfx.new()
	add_child(sfx)
	sfx.start_ambience()

	Game.reset()
	Game.phase_changed.connect(_on_phase)
	Game.caught.connect(_trigger_caught)
	Game.game_over.connect(_on_game_over)
	Game.day_started.connect(_on_new_day)
	hud.play_pressed.connect(_on_play)
	hud.retry_pressed.connect(_on_retry)
	hud.spoon_pressed.connect(_on_spoon)
	hud.speed_pressed.connect(_on_speed)
	hud.action_down.connect(_on_action_down)
	hud.action_up.connect(_on_action_up)
	hud.aux_pressed.connect(_on_aux)
	hud.jump_pressed.connect(func() -> void: player.jump())
	hud.dialog_choice.connect(_on_dialog_choice)
	guard.swing_hit.connect(_on_swing)

	world.set_tod(Game.minutes, false)
	cell.set_dig(0.0)
	hud.show_title(true)
	if Game.auto_start:
		Game.auto_start = false
		_on_play()


# ------------------------------------------------------------------ flux

func _on_play() -> void:
	if _starting:
		return
	_starting = true
	hud.show_title(false)
	if not Game.seen_intro:
		state = "intro"
		await cine.intro()
		Game.seen_intro = true
	await _begin_play()


func _on_retry() -> void:
	Game.auto_start = true
	get_tree().reload_current_scene()


func _begin_play() -> void:
	Game.reset()
	world.reset_day()
	cell.set_poster_moved(false, false)
	cell.set_dig(0.0)
	cell.tray.visible = false
	cell.open_door(true)
	cell.open_exit(true)
	_door_closed = false
	_exit_closed = false
	world.hide_counter_tray()
	world.hide_table_tray()
	player.teleport(World.SPAWN, 0.0)
	player.locked = false
	player.cinematic = false
	player.hands.visible = true
	player.hands.set_pose("idle")
	player.hands.set_spoon(false)
	guard.position = Guard.SEAT
	world.set_tod(Game.minutes, false)
	guard.set_mode("patrol")
	hud.set_gameplay_visible(true)
	hud.set_objective("Explore la prison. Un colis de Léa arrive à la cantine au déjeuner (13:00). Gagne un peu d'argent au jardin.")
	await hud.fade_to(0.0, 0.6)
	state = "play"
	player.input_enabled = true
	Game.start()
	hud.toast("Joystick à gauche pour marcher, glisse à droite pour regarder.", 6.0)


func _on_game_over() -> void:
	state = "over"
	Game.digging = false
	_dig_active = false
	player.input_enabled = false
	cell.set_digging_fx(false)
	sfx.dig_loop(false)
	sfx.play("alarm", -4.0)
	hud.hide_dialog()
	await get_tree().create_timer(1.6).timeout
	hud.show_gameover()


func _escape() -> void:
	if state != "play":
		return
	state = "end"
	sfx.dig_loop(false)
	sfx.play("win", -2.0)
	Game.running = false
	Game.digging = false
	_dig_active = false
	player.input_enabled = false
	cell.set_digging_fx(false)
	hud.set_gameplay_visible(false)
	await cine.ending()
	hud.show_end()


func _on_new_day(d: int) -> void:
	if state != "play":
		return
	world.reset_day()
	hud.banner("Jour %d" % d, Color(1, 0.9, 0.6))
	hud.toast("Les plantes ont soif et des pièces traînent dans la prison.", 4.0)


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	_tod_t += delta
	if _tod_t > 0.2:
		_tod_t = 0.0
		world.set_tod(Game.minutes, Game.is_night())
	guard.gaze = player.head_pos()
	if state != "play":
		return
	player.boost = Game.boost_t > 0.0
	hud.refresh()
	_update_minimap()
	_update_near(delta)
	_update_guard_mode(delta)
	_update_doors_and_curfew(delta)
	_update_suspicion(delta)
	_update_dig(delta)
	_update_coins()
	_update_sleep()


func _update_minimap() -> void:
	var pts: Array = []
	for n in world.npcs:
		pts.append((n as Node3D).global_position)
	hud.minimap.update_view(player.pos(), player.yaw, guard.global_position, pts, world.npcs[0].global_position)


func _update_coins() -> void:
	var n: int = world.collect_coins(player.pos())
	if n > 0:
		Game.money += 2 * n
		sfx.play("clink", -6.0)
		hud.toast("+%d € ramassés" % (2 * n), 1.6)


func _update_sleep() -> void:
	if Game.sleeping and Game.phase != "night":
		_wake()


func _update_guard_mode(delta: float) -> void:
	_mode_t += delta
	if _mode_t < 0.4:
		return
	_mode_t = 0.0
	if guard.is_busy() or in_caught:
		return
	var want: String = "patrol"
	var arg: Vector3 = Vector3.ZERO
	match Game.phase:
		"meal":
			if not Game.duty_done:
				want = "post"
				arg = world.node_pos("k_in")
		"pee":
			if not Game.duty_done:
				want = "post"
				arg = world.node_pos("c_door")
		"inspect":
			want = "post"
			arg = world.node_pos("c_door")
		"night":
			want = "doze"
	if want != guard.mode or (want == "post" and not guard.post_point.is_equal_approx(arg)):
		guard.set_mode(want, arg)


func _update_doors_and_curfew(delta: float) -> void:
	var lock: bool = Game.phase == "inspect" or Game.phase == "night"
	var pp: Vector3 = player.pos()
	var inside: bool = world.in_cell(pp)
	var in_block: bool = world.in_block(pp)
	var want_door: bool = lock and inside
	var want_exit: bool = lock and in_block
	if want_door != _door_closed:
		_door_closed = want_door
		cell.open_door(not want_door)
		if want_door:
			sfx.play("clink", -2.0)
	if want_exit != _exit_closed:
		_exit_closed = want_exit
		cell.open_exit(not want_exit)
	# couvre-feu : il faut être dans la cellule pendant l'inspection et la nuit
	if lock and not inside and not in_caught:
		_curfew_t -= delta
		if not _curfew_warned:
			_curfew_warned = true
			hud.toast("Retourne dans ta cellule, vite !", 4.0)
		if _curfew_t <= 0.0:
			_trigger_caught("curfew")
	else:
		_curfew_t = CURFEW_TIME
		_curfew_warned = false
	# inspection de la cellule
	if Game.phase == "inspect" and _inspect_t > 0.0:
		_inspect_t -= delta
		if _inspect_t <= 0.0 and not in_caught:
			if inside:
				if Game.spoon_equipped or Game.poster_moved:
					_trigger_caught("inspection")
				else:
					guard.say("Rien à signaler... pour cette fois.", 3.0)
					hud.toast("Inspection réussie.", 2.5)


func _update_suspicion(delta: float) -> void:
	if in_caught:
		return
	var aw: Vector2 = guard.awareness()
	_sus_t -= delta
	if _sus_t <= 0.0:
		_sus_t = 0.12
		_seen = guard.can_see(player.head_pos())
		_hole_seen = Game.poster_moved and guard.can_see(cell.hole_node.global_position)
	var rate: float = 0.0
	if _seen:
		if Game.spoon_equipped:
			rate += 14.0
		if Game.digging:
			rate += 32.0
	if _hole_seen:
		rate += 10.0
	rate *= aw.x
	var dist: float = guard.global_position.distance_to(player.pos())
	if Game.digging and dist < 9.0:
		rate += 18.0 * aw.y * Game.noise_mult() * (1.0 - dist / 9.0)
	var decay: float = 10.0 if rate < 0.05 else 5.0
	Game.suspicion = clampf(Game.suspicion + (rate - decay) * delta, 0.0, 100.0)
	if Game.suspicion > 55.0 and not _warned:
		_warned = true
		hud.toast("Gaston se méfie... Cache-toi !", 2.5)
	elif Game.suspicion < 25.0:
		_warned = false
	if Game.suspicion >= 100.0:
		_trigger_caught("suspicion")


func _update_dig(delta: float) -> void:
	if not Game.digging:
		return
	if not (Game.poster_moved and Game.spoon_equipped) or in_caught:
		_stop_dig()
		return
	Game.dig = minf(100.0, Game.dig + Game.dig_rate() * delta)
	cell.set_dig(Game.dig)
	var marks: int = int(Game.dig / 25.0)
	if marks > _dig_marks and marks < 4:
		_dig_marks = marks
		match marks:
			1:
				hud.toast("Les briques commencent à céder...", 3.0)
			2:
				hud.toast("À mi-chemin ! Le mur est plus fin que prévu.", 3.0)
			3:
				hud.toast("Tu sens l'air frais de l'extérieur !", 3.0)
	if Game.dig >= 100.0:
		_escape()


# ------------------------------------------------------------------ phases

func _on_phase(phase: String, kind: String) -> void:
	if state != "play":
		return
	if phase != "meal":
		Game.has_tray = false
		world.hide_counter_tray()
		if not busy:
			world.hide_table_tray()
	if phase != "free":
		sfx.play("bell", -6.0)
	match phase:
		"meal":
			var with_cake: bool = (kind == "lunch" and not Game.has_spoon)
			world.show_counter_tray(with_cake, kind)
			var lines: Dictionary = {
				"breakfast": "Petit-déj ! Magne-toi !",
				"lunch": "À table, la racaille !",
				"dinner": "Dîner ! Et ça se mange en silence !",
			}
			guard.say(lines.get(kind, "À manger !"), 3.0)
			hud.banner("Repas à la cantine !", Color(1, 0.75, 0.3))
			if with_cake:
				hud.toast("Un colis de Léa : un gâteau d'anniversaire ! Prends ton plateau au comptoir.", 6.0)
			else:
				hud.toast("Va à la cantine, prends ton plateau au comptoir puis mange à une table.", 5.0)
		"pee":
			guard.say("Debout ! Tout le monde aux toilettes !", 3.0)
			hud.banner("Toilettes !", Color(0.5, 0.8, 1.0))
			hud.toast("Retourne dans ta cellule et utilise les toilettes.", 4.0)
		"inspect":
			guard.say("INSPECTION ! Tout le monde en cellule !", 3.0)
			hud.banner("INSPECTION !", Color(1, 0.3, 0.25))
			hud.toast("En cellule ! Remets le poster et range la cuillère !", 4.0)
			_inspect_t = INSPECT_DELAY
		"night":
			guard.say("Couvre-feu... *bâille*", 3.0)
			hud.banner("Couvre-feu", Color(0.55, 0.65, 1.0))
			hud.toast("Regagne ta cellule. Dors sur ton lit, ou creuse en silence...", 5.0)


# ------------------------------------------------------------------ interactions (proximité)

func _id_available(id: String) -> bool:
	match id:
		"poster":
			return not Game.poster_moved
		"hole":
			return Game.poster_moved
		"tray_counter":
			return true
	return true


func _label_for(id: String) -> String:
	if Game.sleeping:
		return "Se réveiller"
	match id:
		"toilet":
			return "Toilettes"
		"sink":
			return "Se laver"
		"bed":
			return "Dormir" if Game.phase == "night" else "Le lit"
		"window":
			return "Regarder dehors"
		"tally":
			return "Les traits"
		"poster":
			return "Tirer le poster"
		"hole":
			return "Creuser (maintenir)"
		"tray_counter":
			return "Prendre le plateau"
		"eat":
			if not Game.has_tray:
				return "Table"
			if Game.tray_cake and not Game.has_spoon:
				return "Fouiller le gâteau"
			return "Manger"
		"npc_marco":
			return "Parler à Marco"
		"npc_jo":
			return "Parler à Jo"
		"npc_cook":
			return "Parler au cuistot"
		"npc_chat":
			return "Discuter"
	if id.begins_with("water_"):
		return "Arroser"
	return ""


func _update_near(delta: float) -> void:
	_near_t -= delta
	if _near_t > 0.0:
		return
	_near_t = 0.1
	var pp: Vector3 = player.pos()
	var best: float = 1e9
	var best_node: Node3D = null
	var poster_d: float = 1e9
	for n in get_tree().get_nodes_in_group("interact"):
		var nd: Node3D = n
		if not nd.is_visible_in_tree():
			continue
		var id: String = nd.get_meta("id")
		var gp: Vector3 = nd.global_position
		var d: float = Vector2(gp.x - pp.x, gp.z - pp.z).length()
		if id == "poster":
			poster_d = d
		if d > float(nd.get_meta("radius")) or not _id_available(id):
			continue
		if id.begins_with("npc_"):
			d -= 0.4
		if d < best:
			best = d
			best_node = nd
	if Game.poster_moved:
		poster_d = Vector2(cell.poster_pivot.global_position.x - pp.x, cell.poster_pivot.global_position.z - pp.z).length()
	near_node = best_node
	near_id = (best_node.get_meta("id") if best_node != null else "")
	aux_active = Game.poster_moved and poster_d < 2.2 and not Game.sleeping
	if _dig_active:
		hud.set_action("Creuser...")
		hud.set_aux("")
	elif state == "play" and not in_caught and not hud.is_dialog_open() and not busy:
		hud.set_action(_label_for(near_id) if near_id != "" else ("Se réveiller" if Game.sleeping else ""))
		hud.set_aux("Remettre le poster" if aux_active else "")
	else:
		hud.set_action("")
		hud.set_aux("")


func _begin() -> int:
	busy = true
	_action_id += 1
	return _action_id


func _alive(id: int) -> bool:
	return id == _action_id and state == "play" and not in_caught


func _end(id: int) -> void:
	if id == _action_id:
		busy = false
		player.locked = false
		player.hands.set_pose("idle")


func _on_action_down() -> void:
	if state != "play" or in_caught or busy:
		return
	if Game.sleeping:
		_wake()
		return
	if near_id == "":
		return
	var id: String = near_id
	if id.begins_with("water_"):
		_water(int(id.substr(6)))
		return
	match id:
		"toilet":
			_use_toilet()
		"sink", "window", "tally":
			_flavor(id)
		"bed":
			if Game.phase == "night":
				_sleep()
			else:
				_flavor(id)
		"poster":
			_toggle_poster()
		"hole":
			_start_dig()
		"tray_counter":
			_take_tray()
		"eat":
			_eat()
		"npc_marco", "npc_jo", "npc_cook", "npc_chat":
			_open_dialog(near_node.get_parent() as Npc, id)


func _on_action_up() -> void:
	if _dig_active:
		_stop_dig()


func _on_aux() -> void:
	if state != "play" or in_caught or busy or not Game.poster_moved:
		return
	_toggle_poster()


func _flavor(id: String) -> void:
	var my: int = _begin()
	hud.toast(FLAVOR.get(id, ""), 3.0)
	player.hands.reach()
	await get_tree().create_timer(0.6).timeout
	_end(my)


func _use_toilet() -> void:
	var my: int = _begin()
	player.locked = true
	player.face_toward(near_node.global_position + Vector3(0, -0.2, 0))
	player.hands.set_pose("pee")
	hud.toast("Tu te soulages...", 2.2)
	sfx.play("pee", -6.0)
	await get_tree().create_timer(2.6).timeout
	if not _alive(my):
		return
	sfx.play("flush", -6.0)
	if Game.phase == "pee" and not Game.duty_done:
		Game.finish_duty()
		guard.say("Bien. Maintenant, tiens-toi tranquille.", 3.0)
		hud.toast("Corvée accomplie.", 2.0)
	else:
		hud.toast("Ça soulage.", 2.0)
	_end(my)


func _take_tray() -> void:
	if Game.phase != "meal" or Game.duty_done or Game.has_tray:
		var npc: Npc = world.npcs[2]
		hud.toast("Gros Rémi : « Ce n'est pas l'heure du repas, détenu. »" if Game.phase != "meal" else "Tu as déjà ton plateau.", 3.0)
		npc.face(player.pos())
		return
	Game.has_tray = true
	Game.tray_cake = world.counter["cake"].visible
	world.hide_counter_tray()
	sfx.play("clink", -4.0)
	player.hands.reach()
	hud.toast("Plateau récupéré. Va t'asseoir à une table pour manger.", 4.0)
	if Game.tray_cake:
		hud.toast("Un gâteau ! Fouille-le à une table, il cache peut-être quelque chose...", 5.0)


func _eat() -> void:
	if not Game.has_tray:
		hud.toast("Prends d'abord un plateau au comptoir pendant les repas.", 3.0)
		return
	var my: int = _begin()
	player.locked = true
	var tp: Vector3 = near_node.global_position
	var at := Vector3(tp.x, 0.0, tp.z)
	world.place_table_tray(at, Game.tray_cake)
	player.face_toward(tp + Vector3(0, 0, 0))
	if Game.tray_cake and not Game.has_spoon:
		player.hands.set_pose("cake")
		hud.toast("Tu fouilles le gâteau...", 2.0)
		await get_tree().create_timer(1.6).timeout
		if not _alive(my):
			return
		world.cut_table_cake()
		sfx.play("clink", -4.0)
		await get_tree().create_timer(0.9).timeout
		if not _alive(my):
			return
		world.take_cake_spoon()
		Game.has_spoon = true
		Game.cake_given = true
		Game.tray_cake = false
		sfx.play("found", -4.0)
		hud.banner("Une cuillère !", Color(0.95, 0.85, 0.4))
		hud.toast("Léa a caché une cuillère dans le gâteau ! Finis ton repas, puis retourne en cellule.", 6.0)
		hud.set_objective("Retourne en cellule : tire le poster, sors la cuillère et creuse (maintiens Action) quand Gaston est loin. Achète une pelle et des chaussettes à Marco !")
		_end(my)
		return
	player.hands.set_pose("eat")
	for i in 3:
		sfx.play("chew", -4.0)
		await get_tree().create_timer(1.1).timeout
		if not _alive(my):
			return
		world.set_table_food(1.0 - float(i + 1) / 3.0)
	if not Game.duty_done:
		Game.finish_duty()
		guard.say("Voilà. Rends-moi ça.", 2.5)
		hud.toast("Repas terminé.", 2.0)
	await get_tree().create_timer(0.5).timeout
	if not _alive(my):
		return
	Game.has_tray = false
	world.hide_table_tray()
	_end(my)


func _water(i: int) -> void:
	if Game.phase == "night":
		hud.toast("Il fait nuit, les plantes dorment.", 2.5)
		return
	if world.is_watered(i):
		hud.toast("Ce parterre est déjà arrosé aujourd'hui.", 2.5)
		return
	var my: int = _begin()
	player.locked = true
	player.face_toward(near_node.global_position)
	player.hands.set_pose("cake")
	sfx.play("scrape", -10.0)
	await get_tree().create_timer(1.6).timeout
	if not _alive(my):
		return
	world.water_bed(i)
	Game.money += 6
	sfx.play("found", -8.0)
	hud.toast("Parterre arrosé : +6 €", 2.5)
	_end(my)


func _toggle_poster() -> void:
	var my: int = _begin()
	player.locked = true
	player.face_toward(cell.poster_pivot.global_position + Vector3(0, -0.3, 0))
	Game.poster_moved = not Game.poster_moved
	cell.set_poster_moved(Game.poster_moved)
	sfx.play("scrape", -8.0)
	player.hands.reach()
	await get_tree().create_timer(0.6).timeout
	if not _alive(my):
		return
	if Game.poster_moved:
		if not Game.has_spoon:
			hud.toast("Un mur fissuré derrière le poster... Il te faudrait un outil.", 4.0)
		elif not Game.spoon_equipped:
			hud.toast("Sors ta cuillère (bouton en bas), puis maintiens Action sur le trou.", 4.5)
		else:
			hud.toast("Maintiens Action près du trou pour creuser.", 3.5)
	else:
		hud.toast("Le poster cache de nouveau le mur.", 2.5)
	_end(my)


func _start_dig() -> void:
	if not Game.has_spoon:
		hud.toast("Il te faudrait un outil pour entamer ce mur.", 3.0)
		return
	if not Game.spoon_equipped:
		hud.toast("Sors ta cuillère (bouton en bas).", 3.0)
		return
	_begin()
	player.locked = true
	player.face_toward(cell.hole_node.global_position)
	_dig_active = true
	Game.digging = true
	Game.speed = 1.0
	player.hands.set_pose("dig")
	cell.set_digging_fx(true)
	sfx.dig_loop(true)


func _stop_dig() -> void:
	if not _dig_active and not Game.digging:
		return
	_dig_active = false
	Game.digging = false
	cell.set_digging_fx(false)
	sfx.dig_loop(false)
	busy = false
	player.locked = false
	player.hands.set_pose("idle")


func _sleep() -> void:
	if not world.in_cell(player.pos()):
		return
	Game.sleeping = true
	player.locked = true
	Game.speed = 6.0
	hud.toast("Tu t'endors... (appuie sur Action pour te réveiller)", 3.0)
	hud.fade_to(0.8, 1.0)


func _wake() -> void:
	if not Game.sleeping:
		return
	Game.sleeping = false
	Game.speed = 1.0
	player.locked = false
	hud.fade_to(0.0, 0.8)
	hud.toast("Tu te réveilles.", 2.0)


func _on_spoon() -> void:
	if not Game.has_spoon or state != "play":
		return
	Game.spoon_equipped = not Game.spoon_equipped
	player.hands.set_spoon(Game.spoon_equipped)
	sfx.play("clink", -10.0)
	if not Game.spoon_equipped:
		_stop_dig()


func _on_speed() -> void:
	if Game.digging or Game.sleeping:
		return
	Game.speed = 4.0 if Game.speed < 2.0 else 1.0


# ------------------------------------------------------------------ PNJ et boutique

func _open_dialog(npc: Npc, id: String) -> void:
	if npc == null:
		return
	_dialog_npc = npc
	_dialog_role = npc.role
	busy = true
	player.locked = true
	npc.face(player.pos())
	_show_dialog()


func _show_dialog() -> void:
	var npc: Npc = _dialog_npc
	var opts: Array = []
	var text: String = ""
	match npc.role:
		"shop":
			text = "Psst... Marco a tout ce qu'il te faut. Les affaires, c'est les affaires. Tu as %d €." % Game.money
			opts.append({"label": "Pelle de poche — 60 € (creuse 2x plus vite)" if not Game.has_pelle else "Pelle de poche (déjà achetée)", "id": "buy_pelle", "enabled": not Game.has_pelle and Game.money >= PRICES["pelle"]})
			opts.append({"label": "Chaussettes épaisses — 30 € (creuse moins bruyant)" if not Game.has_socks else "Chaussettes (déjà achetées)", "id": "buy_socks", "enabled": not Game.has_socks and Game.money >= PRICES["socks"]})
			opts.append({"label": "Pot-de-vin pour Gaston — 45 € (efface un coup)", "id": "buy_bribe", "enabled": Game.strikes > 0 and Game.money >= PRICES["bribe"]})
			opts.append({"label": "Café fort — 8 € (cours plus vite 60 s)", "id": "buy_coffee", "enabled": Game.money >= PRICES["coffee"]})
		"hint":
			if not Game.has_spoon:
				text = "Un colis de ta sœur arrive à la cantine au déjeuner, gamin. Fouille bien le gâteau. Et arrose mes tomates : 6 € par parterre !"
			elif not Game.poster_moved:
				text = "Un mur, une cuillère, du temps... Creuse la nuit, quand Gaston pionce. Les chaussettes de Marco étouffent le bruit."
			else:
				text = "Gaston voit tout quand il ne dort pas. Garde un oeil sur la minicarte : le point rouge, c'est lui."
		"cook":
			if Game.phase == "meal" and not Game.duty_done and not Game.has_tray:
				text = "Ton plateau est sur le comptoir, détenu. Prends-le avant que ça refroidisse."
			else:
				text = "La cantine, c'est sacré. Reviens à l'heure des repas, et ne fais pas d'histoires."
		_:
			text = "%s : « %s »" % [npc.npc_name, npc.chatter[randi() % npc.chatter.size()]]
	opts.append({"label": "Partir", "id": "close", "enabled": true})
	hud.show_dialog(npc.npc_name, text, opts)


func _on_dialog_choice(id: String) -> void:
	if id == "close":
		hud.hide_dialog()
		if _dialog_npc != null:
			_dialog_npc.release()
		_dialog_npc = null
		busy = false
		player.locked = false
		return
	if id.begins_with("buy_"):
		var item: String = id.substr(4)
		var price: int = PRICES[item]
		if Game.money < price:
			hud.toast("Pas assez d'argent.", 2.0)
			return
		Game.money -= price
		match item:
			"pelle":
				Game.has_pelle = true
			"socks":
				Game.has_socks = true
			"bribe":
				Game.strikes = maxi(0, Game.strikes - 1)
			"coffee":
				Game.boost_t = 60.0
		sfx.play("found", -6.0)
		hud.toast("Acheté !", 1.5)
		_show_dialog()


# ------------------------------------------------------------------ punitions

func _trigger_caught(reason: String) -> void:
	if in_caught or state != "play":
		return
	in_caught = true
	_action_id += 1
	busy = false
	_stop_dig()
	_wake()
	hud.hide_dialog()
	if _dialog_npc != null:
		_dialog_npc.release()
		_dialog_npc = null
	sfx.play("alarm", -8.0)
	player.input_enabled = false
	player.locked = true
	player.hands.set_pose("cover")
	var titles: Dictionary = {
		"suspicion": "Pris sur le fait !",
		"duty": "Tu as désobéi !",
		"curfew": "Couvre-feu violé !",
		"inspection": "Contrebande trouvée !",
	}
	hud.banner(titles.get(reason, "Pris !"), Color(1, 0.3, 0.25))
	await guard.chase(player.body)
	in_caught = false
	if state != "play":
		return
	Game.duty_done = true
	Game.suspicion = 0.0
	_warned = false
	_curfew_t = CURFEW_TIME
	_curfew_warned = false
	player.locked = false
	player.input_enabled = true
	player.hands.set_pose("idle")


func _on_swing() -> void:
	sfx.play("whack", 0.0)
	player.shake(1.0, 0.7)
	hud.flash_red()
	Game.speed = 1.0
	Game.dig = maxf(0.0, Game.dig - 25.0)
	_dig_marks = int(Game.dig / 25.0)
	cell.set_dig(Game.dig)
	Game.spoon_equipped = false
	player.hands.set_spoon(false)
	Game.poster_moved = false
	cell.set_poster_moved(false, false)
	Game.suspicion = 0.0
	Game.has_tray = false
	world.hide_table_tray()
	var fine: int = mini(Game.money, 5)
	Game.money -= fine
	# le garde traîne le joueur jusqu'à sa cellule
	player.teleport(World.SPAWN, 0.0)
	Game.add_strike()
	if Game.strikes < Game.MAX_STRIKES:
		hud.toast("Aïe ! Gaston t'a ramené en cellule, a remis le poster et abîmé ton tunnel. Amende : %d €." % fine, 4.5)
