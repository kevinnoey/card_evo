class_name BattleHUD
extends Control
## Battle HUD - HP bars, EP display, reserve bar, messages, enemy intent (1920x1080 PRD layout)

signal deck_viewer_closed

const CardUIScene = preload("res://scenes/card_ui.tscn")

var player_hp_bar: ProgressBar
var player_hp_label: Label
var enemy_hp_bar: ProgressBar
var enemy_hp_label: Label
var enemy_name_label: Label
var enemy_intent_label: Label
var enemy_intent_icon: Label
var enemy_shield_label: Label
var enemy_ice_label: Label
var enemy_portrait: TextureRect
var enemy_crash_label: Label  # 崩溃层数显示
var ep_dots: Array = []
var ep_count_label: Label
var reserve_bar: ProgressBar
var reserve_label: Label
var energy_shield_label: Label
var end_turn_btn: Button
var message_label: Label
var block_label: Label
var barrier_label: Label
var _clean_enemy_name: String = ""
var _msg_tween: Tween
var _player_portrait_fx: PortraitFX
var _enemy_portrait_fx: PortraitFX

# Deck viewer
var deck_btn: Button
var _deck_overlay: Control
var _deck_grid: Control
var _deck_card_count_label: Label

# Log panel
var _log_container: VBoxContainer
var _log_scroll: ScrollContainer
const MAX_LOG_ENTRIES = 50

func _ready():
	_build_hud()
	# 监听全局日志信号，实时显示新条目
	ActionLog.entry_added.connect(_on_action_log_added)

func _build_hud():
	# ===== TOP-LEFT: Player HP =====
	var char_info = CardDatabase.get_character_info(RunRewardState.selected_character)
	var char_color = char_info.get("color", Color("#00F0FF"))
	var char_hp = char_info.get("hp", 70)
	var player_name = Label.new()
	player_name.text = char_info.get("name", "渗透者")
	player_name.position = Vector2(40, 28)
	player_name.add_theme_font_size_override("font_size", 22)
	player_name.add_theme_color_override("font_color", char_color)
	add_child(player_name)

	_add_bar_frame(Vector2(40, 60), Vector2(400, 30), Color("#3BFF8C"))

	player_hp_bar = ProgressBar.new()
	player_hp_bar.position = Vector2(40, 60)
	player_hp_bar.size = Vector2(400, 26)
	player_hp_bar.max_value = char_hp
	player_hp_bar.value = char_hp
	player_hp_bar.show_percentage = false
	var php_bg = StyleBoxFlat.new()
	php_bg.bg_color = Color("#1A1A2E")
	php_bg.corner_radius_top_left = 6
	php_bg.corner_radius_top_right = 6
	php_bg.corner_radius_bottom_left = 6
	php_bg.corner_radius_bottom_right = 6
	player_hp_bar.add_theme_stylebox_override("background", php_bg)
	var php_fill = StyleBoxFlat.new()
	php_fill.bg_color = Color("#3BFF8C")
	php_fill.corner_radius_top_left = 6
	php_fill.corner_radius_top_right = 6
	php_fill.corner_radius_bottom_left = 6
	php_fill.corner_radius_bottom_right = 6
	player_hp_bar.add_theme_stylebox_override("fill", php_fill)
	add_child(player_hp_bar)

	player_hp_label = Label.new()
	player_hp_label.text = str(char_hp) + " / " + str(char_hp)
	player_hp_label.position = Vector2(370, 30)
	player_hp_label.add_theme_font_size_override("font_size", 20)
	player_hp_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(player_hp_label)

	# Player portrait with neon frame
	var portrait_path = "res://card/渗透者.png" if RunRewardState.selected_character == "infiltrator" else "res://card/代码崩溃者.png"
	_add_framed_portrait(Vector2(78, 220), Vector2(240, 330), load(portrait_path), char_color, true)

	# ===== TOP-LEFT: EP Dots + Count =====
	var ep_label_title = Label.new()
	ep_label_title.text = "EP"
	ep_label_title.position = Vector2(40, 115)
	ep_label_title.add_theme_font_size_override("font_size", 24)
	ep_label_title.add_theme_color_override("font_color", Color("#FFD700"))
	add_child(ep_label_title)

	for i in range(3):
		var dot = ColorRect.new()
		dot.size = Vector2(24, 24)
		dot.position = Vector2(40 + i * 32, 150)
		dot.color = Color("#FFD700")
		add_child(dot)
		ep_dots.append(dot)

	ep_count_label = Label.new()
	ep_count_label.text = "3"
	ep_count_label.position = Vector2(145, 150)
	ep_count_label.add_theme_font_size_override("font_size", 24)
	ep_count_label.add_theme_color_override("font_color", Color("#FFD700"))
	add_child(ep_count_label)

	# Barrier display
	barrier_label = Label.new()
	barrier_label.text = "屏障: 0"
	barrier_label.position = Vector2(190, 96)
	barrier_label.add_theme_font_size_override("font_size", 18)
	barrier_label.add_theme_color_override("font_color", Color("#00FFFF"))
	add_child(barrier_label)

	# Block display
	block_label = Label.new()
	block_label.text = "格挡: 0"
	block_label.position = Vector2(320, 96)
	block_label.add_theme_font_size_override("font_size", 18)
	block_label.add_theme_color_override("font_color", Color("#3B8CFF"))
	add_child(block_label)

	# ===== CENTER-TOP: EP Reserve Bar =====
	var reserve_title = Label.new()
	reserve_title.text = "EP 储备池"
	reserve_title.position = Vector2(840, 20)
	reserve_title.size = Vector2(200, 22)
	reserve_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reserve_title.add_theme_font_size_override("font_size", 20)
	reserve_title.add_theme_color_override("font_color", Color("#FFD700"))
	add_child(reserve_title)

	_add_bar_frame(Vector2(660, 55), Vector2(600, 28), Color("#FF8C00"))

	reserve_bar = ProgressBar.new()
	reserve_bar.position = Vector2(660, 55)
	reserve_bar.size = Vector2(600, 24)
	reserve_bar.max_value = 15
	reserve_bar.value = 0
	reserve_bar.show_percentage = false
	var rsv_bg = StyleBoxFlat.new()
	rsv_bg.bg_color = Color("#1A1A2E")
	rsv_bg.corner_radius_top_left = 6
	rsv_bg.corner_radius_top_right = 6
	rsv_bg.corner_radius_bottom_left = 6
	rsv_bg.corner_radius_bottom_right = 6
	reserve_bar.add_theme_stylebox_override("background", rsv_bg)
	var rsv_fill = StyleBoxFlat.new()
	rsv_fill.bg_color = Color("#FFD700")
	rsv_fill.corner_radius_top_left = 6
	rsv_fill.corner_radius_top_right = 6
	rsv_fill.corner_radius_bottom_left = 6
	rsv_fill.corner_radius_bottom_right = 6
	reserve_bar.add_theme_stylebox_override("fill", rsv_fill)
	add_child(reserve_bar)

	for threshold in [5, 10]:
		var marker = ColorRect.new()
		marker.size = Vector2(3, 24)
		marker.position = Vector2(660 + (600.0 * threshold / 15), 55)
		marker.color = Color("#FF6B35")
		add_child(marker)

	reserve_label = Label.new()
	reserve_label.text = "：0 / 15"
	reserve_label.position = Vector2(990, 20)
	reserve_label.add_theme_font_size_override("font_size", 20)
	reserve_label.add_theme_color_override("font_color", Color("#FFD700"))
	add_child(reserve_label)

	energy_shield_label = Label.new()
	energy_shield_label.text = "能量护盾 : 0"
	energy_shield_label.position = Vector2(870, 82)
	energy_shield_label.size = Vector2(180, 22)
	energy_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_shield_label.add_theme_font_size_override("font_size", 20)
	energy_shield_label.add_theme_color_override("font_color", Color("#FFD700"))
	add_child(energy_shield_label)

	# ===== RIGHT: Enemy Area (mirrors left player area) =====
	enemy_name_label = Label.new()
	enemy_name_label.text = "防火墙哨兵"
	enemy_name_label.position = Vector2(1480, 28)
	enemy_name_label.size = Vector2(400, 26)
	enemy_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_name_label.add_theme_font_size_override("font_size", 22)
	enemy_name_label.add_theme_color_override("font_color", Color("#FF6B35"))
	add_child(enemy_name_label)

	_add_bar_frame(Vector2(1480, 60), Vector2(400, 30), Color("#FF3B3B"))

	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.position = Vector2(1480, 60)
	enemy_hp_bar.size = Vector2(400, 26)
	enemy_hp_bar.max_value = 35
	enemy_hp_bar.value = 35
	enemy_hp_bar.show_percentage = false
	var ehp_bg = StyleBoxFlat.new()
	ehp_bg.bg_color = Color("#1A1A2E")
	ehp_bg.corner_radius_top_left = 6
	ehp_bg.corner_radius_top_right = 6
	ehp_bg.corner_radius_bottom_left = 6
	ehp_bg.corner_radius_bottom_right = 6
	enemy_hp_bar.add_theme_stylebox_override("background", ehp_bg)
	var ehp_fill = StyleBoxFlat.new()
	ehp_fill.bg_color = Color("#FF3B3B")
	ehp_fill.corner_radius_top_left = 6
	ehp_fill.corner_radius_top_right = 6
	ehp_fill.corner_radius_bottom_left = 6
	ehp_fill.corner_radius_bottom_right = 6
	enemy_hp_bar.add_theme_stylebox_override("fill", ehp_fill)
	add_child(enemy_hp_bar)

	enemy_hp_label = Label.new()
	enemy_hp_label.text = "35 / 35"
	enemy_hp_label.position = Vector2(1480, 30)
	enemy_hp_label.add_theme_font_size_override("font_size", 20)
	enemy_hp_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(enemy_hp_label)

	# Enemy portrait with neon frame
	enemy_portrait = _add_framed_portrait(Vector2(1548, 220), Vector2(240, 330), load("res://card/防火墙哨兵.png"), Color("#FF3B3B"))

	# Enemy ICE
	enemy_ice_label = Label.new()
	enemy_ice_label.text = ""
	enemy_ice_label.position = Vector2(1480, 90)
	enemy_ice_label.size = Vector2(400, 20)
	enemy_ice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_ice_label.add_theme_font_size_override("font_size", 18)
	enemy_ice_label.add_theme_color_override("font_color", Color("#3B8CFF"))
	add_child(enemy_ice_label)

	# Enemy Crash stacks (代码崩溃者机制)
	enemy_crash_label = Label.new()
	enemy_crash_label.text = ""
	enemy_crash_label.position = Vector2(1480, 70)
	enemy_crash_label.size = Vector2(400, 20)
	enemy_crash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_crash_label.add_theme_font_size_override("font_size", 18)
	enemy_crash_label.add_theme_color_override("font_color", Color("#FF3B8B"))
	add_child(enemy_crash_label)

	# Enemy shield
	enemy_shield_label = Label.new()
	enemy_shield_label.text = ""
	enemy_shield_label.position = Vector2(1480, 110)
	enemy_shield_label.size = Vector2(400, 20)
	enemy_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_shield_label.add_theme_font_size_override("font_size", 16)
	enemy_shield_label.add_theme_color_override("font_color", Color("#3B8CFF"))
	add_child(enemy_shield_label)

	# ===== RIGHT: Enemy Intent =====
	enemy_intent_icon = Label.new()
	enemy_intent_icon.text = "⚔️"
	enemy_intent_icon.position = Vector2(1640, 120)
	enemy_intent_icon.size = Vector2(80, 50)
	enemy_intent_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_intent_icon.add_theme_font_size_override("font_size", 48)
	add_child(enemy_intent_icon)

	enemy_intent_label = Label.new()
	enemy_intent_label.text = "攻击 6"
	enemy_intent_label.position = Vector2(1640, 180)
	enemy_intent_label.size = Vector2(80, 36)
	enemy_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_intent_label.add_theme_font_size_override("font_size", 24)
	enemy_intent_label.add_theme_color_override("font_color", Color("#FF6B35"))
	add_child(enemy_intent_label)

	# ===== MESSAGE AREA =====
	message_label = Label.new()
	message_label.text = ""
	message_label.position = Vector2(160, 530)
	message_label.size = Vector2(1600, 40)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(message_label)

	# ===== BOTTOM-RIGHT: End Turn Button =====
	end_turn_btn = Button.new()
	end_turn_btn.text = "结束回合 ▶"
	end_turn_btn.position = Vector2(1640, 980)
	end_turn_btn.size = Vector2(240, 60)
	end_turn_btn.add_theme_font_size_override("font_size", 24)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#3B3B6B")
	btn_style.corner_radius_top_left = 12
	btn_style.corner_radius_top_right = 12
	btn_style.corner_radius_bottom_left = 12
	btn_style.corner_radius_bottom_right = 12
	end_turn_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color("#5050A0")
	btn_hover.corner_radius_top_left = 12
	btn_hover.corner_radius_top_right = 12
	btn_hover.corner_radius_bottom_left = 12
	btn_hover.corner_radius_bottom_right = 12
	end_turn_btn.add_theme_stylebox_override("hover", btn_hover)
	add_child(end_turn_btn)

	# ===== BOTTOM-CENTER: Deck Viewer Button =====
	deck_btn = Button.new()
	deck_btn.text = "📋 卡组"
	deck_btn.position = Vector2(1640, 880)
	deck_btn.size = Vector2(240, 45)
	deck_btn.add_theme_font_size_override("font_size", 20)
	deck_btn.add_theme_color_override("font_color", Color("#00F0FF"))
	var dk_style = StyleBoxFlat.new()
	dk_style.bg_color = Color("#1A1A3A")
	dk_style.border_color = Color("#00F0FF")
	dk_style.border_width_left = 2; dk_style.border_width_right = 2
	dk_style.border_width_top = 2; dk_style.border_width_bottom = 2
	dk_style.corner_radius_top_left = 8; dk_style.corner_radius_top_right = 8
	dk_style.corner_radius_bottom_left = 8; dk_style.corner_radius_bottom_right = 8
	deck_btn.add_theme_stylebox_override("normal", dk_style)
	var dk_hover = dk_style.duplicate()
	dk_hover.bg_color = Color("#2A2A5A")
	dk_hover.border_color = Color("#FFFFFF")
	dk_hover.shadow_size = 10
	dk_hover.shadow_color = Color("#00F0FF")
	deck_btn.add_theme_stylebox_override("hover", dk_hover)
	deck_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	deck_btn.z_index = 10
	
	add_child(deck_btn)

	# ===== BOTTOM-LEFT: Action Log Panel =====
	_build_log_panel(char_color)

# === Update Methods ===

func update_player_hp(current: int, max_hp: int):
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = current
	player_hp_label.text = str(current) + " / " + str(max_hp)

	var tween = create_tween()
	player_hp_label.add_theme_color_override("font_color", Color.RED)
	tween.tween_property(player_hp_label, "theme_override_colors/font_color", Color.WHITE, 0.3)

func update_enemy_hp(current: int, max_hp: int):
	enemy_hp_bar.max_value = max_hp
	enemy_hp_bar.value = current
	enemy_hp_label.text = str(current) + " / " + str(max_hp)

func update_enemy_name(name: String):
	_clean_enemy_name = name
	enemy_name_label.text = name

func update_ep(current: int, max_ep: int):
	for i in range(ep_dots.size()):
		ep_dots[i].color = Color("#FFD700") if i < current else Color("#333333")
	ep_count_label.text = str(current)

func update_reserve(current: int, max_reserve: int):
	reserve_bar.max_value = max_reserve
	reserve_bar.value = current
	reserve_label.text = str(current) + " / " + str(max_reserve)

	if current in [5, 10, 15]:
		var tween = create_tween()
		reserve_bar.modulate = Color("#FF6B35")
		tween.tween_property(reserve_bar, "modulate", Color.WHITE, 0.5)

func update_block(block: int):
	block_label.text = "格挡: " + str(block)
	block_label.visible = block > 0

func update_barrier(barrier: int):
	barrier_label.text = "屏障: " + str(barrier)
	barrier_label.visible = barrier > 0

func update_energy_shield(shields: int):
	energy_shield_label.text = "能量护盾: " + str(shields)
	if shields > 0:
		energy_shield_label.add_theme_color_override("font_color", Color("#FFD700"))

func update_intent(intent: Dictionary):
	var icon = intent.get("icon", "❓")
	var desc = intent.get("desc", "???")
	enemy_intent_icon.text = icon
	enemy_intent_label.text = desc

func update_ice(ice: int):
	if ice > 0:
		enemy_ice_label.text = "ICE: " + str(ice)
	else:
		enemy_ice_label.text = ""

func update_enemy_crash(crash_stacks: int):
	if enemy_crash_label == null:
		return
	if crash_stacks > 0:
		enemy_crash_label.text = "崩溃: ×" + str(crash_stacks) + " (+" + str(crash_stacks * 3) + "伤)"
	else:
		enemy_crash_label.text = ""

func update_enemy_shield(shield: int):
	if shield > 0:
		enemy_shield_label.text = "护盾: " + str(shield)
	else:
		enemy_shield_label.text = ""

func show_message(text: String):
	message_label.text = text
	message_label.modulate.a = 1.0
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(1.8)
	_msg_tween.tween_property(message_label, "modulate:a", 0.6, 0.3)

func swap_enemy_portrait(new_texture: Texture2D):
	if not enemy_portrait:
		return
	var tween = create_tween()
	tween.tween_property(enemy_portrait, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		enemy_portrait.texture = new_texture
	)
	tween.tween_property(enemy_portrait, "modulate:a", 1.0, 0.3)

func _add_framed_portrait(pos: Vector2, size: Vector2, tex: Texture2D, glow_color: Color, is_player: bool = false):
	var w = size.x; var h = size.y

	# Container groups all portrait elements for gentle idle animation
	var container = Control.new()
	container.position = pos
	container.size = size + Vector2(20, 20)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	# Dark vignette backing
	var vignette = Panel.new()
	vignette.position = Vector2(-10, -10)
	vignette.size = size + Vector2(20, 20)
	var vig_style = StyleBoxFlat.new()
	vig_style.bg_color = Color(0, 0, 0, 0.55)
	vig_style.corner_radius_top_left = 2; vig_style.corner_radius_top_right = 2
	vig_style.corner_radius_bottom_left = 2; vig_style.corner_radius_bottom_right = 2
	vig_style.shadow_size = 24
	vig_style.shadow_color = Color(glow_color, 0.35)
	vignette.add_theme_stylebox_override("panel", vig_style)
	container.add_child(vignette)

	# Neon glow border
	var border = Panel.new()
	border.position = Vector2(-4, -4)
	border.size = size + Vector2(8, 8)
	var bord_style = StyleBoxFlat.new()
	bord_style.bg_color = Color(glow_color, 0.03)
	bord_style.border_color = glow_color
	bord_style.border_width_left = 2; bord_style.border_width_right = 2
	bord_style.border_width_top = 2; bord_style.border_width_bottom = 2
	bord_style.corner_radius_top_left = 2; bord_style.corner_radius_top_right = 2
	bord_style.corner_radius_bottom_left = 2; bord_style.corner_radius_bottom_right = 2
	bord_style.shadow_size = 10
	bord_style.shadow_color = Color(glow_color, 0.5)
	border.add_theme_stylebox_override("panel", bord_style)
	container.add_child(border)

	# Sci-fi corner brackets
	var corner_rects: Array[ColorRect] = []
	var bw = 16; var bt = 3
	var corners = [
		[Vector2(-2, -2), Vector2(bw, bt), Vector2(bt, bw)],
		[Vector2(w + 2 - bw, -2), Vector2(bw, bt), Vector2.ZERO],
		[Vector2(-2, h + 2 - bw), Vector2(bt, bw), Vector2.ZERO],
		[Vector2(w + 2 - bw, h + 2 - bt), Vector2(bw, bt), Vector2.ZERO],
	]
	for c in corners:
		var hb = ColorRect.new()
		hb.position = c[0]; hb.size = c[1]; hb.color = glow_color
		container.add_child(hb)
		corner_rects.append(hb)
		if c[2] != Vector2.ZERO:
			var vb = ColorRect.new()
			vb.position = c[0]; vb.size = c[2]; vb.color = glow_color
			container.add_child(vb)
			corner_rects.append(vb)
		else:
			var vb = ColorRect.new()
			vb.position = Vector2(c[0].x + bw - bt, c[0].y - bw + bt); vb.size = Vector2(bt, bw); vb.color = glow_color
			container.add_child(vb)
			corner_rects.append(vb)

	# Portrait texture
	var portrait = TextureRect.new()
	portrait.texture = tex
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size = size
	container.add_child(portrait)

	# Idle animation: gentle float + sway + breathing (3 independent Tween loops)
	var tween_x = create_tween().set_loops()
	tween_x.tween_property(container, "position:x", pos.x - 3, 1.0).set_ease(Tween.EASE_IN_OUT)
	tween_x.tween_property(container, "position:x", pos.x + 3, 2.0).set_ease(Tween.EASE_IN_OUT)
	tween_x.tween_property(container, "position:x", pos.x, 1.0).set_ease(Tween.EASE_IN_OUT)

	var tween_y = create_tween().set_loops()
	tween_y.tween_property(container, "position:y", pos.y - 4, 1.5).set_ease(Tween.EASE_IN_OUT)
	tween_y.tween_property(container, "position:y", pos.y + 3, 1.5).set_ease(Tween.EASE_IN_OUT)
	tween_y.tween_property(container, "position:y", pos.y, 1.0).set_ease(Tween.EASE_IN_OUT)

	var tween_scale = create_tween().set_loops()
	tween_scale.tween_property(container, "scale", Vector2(1.025, 1.025), 2.0).set_ease(Tween.EASE_IN_OUT)
	tween_scale.tween_property(container, "scale", Vector2(1.0, 1.0), 2.0).set_ease(Tween.EASE_IN_OUT)

	var fx = PortraitFX.new()
	fx.setup(self, container, border, bord_style, corner_rects, portrait, pos, size, glow_color, tween_x, tween_y, tween_scale)
	fx.start()
	if is_player:
		_player_portrait_fx = fx
	else:
		_enemy_portrait_fx = fx

	return portrait

func _add_bar_frame(pos: Vector2, size: Vector2, glow_color: Color):
	var w = size.x; var h = size.y; var pad = 10
	# Dark vignette backing
	var vig = Panel.new()
	vig.position = pos - Vector2(pad, pad * 0.6)
	vig.size = size + Vector2(pad * 2, pad * 1.2)
	var vig_s = StyleBoxFlat.new()
	vig_s.bg_color = Color(0, 0, 0, 0.45)
	vig_s.corner_radius_top_left = 4; vig_s.corner_radius_top_right = 4
	vig_s.corner_radius_bottom_left = 4; vig_s.corner_radius_bottom_right = 4
	vig_s.shadow_size = 18
	vig_s.shadow_color = Color(glow_color, 0.3)
	vig.add_theme_stylebox_override("panel", vig_s)
	add_child(vig)
	# Neon border
	var bord = Panel.new()
	bord.position = pos - Vector2(4, 3)
	bord.size = size + Vector2(8, 6)
	var bord_s = StyleBoxFlat.new()
	bord_s.bg_color = Color(glow_color, 0.02)
	bord_s.border_color = glow_color
	bord_s.border_width_left = 1; bord_s.border_width_right = 1
	bord_s.border_width_top = 1; bord_s.border_width_bottom = 1
	bord_s.corner_radius_top_left = 3; bord_s.corner_radius_top_right = 3
	bord_s.corner_radius_bottom_left = 3; bord_s.corner_radius_bottom_right = 3
	bord_s.shadow_size = 8
	bord_s.shadow_color = Color(glow_color, 0.5)
	bord.add_theme_stylebox_override("panel", bord_s)
	add_child(bord)
	# Corner brackets
	var bw = 12; var bt = 2
	var corners = [
		[pos - Vector2(2, 1), Vector2(bw, bt), true, true],
		[Vector2(pos.x + w + 2 - bw, pos.y - 1), Vector2(bw, bt), true, false],
		[pos - Vector2(2, 0), Vector2(bt, bw), false, true],
		[Vector2(pos.x + w + 2 - bt, pos.y + h - bw), Vector2(bt, bw), false, false],
	]
	for c in corners:
		var cr = ColorRect.new()
		cr.position = c[0]; cr.size = c[1]; cr.color = glow_color
		add_child(cr)

# === Attack & Hit Effect Methods ===

func play_player_attack():
	# Player portrait lunges toward enemy (rightward)
	if _player_portrait_fx:
		_player_portrait_fx.play_attack_lunge(1548.0)

func play_enemy_attack():
	# Enemy portrait lunges toward player (leftward)
	if _enemy_portrait_fx:
		_enemy_portrait_fx.play_attack_lunge(78.0)

func play_player_hit(effect_type: String):
	if not _player_portrait_fx:
		return
	match effect_type:
		"damage":
			_player_portrait_fx.play_hit_shake(1.0)
			_player_portrait_fx.play_hit_flash(Color("#FF3B3B"), 0.2)
			_player_portrait_fx.play_hit_particles(Color("#FF3B3B"), 8)
		"block":
			_player_portrait_fx.play_hit_flash(Color("#3B8CFF"), 0.15)
			_player_portrait_fx.play_hit_particles(Color("#3B8CFF"), 5)
		"barrier":
			_player_portrait_fx.play_hit_flash(Color("#00FFFF"), 0.15)
			_player_portrait_fx.play_hit_particles(Color("#00FFFF"), 5)
		"energy_shield":
			_player_portrait_fx.play_hit_flash(Color("#FFD700"), 0.12)
			_player_portrait_fx.play_hit_particles(Color("#FFD700"), 4)

func play_enemy_hit(effect_type: String):
	if not _enemy_portrait_fx:
		return
	match effect_type:
		"damage":
			_enemy_portrait_fx.play_hit_shake(1.0)
			_enemy_portrait_fx.play_hit_flash(Color("#FF3B3B"), 0.2)
			_enemy_portrait_fx.play_hit_particles(Color("#FF3B3B"), 8)
		"block":
			_enemy_portrait_fx.play_hit_flash(Color("#3B8CFF"), 0.15)
			_enemy_portrait_fx.play_hit_particles(Color("#3B8CFF"), 5)

# === Log Panel ===

func _build_log_panel(char_color: Color = Color("#00F0FF")):
	# Log panel background (bottom-left corner)
	var log_panel = Panel.new()
	log_panel.position = Vector2(10, 580)
	log_panel.size = Vector2(400, 490)
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var log_style = StyleBoxFlat.new()
	log_style.bg_color = Color(0, 0, 0, 0.7)
	log_style.border_color = Color(char_color, 0.6)
	log_style.border_width_left = 2
	log_style.border_width_top = 2
	log_style.border_width_right = 2
	log_style.border_width_bottom = 2
	log_style.corner_radius_top_left = 8
	log_style.corner_radius_top_right = 8
	log_style.corner_radius_bottom_left = 8
	log_style.corner_radius_bottom_right = 8
	log_panel.add_theme_stylebox_override("panel", log_style)
	add_child(log_panel)

	# Log title
	var log_title = Label.new()
	log_title.text = "📋 行动日志"
	log_title.position = Vector2(10, 5)
	log_title.size = Vector2(360, 25)
	log_title.add_theme_font_size_override("font_size", 20)
	log_title.add_theme_color_override("font_color", char_color)
	log_panel.add_child(log_title)

	# Scroll container for logs
	_log_scroll = ScrollContainer.new()
	_log_scroll.position = Vector2(5, 35)
	_log_scroll.size = Vector2(390, 440)
	_log_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_panel.add_child(_log_scroll)

	# Container for log entries
	_log_container = VBoxContainer.new()
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_container.add_theme_constant_override("separation", 2)
	_log_scroll.add_child(_log_container)

	# 回放 ActionLog 中的历史条目（包含游戏开始、地图操作等）
	for entry in ActionLog.get_entries():
		_add_log_entry(entry["text"], entry["color"], entry["time_str"])

func add_log(text: String, color: Color = Color.WHITE):
	"""添加日志条目 — 委托给全局 ActionLog 存储，UI 通过信号自动响应"""
	ActionLog.add_log(text, color)

func _on_action_log_added(text: String, color: Color, time_str: String):
	"""ActionLog 信号回调 — 在 UI 面板中显示新条目"""
	_add_log_entry(text, color, time_str)

func _add_log_entry(text: String, color: Color, time_str: String):
	"""仅负责创建 RichTextLabel 并添加到日志面板（不含存储逻辑）"""
	if not _log_container:
		return

	# 超过上限时移除最旧的条目（立即 free，防止内存堆积）
	while _log_container.get_child_count() >= MAX_LOG_ENTRIES:
		var oldest = _log_container.get_child(0)
		_log_container.remove_child(oldest)
		oldest.free()

	var log_entry = RichTextLabel.new()
	log_entry.bbcode_enabled = true
	log_entry.fit_content = true
	log_entry.scroll_active = false
	log_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_entry.add_theme_font_size_override("normal_font_size", 18)
	log_entry.add_theme_color_override("default_color", color)


	log_entry.text = "[color=#666666][" + time_str + "][/color] " + text

	_log_container.add_child(log_entry)

	# 自动滚动到底部
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom():
	if _log_scroll and is_inside_tree():
		var scrollbar = _log_scroll.get_v_scroll_bar()
		if scrollbar:
			scrollbar.value = scrollbar.max_value

func clear_log():
	"""清空 UI 面板和全局 ActionLog"""
	if _log_container:
		for child in _log_container.get_children():
			_log_container.remove_child(child)
			child.free()
	ActionLog.clear_log()

# === Deck Viewer ===


func show_deck_viewer(deck_cards: Array, ep_mgr = null):
	"""显示卡组查看面板，展示当前完整卡组（含进化等级）"""
	if _deck_overlay:
		_deck_overlay.queue_free()
		_deck_overlay = null

	_deck_overlay = Control.new()
	_deck_overlay.name = "DeckViewer"
	_deck_overlay.position = Vector2.ZERO
	_deck_overlay.size = Vector2(1920, 1080)
	_deck_overlay.z_index = 150
	_deck_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Add to Battle root (Node2D) so z_index competes directly with CardHand's z_index=0.
	# If added to BattleHUD instead, CardHand (a later sibling) will always render on top
	# regardless of z_index, because both BattleHUD and CardHand share z_index=0 at parent level.
	get_parent().add_child(_deck_overlay)

	var dim = ColorRect.new()
	dim.size = Vector2(1920, 1080)
	dim.color = Color(0, 0, 0, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	# Clicking the dark backdrop closes the viewer. gui_input runs at the correct
	# input phase to block events from reaching battle UI below (unlike _input).
	dim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_deck_viewer()
	)
	_deck_overlay.add_child(dim)

	# 3. 主面板：【重要修改】将其添加为 dim 的子节点，或者保持平级但确保其 mouse_filter 正常
	var panel = Panel.new()
	panel.name = "Panel"
	panel.position = Vector2(200, 60)
	panel.size = Vector2(1520, 960)
	# 【重要修复】面板本身要拦截点击，防止点击穿透到暗色背景
	panel.mouse_filter = Control.MOUSE_FILTER_STOP 
	
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color("#0A0E27")
	ps.border_color = Color("#00F0FF")
	ps.border_width_left = 2; ps.border_width_right = 2
	ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.corner_radius_top_left = 16; ps.corner_radius_top_right = 16
	ps.corner_radius_bottom_left = 16; ps.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", ps)
	_deck_overlay.add_child(panel) # 保持平级，但此时通过 filter 隔离

	# Title
	var title = Label.new()
	title.text = "📋 当前卡组"
	title.position = Vector2(50, 15)
	title.size = Vector2(600, 40)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE # 文本忽略鼠标，防止挡住后面的点击
	panel.add_child(title)

	# Card count
	_deck_card_count_label = Label.new()
	_deck_card_count_label.text = "共 %d 张" % deck_cards.size()
	_deck_card_count_label.position = Vector2(660, 18)
	_deck_card_count_label.size = Vector2(200, 35)
	_deck_card_count_label.add_theme_font_size_override("font_size", 20)
	_deck_card_count_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	_deck_card_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_deck_card_count_label)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "✕ 关闭"
	close_btn.position = Vector2(1340, 12)
	close_btn.size = Vector2(140, 40)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color("#FF6B35"))
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color("#1A1A3A")
	cs.border_color = Color("#FF6B35")
	cs.border_width_left = 1; cs.border_width_right = 1
	cs.border_width_top = 1; cs.border_width_bottom = 1
	cs.corner_radius_top_left = 8; cs.corner_radius_top_right = 8
	cs.corner_radius_bottom_left = 8; cs.corner_radius_bottom_right = 8
	close_btn.add_theme_stylebox_override("normal", cs)
	
	# 【重要修复】确保按钮的鼠标模式为 STOP，优先响应
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_close_deck_viewer)
	panel.add_child(close_btn)

	# Separator
	var sep = ColorRect.new()
	sep.position = Vector2(50, 60)
	sep.size = Vector2(1420, 2)
	sep.color = Color("#00F0FF", 0.5)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sep)

	# Scroll container for card grid
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(10, 70)
	scroll.size = Vector2(1500, 880)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP # 允许滚动拦截
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_deck_grid = Control.new()
	_deck_grid.custom_minimum_size = Vector2(1480, 0)
	_deck_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_grid.mouse_filter = Control.MOUSE_FILTER_PASS # 允许卡牌接收事件
	scroll.add_child(_deck_grid)

	_build_deck_grid(deck_cards, ep_mgr)

	# Entrance animation
	_deck_overlay.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(_deck_overlay, "modulate:a", 1.0, 0.15)



func _build_deck_grid(deck_cards: Array, ep_mgr):
	"""Build the card grid inside the deck viewer — uses CardUI at full size (240x330)."""
	if _deck_grid:
		for child in _deck_grid.get_children():
			child.queue_free()

	var cols = 5
	var card_w = 240
	var card_h = 330
	var gap_x = 24
	var gap_y = 40
	var start_x = 30
	var start_y = 10

	# Group cards by family (one entry per family)
	var families_seen = {}
	var families_order = []
	for card_id in deck_cards:
		var def = CardDatabase.get_card_def(card_id)
		if def.is_empty():
			continue
		var family = def.get("evolution_family", card_id)
		if not families_seen.has(family):
			families_seen[family] = card_id
			families_order.append(family)

	var count = 0
	for family in families_order:
		var col = count % cols
		var row = count / cols
		var x = start_x + col * (card_w + gap_x)
		var y = start_y + row * (card_h + gap_y)

		# Determine the evolved card_id based on family's max level
		var base_card_id = families_seen[family]
		var max_level = 1
		if ep_mgr:
			max_level = ep_mgr.family_max_level.get(family, 1)
		else:
			max_level = RunRewardState.family_max_level.get(family, 1)

		var display_card_id = base_card_id
		if max_level >= 3:
			display_card_id = base_card_id + "_l3"
		elif max_level >= 2:
			display_card_id = base_card_id + "_l2"

		var card_def = CardDatabase.get_card_def(display_card_id)
		if card_def.is_empty():
			card_def = CardDatabase.get_card_def(base_card_id)
		if card_def.is_empty():
			continue

		# Create CardUI instance at full size
		var card_ui = CardUIScene.instantiate()
		card_ui.position = Vector2(x, y)
		card_ui.scale = Vector2(1.0, 1.0)
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_deck_grid.add_child(card_ui)
		card_ui.setup_card(card_def.duplicate())

		# EP progress label below card
		var ep = 0
		if ep_mgr:
			ep = ep_mgr.card_ep_by_family.get(family, 0)
		else:
			ep = RunRewardState.card_ep_by_family.get(family, 0)

		var progress_label = Label.new()
		if max_level >= 3:
			progress_label.text = "MAX"
			progress_label.add_theme_color_override("font_color", Color("#FFD700"))
		else:
			var needed = 8 if max_level == 1 else 20
			progress_label.text = "%d/%d EP" % [ep, needed]
			progress_label.add_theme_color_override("font_color", Color("#3BFF8C"))
		progress_label.position = Vector2(x + 10, y + card_h + 2)
		progress_label.add_theme_font_size_override("font_size", 16)
		progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_deck_grid.add_child(progress_label)

		count += 1

	# Update grid minimum size for scrolling
	var total_rows = ceili(float(count) / cols) if count > 0 else 1
	_deck_grid.custom_minimum_size = Vector2(1480, total_rows * (card_h + gap_y))

func _close_deck_viewer():
	if _deck_overlay:
		var tw = create_tween()
		tw.tween_property(_deck_overlay, "modulate:a", 0.0, 0.12)
		tw.tween_callback(func():
			_deck_overlay.queue_free()
			_deck_overlay = null
			_deck_grid = null
			deck_viewer_closed.emit()
		)

func refresh_deck_viewer(deck_cards: Array, ep_mgr = null):
	"""实时更新卡组面板（卡牌进化时调用）"""
	if not _deck_overlay:
		return
	# Update card count
	if _deck_card_count_label:
		_deck_card_count_label.text = "共 %d 张" % deck_cards.size()
	# Rebuild grid
	if _deck_grid:
		for child in _deck_grid.get_children():
			child.queue_free()
	_build_deck_grid(deck_cards, ep_mgr)
