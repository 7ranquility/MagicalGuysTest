class_name FxManager
extends Node2D
## Pooled particles, shockwave rings, floating damage numbers and screen shake.

const PCAP: int = 700
const NCAP: int = 90
const WCAP: int = 48

var run: Run
var show_numbers: bool = true
var shake_enabled: bool = true
var shake: float = 0.0

var _p_n: int = 0
var _px: PackedFloat32Array = PackedFloat32Array()
var _py: PackedFloat32Array = PackedFloat32Array()
var _pvx: PackedFloat32Array = PackedFloat32Array()
var _pvy: PackedFloat32Array = PackedFloat32Array()
var _plife: PackedFloat32Array = PackedFloat32Array()
var _plife0: PackedFloat32Array = PackedFloat32Array()
var _psize: PackedFloat32Array = PackedFloat32Array()
var _pcol: PackedColorArray = PackedColorArray()

var _n_next: int = 0
var _nx: PackedFloat32Array = PackedFloat32Array()
var _ny: PackedFloat32Array = PackedFloat32Array()
var _nlife: PackedFloat32Array = PackedFloat32Array()
var _ntext: Array[String] = []
var _ncol: PackedColorArray = PackedColorArray()
var _number_budget: int = 0

var _w_next: int = 0
var _wx: PackedFloat32Array = PackedFloat32Array()
var _wy: PackedFloat32Array = PackedFloat32Array()
var _wr: PackedFloat32Array = PackedFloat32Array()
var _wlife: PackedFloat32Array = PackedFloat32Array()
var _wcol: PackedColorArray = PackedColorArray()

var _font: Font


func _ready() -> void:
	for arr: PackedFloat32Array in [_px, _py, _pvx, _pvy, _plife, _plife0, _psize]:
		arr.resize(PCAP)
	_pcol.resize(PCAP)
	for arr2: PackedFloat32Array in [_nx, _ny, _nlife]:
		arr2.resize(NCAP)
	_ncol.resize(NCAP)
	_ntext.resize(NCAP)
	for arr3: PackedFloat32Array in [_wx, _wy, _wr, _wlife]:
		arr3.resize(WCAP)
	_wcol.resize(WCAP)
	_font = UiKit.font_bold()
	show_numbers = bool(Save.setting("damage_numbers"))
	shake_enabled = bool(Save.setting("screen_shake"))


func particle(x: float, y: float, vx: float, vy: float, life: float, size: float, color: Color) -> void:
	if _p_n >= PCAP:
		return
	var i: int = _p_n
	_p_n += 1
	_px[i] = x
	_py[i] = y
	_pvx[i] = vx
	_pvy[i] = vy
	_plife[i] = life
	_plife0[i] = life
	_psize[i] = size
	_pcol[i] = color


func burst(x: float, y: float, color: Color, n: int, speed: float) -> void:
	for k: int in n:
		var a: float = randf() * TAU
		var s: float = speed * randf_range(0.3, 1.0)
		particle(x, y, cos(a) * s, sin(a) * s, randf_range(0.25, 0.55), randf_range(1.5, 3.5), color)


func shockwave(x: float, y: float, radius: float, color: Color) -> void:
	var i: int = _w_next
	_w_next = (_w_next + 1) % WCAP
	_wx[i] = x
	_wy[i] = y
	_wr[i] = radius
	_wlife[i] = 0.3
	_wcol[i] = color


func number(x: float, y: float, value: float, color: Color = Color.WHITE) -> void:
	if not show_numbers or _number_budget <= 0:
		return
	_number_budget -= 1
	text(x, y, str(int(value)), color)


func text(x: float, y: float, s: String, color: Color = Color.WHITE) -> void:
	var i: int = _n_next
	_n_next = (_n_next + 1) % NCAP
	_nx[i] = x + randf_range(-6.0, 6.0)
	_ny[i] = y - 10.0
	_nlife[i] = 0.6
	_ntext[i] = s
	_ncol[i] = color


func add_shake(amount: float) -> void:
	if shake_enabled:
		shake = minf(shake + amount, 10.0)


func update(dt: float) -> void:
	_number_budget = 6
	shake = maxf(0.0, shake - dt * 22.0)
	var i: int = 0
	while i < _p_n:
		var l: float = _plife[i] - dt
		if l <= 0.0:
			_p_n -= 1
			var j: int = _p_n
			_px[i] = _px[j]
			_py[i] = _py[j]
			_pvx[i] = _pvx[j]
			_pvy[i] = _pvy[j]
			_plife[i] = _plife[j]
			_plife0[i] = _plife0[j]
			_psize[i] = _psize[j]
			_pcol[i] = _pcol[j]
			continue
		_plife[i] = l
		_px[i] += _pvx[i] * dt
		_py[i] += _pvy[i] * dt
		_pvx[i] *= 0.94
		_pvy[i] *= 0.94
		i += 1
	for k: int in NCAP:
		if _nlife[k] > 0.0:
			_nlife[k] -= dt
			_ny[k] -= 26.0 * dt
	for k2: int in WCAP:
		if _wlife[k2] > 0.0:
			_wlife[k2] -= dt


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for i: int in _p_n:
		var c: Color = _pcol[i]
		var u: float = _plife[i] / _plife0[i]
		c.a *= u
		var s: float = _psize[i]
		draw_rect(Rect2(_px[i] - s * 0.5, _py[i] - s * 0.5, s, s), c)
	for k: int in WCAP:
		var wl: float = _wlife[k]
		if wl > 0.0:
			var wu: float = wl / 0.3
			var wc: Color = _wcol[k]
			wc.a = wu * 0.8
			draw_arc(Vector2(_wx[k], _wy[k]), _wr[k] * (1.0 - wu * 0.5), 0.0, TAU, 28, wc, 1.0 + 3.0 * wu)
	for n: int in NCAP:
		var nl: float = _nlife[n]
		if nl > 0.0:
			var nc: Color = _ncol[n]
			nc.a = minf(1.0, nl * 3.0)
			draw_string_outline(_font, Vector2(_nx[n], _ny[n]), _ntext[n], HORIZONTAL_ALIGNMENT_CENTER, -1, 8, 3, Color(0.1, 0.1, 0.15, nc.a))
			draw_string(_font, Vector2(_nx[n], _ny[n]), _ntext[n], HORIZONTAL_ALIGNMENT_CENTER, -1, 8, nc)
