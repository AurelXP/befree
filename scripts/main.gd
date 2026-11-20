extends Node3D
## Chef d'orchestre : assemble la cellule, le garde, le joueur et l'interface,
## et applique les règles du jeu (routine, suspicion, tunnel, punitions).

const FLAVOR: Dictionary = {
	"bed": "Un matelas dur comme du béton. Mais c'est TON matelas.",
	"sink": "L'eau est glacée. Tu te rafraîchis le visage.",
	"window": "Trop petite, trop haute, trop de barreaux. Pas par là.",
	"tally": "Chaque trait, un jour de perdu. Ça va changer.",
}
const FLAVOR_STATION: Dictionary = {
	"bed": "bed",
	"sink": "toilet",
	"window": "window",
	"tally": "center",
}

var cell: Cell
var guard: Guard
var player: Player
var hud: Hud
var cine: Cinematic
var sfx: Sfx

var state: String = "menu"  # menu | intro | play | over | end
var busy: bool = false
var in_caught: bool = false

var _action_id: int = 0
var _tod_t: float = 0.0
var _mode_t: float = 0.0
var _dig_marks: int = 0
var _warned: bool = false
var _starting: bool = false


func _ready() -> void:
	cell = Cell.new()
	add_child(cell)
	cell.build()
	guard = Guard.new()
	add_child(guard)
	player = Player.new()
	add_child(player)
	hud = Hud.new()
	add_child(hud)
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
	hud.play_pressed.connect(_on_play)
	hud.retry_pressed.connect(_on_retry)
	hud.spoon_pressed.connect(_on_spoon)
	hud.speed_pressed.connect(_on_speed)
	hud.nav_pressed.connect(_on_nav)
	player.tapped.connect(_on_tap)
	player.dig_hold.connect(_on_dig_hold)
	guard.swing_hit.connect(_on_swing)

	cell.set_tod(Game.minutes, false)
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
	cell.set_poster_moved(false, false)
	cell.set_dig(0.0)
	cell.tray.visible = false
	player.snap_to("center")
	player.hands.set_pose("idle")
	player.hands.set_spoon(false)
	cell.set_tod(Game.minutes, false)
	guard.set_mode("cycle")
	hud.set_gameplay_visible(true)
	hud.set_objective("Observe la routine de Gaston. Le colis de Léa doit arriver au déjeuner (12:30).")
	await hud.fade_to(0.0, 0.6)
	state = "play"
	player.input_enabled = true
	Game.start()
	hud.toast("Glisse pour regarder autour de toi. Touche les objets pour t'en servir.", 5.0)


func _on_game_over() -> void:
	state = "over"
	Game.digging = false
	sfx.dig_loop(false)
	sfx.play("alarm", -4.0)
	player.input_enabled = false
	cell.set_digging_fx(false)
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
	player.stop_digging()
	player.input_enabled = false
	cell.set_digging_fx(false)
	hud.set_gameplay_visible(false)
	await cine.ending()
	hud.show_end()


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	_tod_t += delta
	if _tod_t > 0.2:
		_tod_t = 0.0
		cell.set_tod(Game.minutes, Game.is_night())
	guard.gaze = player.cam.global_position
	if state != "play":
		return
	hud.refresh()
	_update_guard_mode(delta)
	_update_suspicion(delta)
	_update_dig(delta)


func _update_guard_mode(delta: float) -> void:
	_mode_t += delta
	if _mode_t < 0.3:
		return
	_mode_t = 0.0
	if guard.is_busy() or in_caught:
		return
	var want: String = "cycle"
	match Game.phase:
		"meal", "pee":
			want = "stand" if not Game.duty_done else "cycle"
		"inspect":
			want = "stand"
		"night":
			want = "doze"
	if want != guard.mode:
		guard.set_mode(want)


func _update_suspicion(delta: float) -> void:
	if in_caught:
		return
	var aw: Vector2 = guard.awareness()
	var visual: float = 0.0
	if Game.poster_moved:
		visual += 10.0
	if Game.spoon_equipped:
		visual += 12.0
	if Game.phase == "inspect":
		visual *= 3.0
	var noise: float = 18.0 if Game.digging else 0.0
	var rate: float = aw.x * visual + aw.y * noise
	var decay: float = 10.0 if rate < 0.05 else 5.0
	Game.suspicion = clampf(Game.suspicion + (rate - decay) * delta, 0.0, 100.0)
	if Game.suspicion > 55.0 and not _warned:
		_warned = true
		hud.toast("Gaston se méfie... Arrête-toi !", 2.5)
	elif Game.suspicion < 25.0:
		_warned = false
	if Game.suspicion >= 100.0:
		_trigger_caught("suspicion")


func _update_dig(delta: float) -> void:
	if not Game.digging:
		return
	if not (Game.poster_moved and Game.spoon_equipped) or in_caught:
		Game.digging = false
		sfx.dig_loop(false)
		cell.set_digging_fx(false)
		return
	Game.dig = minf(100.0, Game.dig + Game.DIG_RATE * delta)
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
		_clear_tray()
	if phase != "free":
		sfx.play("bell", -6.0)
	match phase:
		"meal":
			var with_cake: bool = (kind == "lunch" and not Game.has_spoon and Game.day == 1)
			cell.show_tray(kind, with_cake)
			var lines: Dictionary = {
				"breakfast": "Petit-déj ! Magne-toi !",
				"lunch": "À table, la racaille !",
				"dinner": "Dîner ! Et ça se mange en silence !",
			}
			guard.say(lines.get(kind, "À manger !"), 3.0)
			hud.banner("Repas !", Color(1, 0.75, 0.3))
			if with_cake:
				hud.toast("Un colis de Léa : un gâteau d'anniversaire ! Fouille-le...", 6.0)
			else:
				hud.toast("Touche ton plateau pour manger.", 3.0)
		"pee":
			guard.say("Debout ! Tout le monde aux toilettes !", 3.0)
			hud.banner("Toilettes !", Color(0.5, 0.8, 1.0))
			hud.toast("Touche les toilettes, vite.", 3.0)
		"inspect":
			guard.say("INSPECTION ! Qu'est-ce que tu caches ?", 3.0)
			hud.banner("INSPECTION !", Color(1, 0.3, 0.25))
			hud.toast("Remets le poster en place et range la cuillère !", 4.0)
		"night":
			guard.say("Bonne nuit... *bâille*", 3.0)
			hud.banner("Extinction des feux", Color(0.55, 0.65, 1.0))
		"free":
			if Game.minutes < 400.0 and Game.minutes >= 330.0:
				hud.banner("Jour %d" % Game.day, Color(1, 0.9, 0.6))


func _clear_tray() -> void:
	if not cell.tray.visible:
		return
	if cell.cake.visible and not Game.has_spoon:
		cell.food.visible = false
	else:
		cell.hide_tray()


# ------------------------------------------------------------------ actions

func _begin() -> int:
	busy = true
	_action_id += 1
	return _action_id


func _alive(id: int) -> bool:
	return id == _action_id and state == "play" and not in_caught


func _end(id: int) -> void:
	if id == _action_id:
		busy = false


func _on_tap(id: String) -> void:
	if state != "play" or busy or in_caught or id == "":
		return
	match id:
		"toilet":
			_use_toilet()
		"tray":
			_eat()
		"cake":
			_cake()
		"poster":
			_toggle_poster()
		"hole":
			_hole()
		_:
			_flavor(id)


func _flavor(id: String) -> void:
	var my: int = _begin()
	await player.go_to(FLAVOR_STATION.get(id, "center"))
	if not _alive(my):
		return
	hud.toast(FLAVOR.get(id, ""), 3.0)
	player.hands.reach()
	_end(my)


func _use_toilet() -> void:
	var my: int = _begin()
	await player.go_to("toilet")
	if not _alive(my):
		return
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
	player.hands.set_pose("idle")
	await player.go_to("center")
	_end(my)


func _eat() -> void:
	if not cell.tray.visible:
		return
	if Game.phase != "meal":
		hud.toast("Tu n'as plus faim.", 2.0)
		return
	var my: int = _begin()
	await player.go_to("table")
	if not _alive(my):
		return
	player.hands.set_pose("eat")
	for i in 3:
		sfx.play("chew", -4.0)
		await get_tree().create_timer(1.1).timeout
		if not _alive(my):
			return
		cell.set_food(1.0 - float(i + 1) / 3.0)
	player.hands.set_pose("idle")
	if not Game.duty_done:
		Game.finish_duty()
		guard.say("Voilà. Rends-moi ça.", 2.5)
		hud.toast("Repas terminé.", 2.0)
	await get_tree().create_timer(0.6).timeout
	if not _alive(my):
		return
	_clear_tray()
	await player.go_to("center")
	_end(my)


func _cake() -> void:
	if Game.has_spoon:
		hud.toast("Le gâteau était délicieux.", 2.0)
		return
	var my: int = _begin()
	await player.go_to("table")
	if not _alive(my):
		return
	player.hands.set_pose("cake")
	hud.toast("Tu fouilles le gâteau...", 2.0)
	await get_tree().create_timer(1.6).timeout
	if not _alive(my):
		return
	cell.cake_cut()
	sfx.play("clink", -4.0)
	await get_tree().create_timer(0.9).timeout
	if not _alive(my):
		return
	cell.cake_spoon.visible = false
	Game.has_spoon = true
	Game.cake_given = true
	sfx.play("found", -4.0)
	player.hands.set_pose("idle")
	hud.banner("Une cuillère !", Color(0.95, 0.85, 0.4))
	hud.toast("Léa a caché une cuillère dans le gâteau ! Tire le poster, sors-la et creuse.", 6.0)
	hud.set_objective("Tire le poster, sors la cuillère et creuse (maintiens le doigt sur le trou). Creuse quand Gaston ne regarde pas !")
	await player.go_to("center")
	_end(my)


func _toggle_poster() -> void:
	var my: int = _begin()
	await player.go_to("wall")
	if not _alive(my):
		return
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
			hud.toast("Sors ta cuillère (bouton en bas à droite), puis maintiens le doigt sur le trou.", 4.5)
		else:
			hud.toast("Maintiens ton doigt appuyé sur le trou pour creuser.", 3.5)
	else:
		hud.toast("Le poster cache de nouveau le mur.", 2.5)
	_end(my)


func _hole() -> void:
	var my: int = _begin()
	await player.go_to("wall")
	if not _alive(my):
		return
	if not Game.has_spoon:
		hud.toast("Il te faudrait un outil pour entamer ce mur.", 3.0)
	elif not Game.spoon_equipped:
		hud.toast("Sors ta cuillère (bouton en bas à droite).", 3.0)
	else:
		hud.toast("Maintiens ton doigt appuyé sur le trou pour creuser.", 3.0)
	_end(my)


func _on_spoon() -> void:
	if not Game.has_spoon or state != "play":
		return
	Game.spoon_equipped = not Game.spoon_equipped
	player.hands.set_spoon(Game.spoon_equipped)
	sfx.play("clink", -10.0)
	if not Game.spoon_equipped:
		player.stop_digging()


func _on_nav(station: String) -> void:
	if state != "play" or in_caught:
		return
	if busy:
		return
	Game.digging = false
	player.stop_digging()
	cell.set_digging_fx(false)
	sfx.dig_loop(false)
	player.hands.set_pose("idle")
	var my: int = _begin()
	await player.go_to(station)
	_end(my)


func _on_speed() -> void:
	if Game.digging:
		return
	Game.speed = 4.0 if Game.speed < 2.0 else 1.0


func _on_dig_hold(active: bool) -> void:
	if state != "play" or busy or in_caught:
		Game.digging = false
		return
	Game.digging = active
	player.hands.set_pose("dig" if active else "idle")
	sfx.dig_loop(active)
	cell.set_digging_fx(active)
	if active:
		Game.speed = 1.0


# ------------------------------------------------------------------ punitions

func _trigger_caught(reason: String) -> void:
	if in_caught or state != "play":
		return
	in_caught = true
	_action_id += 1
	busy = false
	Game.digging = false
	sfx.dig_loop(false)
	sfx.play("alarm", -8.0)
	player.stop_digging()
	cell.set_digging_fx(false)
	player.input_enabled = false
	player.hands.set_pose("cover")
	hud.banner("Pris sur le fait !" if reason == "suspicion" else "Tu as désobéi !", Color(1, 0.3, 0.25))
	await guard.attack(cell, player.cam.global_position)
	in_caught = false
	if state != "play":
		return
	Game.duty_done = true
	Game.suspicion = 0.0
	_warned = false
	player.hands.set_pose("idle")
	player.input_enabled = true
	await player.go_to("center")


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
	Game.add_strike()
	if Game.strikes < Game.MAX_STRIKES:
		hud.toast("Aïe ! Gaston a remis le poster en place et a abîmé ton tunnel.", 4.0)
