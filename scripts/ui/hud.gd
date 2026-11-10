class_name Hud
extends CanvasLayer
## In-run interface: status bars, inventory, boss bar, banners and the level-up, chest and
## pause menus.

var run: Run
var root: Control
var _xp_bar: ProgressBar
var _level_label: Label
var _timer_label: Label
var _kills_label: Label
var _gold_label: Label
var _inv_box: VBoxContainer
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_label: Label
var _banner: Label
var _banner_t: float = 0.0
var _flash: ColorRect
var _flash_a: float = 0.0
var _beat_dots: Array[ColorRect] = []
var _menu_layer: Control
var _menu: Control = null
var _banish_mode: bool = false
var _fps_label: Label
var _relic_arrow: Label
var _stick: TouchStick = null
var debug_menu: Control = null


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 0, 0, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	_xp_bar = ProgressBar.new()
	_xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_xp_bar.offset_left = 12
	_xp_bar.offset_right = -12
	_xp_bar.offset_top = 10
	_xp_bar.offset_bottom = 40
	_xp_bar.show_percentage = false
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_xp_bar)
	_level_label = UiKit.label("LV 1", UiKit.SIZE_SMALL, UiKit.C_TEXT, true)
	_level_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_level_label.offset_left = -140
	_level_label.offset_right = -24
	_level_label.offset_top = 12
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_level_label)

	var top: VBoxContainer = UiKit.vbox(2)
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 48
	top.offset_left = -200
	top.offset_right = 200
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_timer_label = UiKit.label("00:00", 52, UiKit.C_TEXT, true)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_timer_label)
	var dots: HBoxContainer = UiKit.hbox(8)
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(dots)
	for k: int in 4:
		var d: ColorRect = ColorRect.new()
		d.custom_minimum_size = Vector2(18, 8)
		d.color = Color(1, 1, 1, 0.25)
		dots.add_child(d)
		_beat_dots.append(d)
	_boss_box = UiKit.vbox(2)
	_boss_box.visible = false
	top.add_child(_boss_box)
	_boss_label = UiKit.label("", UiKit.SIZE_BODY, UiKit.C_BAD, true)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_label)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(520, 22)
	_boss_bar.show_percentage = false
	_boss_bar.add_theme_stylebox_override("fill", UiKit.flat(UiKit.C_BAD, Color.TRANSPARENT, 0, 2))
	_boss_box.add_child(_boss_bar)

	var right: VBoxContainer = UiKit.vbox(4)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -260
	right.offset_right = -24
	right.offset_top = 50
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	var krow: HBoxContainer = UiKit.hbox(8)
	krow.alignment = BoxContainer.ALIGNMENT_END
	_kills_label = UiKit.label("0", UiKit.SIZE_BODY)
	krow.add_child(_kills_label)
	krow.add_child(UiKit.icon("ui_curse", 32))
	right.add_child(krow)
	var grow: HBoxContainer = UiKit.hbox(8)
	grow.alignment = BoxContainer.ALIGNMENT_END
	_gold_label = UiKit.label("0", UiKit.SIZE_BODY, UiKit.C_ACCENT)
	grow.add_child(_gold_label)
	grow.add_child(UiKit.icon("pk_coin", 32))
	right.add_child(grow)
	_fps_label = UiKit.label("", UiKit.SIZE_SMALL, UiKit.C_DIM)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.visible = bool(Save.setting("show_fps"))
	right.add_child(_fps_label)

	_inv_box = UiKit.vbox(4)
	_inv_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_inv_box.offset_left = 16
	_inv_box.offset_top = 50
	_inv_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_inv_box)

	_banner = UiKit.label("", 56, UiKit.C_ACCENT, true)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -900
	_banner.offset_right = 900
	_banner.offset_top = 230
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner)

	_relic_arrow = UiKit.label("▲", 40, UiKit.C_GOOD, true)
	_relic_arrow.visible = false
	_relic_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_relic_arrow)

	if bool(Save.setting("touch_stick")) or DisplayServer.is_touchscreen_available():
		_stick = TouchStick.new()
		_stick.player = run.player
		root.add_child(_stick)

	_menu_layer = Control.new()
	_menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_menu_layer)
	rebuild_inventory()


func _process(delta: float) -> void:
	var p: Player = run.player
	_xp_bar.max_value = p.xp_next
	_xp_bar.value = p.xp
	_level_label.text = "LV %d" % p.level
	var remaining: float = maxf(0.0, run.stage_len - run.time)
	_timer_label.text = UiKit.format_time(run.time)
	_timer_label.add_theme_color_override("font_color", UiKit.C_BAD if remaining < 60.0 and remaining > 0.0 else UiKit.C_TEXT)
	_kills_label.text = str(run.kills)
	_gold_label.text = str(int(run.gold))
	var beat: int = (Music.step >> 2) & 3
	for k: int in 4:
		var on: bool = k == beat
		var pulse: float = 1.0 - Music.beat_phase if on else 0.0
		_beat_dots[k].color = Color(1.0, 0.95, 0.4, 0.3 + 0.7 * pulse) if on else Color(1, 1, 1, 0.22)
	var boss: BossController = null
	for b: BossController in run.bosses:
		if b.is_final and b.alive():
			boss = b
	_boss_box.visible = boss != null
	if boss != null:
		_boss_label.text = boss.display_name()
		_boss_bar.value = boss.hp_fraction() * 100.0
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	if _flash_a > 0.0:
		_flash_a = maxf(0.0, _flash_a - delta * 2.5)
		_flash.color.a = _flash_a
	if _fps_label.visible:
		_fps_label.text = "%d fps  %d enemies  %d shots" % [Engine.get_frames_per_second(), run.enemies.count, run.shots.count]
	_update_relic_arrow()


func _update_relic_arrow() -> void:
	var pk: PickupManager = run.pickups
	var found: bool = false
	for i: int in pk.n:
		if pk.kind[i] == PickupManager.Kind.RELIC:
			var d: Vector2 = Vector2(pk.x[i], pk.y[i]) - run.player.position
			if d.length() > 260.0 and d.length() < 1400.0:
				var size: Vector2 = root.size
				var dir: Vector2 = d.normalized()
				_relic_arrow.position = size * 0.5 + Vector2(dir.x * size.x * 0.42, dir.y * size.y * 0.38) - Vector2(20, 20)
				_relic_arrow.rotation = dir.angle() + PI * 0.5
				_relic_arrow.pivot_offset = Vector2(20, 24)
				found = true
			break
	_relic_arrow.visible = found


func banner(text: String) -> void:
	_banner.text = text
	_banner_t = 3.0


func flash_damage() -> void:
	if not run.reduced_flashing:
		_flash.color = Color(1, 0.1, 0.1, 0.0)
		_flash_a = 0.25


func flash_screen() -> void:
	if not run.reduced_flashing:
		_flash.color = Color(1, 1, 1, 0.0)
		_flash_a = 0.5


func rebuild_inventory() -> void:
	if _inv_box == null:
		return
	for c: Node in _inv_box.get_children():
		c.queue_free()
	var wrow: HBoxContainer = UiKit.hbox(6)
	for w: WeaponSystem.Weapon in run.weapons.weapons:
		wrow.add_child(_inv_icon(w.def.get("icon", "ui_unknown"), w.level, Content.instrument_max_level(w.id), w.evolved))
	_inv_box.add_child(wrow)
	var prow: HBoxContainer = UiKit.hbox(6)
	for id: String in run.player.passives:
		prow.add_child(_inv_icon(Content.passives[id].get("icon", "ui_unknown"), int(run.player.passives[id]), Content.passive_max_level(id), false))
	_inv_box.add_child(prow)


func _inv_icon(sprite: String, level: int, max_level: int, evolved: bool) -> Control:
	var holder: PanelContainer = UiKit.card(Color(0, 0, 0, 0.45))
	holder.add_theme_stylebox_override("panel", UiKit.flat(Color(0, 0, 0, 0.45), UiKit.C_ACCENT if evolved or level >= max_level else Color("3f3f74"), 2, 4))
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v: VBoxContainer = UiKit.vbox(0)
	v.add_child(UiKit.icon(sprite, 44))
	var l: Label = UiKit.label("MAX" if evolved or level >= max_level else str(level), 16, UiKit.C_ACCENT if level >= max_level else UiKit.C_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	holder.add_child(v)
	return holder


# --- menus ---------------------------------------------------------------------------------

func hide_menus() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	_banish_mode = false


func _open_menu(content: Control, dim: float = 0.55) -> void:
	hide_menus()
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(shade)
	_menu.add_child(UiKit.center(content))
	_menu_layer.add_child(_menu)


func show_level_up() -> void:
	var panel: PanelContainer = UiKit.panel()
	var v: VBoxContainer = UiKit.vbox(14)
	panel.add_child(v)
	var title: Label = UiKit.label("LEVEL UP!" if not _banish_mode else "BANISH WHICH ONE?", UiKit.SIZE_HEAD, UiKit.C_ACCENT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var first: Button = null
	for k: int in run.options.size():
		var b: Button = _option_button(run.options[k], k)
		v.add_child(b)
		if first == null:
			first = b
	var row: HBoxContainer = UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var reroll: Button = UiKit.button("Reroll (%d)" % run.rerolls, run.reroll_options, Vector2(220, 56))
	reroll.disabled = run.rerolls <= 0
	row.add_child(reroll)
	var skip: Button = UiKit.button("Skip (%d)" % run.skips, run.skip_level, Vector2(220, 56))
	skip.disabled = run.skips <= 0
	row.add_child(skip)
	var banish: Button = UiKit.button("Banish (%d)" % run.banishes if not _banish_mode else "Cancel", _toggle_banish, Vector2(220, 56))
	banish.disabled = run.banishes <= 0
	row.add_child(banish)
	v.add_child(row)
	var keep_banish: bool = _banish_mode
	_open_menu(panel)
	_banish_mode = keep_banish
	if first != null:
		first.grab_focus.call_deferred()


func _toggle_banish() -> void:
	_banish_mode = not _banish_mode
	show_level_up()


func _option_button(opt: Dictionary, index: int) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(820, 118)
	b.pressed.connect(func() -> void:
		Audio.play("click", -6.0)
		if _banish_mode:
			_banish_mode = false
			run.banish_option(index)
		else:
			run.choose_option(index))
	b.focus_entered.connect(func() -> void: Audio.play("tick", -14.0))
	var row: HBoxContainer = UiKit.hbox(18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.offset_top = 8
	row.offset_bottom = -8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiKit.icon(opt.get("icon", "ui_unknown"), 80))
	var col: VBoxContainer = UiKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head: HBoxContainer = UiKit.hbox(12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(UiKit.label(opt.get("title", ""), 30, Color.WHITE, true))
	var tag: String = ""
	var tag_col: Color = UiKit.C_DIM
	if opt["kind"] == "evolve":
		tag = "EVOLUTION"
		tag_col = UiKit.C_ACCENT
	elif opt.get("new", false):
		tag = "NEW"
		tag_col = UiKit.C_GOOD
	elif int(opt.get("level", 0)) > 0:
		tag = "LV %d" % int(opt["level"])
	head.add_child(UiKit.label(tag, UiKit.SIZE_SMALL, tag_col, true))
	col.add_child(head)
	var desc: Label = UiKit.wrapped(opt.get("desc", ""), 22, UiKit.C_TEXT, 600)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(desc)
	row.add_child(col)
	b.add_child(row)
	return b


func show_chest() -> void:
	var panel: PanelContainer = UiKit.panel()
	var v: VBoxContainer = UiKit.vbox(12)
	panel.add_child(v)
	var title: Label = UiKit.label("TREASURE!", UiKit.SIZE_HEAD, UiKit.C_ACCENT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var chest_icon: TextureRect = UiKit.icon("pk_chest", 128)
	chest_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(chest_icon)
	for opt: Dictionary in run.chest_rewards:
		var row: HBoxContainer = UiKit.hbox(16)
		row.custom_minimum_size = Vector2(700, 72)
		row.add_child(UiKit.icon(opt.get("icon", "ui_unknown"), 64))
		var col: VBoxContainer = UiKit.vbox(0)
		var name_col: Color = UiKit.C_ACCENT if opt["kind"] == "evolve" else Color.WHITE
		var suffix: String = "  EVOLVED!" if opt["kind"] == "evolve" else ("  LV %d" % int(opt["level"]) if int(opt.get("level", 0)) > 0 else "")
		col.add_child(UiKit.label(str(opt.get("title", "")) + suffix, 28, name_col, true))
		col.add_child(UiKit.wrapped(opt.get("desc", ""), 20, UiKit.C_DIM, 560))
		row.add_child(col)
		v.add_child(row)
	var ok: Button = UiKit.button("Continue", run.close_chest)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ok)
	_open_menu(panel)
	ok.grab_focus.call_deferred()


func show_pause() -> void:
	var panel: PanelContainer = UiKit.panel()
	var h: HBoxContainer = UiKit.hbox(40)
	panel.add_child(h)
	var left: VBoxContainer = UiKit.vbox(14)
	left.add_child(UiKit.label("PAUSED", UiKit.SIZE_HEAD, UiKit.C_ACCENT, true))
	var resume: Button = UiKit.button("Resume", func() -> void: run.set_paused(false))
	left.add_child(resume)
	left.add_child(UiKit.button("Settings", _open_settings))
	left.add_child(UiKit.button("Give up", run.give_up))
	left.add_child(UiKit.spacer(Vector2(0, 10), false))
	left.add_child(UiKit.label("%s  ·  %s" % [run.stage.get("name", ""), run.player.def.get("name", "")], UiKit.SIZE_SMALL, UiKit.C_DIM))
	left.add_child(UiKit.label("Time %s   Kills %d   Gold %d" % [UiKit.format_time(run.time), run.kills, int(run.gold)], UiKit.SIZE_SMALL, UiKit.C_DIM))
	h.add_child(left)
	h.add_child(build_panel(run))
	_open_menu(panel, 0.7)
	resume.grab_focus.call_deferred()


func _open_settings() -> void:
	var panel: PanelContainer = UiKit.panel()
	var v: VBoxContainer = UiKit.vbox(12)
	panel.add_child(v)
	var settings: SettingsPanel = SettingsPanel.new()
	v.add_child(settings)
	var back: Button = UiKit.button("Back", show_pause)
	v.add_child(back)
	_open_menu(panel, 0.7)
	back.grab_focus.call_deferred()


## Build and stat summary shown in the pause menu.
static func build_panel(run_: Run) -> Control:
	var v: VBoxContainer = UiKit.vbox(8)
	v.add_child(UiKit.label("BUILD", UiKit.SIZE_BODY, UiKit.C_ACCENT, true))
	var dmg: Dictionary = run_.weapons.damage_report()
	for w: WeaponSystem.Weapon in run_.weapons.weapons:
		var row: HBoxContainer = UiKit.hbox(10)
		row.add_child(UiKit.icon(w.def.get("icon", "ui_unknown"), 40))
		var lvl: String = "EVO" if w.evolved else "Lv %d" % w.level
		row.add_child(UiKit.label("%s  %s" % [w.def.get("name", w.id), lvl], 22))
		row.add_child(UiKit.spacer())
		row.add_child(UiKit.label(UiKit.format_number(float(dmg.get(w.id, 0.0))) + " dmg", 20, UiKit.C_DIM))
		row.custom_minimum_size.x = 560
		v.add_child(row)
	var prow: HBoxContainer = UiKit.hbox(8)
	for id: String in run_.player.passives:
		var cell: VBoxContainer = UiKit.vbox(0)
		cell.add_child(UiKit.icon(Content.passives[id].get("icon", "ui_unknown"), 40))
		var l: Label = UiKit.label(str(int(run_.player.passives[id])), 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		prow.add_child(cell)
	v.add_child(prow)
	v.add_child(UiKit.label("STATS", UiKit.SIZE_BODY, UiKit.C_ACCENT, true))
	var g: GridContainer = UiKit.grid(4, 16)
	var p: Player = run_.player
	var rows: Array = [
		["Max HP", "%d" % int(p.max_hp)], ["Recovery", "%.1f/s" % p.stat("recovery")],
		["Armor", "%d" % int(p.stat("armor"))], ["Move speed", "%d%%" % int(p.stat("move_speed") * 100)],
		["Might", "%d%%" % int(p.stat("might") * 100)], ["Area", "%d%%" % int(p.stat("area") * 100)],
		["Speed", "%d%%" % int(p.stat("speed") * 100)], ["Duration", "%d%%" % int(p.stat("duration") * 100)],
		["Amount", "+%d" % int(p.stat("amount"))], ["Cooldown", "%d%%" % int(p.stat("cooldown") * 100)],
		["Luck", "%d%%" % int(p.stat("luck") * 100)], ["Growth", "%d%%" % int(p.stat("growth") * 100)],
		["Greed", "%d%%" % int(p.stat("greed") * 100)], ["Curse", "%d%%" % int(p.stat("curse") * 100)],
		["Magnet", "%d%%" % int(p.stat("magnet") * 100)], ["Revivals", "%d" % p.revives_left],
	]
	for r: Array in rows:
		g.add_child(UiKit.label(r[0], 20, UiKit.C_DIM))
		g.add_child(UiKit.label(r[1], 20))
	v.add_child(g)
	return v
