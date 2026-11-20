class_name Hud
extends CanvasLayer
## Interface : horloge, objectifs, barres de tunnel/suspicion, menus, sous-titres, fondus.

signal play_pressed
signal retry_pressed
signal spoon_pressed
signal speed_pressed
signal skip_pressed

var root: Control
var gameplay: Control
var time_label: Label
var phase_label: Label
var objective_label: Label
var strikes_label: Label
var toast_label: Label
var banner_label: Label
var subtitle: Label
var dig_box: Control
var dig_bar: ProgressBar
var susp_bar: ProgressBar
var spoon_btn: Button
var speed_btn: Button
var skip_btn: Button
var bl_box: Control
var fade: ColorRect
var flash: ColorRect
var bar_top: ColorRect
var bar_bottom: ColorRect
var title_panel: Control
var help_panel: Control
var over_panel: Control
var end_panel: Control

var _toast_tween: Tween
var _banner_tween: Tween
var _sub_tween: Tween


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_build_gameplay()
	_build_overlays()
	_build_menus()
	gameplay.visible = false
	over_panel.visible = false
	end_panel.visible = false
	help_panel.visible = false
	skip_btn.visible = false
	_ignore_mouse(gameplay)
	get_viewport().size_changed.connect(_layout)
	_layout()


## Replace les éléments à position absolue selon la taille réelle de l'écran
## (le mode d'étirement "expand" donne un viewport plus large que 1280 sur téléphones allongés).
func _layout() -> void:
	var sz: Vector2 = get_viewport().get_visible_rect().size
	var w: float = sz.x
	var h: float = sz.y
	bar_bottom.size.x = w
	bar_top.size.x = w
	bar_bottom.position.y = h - bar_bottom.size.y
	bl_box.position = Vector2(24, h - 160)
	spoon_btn.position = Vector2(w - 324, h - 94)
	toast_label.size = Vector2(minf(1000.0, w - 80.0), 80)
	toast_label.position = Vector2((w - toast_label.size.x) * 0.5, h - 130)
	banner_label.size = Vector2(minf(1000.0, w - 80.0), 90)
	banner_label.position = Vector2((w - banner_label.size.x) * 0.5, 150)
	subtitle.size = Vector2(minf(1040.0, w - 240.0), 120)
	subtitle.position = Vector2((w - subtitle.size.x) * 0.5, h - 170)
	skip_btn.position = Vector2(w - 214, 24)


# ------------------------------------------------------------------ fabrique

func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	return l


func _style(bg: Color, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


func _button(text: String, size: int = 30, accent: Color = Color(0.85, 0.55, 0.1)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _style(accent.darkened(0.25)))
	b.add_theme_stylebox_override("hover", _style(accent))
	b.add_theme_stylebox_override("pressed", _style(accent.lightened(0.2)))
	b.add_theme_stylebox_override("focus", _style(accent))
	b.custom_minimum_size = Vector2(0, 70)
	return b


func _bar(color: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 100.0
	p.show_percentage = false
	p.custom_minimum_size = Vector2(260, 22)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(8)
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p


func _ignore_mouse(n: Node) -> void:
	if n is Control and not (n is BaseButton):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


func _build_gameplay() -> void:
	gameplay = Control.new()
	gameplay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(gameplay)

	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 24)
	top.add_theme_constant_override("margin_top", 16)
	top.add_theme_constant_override("margin_right", 24)
	gameplay.add_child(top)
	var hb := HBoxContainer.new()
	top.add_child(hb)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(left)
	time_label = _label("Jour 1 — 07:30", 38, Color(1, 0.92, 0.7))
	phase_label = _label("Temps libre", 26, Color(0.8, 0.9, 1.0))
	objective_label = _label("", 24, Color(1, 1, 0.75))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size = Vector2(640, 0)
	left.add_child(time_label)
	left.add_child(phase_label)
	left.add_child(objective_label)
	var right := VBoxContainer.new()
	hb.add_child(right)
	strikes_label = _label("Coups : 0 / 3", 28, Color(1, 0.6, 0.5))
	strikes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(strikes_label)
	speed_btn = _button("Temps x1", 24, Color(0.3, 0.5, 0.8))
	speed_btn.custom_minimum_size = Vector2(190, 56)
	speed_btn.pressed.connect(func() -> void: speed_pressed.emit())
	right.add_child(speed_btn)

	# bas gauche : barres
	var bl := VBoxContainer.new()
	bl.size = Vector2(320, 140)
	bl_box = bl
	gameplay.add_child(bl)
	bl.add_child(_label("Suspicion du garde", 20, Color(1, 0.75, 0.7)))
	susp_bar = _bar(Color(0.9, 0.2, 0.15))
	bl.add_child(susp_bar)
	dig_box = VBoxContainer.new()
	bl.add_child(dig_box)
	dig_box.add_child(_label("Tunnel", 20, Color(0.9, 0.85, 0.6)))
	dig_bar = _bar(Color(0.85, 0.65, 0.25))
	dig_box.add_child(dig_bar)
	dig_box.visible = false

	# bas droite : cuillère
	spoon_btn = _button("Sortir la cuillère", 26, Color(0.6, 0.6, 0.7))
	spoon_btn.custom_minimum_size = Vector2(300, 70)
	spoon_btn.visible = false
	spoon_btn.pressed.connect(func() -> void: spoon_pressed.emit())
	gameplay.add_child(spoon_btn)

	# messages
	toast_label = _label("", 30, Color.WHITE)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.modulate.a = 0.0
	gameplay.add_child(toast_label)
	banner_label = _label("", 56, Color(1, 0.85, 0.3))
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.modulate.a = 0.0
	gameplay.add_child(banner_label)


func _build_overlays() -> void:
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.8, 0.0, 0.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	bar_top = ColorRect.new()
	bar_top.color = Color.BLACK
	bar_top.size = Vector2(1280, 0)
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_top)
	bar_bottom = ColorRect.new()
	bar_bottom.color = Color.BLACK
	bar_bottom.size = Vector2(1280, 0)
	bar_bottom.position = Vector2(0, 720)
	bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_bottom)
	subtitle = _label("", 34, Color(1, 1, 1))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.visible_ratio = 0.0
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(subtitle)
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	skip_btn = _button("Passer >>", 24, Color(0.4, 0.4, 0.45))
	skip_btn.custom_minimum_size = Vector2(190, 56)
	skip_btn.pressed.connect(func() -> void: skip_pressed.emit())
	root.add_child(skip_btn)


func _center_panel(bg: Color) -> Control:
	var p := ColorRect.new()
	p.color = bg
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(p)
	return p


func _col(parent: Control, width: float = 720.0) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(width, 0)
	v.add_theme_constant_override("separation", 22)
	c.add_child(v)
	return v


func _build_menus() -> void:
	# titre
	title_panel = _center_panel(Color(0, 0, 0, 0.55))
	var tv: VBoxContainer = _col(title_panel)
	var t: Label = _label("BEFREE", 130, Color(0.95, 0.7, 0.2))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t)
	var sub: Label = _label("Évade-toi. Chaque minute compte.", 34, Color(0.9, 0.9, 0.95))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(sub)
	var play: Button = _button("JOUER", 44)
	play.custom_minimum_size = Vector2(0, 96)
	play.pressed.connect(func() -> void: play_pressed.emit())
	tv.add_child(play)
	var help: Button = _button("Comment jouer ?", 28, Color(0.35, 0.45, 0.7))
	help.pressed.connect(func() -> void: help_panel.visible = true)
	tv.add_child(help)

	# aide
	help_panel = _center_panel(Color(0.03, 0.03, 0.05, 0.95))
	var hv: VBoxContainer = _col(help_panel, 900.0)
	var ht: Label = _label("Comment s'évader", 54, Color(0.95, 0.7, 0.2))
	hv.add_child(ht)
	var body: Label = _label(
		"• Glisse le doigt pour regarder autour de toi.\n" +
		"• Touche un objet pour t'en servir : toilettes, plateau-repas, gâteau, poster...\n" +
		"• Respecte l'emploi du temps : repas et toilettes sont obligatoires, sinon Gaston cogne.\n" +
		"• Trouve la cuillère, tire le poster, puis MAINTIENS ton doigt sur le trou pour creuser.\n" +
		"• Creuse quand Gaston lit, mange ou dort. Quand il lève les yeux, arrête !\n" +
		"• Pendant l'inspection, remets le poster et range la cuillère.\n" +
		"• 3 coups de matraque et c'est le cachot à vie.", 26, Color(0.92, 0.92, 0.95))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(body)
	var back: Button = _button("Compris", 32, Color(0.35, 0.45, 0.7))
	back.pressed.connect(func() -> void: help_panel.visible = false)
	hv.add_child(back)

	# game over
	over_panel = _center_panel(Color(0.25, 0.0, 0.0, 0.85))
	var ov: VBoxContainer = _col(over_panel)
	var ot: Label = _label("CACHOT À VIE", 90, Color(1, 0.35, 0.3))
	ot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(ot)
	var os: Label = _label("Gaston a gagné. Théo ne reverra jamais le soleil...", 30)
	os.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	os.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov.add_child(os)
	var retry: Button = _button("Réessayer", 40)
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	ov.add_child(retry)

	# fin
	end_panel = _center_panel(Color(1, 1, 1, 0.0))
	var ev: VBoxContainer = _col(end_panel)
	var et: Label = _label("LIBRE !", 120, Color(0.2, 0.55, 0.25))
	et.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1))
	et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(et)
	var es: Label = _label("Théo court vers la forêt. Pour la première fois depuis deux ans, il respire l'air libre.\nMerci d'avoir joué à BeFree.", 30, Color(0.1, 0.1, 0.1))
	es.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1))
	es.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	es.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ev.add_child(es)
	var again: Button = _button("Rejouer", 40, Color(0.3, 0.6, 0.35))
	again.pressed.connect(func() -> void: retry_pressed.emit())
	ev.add_child(again)


# ------------------------------------------------------------------ API

func phase_text() -> String:
	match Game.phase:
		"meal":
			match Game.kind:
				"breakfast":
					return "Petit-déjeuner — va manger !"
				"lunch":
					return "Déjeuner — va manger !"
				_:
					return "Dîner — va manger !"
		"pee":
			return "Toilettes obligatoires !"
		"inspect":
			return "INSPECTION — range tout !"
		"night":
			return "Nuit — extinction des feux"
	return "Temps libre"


func refresh() -> void:
	time_label.text = "Jour %d — %s" % [Game.day, Game.time_string()]
	phase_label.text = phase_text()
	var urgent: bool = Game.phase == "meal" or Game.phase == "pee" or Game.phase == "inspect"
	phase_label.add_theme_color_override("font_color", Color(1, 0.5, 0.4) if urgent else Color(0.8, 0.9, 1.0))
	strikes_label.text = "Coups : %d / %d" % [Game.strikes, Game.MAX_STRIKES]
	susp_bar.value = Game.suspicion
	dig_bar.value = Game.dig
	dig_box.visible = Game.has_spoon
	spoon_btn.visible = Game.has_spoon
	spoon_btn.text = "Ranger la cuillère" if Game.spoon_equipped else "Sortir la cuillère"
	speed_btn.text = "Temps x%d" % int(Game.speed)


func set_objective(text: String) -> void:
	objective_label.text = text


func toast(text: String, duration: float = 3.2) -> void:
	toast_label.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)


func banner(text: String, color: Color = Color(1, 0.85, 0.3)) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	banner_label.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(2.2)
	_banner_tween.tween_property(banner_label, "modulate:a", 0.0, 0.6)


func flash_red() -> void:
	flash.color = Color(0.8, 0.0, 0.0, 0.65)
	create_tween().tween_property(flash, "color:a", 0.0, 0.7)


func fade_to(alpha: float, duration: float, color: Color = Color.BLACK) -> void:
	fade.color = Color(color.r, color.g, color.b, fade.color.a)
	var t: Tween = create_tween()
	t.tween_property(fade, "color:a", alpha, duration)
	await t.finished


func letterbox(on: bool) -> void:
	var h: float = 90.0 if on else 0.0
	var sh: float = get_viewport().get_visible_rect().size.y
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(bar_top, "size:y", h, 0.6)
	t.tween_property(bar_bottom, "size:y", h, 0.6)
	t.tween_property(bar_bottom, "position:y", sh - h, 0.6)


## Sous-titre type machine à écrire, retourne quand le texte est affiché.
func say(text: String, hold: float = 1.8) -> void:
	subtitle.text = text
	subtitle.visible_ratio = 0.0
	if _sub_tween != null and _sub_tween.is_valid():
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_property(subtitle, "visible_ratio", 1.0, maxf(0.6, float(text.length()) * 0.04))
	_sub_tween.tween_interval(hold)
	await _sub_tween.finished


func clear_subtitle() -> void:
	if _sub_tween != null and _sub_tween.is_valid():
		_sub_tween.kill()
	subtitle.visible_ratio = 0.0


func set_gameplay_visible(v: bool) -> void:
	gameplay.visible = v


func set_skip_visible(v: bool) -> void:
	skip_btn.visible = v


func show_title(v: bool) -> void:
	title_panel.visible = v
	if not v:
		help_panel.visible = false


func show_gameover() -> void:
	gameplay.visible = false
	over_panel.visible = true


func show_end() -> void:
	gameplay.visible = false
	end_panel.visible = true
	end_panel.color = Color(1, 1, 1, 0.0)
	create_tween().tween_property(end_panel, "color:a", 0.85, 1.2)
