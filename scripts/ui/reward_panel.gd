class_name RewardPanel
extends Control
## Post-battle reward selection panel - shows 3 random rewards, player picks one

signal reward_chosen(reward_type: String, extra_data: Dictionary)

const REWARD_TYPES = ["evolution_module", "energy_core", "tactical_protocol", "overclock_chip", "heal", "max_hp_up", "random_card", "copy_card"]
const CardUIScene = preload("res://scenes/card_ui.tscn")

const REWARD_INFO = {
	"evolution_module": {
		"title": "进化模块",
		"icon": "🧬",
		"description": "选择一张卡牌\n+8 EP 注入进度",
		"description_max": "所有卡牌已满级\n+5 储备池进度",
	},
	"energy_core": {
		"title": "能源核心",
		"icon": "⚡",
		"description": "立即 +5 EP\n储备池进度",
	},
	"tactical_protocol": {
		"title": "战术协议",
		"icon": "🛡️",
		"description": "下场战斗开始时\n+6 屏障 +2 格挡",
	},
	"overclock_chip": {
		"title": "超频芯片",
		"icon": "🔧",
		"description": "下场战斗每回合\n+1 EP（最高6）",
	},
	"heal": {
		"title": "纳米修复",
		"icon": "❤️",
		"description": "立即恢复\n25 点 HP",
	},
	"max_hp_up": {
		"title": "基因强化",
		"icon": "💎",
		"description": "+10 最大HP\n并恢复 10 点 HP",
	},
	"random_card": {
		"title": "随机卡牌",
		"icon": "🃏",
		"description": "从所有卡牌中\n随机获得一张 Lv.1",
	},
	"copy_card": {
		"title": "复制卡牌",
		"icon": "📋",
		"description": "复制当前牌库中\n一张卡牌",
	},
}

var ep_manager: EPManager
var card_selector: Control  # Reference to card selector panel
var _reward_cards: Array = []
var _overlay: Control
var _selected_types: Array = []
var _panel_ref: Panel
var _reroll_used: bool = false
var _reroll_btn: Button

const REWARD_CARD_WIDTH = 240
const REWARD_CARD_HEIGHT = 320
const REWARD_CARD_GAP = 40
const REWARD_CARD_Y = 120

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200

func setup(ep_mgr: EPManager):
	ep_manager = ep_mgr

func show_panel():
	# Pick 3 random different rewards
	var available = REWARD_TYPES.duplicate()
	available.shuffle()
	var selected = available.slice(0, 3)

	# Create overlay
	_overlay = Control.new()
	_overlay.layout_mode = 1
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.z_index = 200
	add_child(_overlay)

	var dim_bg = ColorRect.new()
	dim_bg.size = Vector2(1920, 1080)
	dim_bg.color = Color(0, 0, 0, 0.8)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim_bg)

	# Panel
	var panel = Panel.new()
	panel.position = Vector2(410, 240)
	panel.size = Vector2(1100, 600)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#0A0E27")
	panel_style.border_color = Color("#FFD700")
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	_overlay.add_child(panel)
	_panel_ref = panel

	# Title
	var title = Label.new()
	title.text = "战斗胜利 — 选择一项增强"
	title.position = Vector2(50, 30)
	title.size = Vector2(1000, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	panel.add_child(title)

	# Separator
	var sep = ColorRect.new()
	sep.position = Vector2(150, 90)
	sep.size = Vector2(800, 2)
	sep.color = Color("#FFD700")
	panel.add_child(sep)

	# Info button (top-left corner)
	var info_btn = Button.new()
	info_btn.text = "?"
	info_btn.position = Vector2(20, 20)
	info_btn.size = Vector2(40, 40)
	info_btn.add_theme_font_size_override("font_size", 22)
	info_btn.add_theme_color_override("font_color", Color("#FFD700"))
	var info_btn_style = StyleBoxFlat.new()
	info_btn_style.bg_color = Color("#FFD700", 0.1)
	info_btn_style.border_color = Color("#FFD700", 0.6)
	info_btn_style.border_width_left = 1; info_btn_style.border_width_right = 1
	info_btn_style.border_width_top = 1; info_btn_style.border_width_bottom = 1
	info_btn_style.corner_radius_top_left = 20; info_btn_style.corner_radius_top_right = 20
	info_btn_style.corner_radius_bottom_left = 20; info_btn_style.corner_radius_bottom_right = 20
	info_btn.add_theme_stylebox_override("normal", info_btn_style)
	info_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	info_btn.pressed.connect(func(): _show_reward_info())
	info_btn.mouse_entered.connect(func():
		var t = create_tween()
		t.tween_property(info_btn, "scale", Vector2(1.2, 1.2), 0.1)
	)
	info_btn.mouse_exited.connect(func():
		var t = create_tween()
		t.tween_property(info_btn, "scale", Vector2(1.0, 1.0), 0.1)
	)
	panel.add_child(info_btn)

	# Create 3 reward cards
	_selected_types = selected
	_reroll_used = false
	_build_reward_cards(panel)
	_add_reroll_button(panel)

	# Entrance animation
	_overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.2)

func _build_reward_cards(panel: Panel):
	"""Create the 3 reward card UI elements from _selected_types."""
	var total_width = 3 * REWARD_CARD_WIDTH + 2 * REWARD_CARD_GAP
	var start_x = (1100 - total_width) / 2

	for i in range(3):
		var reward_type = _selected_types[i]
		var card = _create_reward_card(reward_type, Vector2(start_x + i * (REWARD_CARD_WIDTH + REWARD_CARD_GAP), REWARD_CARD_Y), Vector2(REWARD_CARD_WIDTH, REWARD_CARD_HEIGHT))
		panel.add_child(card)
		_reward_cards.append(card)

	# Entrance animation for new cards
	for card in _reward_cards:
		card.modulate.a = 0.0
		var t = create_tween().set_parallel(true)
		t.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(0.05 * _reward_cards.find(card))


func _add_reroll_button(panel: Panel):
	"""Add the one-time re-roll button below the reward cards."""
	_reroll_btn = Button.new()
	_reroll_btn.text = "🔄 重新选择一次"
	_reroll_btn.position = Vector2(370, 460)
	_reroll_btn.size = Vector2(360, 50)
	_reroll_btn.add_theme_font_size_override("font_size", 20)
	_reroll_btn.add_theme_color_override("font_color", Color("#FFD700"))

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#1A1A3A")
	btn_style.border_color = Color("#FFD700")
	btn_style.border_width_left = 1; btn_style.border_width_right = 1
	btn_style.border_width_top = 1; btn_style.border_width_bottom = 1
	btn_style.corner_radius_top_left = 8; btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8; btn_style.corner_radius_bottom_right = 8
	_reroll_btn.add_theme_stylebox_override("normal", btn_style)

	var hover_s = btn_style.duplicate()
	hover_s.border_color = Color("#00F0FF")
	hover_s.shadow_size = 8
	hover_s.shadow_color = Color("#00F0FF")
	_reroll_btn.add_theme_stylebox_override("hover", hover_s)

	_reroll_btn.mouse_entered.connect(func():
		var t = create_tween()
		t.tween_property(_reroll_btn, "scale", Vector2(1.05, 1.05), 0.08)
	)
	_reroll_btn.mouse_exited.connect(func():
		var t = create_tween()
		t.tween_property(_reroll_btn, "scale", Vector2(1.0, 1.0), 0.08)
	)

	_reroll_btn.pressed.connect(_reroll_rewards)
	panel.add_child(_reroll_btn)


func _reroll_rewards():
	"""Replace current 3 reward cards with 3 new random ones (one-time use)."""
	if _reroll_used:
		return
	_reroll_used = true
	_reroll_btn.disabled = true
	_reroll_btn.text = "✓ 已重新选择"

	# Pick 3 new rewards
	var available = REWARD_TYPES.duplicate()
	available.shuffle()
	_selected_types = available.slice(0, 3)

	# Remove old cards
	for card in _reward_cards.duplicate():
		card.queue_free()
	_reward_cards.clear()

	# Build new cards
	_build_reward_cards(_panel_ref)

func _create_reward_card(reward_type: String, pos: Vector2, size: Vector2) -> Control:
	var info = REWARD_INFO[reward_type]
	var all_max = _all_cards_at_max()

	var card = Panel.new()
	card.position = pos
	card.size = size
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color("#1A1A3A")
	card_style.border_color = Color("#FFD700")
	card_style.border_width_left = 1
	card_style.border_width_right = 1
	card_style.border_width_top = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card.add_theme_stylebox_override("panel", card_style)

	# Icon
	var icon = Label.new()
	icon.text = info.get("icon", "?")
	icon.position = Vector2(0, 40)
	icon.size = Vector2(size.x, 60)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 48)
	card.add_child(icon)

	# Title
	var card_title = Label.new()
	card_title.text = info.get("title", "???")
	card_title.position = Vector2(0, 120)
	card_title.size = Vector2(size.x, 36)
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.add_theme_font_size_override("font_size", 24)
	card_title.add_theme_color_override("font_color", Color("#FFD700"))
	card.add_child(card_title)

	# Permanent/Temporary tag
	var is_perm = _is_reward_permanent(reward_type)
	var tag_text = "[永久]" if is_perm else "[临时]"
	var tag_color = Color("#3BFF8C") if is_perm else Color("#FF6B35")
	var tag = Label.new()
	tag.text = tag_text
	tag.position = Vector2(0, 155)
	tag.size = Vector2(size.x, 24)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", tag_color)
	card.add_child(tag)

	# Description
	var desc_text = info.get("description", "")
	if reward_type == "evolution_module" and all_max:
		desc_text = info.get("description_max", desc_text)

	var desc = Label.new()
	desc.text = desc_text
	desc.position = Vector2(10, 185)
	desc.size = Vector2(size.x - 20, 85)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color("#CCCCCC"))
	card.add_child(desc)

	# Hover effects
	card.mouse_entered.connect(func():
		var hover_style = card_style.duplicate()
		hover_style.border_color = Color("#00F0FF")
		hover_style.border_width_left = 2
		hover_style.border_width_right = 2
		hover_style.border_width_top = 2
		hover_style.border_width_bottom = 2
		hover_style.shadow_size = 16
		hover_style.shadow_color = Color("#00F0FF")
		card.add_theme_stylebox_override("panel", hover_style)
		var t = create_tween()
		t.tween_property(card, "scale", Vector2(1.05, 1.05), 0.1)
	)

	card.mouse_exited.connect(func():
		card.add_theme_stylebox_override("panel", card_style)
		var t = create_tween()
		t.tween_property(card, "scale", Vector2(1.0, 1.0), 0.1)
	)

	# Click handler
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_reward_selected(reward_type)
	)

	return card

func _all_cards_at_max() -> bool:
	if not ep_manager:
		return false
	for key in CardDatabase.CARD_DATABASE:
		var def = CardDatabase.CARD_DATABASE[key]
		if def.get("level", 1) < 3 and def.get("ep_to_evolve", -1) > 0:
			return false
	return true

func _is_reward_permanent(reward_type: String) -> bool:
	return reward_type in ["evolution_module", "energy_core", "max_hp_up"]

func _on_reward_selected(reward_type: String):
	# Selection effect
	var flash = ColorRect.new()
	flash.size = Vector2(1920, 1080)
	flash.color = Color.WHITE
	flash.modulate.a = 0.0
	flash.z_index = 250
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.3, 0.05)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	flash_tween.tween_callback(flash.queue_free)

	# Close panel
	var close_tween = create_tween()
	close_tween.tween_property(_overlay, "modulate:a", 0.0, 0.2)
	close_tween.tween_callback(func():
		_overlay.queue_free()
		_reward_cards.clear()

		# Handle reward logic
		match reward_type:
			"evolution_module":
				_handle_evolution_module()
			"energy_core":
				_handle_energy_core()
			"tactical_protocol":
				_handle_tactical_protocol()
			"overclock_chip":
				_handle_overclock_chip()
			"heal":
				_handle_heal()
			"max_hp_up":
				_handle_max_hp_up()
			"random_card":
				_handle_random_card()
			"copy_card":
				_handle_copy_card()
	)

func _handle_evolution_module():
	# Show card selector
	if _all_cards_at_max():
		# All cards maxed, give reserve progress instead
		ep_manager.add_reserve_progress(5)
		reward_chosen.emit("evolution_module", {"mode": "reserve_fallback", "amount": 5})
		return

	# Create card selector
	var selector = Control.new()
	selector.layout_mode = 1
	selector.anchor_right = 1.0
	selector.anchor_bottom = 1.0
	selector.z_index = 210
	add_child(selector)

	var dim = ColorRect.new()
	dim.size = Vector2(1920, 1080)
	dim.color = Color(0, 0, 0, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	selector.add_child(dim)

	var panel = Panel.new()
	panel.position = Vector2(310, 140)
	panel.size = Vector2(1300, 800)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color("#0A0E27")
	ps.border_color = Color("#00F0FF")
	ps.border_width_left = 2; ps.border_width_right = 2
	ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.corner_radius_top_left = 16; ps.corner_radius_top_right = 16
	ps.corner_radius_bottom_left = 16; ps.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", ps)
	selector.add_child(panel)

	var title = Label.new()
	title.text = "选择一张卡牌 +8 EP 进度"
	title.position = Vector2(50, 20)
	title.size = Vector2(1200, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	panel.add_child(title)

	# Build interactive card grid
	var families = _get_all_families()
	_build_card_selector_grid(panel, families, selector)

func _get_all_families() -> Array:
	# Get all unique evolution families from starting deck + card database
	# Returns current evolution-level card_def and progress for each family
	var seen = {}
	var result = []
	var deck = CardDatabase.get_starting_deck_for_character(RunRewardState.selected_character)
	for card_id in deck:
		var def = CardDatabase.get_card_def(card_id)
		var family = def.get("evolution_family", "")
		if family != "" and not seen.has(family):
			seen[family] = true
			var chain = def.get("evolution_chain", [])
			var accumulated = ep_manager.card_ep_by_family.get(family, 0)

			# Determine current evolution level based on accumulated EP
			# Thresholds: 8 for Lv1→Lv2, 20 for Lv2→Lv3
			var current_idx = 0
			if chain.size() >= 2 and accumulated >= 8:
				current_idx = 1
			if chain.size() >= 3 and accumulated >= 20:
				current_idx = 2

			var current_card_id = chain[current_idx] if current_idx < chain.size() else card_id
			var current_def = CardDatabase.get_card_def(current_card_id)
			if current_def.is_empty():
				current_def = def

			result.append({
				"family": family,
				"name": current_def.get("name", "???"),
				"level": current_def.get("level", 1),
				"accumulated": accumulated,
				"needed": current_def.get("ep_to_evolve", -1),
				"card_def": current_def,
			})
	return result

func _build_card_selector_grid(panel: Panel, families: Array, selector: Control):
	# Build a grid of interactive CardUI nodes for EP injection selection
	var card_scale = 0.7
	var card_visual_w = 240 * card_scale
	var card_visual_h = 330 * card_scale
	var cols = 5
	var gap_x = 18
	var gap_y = 20
	var total_w = cols * card_visual_w + (cols - 1) * gap_x
	var start_x = (panel.size.x - total_w) / 2
	var start_y = 75

	for i in range(families.size()):
		var fd = families[i]
		var col = i % cols
		var row = floori(i / cols)
		var x = start_x + col * (card_visual_w + gap_x)
		var y = start_y + row * (card_visual_h + gap_y)

		var card = CardUI.new()
		card.position = Vector2(x, y)
		card.scale = Vector2(card_scale, card_scale)
		card.z_index = 0

		# Set up card with correct evolution-level definition
		var def = fd.get("card_def", {})
		card.setup_card(def)

		# Update EP progress display
		var accumulated = fd.accumulated
		var needed = fd.needed
		var is_max = fd.level >= 3 or needed <= 0

		if not is_max:
			var progress = 0.0
			if fd.level >= 2:
				# Lv2 card: calculate progress from 8 toward needed (20)
				var base = 8
				var range = needed - base
				progress = float(accumulated - base) / float(range) if range > 0 else 0.0
			else:
				# Lv1 card: progress from 0 toward needed (8)
				progress = float(accumulated) / float(needed) if needed > 0 else 0.0
			card.update_evolution_progress(clamp(progress, 0.0, 1.0))
			card.update_ep_text(str(accumulated) + "/" + str(needed))
		else:
			# MAX level card — hide progress bar
			card.evo_progress.visible = false
			card.evo_text_label.visible = false

		# Disconnect default hover handlers (prevents tooltip and unwanted transforms)
		if card.mouse_entered.is_connected(Callable(card, "_on_mouse_entered")):
			card.mouse_entered.disconnect(Callable(card, "_on_mouse_entered"))
		if card.mouse_exited.is_connected(Callable(card, "_on_mouse_exited")):
			card.mouse_exited.disconnect(Callable(card, "_on_mouse_exited"))

		# Custom hover: bring to front with scale-up
		card.mouse_entered.connect(_on_selector_card_entered.bind(card, card_scale))
		card.mouse_exited.connect(_on_selector_card_exited.bind(card, card_scale))
		card.card_clicked.connect(_on_selector_card_chosen.bind(fd, selector))

		panel.add_child(card)


func _on_selector_card_entered(card: CardUI, card_scale: float):
	card.z_index = 100
	var tw = create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2(card_scale, card_scale) * 1.12, 0.1).set_ease(Tween.EASE_OUT)


func _on_selector_card_exited(card: CardUI, card_scale: float):
	card.z_index = 0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2(card_scale, card_scale), 0.1).set_ease(Tween.EASE_IN)


func _on_selector_card_chosen(_c: CardUI, fd: Dictionary, selector: Control):
	selector.queue_free()
	var is_max = fd.level >= 3 or fd.needed <= 0
	if is_max:
		ep_manager.add_reserve_progress(5)
		reward_chosen.emit("evolution_module", {"mode": "reserve_fallback", "amount": 5})
	else:
		# EP injection and evolution handled by BattleManager via reward_chosen signal
		reward_chosen.emit("evolution_module", {"mode": "family", "family": fd.family, "amount": 8})

func _handle_energy_core():
	ep_manager.add_reserve_progress(5)
	reward_chosen.emit("energy_core", {"amount": 5})

func _handle_tactical_protocol():
	RunRewardState.next_battle_temp_bonus.barrier += 6
	RunRewardState.next_battle_temp_bonus.block += 2
	reward_chosen.emit("tactical_protocol", {"barrier": 6, "block": 2})

func _handle_overclock_chip():
	RunRewardState.next_battle_temp_bonus.ep_per_turn_add += 1
	reward_chosen.emit("overclock_chip", {"ep_add": 1})

func _handle_heal():
	# Heal 25 HP immediately (applied via BattleManager signal)
	reward_chosen.emit("heal", {"amount": 25})

func _handle_max_hp_up():
	# Permanent max HP increase
	RunRewardState.permanent_bonus.max_hp_bonus += 10
	reward_chosen.emit("max_hp_up", {"amount": 10})

func _handle_random_card():
	# v1.6: Give player a random Lv.1 card from the full card pool
	var all_base_cards = [
		"c01_basic_probe", "c02_basic_probe_b", "c03_basic_probe_c",
		"c04_basic_firewall", "c05_basic_firewall_b", "c06_basic_firewall_c",
		"c07_data_overload", "c08_light_scan",
		"c09_deep_infiltrate", "c10_shield_reconstruct",
		"c11_heavy_strike", "c12_quick_scan", "c13_ep_amplify",
		"c14_overload_pulse", "c15_fortify", "c16_system_draw",
		"c17_quick_inject", "c18_mirror_shield",
		"c19_core_overclock", "c20_barrier_matrix"
	]
	var random_card = all_base_cards[randi() % all_base_cards.size()]
	if RunRewardState.run_active:
		RunRewardState.add_card_to_deck(random_card)
	reward_chosen.emit("random_card", {"card_id": random_card})

func _handle_copy_card():
	# v1.6: Show card selector to copy a card from current deck
	if not RunRewardState.run_active:
		reward_chosen.emit("copy_card", {})
		return
	# Show a card selector panel (reuse the evolution module pattern)
	_show_copy_card_selector()

func _show_copy_card_selector():
	"""Show a card selector for copying a card from the player's deck."""
	var selector_overlay = Control.new()
	selector_overlay.name = "CopyCardSelector"
	selector_overlay.layout_mode = 1
	selector_overlay.anchor_right = 1.0
	selector_overlay.anchor_bottom = 1.0
	var bg = ColorRect.new()
	bg.layout_mode = 1
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0, 0, 0, 0.85)
	selector_overlay.add_child(bg)
	add_child(selector_overlay)

	var panel = Panel.new()
	panel.size = Vector2(1200, 700)
	panel.position = Vector2(360, 190)
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color("#0A0E27")
	p_style.border_color = Color("#00F0FF")
	p_style.border_width_left = 2
	p_style.border_width_right = 2
	p_style.border_width_top = 2
	p_style.border_width_bottom = 2
	p_style.corner_radius_top_left = 16
	p_style.corner_radius_top_right = 16
	p_style.corner_radius_bottom_left = 16
	p_style.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", p_style)
	selector_overlay.add_child(panel)

	var title = Label.new()
	title.text = "选择一张卡牌复制"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(50, 20)
	title.size = Vector2(1100, 40)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	panel.add_child(title)

	# Scrollable grid container for cards
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(20, 70)
	scroll.size = Vector2(1160, 610)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var grid_container = Control.new()
	grid_container.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(grid_container)

	# Build card grid from unique families in deck
	var families = []
	for card_id in RunRewardState.player_deck:
		var fam = RunRewardState._get_family_for_card(card_id)
		if not families.has(fam):
			families.append(fam)

	var cols = 5
	var card_w = 168
	var card_h = 231
	var gap_x = 18
	var gap_y = 50
	var start_x = 40
	var start_y = 10

	var count = 0
	for family in families:
		var col = count % cols
		var row = count / cols
		var x = start_x + col * (card_w + gap_x)
		var y = start_y + row * (card_h + gap_y)

		# Find base card_id for this family
		var base_id = ""
		for cid in RunRewardState.player_deck:
			if RunRewardState._get_family_for_card(cid) == family:
				base_id = cid
				break

		if base_id == "":
			continue

		# Get card definition
		var card_def = CardDatabase.get_card_def(base_id)
		if card_def.is_empty():
			continue

		var card_ui = CardUIScene.instantiate()
		card_ui.position = Vector2(x, y)
		card_ui.scale = Vector2(0.7, 0.7)
		grid_container.add_child(card_ui)
		card_ui.setup_card(card_def.duplicate())

		# Clickable overlay
		var click_btn = Button.new()
		click_btn.flat = true
		click_btn.position = Vector2(x, y)
		click_btn.size = Vector2(card_w, card_h)
		click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		click_btn.pressed.connect(func():
			RunRewardState.add_card_to_deck(base_id)
			reward_chosen.emit("copy_card", {"card_id": base_id})
			selector_overlay.queue_free()
		)
		grid_container.add_child(click_btn)

		count += 1

	# Set grid height so ScrollContainer knows the content size
	var total_rows = ceili(float(count) / cols) if count > 0 else 1
	grid_container.custom_minimum_size = Vector2(1120, total_rows * (card_h + gap_y))

func _show_reward_info():
	# Create info overlay
	var info_overlay = Control.new()
	info_overlay.layout_mode = 1
	info_overlay.anchor_right = 1.0
	info_overlay.anchor_bottom = 1.0
	info_overlay.z_index = 250
	_overlay.add_child(info_overlay)

	var dim = ColorRect.new()
	dim.size = Vector2(1920, 1080)
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	info_overlay.add_child(dim)

	var panel = Panel.new()
	panel.position = Vector2(360, 140)
	panel.size = Vector2(1200, 800)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color("#0A0E27")
	ps.border_color = Color("#FFD700")
	ps.border_width_left = 2; ps.border_width_right = 2
	ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.corner_radius_top_left = 16; ps.corner_radius_top_right = 16
	ps.corner_radius_bottom_left = 16; ps.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", ps)
	info_overlay.add_child(panel)

	var title = Label.new()
	title.text = "全部奖励一览"
	title.position = Vector2(50, 20)
	title.size = Vector2(1100, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	panel.add_child(title)

	var sep = ColorRect.new()
	sep.position = Vector2(100, 80)
	sep.size = Vector2(1000, 2)
	sep.color = Color("#FFD700")
	panel.add_child(sep)

	# List all rewards
	var y_offset = 100
	for reward_type in REWARD_TYPES:
		var info = REWARD_INFO[reward_type]
		var icon_lbl = Label.new()
		icon_lbl.text = str(info.get("icon", "?"))
		icon_lbl.position = Vector2(40, y_offset)
		icon_lbl.size = Vector2(60, 40)
		icon_lbl.add_theme_font_size_override("font_size", 32)
		panel.add_child(icon_lbl)

		var name_lbl = Label.new()
		name_lbl.text = str(info.get("title", "???"))
		name_lbl.position = Vector2(110, y_offset)
		name_lbl.size = Vector2(200, 40)
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", Color("#FFD700"))
		panel.add_child(name_lbl)

		# Build full description
		var desc_text = str(info.get("description", ""))
		if reward_type == "evolution_module":
			desc_text += "\n" + str(info.get("description_max", ""))

		var type_tag = "永久" if reward_type in ["evolution_module", "energy_core", "max_hp_up"] else "临时"
		var tag_color = Color("#3BFF8C") if type_tag == "永久" else Color("#FF6B35")

		var tag_lbl = Label.new()
		tag_lbl.text = "[" + type_tag + "]"
		tag_lbl.position = Vector2(320, y_offset)
		tag_lbl.size = Vector2(80, 40)
		tag_lbl.add_theme_font_size_override("font_size", 16)
		tag_lbl.add_theme_color_override("font_color", tag_color)
		panel.add_child(tag_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = desc_text.replace("\n", "  ")
		desc_lbl.position = Vector2(410, y_offset)
		desc_lbl.size = Vector2(750, 40)
		desc_lbl.add_theme_font_size_override("font_size", 17)
		desc_lbl.add_theme_color_override("font_color", Color("#CCCCCC"))
		desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(desc_lbl)

		y_offset += 60

	# Close button
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(480, 730)
	close_btn.size = Vector2(240, 48)
	close_btn.add_theme_font_size_override("font_size", 22)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color("#3B3B6B")
	close_style.border_color = Color("#FFD700")
	close_style.border_width_left = 1; close_style.border_width_right = 1
	close_style.border_width_top = 1; close_style.border_width_bottom = 1
	close_style.corner_radius_top_left = 10; close_style.corner_radius_top_right = 10
	close_style.corner_radius_bottom_left = 10; close_style.corner_radius_bottom_right = 10
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(func():
		info_overlay.queue_free()
	)
	panel.add_child(close_btn)

	# Entrance animation
	info_overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(info_overlay, "modulate:a", 1.0, 0.15)


func show_core_breakthrough():
	"""Show core breakthrough protocol selection panel after Chapter 1 boss (v1.5)."""
	_overlay = Control.new()
	_overlay.layout_mode = 1
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.z_index = 200
	add_child(_overlay)

	var dim_bg = ColorRect.new()
	dim_bg.size = Vector2(1920, 1080)
	dim_bg.color = Color(0, 0, 0, 0.85)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim_bg)

	var panel = Panel.new()
	panel.position = Vector2(360, 140)
	panel.size = Vector2(1200, 800)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#0A0E27")
	panel_style.border_color = Color("#B03BFF")
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.shadow_size = 24
	panel_style.shadow_color = Color("#B03BFF")
	_overlay.add_child(panel)

	var title = Label.new()
	title.text = "\u2726 \u6838\u5fc3\u7a81\u7834 \u2014 \u9009\u62e9\u4e00\u9879\u7a81\u7834\u534f\u8bae \u2726"
	title.position = Vector2(50, 30)
	title.size = Vector2(1100, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#B03BFF"))
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "\u9009\u62e9\u4e00\u9879\u6c38\u4e45\u88ab\u52a8\u534f\u8bae\uff0c\u6539\u53d8\u540e\u7eed\u6218\u6597\u89c4\u5219"
	subtitle.position = Vector2(50, 75)
	subtitle.size = Vector2(1100, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("#888888"))
	panel.add_child(subtitle)

	var sep = ColorRect.new()
	sep.position = Vector2(100, 110)
	sep.size = Vector2(1000, 2)
	sep.color = Color("#B03BFF")
	panel.add_child(sep)

	# Protocol definitions (using unicode escapes for Chinese)
	var protocols = [
		{"name": "\u8d85\u9650\u8dc3\u8fc1", "icon": "\U0001f9e0", "color": Color("#B03BFF"), "desc": "\u624b\u724c\u4e0a\u9650\u6c38\u4e45\u63d0\u5347\u81f3 6 \u5f20", "cost": "\u6bcf\u573a\u6218\u6597\u7b2c1\u56de\u5408\u5931\u53bb 5 HP", "value": "\u6781\u5927\u63d0\u5347\u6bcf\u56de\u5408\u7684\u5bb9\u9519\u7387\u4e0e\u7ec4\u5408\u6280\u6982\u7387"},
		{"name": "\u6d8c\u52a8\u6838\u5fc3", "icon": "\u26a1", "color": Color("#FFD700"), "desc": "EP\u50a8\u5907\u6c60\u4e0a\u9650\u6269\u5c55\u81f3 20", "cost": "\u62a4\u76fe\u89e6\u53d1\u8282\u70b9\u53d8\u66f4\u4e3a 5/10/15/20", "value": "\u5f3a\u5316\u957f\u671f\u8fd0\u8425\u4e0a\u9650\uff0c\u53e0\u51fa\u66f4\u9ad8\u5e38\u9a7b\u5168\u51cf\u514d\u62a4\u76fe"},
		{"name": "\u57fa\u56e0\u98de\u5347", "icon": "\U0001f9ec", "color": Color("#00F0FF"), "desc": "\u6240\u6709Lv.1\u5361\u724c\u76f4\u63a5\u63d0\u5347\u81f3 Lv.2", "cost": "\u65e0\u526f\u4f5c\u7528", "value": "\u5373\u65f6\u6218\u529b\u62c9\u5347\uff0c\u9002\u5408\u524d\u671f\u672a\u79ef\u7d2f\u8db3\u591f\u8fdb\u5316\u7684\u73a9\u5bb6"},
		{"name": "\u5c4f\u969c\u8f6c\u5316", "icon": "\U0001f6e1", "color": Color("#3B8CFF"), "desc": "\u56de\u5408\u7ed3\u675f\u65f6\uff0c\u5269\u4f59\u5c4f\u969c\u768450%\u8f6c\u5316\u4e3a\u6c38\u4e45\u6700\u5927HP", "cost": "\u9700\u8981\u4e3b\u52a8\u6ce8\u5165EP\u79ef\u7d2f\u5c4f\u969c", "value": "\u9f13\u52b1\u79ef\u6781\u6ce8\u5165EP\uff0c\u5373\u4f7f\u4e0d\u6218\u6597\u4e5f\u80fd\u8f6c\u5316\u4e3a\u957f\u671f\u6536\u76ca"},
		{"name": "\u8d85\u9891\u8fc7\u8f7d", "icon": "\U0001f525", "color": Color("#FF3B3B"), "desc": "\u6bcf\u56de\u5408\u53ef\u5206\u914dEP\u6c38\u4e45 +1", "cost": "\u53d7\u5230\u7684\u6240\u6709\u4f24\u5bb3\u9ed8\u8ba4 +1", "value": "\u9ad8\u98ce\u9669\u9ad8\u56de\u62a5\uff0c\u66f4\u5f3a\u7684\u5355\u56de\u5408\u64cd\u4f5c\u7a7a\u95f4"},
	]

	protocols.shuffle()
	var selected = protocols.slice(0, 3)

	var card_w = 320
	var card_h = 420
	var gap = 40
	var total_w = 3 * card_w + 2 * gap
	var start_x = (1200 - total_w) / 2

	for i in range(3):
		var proto = selected[i]
		var card = Panel.new()
		card.position = Vector2(start_x + i * (card_w + gap), 140)
		card.size = Vector2(card_w, card_h)
		card.mouse_filter = Control.MOUSE_FILTER_STOP

		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color("#0D1230")
		card_style.border_color = proto.color
		card_style.border_width_left = 2
		card_style.border_width_right = 2
		card_style.border_width_top = 2
		card_style.border_width_bottom = 2
		card_style.corner_radius_top_left = 12
		card_style.corner_radius_top_right = 12
		card_style.corner_radius_bottom_left = 12
		card_style.corner_radius_bottom_right = 12
		card_style.shadow_size = 12
		card_style.shadow_color = proto.color
		card.add_theme_stylebox_override("panel", card_style)
		panel.add_child(card)

		# Icon
		var icon_lbl = Label.new()
		icon_lbl.text = proto.icon
		icon_lbl.position = Vector2(0, 20)
		icon_lbl.size = Vector2(card_w, 60)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 48)
		card.add_child(icon_lbl)

		# Name
		var name_lbl = Label.new()
		name_lbl.text = proto.name
		name_lbl.position = Vector2(0, 90)
		name_lbl.size = Vector2(card_w, 36)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", proto.color)
		card.add_child(name_lbl)

		# Description
		var desc_label = Label.new()
		desc_label.text = proto.desc + "\n" + proto.cost
		desc_label.position = Vector2(15, 140)
		desc_label.size = Vector2(card_w - 30, 120)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.add_theme_font_size_override("font_size", 16)
		desc_label.add_theme_color_override("font_color", Color("#CCCCCC"))
		card.add_child(desc_label)

		# Strategy value
		var val_label = Label.new()
		val_label.text = "\u7b56\u7565\u4ef7\u503c"
		val_label.position = Vector2(15, 270)
		val_label.size = Vector2(card_w - 30, 20)
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_label.add_theme_font_size_override("font_size", 13)
		val_label.add_theme_color_override("font_color", Color("#888888"))
		card.add_child(val_label)

		var val_text = Label.new()
		val_text.text = proto.value
		val_text.position = Vector2(15, 292)
		val_text.size = Vector2(card_w - 30, 60)
		val_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_text.autowrap_mode = TextServer.AUTOWRAP_WORD
		val_text.add_theme_font_size_override("font_size", 14)
		val_text.add_theme_color_override("font_color", Color("#3BFF8C"))
		card.add_child(val_text)

		# Hover effects
		card.mouse_entered.connect(func():
			var hs = card_style.duplicate()
			hs.shadow_size = 24
			hs.shadow_color = proto.color
			hs.border_color = Color("#FFFFFF")
			card.add_theme_stylebox_override("panel", hs)
			var t = create_tween()
			t.tween_property(card, "scale", Vector2(1.05, 1.05), 0.08)
		)
		card.mouse_exited.connect(func():
			card.add_theme_stylebox_override("panel", card_style)
			var t = create_tween()
			t.tween_property(card, "scale", Vector2(1.0, 1.0), 0.08)
		)

		# Click - select this protocol
		var protocol_name = proto.name
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				# Selection flash
				var flash = ColorRect.new()
				flash.size = Vector2(1920, 1080)
				flash.color = Color.WHITE
				flash.modulate.a = 0.0
				flash.z_index = 250
				flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
				self.add_child(flash)
				var ft = create_tween()
				ft.tween_property(flash, "modulate:a", 0.3, 0.05)
				ft.tween_property(flash, "modulate:a", 0.0, 0.1)
				ft.tween_callback(flash.queue_free)
				# Close and emit
				var ct = create_tween()
				ct.tween_property(_overlay, "modulate:a", 0.0, 0.2)
				ct.tween_callback(func():
					_overlay.queue_free()
					reward_chosen.emit("core_breakthrough", {"protocol_name": protocol_name})
				)
		)

	# Entrance
	_overlay.modulate.a = 0.0
	var entrance_tween = create_tween()
	entrance_tween.tween_property(_overlay, "modulate:a", 1.0, 0.2)

# === External API for TCP Bridge (Training Mode) ===

func get_bridge_state() -> Dictionary:
	"""Return reward state for bridge snapshot."""
	if name == "CoreBreakthroughPanel":
		return {
			"mode": "core_breakthrough",
			"available": _get_breakthrough_protocols(),
		}
	# Normal reward panel
	return {
		"mode": "reward_type",
		"rewardTypes": _selected_types.duplicate(),
		"rerollUsed": _reroll_used,
	}

func _get_breakthrough_protocols() -> Array:
	"""Get list of available protocols from current panel."""
	# Extract from the UI - find protocol cards
	var protocols = []
	if _panel_ref:
		for child in _panel_ref.get_children():
			if child is Panel and child.get_child_count() > 2:
				# Find name label
				for sub in child.get_children():
					if sub is Label and sub.position.y > 80 and sub.position.y < 130:
						protocols.append(sub.text)
						break
	return protocols

func get_legal_actions_bridge() -> Array:
	"""Return legal actions for bridge."""
	var actions = []
	if name == "CoreBreakthroughPanel":
		var protocols = _get_breakthrough_protocols()
		for i in range(protocols.size()):
			actions.append({
				"kind": "choose_protocol",
				"label": "Choose protocol: " + protocols[i],
				"parameters": {"protocolName": protocols[i], "optionIndex": i}
			})
		return actions

	# Normal reward panel
	for i in range(_selected_types.size()):
		var rt = _selected_types[i]
		actions.append({
			"kind": "choose_reward",
			"label": "Choose reward: " + _get_reward_display_name(rt),
			"parameters": {"rewardType": rt, "optionIndex": i}
		})

	if not _reroll_used:
		actions.append({
			"kind": "reroll_reward",
			"label": "Reroll rewards",
			"parameters": {}
		})

	return actions

func _get_reward_display_name(reward_type: String) -> String:
	var info = REWARD_INFO.get(reward_type, {})
	return info.get("title", reward_type)

func external_choose_reward(reward_type: String) -> Dictionary:
	"""Externally choose a reward type."""
	if not _selected_types.has(reward_type):
		return {"ok": false, "message": "Reward type not available"}

	# Simulate selection
	_on_reward_selected_sync(reward_type)
	return {"ok": true, "message": ""}

func external_choose_reward_card(option_index: int) -> Dictionary:
	"""Externally choose a card from evolution module selector."""
	# This is called when evolution_module shows card selector
	# For simplicity, auto-select first available family
	var families = _get_all_families()
	if option_index < 0 or option_index >= families.size():
		return {"ok": false, "message": "Invalid option index"}

	var fd = families[option_index]
	var is_max = fd.level >= 3 or fd.needed <= 0
	if is_max:
		ep_manager.add_reserve_progress(5)
		reward_chosen.emit("evolution_module", {"mode": "reserve_fallback", "amount": 5})
	else:
		reward_chosen.emit("evolution_module", {"mode": "family", "family": fd.family, "amount": 8})

	# Close the selector if it exists
	if card_selector:
		card_selector.queue_free()
		card_selector = null

	return {"ok": true, "message": ""}

func external_choose_protocol(protocol_name: String) -> Dictionary:
	"""Externally choose a core breakthrough protocol."""
	if name != "CoreBreakthroughPanel":
		return {"ok": false, "message": "Not in breakthrough mode"}

	var protocols = _get_breakthrough_protocols()
	if not protocols.has(protocol_name):
		return {"ok": false, "message": "Protocol not available"}

	reward_chosen.emit("core_breakthrough", {"protocol_name": protocol_name})

	# Close panel
	if _overlay:
		_overlay.queue_free()

	return {"ok": true, "message": ""}

func external_reroll() -> Dictionary:
	"""Externally reroll rewards."""
	if _reroll_used:
		return {"ok": false, "message": "Reroll already used"}
	_reroll_rewards()
	return {"ok": true, "message": ""}

# === Sync versions for training (no animations) ===

func _on_reward_selected_sync(reward_type: String):
	"""Handle reward selection without animations."""
	# Close overlay
	if _overlay:
		_overlay.queue_free()
		_reward_cards.clear()

	# Handle reward logic
	match reward_type:
		"evolution_module":
			# Auto-select first non-max family
			var families = _get_all_families()
			var chosen = null
			for fd in families:
				if fd.level < 3 and fd.needed > 0:
					chosen = fd
					break
			if chosen:
				reward_chosen.emit("evolution_module", {"mode": "family", "family": chosen.family, "amount": 8})
			else:
				ep_manager.add_reserve_progress(5)
				reward_chosen.emit("evolution_module", {"mode": "reserve_fallback", "amount": 5})
		"energy_core":
			_handle_energy_core()
		"tactical_protocol":
			_handle_tactical_protocol()
		"overclock_chip":
			_handle_overclock_chip()
		"heal":
			_handle_heal()
		"max_hp_up":
			_handle_max_hp_up()
		"random_card":
			_handle_random_card()
		"copy_card":
			_handle_copy_card()
