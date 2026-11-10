class_name UiKit
extends RefCounted
## Shared look and small builders for every screen. The theme is made from the existing
## nine-patch sheet (assets/ui/big_ui.png) so new screens match the original art.

const C_BG: Color = Color("1b1a2b")
const C_TEXT: Color = Color("fff1d2")
const C_DIM: Color = Color("b8a98c")
const C_ACCENT: Color = Color("fbf236")
const C_GOOD: Color = Color("99e550")
const C_BAD: Color = Color("d95763")
const C_LOCKED: Color = Color("6b6577")
const C_XP: Color = Color("5fcde4")

const SIZE_SMALL: int = 20
const SIZE_BODY: int = 26
const SIZE_HEAD: int = 40
const SIZE_TITLE: int = 96

static var _theme: Theme = null
static var _font: Font = null
static var _font_bold: Font = null
static var _sheet: Texture2D = null


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/PixelifySans.ttf")
	return _font


static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = load("res://assets/fonts/Silkscreen-Bold.ttf")
	return _font_bold


static func _tile(col: int, row: int, margin: float = 7.0) -> StyleBoxTexture:
	if _sheet == null:
		_sheet = load("res://assets/ui/big_ui.png")
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = _sheet
	sb.region_rect = Rect2(col * 33, row * 33, 32, 32)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(14.0)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	return sb


static func flat(color: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 4) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10.0)
	sb.anti_aliasing = false
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = font()
	t.default_font_size = SIZE_BODY
	var normal: StyleBoxTexture = _tile(1, 0)
	var hover: StyleBoxTexture = _tile(1, 0)
	hover.modulate_color = Color(1.2, 1.15, 1.05)
	var pressed: StyleBoxTexture = _tile(1, 0)
	pressed.modulate_color = Color(0.8, 0.8, 0.8)
	var disabled: StyleBoxTexture = _tile(3, 0)
	disabled.modulate_color = Color(0.8, 0.8, 0.8)
	var focus: StyleBoxFlat = flat(Color.TRANSPARENT, C_ACCENT, 4, 6)
	focus.set_expand_margin_all(4.0)
	for cls: String in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, focus)
		t.set_color("font_color", cls, C_TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, C_ACCENT)
		t.set_color("font_focus_color", cls, Color.WHITE)
		t.set_color("font_disabled_color", cls, C_LOCKED)
		t.set_color("font_outline_color", cls, Color("3b2414"))
		t.set_constant("outline_size", cls, 6)
	var panel: StyleBoxTexture = _tile(3, 0)
	panel.set_content_margin_all(24.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_outline_color", "Label", Color("15141f"))
	t.set_constant("outline_size", "Label", 6)
	t.set_color("default_color", "RichTextLabel", C_TEXT)
	t.set_font("normal_font", "RichTextLabel", font())
	t.set_font_size("normal_font_size", "RichTextLabel", SIZE_BODY)
	t.set_stylebox("background", "ProgressBar", flat(Color("15141f"), Color("3f3f74"), 2, 2))
	t.set_stylebox("fill", "ProgressBar", flat(C_XP, Color.TRANSPARENT, 0, 2))
	t.set_stylebox("slider", "HSlider", flat(Color("15141f"), Color("3f3f74"), 2, 4))
	t.set_stylebox("grabber_area", "HSlider", flat(Color("8f563b"), Color.TRANSPARENT, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(Color("df7126"), Color.TRANSPARENT, 0, 4))
	t.set_stylebox("tab_selected", "TabContainer", _tile(1, 0))
	t.set_stylebox("tab_unselected", "TabContainer", _tile(3, 0))
	t.set_stylebox("tab_hovered", "TabContainer", hover)
	t.set_stylebox("tab_focus", "TabContainer", focus)
	t.set_stylebox("panel", "TabContainer", flat(Color(0, 0, 0, 0.25), Color("3f3f74"), 2, 4))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", C_DIM)
	t.set_stylebox("panel", "TooltipPanel", flat(Color("15141f"), C_DIM, 2, 4))
	t.set_stylebox("normal", "LineEdit", flat(Color("15141f"), Color("3f3f74"), 2, 4))
	t.set_stylebox("focus", "LineEdit", flat(Color("15141f"), C_ACCENT, 2, 4))
	var sep: StyleBoxFlat = flat(Color("3f3f74"))
	sep.set_content_margin_all(1.0)
	t.set_stylebox("separator", "HSeparator", sep)
	_theme = t
	return t


# --- builders ------------------------------------------------------------------------------

static func label(text: String, size: int = SIZE_BODY, color: Color = C_TEXT, bold: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold())
	return l


static func wrapped(text: String, size: int = SIZE_BODY, color: Color = C_TEXT, min_width: float = 300.0) -> Label:
	var l: Label = label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = min_width
	return l


static func button(text: String, on_press: Callable, min_size: Vector2 = Vector2(260, 64)) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		on_press.call())
	b.focus_entered.connect(func() -> void: Audio.play("tick", -14.0))
	return b


static func icon(sprite: String, size: float = 64.0) -> TextureRect:
	var tr: TextureRect = TextureRect.new()
	tr.texture = Atlas.icon(sprite)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(size, size)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func vbox(sep: int = 12) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func grid(columns: int, sep: int = 12) -> GridContainer:
	var g: GridContainer = GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g


static func panel() -> PanelContainer:
	return PanelContainer.new()


static func card(color: Color = Color(0, 0, 0, 0.35)) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(color, Color("3f3f74"), 2, 6))
	return p


static func spacer(min_size: Vector2 = Vector2.ZERO, expand: bool = true) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = min_size
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func scroll(content: Control, min_size: Vector2) -> ScrollContainer:
	var s: ScrollContainer = ScrollContainer.new()
	s.custom_minimum_size = min_size
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.follow_focus = true
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


## Full-rect root for a screen, with the shared theme and a dark backdrop.
static func screen_root(backdrop: Color = C_BG) -> Control:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = theme()
	var bg: ColorRect = ColorRect.new()
	bg.color = backdrop
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	return root


static func center(child: Control) -> CenterContainer:
	var c: CenterContainer = CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(child)
	return c


static func format_time(seconds: float) -> String:
	var s: int = int(seconds)
	return "%02d:%02d" % [s / 60, s % 60]


static func format_number(v: float) -> String:
	if v >= 1000000.0:
		return "%.1fM" % (v / 1000000.0)
	if v >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	return str(int(v))
