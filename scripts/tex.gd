class_name Tex
extends RefCounted
## Textures procédurales (aucun asset externe) : béton, briques, bois, métal, tissu...

static var _cache: Dictionary = {}


static func _h(x: int, y: int, s: int = 0) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	return float(n & 0xFFFF) / 65535.0


static func _noise_img(seed_v: int, freq: float, size: int) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = 4
	return n.get_seamless_image(size, size)


static func _finish(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func concrete(light: Color = Color(0.55, 0.55, 0.52), dark: Color = Color(0.3, 0.3, 0.29)) -> ImageTexture:
	var key: String = "concrete%s%s" % [light, dark]
	if _cache.has(key):
		return _cache[key]
	var size: int = 128
	var a: Image = _noise_img(11, 0.03, size)
	var b: Image = _noise_img(23, 0.012, size)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v: float = a.get_pixel(x, y).r
			var st: float = b.get_pixel(x, y).r
			var c: Color = dark.lerp(light, v)
			c = c * (1.0 - clampf((st - 0.6) * 1.6, 0.0, 0.45))
			c = c * (0.93 + 0.14 * _h(x, y))
			img.set_pixel(x, y, c)
	var t: ImageTexture = _finish(img)
	_cache[key] = t
	return t


static func brick(base: Color = Color(0.5, 0.33, 0.28)) -> ImageTexture:
	var key: String = "brick%s" % [base]
	if _cache.has(key):
		return _cache[key]
	var size: int = 128
	var g: Image = _noise_img(5, 0.05, size)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		var row: int = y / 16
		var off: int = (row % 2) * 16
		for x in size:
			var xx: int = (x + off) % size
			var bx: int = xx % 32
			var by: int = y % 16
			var c: Color
			if bx < 2 or by < 2:
				c = Color(0.58, 0.56, 0.52) * (0.85 + 0.15 * _h(x, y, 2))
			else:
				var id: int = xx / 32
				var var_c: float = 0.8 + 0.4 * _h(id, row, 7)
				c = base * var_c * (0.9 + 0.2 * _h(x, y, 3))
			c = c * (0.65 + 0.5 * g.get_pixel(x, y).r)
			c.a = 1.0
			img.set_pixel(x, y, c)
	var t: ImageTexture = _finish(img)
	_cache[key] = t
	return t


static func floor_tiles() -> ImageTexture:
	if _cache.has("floor"):
		return _cache["floor"]
	var size: int = 128
	var g: Image = _noise_img(31, 0.04, size)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var tx: int = x / 64
			var ty: int = y / 64
			var c: Color = Color(0.36, 0.35, 0.33) * (0.85 + 0.3 * _h(tx, ty, 9))
			if x % 64 < 2 or y % 64 < 2:
				c = Color(0.16, 0.16, 0.15)
			c = c * (0.6 + 0.6 * g.get_pixel(x, y).r) * (0.94 + 0.12 * _h(x, y, 4))
			c.a = 1.0
			img.set_pixel(x, y, c)
	var t: ImageTexture = _finish(img)
	_cache["floor"] = t
	return t


static func wood(base: Color = Color(0.45, 0.3, 0.17)) -> ImageTexture:
	var key: String = "wood%s" % [base]
	if _cache.has(key):
		return _cache[key]
	var size: int = 128
	var g: Image = _noise_img(41, 0.02, size)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var plank: int = x / 32
			var grain: float = sin(float(x) * 0.9 + g.get_pixel(x, y).r * 14.0) * 0.5 + 0.5
			var c: Color = base * (0.75 + 0.2 * grain + 0.15 * _h(plank, 0, 5))
			if x % 32 < 1:
				c = c * 0.45
			c.a = 1.0
			img.set_pixel(x, y, c)
	var t: ImageTexture = _finish(img)
	_cache[key] = t
	return t


static func metal(base: Color = Color(0.45, 0.47, 0.5)) -> ImageTexture:
	var key: String = "metal%s" % [base]
	if _cache.has(key):
		return _cache[key]
	var size: int = 128
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		var row: float = 0.85 + 0.2 * _h(0, y, 12)
		for x in size:
			var c: Color = base * row * (0.96 + 0.08 * _h(x, y, 13))
			c.a = 1.0
			img.set_pixel(x, y, c)
	var t: ImageTexture = _finish(img)
	_cache[key] = t
	return t


static func fabric(c1: Color, c2: Color, stripe: int = 0) -> ImageTexture:
	var key: String = "fabric%s%s%d" % [c1, c2, stripe]
	if _cache.has(key):
		return _cache[key]
	var size: int = 64
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var weave: float = 0.9 + 0.1 * float((x + y) % 2)
			var c: Color = c1
			if stripe > 0 and (x / stripe) % 2 == 1:
				c = c2
			c = c * weave * (0.92 + 0.16 * _h(x, y, 21))
			c.a = 1.0
			img.set_pixel(x, y, c)
	var t: ImageTexture = _finish(img)
	_cache[key] = t
	return t


static func skin() -> ImageTexture:
	if _cache.has("skin"):
		return _cache["skin"]
	var size: int = 64
	var g: Image = _noise_img(51, 0.08, size)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var c: Color = Color(0.86, 0.62, 0.5) * (0.88 + 0.22 * g.get_pixel(x, y).r) * (0.97 + 0.06 * _h(x, y, 31))
			c.a = 1.0
			img.set_pixel(x, y, c)
	var t: ImageTexture = _finish(img)
	_cache["skin"] = t
	return t


static func dirt() -> ImageTexture:
	if _cache.has("dirt"):
		return _cache["dirt"]
	var size: int = 64
	var g: Image = _noise_img(61, 0.1, size)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var c: Color = Color(0.32, 0.22, 0.14) * (0.6 + 0.8 * g.get_pixel(x, y).r) * (0.9 + 0.2 * _h(x, y, 41))
			c.a = 1.0
			img.set_pixel(x, y, c)
	var t: ImageTexture = _finish(img)
	_cache["dirt"] = t
	return t


## Poster "plage tropicale" (la liberté...) 96x128
static func poster() -> ImageTexture:
	if _cache.has("poster"):
		return _cache["poster"]
	var w: int = 96
	var h: int = 128
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var c: Color
			var fy: float = float(y) / float(h)
			if fy < 0.5:
				c = Color(0.98, 0.62, 0.35).lerp(Color(0.35, 0.65, 0.95), fy * 2.0)
				var dx: float = float(x) - 62.0
				var dy: float = float(y) - 36.0
				if dx * dx + dy * dy < 150.0:
					c = Color(1.0, 0.95, 0.55)
			elif fy < 0.72:
				c = Color(0.1, 0.5, 0.75).lerp(Color(0.05, 0.3, 0.55), (fy - 0.5) * 4.5)
				if int(float(x) + sin(float(y) * 0.8) * 3.0) % 12 < 2:
					c = c.lightened(0.25)
			else:
				c = Color(0.95, 0.85, 0.6) * (0.92 + 0.12 * _h(x, y, 8))
			# palmier
			if absf(float(x) - (24.0 + (float(h) - float(y)) * 0.12)) < 2.0 and y > 50 and y < 110:
				c = Color(0.35, 0.22, 0.1)
			var px: float = float(x) - 28.0
			var py: float = float(y) - 48.0
			if py < 0.0 and py > -14.0 and absf(px) < 24.0 + py * 1.4 and absf(px) > 1.0:
				c = Color(0.1, 0.55, 0.2)
			if x < 3 or x > w - 4 or y < 3 or y > h - 4:
				c = Color(0.95, 0.95, 0.9)
			c.a = 1.0
			img.set_pixel(x, y, c)
	var t: ImageTexture = _finish(img)
	_cache["poster"] = t
	return t


## Journal : lignes de texte factices.
static func newspaper() -> ImageTexture:
	if _cache.has("news"):
		return _cache["news"]
	var w: int = 64
	var h: int = 96
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var c: Color = Color(0.86, 0.84, 0.78)
			if y > 6 and y < 20 and x > 4 and x < w - 4:
				c = Color(0.15, 0.15, 0.15)
			elif y >= 24 and y % 4 < 2 and x > 4 and x < w - 4 and _h(x / 6, y / 4, 3) > 0.12:
				c = Color(0.35, 0.35, 0.33)
			elif y >= 24 and y < 50 and x > 34 and x < 58:
				c = Color(0.55, 0.55, 0.52)
			img.set_pixel(x, y, c)
	var t: ImageTexture = _finish(img)
	_cache["news"] = t
	return t


## Traits de comptage des jours sur le mur.
static func tally() -> ImageTexture:
	if _cache.has("tally"):
		return _cache["tally"]
	var w: int = 128
	var h: int = 64
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for g_i in 5:
		for k in 4:
			var x0: int = 8 + g_i * 22 + k * 4
			for y in range(12, 44):
				img.set_pixel(x0, y, Color(0.05, 0.05, 0.05, 0.85))
		for x in range(6 + g_i * 22, 6 + g_i * 22 + 18):
			var y2: int = 44 - int(float(x - (6 + g_i * 22)) * 1.5)
			if y2 >= 0 and y2 < h:
				img.set_pixel(x, y2, Color(0.05, 0.05, 0.05, 0.85))
	var t: ImageTexture = _finish(img)
	_cache["tally"] = t
	return t


## Trou : dégradé radial sombre bordé de gravats (RGBA).
static func hole() -> ImageTexture:
	if _cache.has("hole"):
		return _cache["hole"]
	var size: int = 128
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var dx: float = (float(x) - 64.0) / 64.0
			var dy: float = (float(y) - 64.0) / 64.0
			var r: float = sqrt(dx * dx + dy * dy) + (_h(x / 6, y / 6, 17) - 0.5) * 0.18
			var c: Color = Color(0, 0, 0, 0)
			if r < 0.62:
				var k: float = r / 0.62
				c = Color(0.02, 0.015, 0.01).lerp(Color(0.12, 0.08, 0.05), k * k)
				c.a = 1.0
			elif r < 0.95:
				var d: float = _h(x / 3, y / 3, 19)
				c = Color(0.62, 0.58, 0.52) * (0.5 + 0.6 * d)
				c.a = clampf((0.95 - r) * 12.0, 0.0, 1.0)
			img.set_pixel(x, y, c)
	var t: ImageTexture = _finish(img)
	_cache["hole"] = t
	return t


static func grass() -> ImageTexture:
	if _cache.has("grass"):
		return _cache["grass"]
	var size: int = 128
	var a: Image = _noise_img(71, 0.05, size)
	var b: Image = _noise_img(72, 0.2, size)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v: float = a.get_pixel(x, y).r
			var f: float = b.get_pixel(x, y).r
			var c: Color = Color(0.16, 0.34, 0.1).lerp(Color(0.32, 0.5, 0.16), v) * (0.8 + 0.4 * f)
			c = c * (0.92 + 0.16 * _h(x, y, 61))
			c.a = 1.0
			img.set_pixel(x, y, c)
	var t: ImageTexture = _finish(img)
	_cache["grass"] = t
	return t
