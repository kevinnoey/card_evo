extends Node2D
## Battle Manager - main orchestrator that builds the entire battle scene (1920x1080)
## v1.6: Roguelite mode — battles triggered from map, enemy from RunRewardState.pending_battle

signal turn_started()
signal turn_ended()
signal battle_won()
signal battle_lost()

var enemy: Node
var player: Node
var ep_manager: Node
var card_hand: Control
var battle_hud: Control
var float_layer: Control
var player_info_overlay: Control

var deck: Array = []
var hand: Array = []
var discard: Array = []

var is_player_turn: bool = true
var battle_over: bool = false
var extra_play_available: bool = false
var ep_penalty_next_turn: int = 0
var discard_selection_mode: bool = false
var selected_card: CardUI = null
var current_chapter: int = 1
var hand_size_limit: int = 5
var pending_discard_count: int = 0
var reward_pending: bool = false  # Track if reward is being processed
var fast_mode: bool = false  # Training mode: skip animations
var turn_count: int = 0     # Track turn number for snapshot
var next_attack_bonus: int = 0  # D08 弱点扫描: buffer for next attack this turn
var player_damaged_last_turn: bool = false  # D06 回滚: player took HP damage in last enemy turn

# Data pollution: reduces player barrier gain next turn
var barrier_reduction_next_turn: int = 0

var MAX_HAND_SIZE = 5

# Chapter 1 linear battle sequence
var battle_sequence: Array = [
	"enemy_a",  # 防火墙哨兵
	"enemy_b",  # 脉冲中继器
	"enemy_c",  # 数据腐化体
	"enemy_d",  # 加密守护者
	"enemy_e",  # 虚空信标
	"enemy_f",  # 湮灭协议·原型
	"enemy_g",  # 内存吞噬者
	"enemy_h",  # 矩阵哨卫
	"enemy_i",  # 主控中枢·格式化巨兽
]
var current_battle_index: int = 0

const CardUIScene = preload("res://scenes/card_ui.tscn")

const ENEMY_CONFIGS = {
	# ===== 战斗1: 防火墙哨兵 (random) =====
	"enemy_a": {
		"name": "防火墙哨兵",
		"hp": 35,
		"ice": 0,
		"ai_type": "random",
		"behavior_cycle": [
			{"type": "attack", "value": 6, "icon": "⚔️", "desc": "攻击 6"},
			{"type": "buff", "value": 2, "icon": "⬆", "desc": "强化 +2"},
			{"type": "heavy", "value": 10, "icon": "💀", "desc": "重击 10"},
		],
		"portrait": "res://card/防火墙哨兵.png",
		"portrait_color": Color("#FF3B3B"),
	},

	# ===== 战斗2: 脉冲中继器 (cycle 3回合) =====
	"enemy_b": {
		"name": "脉冲中继器",
		"hp": 28,
		"ice": 1,
		"ai_type": "cycle",
		"behavior_cycle": [
			{"type": "shock", "value": 5, "icon": "⚡", "desc": "电击 5"},
			{"type": "recharge", "value": 8, "self_vulnerable": 1, "icon": "🔋", "desc": "充电 8护盾"},
			{"type": "overload_burst", "value": 9, "icon": "💥", "desc": "过载爆发 9"},
		],
		"portrait": "res://card/脉冲中继器.png",
		"portrait_color": Color("#FFD700"),
	},

	# ===== 战斗3: 数据腐化体 (weighted_random 70/30) =====
	"enemy_c": {
		"name": "数据腐化体",
		"hp": 42,
		"ice": 0,
		"ai_type": "weighted_random",
		"weighted_pool": [
			{"intent": {"type": "corrode", "value": 7, "icon": "🦴", "desc": "腐蚀爪击 7", "vulnerable": 1}, "weight": 70},
			{"intent": {"type": "pollute", "value": 0, "icon": "☣️", "desc": "数据污染 屏障-2", "barrier_reduce": 2}, "weight": 30},
		],
		"portrait": "res://card/数据腐化体.png",
		"portrait_color": Color("#9B3BFF"),
	},

	# ===== 战斗4: 加密守护者 (cycle 4回合) =====
	"enemy_d": {
		"name": "加密守护者",
		"hp": 80,
		"ice": 2,
		"ai_type": "cycle",
		"behavior_cycle": [
			{"type": "data_slash", "value": 10, "icon": "⚔️", "desc": "数据切割 10"},
			{"type": "defend", "value": 15, "icon": "🛡️", "desc": "生成护盾 15"},
			{"type": "charge", "value": 0, "icon": "⏳", "desc": "蓄力中..."},
			{"type": "heavy", "value": 25, "icon": "💀", "desc": "毁灭打击 25"},
		],
		"portrait": "res://card/加密守护者.png",
		"portrait_color": Color("#FF3B3B"),
	},

	# ===== 战斗5: 虚空信标 (smart) =====
	"enemy_e": {
		"name": "虚空信标",
		"hp": 60,
		"ice": 3,
		"ai_type": "smart",
		"smart_rules": [
			{"condition": "hand_ge", "value": 5, "intent": {"type": "signal_jam", "value": 4, "icon": "📡", "desc": "信号干扰 4+弃牌", "discard": 1}},
			{"condition": "hand_le", "value": 2, "intent": {"type": "void_drain", "value": 7, "heal": 5, "icon": "🌀", "desc": "虚空汲取 7+回5"}},
		],
		"fallback_intent": {"type": "attack", "value": 6, "icon": "⚔️", "desc": "常规攻击 6"},
		"portrait": "res://card/虚空信标.png",
		"portrait_color": Color("#008B8B"),
	},

	# ===== 战斗6: 湮灭协议·原型 (multi_phase) =====
	"enemy_f": {
		"name": "湮灭协议·原型",
		"hp": 120,
		"ice": 0,
		"ai_type": "multi_phase",
		"phase_hp_threshold": 0.5,
		"annihilate_interval": 2,
		"phase1_cycle": [
			{"type": "suppress", "value": 8, "icon": "⚔️", "desc": "协议·压制 8", "vulnerable": 1},
			{"type": "reconstruct", "value": 10, "icon": "🛡️", "desc": "协议·重构 10护盾"},
			{"type": "overload", "value": 12, "self_damage": 3, "icon": "💀", "desc": "协议·过载 12"},
		],
		"phase2_cycle": [
			{"type": "annihilate", "value": 18, "icon": "💀", "desc": "终极·湮灭 18(无视屏障)"},
			{"type": "nihil", "value": 5, "icon": "🌀", "desc": "终极·虚无 5+清护盾"},
			{"type": "annihilate", "value": 18, "icon": "💀", "desc": "终极·湮灭 18(无视屏障)"},
		],
		"portrait": "res://card/湮灭协议·原型.png",
		"portrait_color": Color("#FF1A1A"),
	},

	# ===== 战斗7: 内存吞噬者 (cycle 3) =====
	"enemy_g": {
		"name": "内存吞噬者",
		"hp": 75,
		"ice": 1,
		"ai_type": "cycle",
		"behavior_cycle": [
			{"type": "devour", "value": 8, "icon": "🍽", "desc": "数据吞食 8+弃牌"},
			{"type": "digest", "value": 0, "heal": 10, "max_hp_gain": 10, "icon": "🔄", "desc": "消化增殖 回10HP"},
			{"type": "regurgitate", "value": 15, "pierce_shield": 1, "icon": "💥", "desc": "反刍打击 15(穿甲1)"},
		],
		"portrait": "res://card/内存吞噬者.png",
		"portrait_color": Color("#2E8B2E"),
	},

	# ===== 战斗8: 矩阵哨卫 (smart/ICE) =====
	"enemy_h": {
		"name": "矩阵哨卫",
		"hp": 90,
		"ice": 4,
		"ai_type": "smart",
		"smart_rules": [
			{"condition": "ice_le", "value": 3, "intent": {"type": "restore_ice", "value": 0, "icon": "🔧", "desc": "自适应装甲 +2ICE"}},
		],
		"fallback_intent": {"type": "suppress_barrier", "value": 12, "pierce_shield": 1, "icon": "⛔", "desc": "镇压协议 12(穿甲1)"},
		"portrait": "res://card/矩阵哨卫.png",
		"portrait_color": Color("#FFFFFF"),
	},

	# ===== 战斗9: 主控中枢·格式化巨兽 (multi_phase) =====
	"enemy_i": {
		"name": "主控中枢·格式化巨兽",
		"hp": 180,
		"ice": 2,
		"ai_type": "multi_phase",
		"phase_hp_threshold": 0.5,
		"annihilate_interval": 2,
		"phase1_cycle": [
			{"type": "format", "value": 10, "icon": "💾", "desc": "底层格式化 10"},
			{"type": "grid_overload", "value": 15, "icon": "⚡", "desc": "过载电网 15"},
			{"type": "defense_matrix", "value": 20, "attack_buff": 5, "icon": "🛡️", "desc": "防御矩阵 20+"},
		],
		"phase2_cycle": [
			{"type": "system_restart", "value": 0, "icon": "🔄", "desc": "系统重启 清debuff+退化"},
			{"type": "berserk_overwrite", "value": 22, "pierce_shield": 2, "icon": "💀", "desc": "狂暴覆写 22(无视+穿甲2)"},
			{"type": "berserk_overwrite", "value": 22, "pierce_shield": 2, "icon": "💀", "desc": "狂暴覆写 22(无视+穿甲2)"},
		],
		"portrait": "res://card/格式化巨兽.png",
		"portrait_color": Color("#000000"),
	},

	# ===== Chapter 2 Enhanced Variants =====
	# 脉冲中继器·改 (HP +10, damage +2)
	"enemy_b_ch2": {
		"name": "脉冲中继器·改",
		"hp": 38,
		"ice": 1,
		"ai_type": "cycle",
		"behavior_cycle": [
			{"type": "shock", "value": 7, "icon": "⚡", "desc": "电击 7"},
			{"type": "recharge", "value": 10, "self_vulnerable": 1, "icon": "🔋", "desc": "充电 10护盾"},
			{"type": "overload_burst", "value": 11, "pierce_shield": 1, "icon": "💥", "desc": "过载爆发 11(穿甲1)"},
		],
		"portrait": "res://card/脉冲中继器.png",
		"portrait_color": Color("#FFD700"),
	},

	# 数据腐化体·改 (HP +10, damage +2)
	"enemy_c_ch2": {
		"name": "数据腐化体·改",
		"hp": 52,
		"ice": 0,
		"ai_type": "weighted_random",
		"weighted_pool": [
			{"intent": {"type": "corrode", "value": 9, "pierce_shield": 1, "icon": "🦴", "desc": "腐蚀爪击 9(穿甲1)", "vulnerable": 1}, "weight": 70},
			{"intent": {"type": "pollute", "value": 0, "icon": "☣️", "desc": "数据污染 屏障-2", "barrier_reduce": 2}, "weight": 30},
		],
		"portrait": "res://card/数据腐化体.png",
		"portrait_color": Color("#9B3BFF"),
	},

	# 加密守护者·改 (HP +20, shield +5)
	"enemy_d_ch2": {
		"name": "加密守护者·改",
		"hp": 100,
		"ice": 2,
		"ai_type": "cycle",
		"behavior_cycle": [
			{"type": "data_slash", "value": 12, "pierce_shield": 1, "icon": "⚔️", "desc": "数据切割 12(穿甲1)"},
			{"type": "defend", "value": 20, "icon": "🛡️", "desc": "生成护盾 20"},
			{"type": "charge", "value": 0, "icon": "⏳", "desc": "蓄力中..."},
			{"type": "heavy", "value": 27, "pierce_shield": 2, "icon": "💀", "desc": "毁灭打击 27(穿甲2)"},
		],
		"portrait": "res://card/加密守护者.png",
		"portrait_color": Color("#FF3B3B"),
	},
}

# Difficulty tiers by map layer (for layer-based scaling)
const DIFFICULTY_TIERS = [
	{"layer_min": 0,  "layer_max": 2,  "hp_mult": 0.80, "dmg_bonus": -2},
	{"layer_min": 3,  "layer_max": 5,  "hp_mult": 0.90, "dmg_bonus": -1},
	{"layer_min": 6,  "layer_max": 8,  "hp_mult": 1.00, "dmg_bonus": 0},
	{"layer_min": 9,  "layer_max": 11, "hp_mult": 1.15, "dmg_bonus": 2},
	{"layer_min": 12, "layer_max": 14, "hp_mult": 1.30, "dmg_bonus": 4},
]


func _ready():
	_create_background()
	_create_player()
	_create_enemy()
	_create_ep_manager()
	_create_battle_hud()
	_create_card_hand()
	_create_float_layer()
	_create_bridge_api()
	_setup_battle()

func _create_bridge_api():
	var bridge = preload("res://scripts/bridge/bridge_api.gd").new()
	bridge.name = "BridgeAPI"
	add_child(bridge)

func _create_background():
	var bg_tex = TextureRect.new()
	bg_tex.texture = load("res://card/背景.png")
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.size = Vector2(1920, 1080)
	bg_tex.z_index = -10
	bg_tex.modulate = Color(0.6, 0.6, 0.6)
	add_child(bg_tex)

	var bg = ColorRect.new()
	bg.size = Vector2(1920, 1080)
	bg.color = Color("#060610", 0.3)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	for i in range(0, 1920, 80):
		var line = ColorRect.new()
		line.size = Vector2(1, 1080)
		line.position = Vector2(i, 0)
		line.color = Color("#1A1A3A")
		add_child(line)
	for i in range(0, 1080, 80):
		var line = ColorRect.new()
		line.size = Vector2(1920, 1)
		line.position = Vector2(0, i)
		line.color = Color("#1A1A3A")
		add_child(line)

func _create_player():
	player = Player.new()
	player.name = "Player"
	player.position = Vector2(400, 720)
	add_child(player)

	var char_info = CardDatabase.get_character_info(RunRewardState.selected_character)
	var char_color = char_info.get("color", Color("#00F0FF"))

	var player_info_icon = Button.new()
	player_info_icon.name = "PlayerInfoIcon"
	player_info_icon.flat = true
	player_info_icon.position = Vector2(4, 20)
	player_info_icon.size = Vector2(44, 44)
	player_info_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pi_style = StyleBoxFlat.new()
	pi_style.bg_color = Color(char_color, 0.25)
	pi_style.border_color = Color(char_color, 0.85)
	pi_style.border_width_left = 2
	pi_style.border_width_right = 2
	pi_style.border_width_top = 2
	pi_style.border_width_bottom = 2
	pi_style.corner_radius_top_left = 22
	pi_style.corner_radius_top_right = 22
	pi_style.corner_radius_bottom_left = 22
	pi_style.corner_radius_bottom_right = 22
	pi_style.shadow_size = 8
	pi_style.shadow_color = Color(char_color, 0.4)
	player_info_icon.add_theme_stylebox_override("normal", pi_style)
	player_info_icon.pressed.connect(_show_player_info)
	player_info_icon.mouse_entered.connect(func(): _on_info_icon_hover(player_info_icon, true))
	player_info_icon.mouse_exited.connect(func(): _on_info_icon_hover(player_info_icon, false))
	add_child(player_info_icon)

	var pi_label = Label.new()
	pi_label.text = "?"
	pi_label.position = Vector2(12, 22)
	pi_label.size = Vector2(24, 24)
	pi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pi_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pi_label.add_theme_font_size_override("font_size", 26)
	pi_label.add_theme_color_override("font_color", char_color)
	pi_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pi_label)

func _create_enemy():
	enemy = Enemy.new()
	enemy.name = "Enemy"
	enemy.position = Vector2(960, 200)
	add_child(enemy)

func _create_ep_manager():
	ep_manager = EPManager.new()
	ep_manager.name = "EPManager"
	add_child(ep_manager)
	# v1.6: Restore persisted evolution state from RunRewardState
	if RunRewardState.run_active:
		RunRewardState.restore_to_ep_manager(ep_manager)

func _create_battle_hud():
	battle_hud = BattleHUD.new()
	battle_hud.name = "BattleHUD"
	battle_hud.anchor_right = 1.0
	battle_hud.anchor_bottom = 1.0
	add_child(battle_hud)

func _create_card_hand():
	card_hand = Control.new()
	card_hand.name = "CardHand"
	card_hand.position = Vector2(460, 660)
	card_hand.size = Vector2(1300, 350)
	add_child(card_hand)

func _create_float_layer():
	float_layer = Control.new()
	float_layer.name = "FloatLayer"
	float_layer.anchor_right = 1.0
	float_layer.anchor_bottom = 1.0
	float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(float_layer)

	_create_player_info_overlay()

func _setup_battle():
	battle_hud.add_log("═══════════════════════════", Color("#444444"))
	battle_hud.add_log("🎮 游戏开始 — [color=#00F0FF]第一章[/color]", Color("#00F0FF"))
	battle_hud.add_log("⚔️ 第一战：对阵 [color=#FF6B35]" + enemy.enemy_name + "[/color]", Color("#FF6B35"))

	player.hp_changed.connect(_on_player_hp_changed)
	player.block_changed.connect(_on_player_block_changed)
	player.barrier_changed.connect(_on_player_barrier_changed)
	player.energy_shield_changed.connect(_on_player_energy_shield_changed)
	player.player_died.connect(_on_battle_lost)

	enemy.hp_changed.connect(_on_enemy_hp_changed)
	enemy.ice_changed.connect(_on_enemy_ice_changed)
	enemy.intent_changed.connect(_on_enemy_intent_changed)
	enemy.enemy_died.connect(_on_battle_won)
	enemy.phase_changed.connect(_on_enemy_phase_changed)
	enemy.crash_changed.connect(_on_enemy_crash_changed)

	ep_manager.ep_changed.connect(_on_ep_changed)
	ep_manager.reserve_changed.connect(_on_reserve_changed)
	ep_manager.card_evolved.connect(_on_card_evolved)
	ep_manager.barrier_granted.connect(_on_barrier_granted)
	ep_manager.milestone_reached.connect(_on_milestone_reached)
	ep_manager.free_upgrade_available.connect(_on_free_upgrade_available)

	turn_started.connect(_on_turn_started)
	battle_won.connect(_on_battle_won_internal)
	battle_lost.connect(_on_battle_lost_internal)

	# v1.6: Build deck from RunRewardState (supports card additions/removals)
	if RunRewardState.run_active:
		deck = _build_evolved_deck()
	else:
		deck = CardDatabase.get_starting_deck()
	deck.shuffle()

	_setup_current_enemy()

	# v1.6: Restore HP from RunRewardState (persists across battles)
	if RunRewardState.run_active:
		RunRewardState.restore_hp_to_player(player)
		# Apply enemy strength bonus from events (e.g., report merchant)
		if RunRewardState.next_battle_enemy_bonus_strength > 0:
			_apply_enemy_strength_bonus(RunRewardState.next_battle_enemy_bonus_strength)
			RunRewardState.next_battle_enemy_bonus_strength = 0
	else:
		var char_info = CardDatabase.get_character_info(RunRewardState.selected_character)
		var char_hp = char_info.get("hp", 70)
		player.max_hp = char_hp
		player.current_hp = char_hp
		player.energy_shield = 0
	player.block = 0
	player.barrier = 0

	battle_hud.update_enemy_hp(enemy.current_hp, enemy.max_hp)
	battle_hud.update_player_hp(player.current_hp, player.max_hp)

	battle_hud.end_turn_btn.pressed.connect(_on_end_turn)
	battle_hud.deck_btn.pressed.connect(_on_deck_btn_pressed)

	# Apply chapter 2 protocol effects
	if RunRewardState.has_protocol("超限跃迁"):
		MAX_HAND_SIZE = 6
	if RunRewardState.has_protocol("涌动核心"):
		RunRewardState.apply_reserve_protocol(ep_manager)

	_start_player_turn()

	# v1.6 fix: Apply next-battle temp bonuses (tactical_protocol / overclock_chip rewards)
	if RunRewardState.run_active:
		RunRewardState.apply_next_battle_bonus(player, ep_manager)
		# Refresh HUD to show temp bonuses (barrier, block, extra EP)
		battle_hud.update_ep(ep_manager.current_ep, ep_manager.max_ep)
		if player.barrier > 0:
			battle_hud.update_barrier(player.barrier)
		if player.block > 0:
			battle_hud.update_block(player.block)

	# Initialize reserve pool display (restored from RunRewardState, no signal fired)
	battle_hud.update_reserve(ep_manager.reserve_pool, ep_manager.max_reserve)
	_sync_shield_from_reserve()

func _get_player_hand_count() -> int:
	return hand.size()

func _setup_current_enemy():
	# v1.6: Get enemy key from RunRewardState.pending_battle (map system)
	var enemy_key = ""
	if RunRewardState.run_active and RunRewardState.pending_battle.has("enemy_key"):
		enemy_key = RunRewardState.pending_battle["enemy_key"]
	elif RunRewardState.run_active:
		# Fallback: shouldn't happen in normal flow
		enemy_key = "enemy_a"
	else:
		# Legacy mode (no roguelite run active)
		if current_battle_index < battle_sequence.size():
			enemy_key = battle_sequence[current_battle_index]
		else:
			enemy_key = "enemy_a"

	if not ENEMY_CONFIGS.has(enemy_key):
		enemy_key = "enemy_a"  # Ultimate fallback

	var config = ENEMY_CONFIGS[enemy_key].duplicate(true)

	# Inject hand count callable for smart AI
	if config.get("ai_type", "") == "smart":
		config["get_player_hand_count"] = _get_player_hand_count

	enemy.setup_enemy(config)

	# Apply layer-based difficulty scaling (map position)
	if RunRewardState.run_active and RunRewardState.pending_battle.has("node_layer"):
		var layer = RunRewardState.pending_battle["node_layer"]
		var mods = _get_difficulty_modifiers(layer)
		enemy.apply_layer_scaling(mods["hp_mult"], mods["dmg_bonus"])
		battle_hud.update_enemy_hp(enemy.current_hp, enemy.max_hp)

	battle_hud.update_enemy_name(enemy.enemy_name)
	battle_hud.update_enemy_hp(enemy.current_hp, enemy.max_hp)
	battle_hud.update_ice(enemy.ice)

	# Swap enemy portrait (skip if file missing, keep current)
	var portrait_path = config.get("portrait", "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var tex = load(portrait_path)
		if tex:
			battle_hud.swap_enemy_portrait(tex)

func _get_difficulty_modifiers(layer: int) -> Dictionary:
	"""Get HP and damage modifiers for the given map layer."""
	for tier in DIFFICULTY_TIERS:
		if layer >= tier["layer_min"] and layer <= tier["layer_max"]:
			return {"hp_mult": tier["hp_mult"], "dmg_bonus": tier["dmg_bonus"]}
	return {"hp_mult": 1.0, "dmg_bonus": 0}

func _start_player_turn():
	is_player_turn = true
	_deselect_card()

	# Always restore EP to max first, then apply penalty
	ep_manager.reset_turn()

	if ep_penalty_next_turn > 0:
		ep_manager.apply_ep_penalty(ep_penalty_next_turn)
		ep_penalty_next_turn = 0

	# Force HUD refresh to ensure display is in sync
	battle_hud.update_ep(ep_manager.current_ep, ep_manager.max_ep)

	# Apply barrier reduction from data pollution
	ep_manager.set_barrier_reduction(barrier_reduction_next_turn)
	barrier_reduction_next_turn = 0

	player.reset_turn()
	enemy.reset_turn()
	extra_play_available = false
	next_attack_bonus = 0
	player_damaged_last_turn = false
	_draw_cards(5)
	turn_started.emit()

func _draw_cards(count: int):
	for i in range(count):
		if deck.is_empty():
			_reshuffle_discard()
		if deck.is_empty():
			break

		var card_id = deck.pop_front()
		var card_def = CardDatabase.get_card_def(card_id)
		if card_def.is_empty():
			continue

		var card_ui = CardUIScene.instantiate()
		card_ui.setup_card(card_def.duplicate())
		card_ui.fast_mode = fast_mode
		card_ui.card_clicked.connect(_on_card_clicked)
		card_ui.inject_clicked.connect(_on_inject_clicked)

		var family = card_def.get("evolution_family", "")
		if family != "" and ep_manager.card_ep_by_family.has(family):
			card_ui.update_evolution_progress(ep_manager.get_card_ep_progress(card_ui))

		var idx = hand.size()
		card_ui.hand_index = idx
		card_ui.z_index = idx
		card_hand.add_child(card_ui)
		hand.append(card_ui)

		var pos = _get_arc_position(idx, hand.size())
		card_ui.position = Vector2(pos.x, pos.y)
		card_ui.rotation = pos.theta
		card_ui.rest_y = pos.y
		_animate_draw(card_ui)

	_reposition_hand()
	_check_hand_limit()

func _check_hand_limit():
	if hand.size() > MAX_HAND_SIZE and not discard_selection_mode:
		pending_discard_count = hand.size() - MAX_HAND_SIZE
		battle_hud.show_message("手牌已满（" + str(hand.size()) + "/" + str(MAX_HAND_SIZE) + "）！需弃掉 " + str(pending_discard_count) + " 张")

		for card in hand:
			var tween = create_tween()
			tween.tween_property(card, "modulate", Color.RED, 0.15)
			tween.tween_property(card, "modulate", Color.WHITE, 0.3)

		await get_tree().create_timer(0.8).timeout
		discard_selection_mode = true
		battle_hud.show_message("点击卡牌弃掉（剩余 " + str(pending_discard_count) + " 张）")

func _discard_card_from_hand(card: CardUI):
	if selected_card == card:
		_deselect_card()
	var card_id = card.card_def.get("card_id", "")
	var card_name = card.card_def.get("name", "未知卡牌")

	# Log discard
	battle_hud.add_log("弃牌：[color=#888888]" + card_name + "[/color]", Color("#888888"))

	# Restore EP that was injected into this card
	if card.injected_ep > 0:
		ep_manager.current_ep += card.injected_ep
		battle_hud.update_ep(ep_manager.current_ep, ep_manager.max_ep)
		battle_hud.show_message("弃牌恢复 " + str(card.injected_ep) + " EP")
		battle_hud.add_log("  → 恢复 [color=#FFD700]+" + str(card.injected_ep) + " EP[/color]", Color.WHITE)

	hand.erase(card)
	discard.append(card_id)
	card.queue_free()
	_reposition_hand()

	pending_discard_count -= 1
	if pending_discard_count <= 0:
		discard_selection_mode = false
		battle_hud.show_message("弃牌完成，继续操作")
	else:
		battle_hud.show_message("还需弃掉 " + str(pending_discard_count) + " 张牌")

func _force_discard_highest_cost(count: int):
	# Signal jam: discard highest cost card from hand
	if hand.is_empty():
		return
	for i in range(count):
		if hand.is_empty():
			break
		var highest: CardUI = null
		var highest_cost = -1
		for card in hand:
			var c = card.card_def.get("cost", 0)
			if c > highest_cost:
				highest_cost = c
				highest = card
		if highest:
			var card_name = highest.card_def.get("name", "???")
			_discard_card_from_hand(highest)
			battle_hud.show_message("信号干扰！弃掉了 [" + card_name + "]")

func _reshuffle_discard():
	discard.shuffle()
	deck = discard.duplicate()
	discard.clear()
	battle_hud.show_message("牌库用尽，已重新洗牌（注入进度已保留）")
	battle_hud.add_log("🔄 [color=#888888]牌库用尽，重新洗牌[/color]", Color("#888888"))

func _force_discard_lowest_cost(count: int):
	"""Discard the lowest-cost cards from hand (内存吞噬者's 数据吞食)."""
	if hand.is_empty():
		return
	for i in range(count):
		if hand.is_empty():
			break
		var lowest: CardUI = null
		var lowest_cost = 999
		for card in hand:
			var c = card.card_def.get("cost", 0)
			if c < lowest_cost:
				lowest_cost = c
				lowest = card
		if lowest:
			var card_name = lowest.card_def.get("name", "???")
			_discard_card_from_hand(lowest)
			battle_hud.show_message("数据吞食！弃掉了 [" + card_name + "]")

func _devolve_hand_cards():
	"""Devolve all evolved cards in hand by 1 level (格式化巨兽's 系统重启)."""
	for card in hand:
		var def_entry = card.card_def
		var family = def_entry.get("evolution_family", "")
		if family == "":
			continue
		var level = def_entry.get("level", 1)
		if level <= 1:
			continue
		var chain = def_entry.get("evolution_chain", [])
		var prev_idx = level - 2  # Lv2 -> index 0, Lv3 -> index 1
		if prev_idx >= 0 and prev_idx < chain.size():
			var prev_id = chain[prev_idx]
			var prev_def = CardDatabase.get_card_def(prev_id)
			if not prev_def.is_empty():
				card.card_def = prev_def.duplicate()
				card.refresh_display()
				card.injected_ep = 0
				card.is_bloom = false
				card.cost_override = -1
				# Restore some EP progress to the family
				var threshold = 8 if level == 2 else 20
				var leftover = threshold - 1  # Put 1 EP below threshold
				var fam = card.card_def.get("evolution_family", family)
				ep_manager.card_ep_by_family[fam] = max(0, leftover)
	battle_hud.show_message("⚡ 系统重启！所有已进化卡牌退化1级！")

func _animate_draw(card: CardUI):
	var target_y = card.position.y
	var target_rot = card.rotation
	card.modulate.a = 0.0
	card.position.y = target_y + 90
	card.rotation = target_rot + randf_range(-0.08, 0.08)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(card, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position:y", target_y, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card, "rotation", target_rot, 0.3)

func _get_arc_position(index: int, total: int) -> Dictionary:
	const R = 2000.0
	const R_Y = 1200.0
	const MAX_SPREAD = 0.4
	const ANGLE_PER_CARD = 0.05
	const CARD_HALF = 120.0

	var cx = card_hand.size.x / 2.0 - 200.0
	var max_x = card_hand.size.x - CARD_HALF

	if total <= 1:
		return {"x": cx, "y": 0.0, "theta": 0.0}

	var spread = min(MAX_SPREAD, float(total - 1) * ANGLE_PER_CARD)
	var frac = float(index) / float(total - 1)
	var theta = (frac - 0.5) * spread

	var tx = cx + R * sin(theta)
	tx = clamp(tx, CARD_HALF, max_x)

	return {
		"x": tx,
		"y": -R_Y * (1.0 - cos(theta)),
		"theta": theta,
	}

func _reposition_hand():
	for i in range(hand.size()):
		var card = hand[i]
		var pos = _get_arc_position(i, hand.size())

		card.hand_index = i
		card.z_index = 100 if card.selected else i
		card.rest_y = pos.y
		var target_y = pos.y - 30 if card.selected else pos.y

		var tween = create_tween().set_parallel(true)
		tween.tween_property(card, "position:x", pos.x, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position:y", target_y, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "rotation", pos.theta, 0.2).set_ease(Tween.EASE_OUT)

func _on_card_clicked(card: CardUI):
	if not is_player_turn or battle_over:
		return

	if discard_selection_mode:
		# Discard mode: select first, second click confirms discard
		if selected_card != null:
			if selected_card == card:
				# Second click on the same card → discard it
				_deselect_card()
				_discard_card_from_hand(card)
				return
			else:
				# Clicked a different card → switch selection
				_deselect_card()

		# First click → select with red highlight
		selected_card = card
		card.set_selected(true, Color(1.0, 0.2, 0.2, 0.9))
		card.z_index = 100
		battle_hud.show_message("再次点击确认弃牌（剩余 " + str(pending_discard_count) + " 张）")
		return

	# If a card is already selected...
	if selected_card != null:
		if selected_card == card:
			# Second click on the same card → play it
			var cost = card.cost_override if card.cost_override >= 0 else card.card_def.get("cost", 0)

			if card.is_bloom:
				battle_hud.show_message("✦ 进化绽放！费用 0，可额外行动一次！")

			if not ep_manager.can_afford(cost):
				battle_hud.show_message("EP 不足！需要 " + str(cost) + " EP")
				return

			_deselect_card()
			ep_manager.spend_ep(cost)
			_play_card(card)
			return
		else:
			# Clicked a different card → switch selection
			_deselect_card()

	# First click → select this card
	selected_card = card
	card.set_selected(true)
	card.z_index = 100

func _deselect_card():
	if selected_card != null:
		selected_card.set_selected(false)
		selected_card = null

func _on_inject_clicked(card: CardUI):
	if not is_player_turn or battle_over:
		return
	if discard_selection_mode:
		return
	if card.card_def.get("ep_to_evolve", -1) <= 0:
		battle_hud.show_message("已达到最高等级！")
		return
	if not ep_manager.can_afford(1):
		battle_hud.show_message("EP 不足！")
		return

	if ep_manager.inject_to_card(card):
		card.injected_ep += 1
		card.update_evolution_progress(ep_manager.get_card_ep_progress(card))
		card.update_ep_text(ep_manager.get_card_ep_text(card))
		_animate_inject(card)
		battle_hud.show_message("注入 EP → " + card.card_def.get("name", "卡牌"))
		battle_hud.add_log("注入 [color=#FFD700]1 EP[/color] → " + card.card_def.get("name", "卡牌"), Color("#00FFFF"))

func _play_card(card: CardUI):
	var effect = card.card_def.get("effect", {})
	var card_name = card.card_def.get("name", "未知卡牌")
	var card_cost = card.card_def.get("cost", 0)

	# Log card play
	battle_hud.add_log("打出 [color=#FFD700]" + card_name + "[/color] (消耗 " + str(card_cost) + " EP)", Color("#00F0FF"))

	# === PRE-DAMAGE: conditional bonuses and crash_copy save ===
	var crash_copy_saved: int = 0
	if effect.get("crash_copy", false):
		crash_copy_saved = enemy.crash_stacks

	var bonus_damage: int = 0
	if effect.has("bonus_if_crash") and enemy.crash_stacks > 0:
		bonus_damage += int(effect.bonus_if_crash)
		enemy.crash_stacks = 0
		enemy.crash_changed.emit(0)
		battle_hud.add_log("崩溃触发！伤害 [color=#FF3B8B]+" + str(int(effect.bonus_if_crash)) + "[/color]", Color("#FF3B8B"))

	if effect.has("bonus_if_crash_ge"):
		var ge_config = effect.bonus_if_crash_ge
		if enemy.crash_stacks >= ge_config.get("threshold", 3):
			bonus_damage += int(ge_config.get("bonus", 0))
			enemy.crash_stacks = 0
			enemy.crash_changed.emit(0)
			battle_hud.add_log("崩溃收割！伤害 [color=#FF3B8B]+" + str(int(ge_config.get("bonus", 0))) + "[/color]", Color("#FF3B8B"))

	# === next_attack_bonus: apply to this attack or buffer ===
	var attack_bonus_apply: int = 0
	if effect.has("damage") and next_attack_bonus > 0:
		attack_bonus_apply = next_attack_bonus
		next_attack_bonus = 0

	if effect.has("damage"):
		var dmg = int(effect.damage) + bonus_damage + attack_bonus_apply
		var pierce = effect.get("pierce", 0)
		battle_hud.play_player_attack()
		var actual = enemy.take_damage(dmg, pierce)
		if actual > 0:
			_float_damage(actual, enemy.position + Vector2(80, -50))
			battle_hud.play_enemy_hit("damage")
			battle_hud.add_log("对 " + enemy.enemy_name + " 造成 [color=#FF3B3B]" + str(actual) + "[/color] 点伤害", Color.WHITE)
		battle_hud.update_enemy_hp(enemy.current_hp, enemy.max_hp)
		battle_hud.update_enemy_shield(enemy.shield)
		battle_hud.update_enemy_crash(enemy.crash_stacks)

	# === POST-DAMAGE: crash_copy re-apply ===
	if effect.get("crash_copy", false) and crash_copy_saved > 0:
		var copy_bonus = effect.get("crash_copy_bonus", 0)
		enemy.add_crash(crash_copy_saved + copy_bonus)
		battle_hud.update_enemy_crash(enemy.crash_stacks)
		_float_text("崩溃×" + str(enemy.crash_stacks), enemy.position + Vector2(50, 20), Color("#FF3B8B"))
		battle_hud.add_log("递归复制崩溃 [color=#FF3B8B]" + str(crash_copy_saved + copy_bonus) + "[/color] 层", Color.WHITE)

	# === kill_ep: check if enemy died from this attack ===
	if effect.has("kill_ep") and enemy.is_dead:
		var kill_ep_amount = int(effect.kill_ep)
		ep_manager.add_ep(kill_ep_amount)
		battle_hud.show_message("击杀！+" + str(kill_ep_amount) + " EP")
		battle_hud.add_log("溢出攻击击杀！获得 [color=#FFD700]+" + str(kill_ep_amount) + "[/color] EP", Color.WHITE)

	if effect.has("block"):
		var blk = int(effect.block)
		player.add_block(blk)
		_float_block(blk, player.position + Vector2(50, -50))
		battle_hud.add_log("获得 [color=#3B8CFF]" + str(blk) + "[/color] 格挡", Color.WHITE)

	if effect.get("block_persist", false):
		player.block_persist = true

	if effect.has("vulnerable"):
		enemy.add_vulnerable(int(effect.vulnerable))
		_float_text("易伤+" + str(int(effect.vulnerable)), enemy.position + Vector2(50, 0), Color.PURPLE)
		battle_hud.add_log("对敌人施加 [color=#9B3BFF]" + str(int(effect.vulnerable)) + "[/color] 易伤", Color.WHITE)

	if effect.has("self_vulnerable"):
		player.vulnerable_stacks += int(effect.self_vulnerable)
		battle_hud.show_message("自身获得 " + str(int(effect.self_vulnerable)) + " 层脆弱")
		battle_hud.add_log("自身获得 [color=#FF6B35]" + str(int(effect.self_vulnerable)) + "[/color] 脆弱", Color.WHITE)

	if effect.has("draw"):
		_draw_cards(int(effect.draw))
		battle_hud.add_log("抽 [color=#FFD700]" + str(int(effect.draw)) + "[/color] 张牌", Color.WHITE)

	if effect.has("ep_penalty"):
		ep_penalty_next_turn += int(effect.ep_penalty)
		battle_hud.show_message("下回合 EP 恢复 -" + str(int(effect.ep_penalty)))
		battle_hud.add_log("下回合 EP [color=#FF6B35]-" + str(int(effect.ep_penalty)) + "[/color]", Color.WHITE)

	if effect.has("gain_ep"):
		ep_manager.add_ep(int(effect.gain_ep))
		battle_hud.show_message("+" + str(int(effect.gain_ep)) + " EP")
		battle_hud.add_log("获得 [color=#FFD700]+" + str(int(effect.gain_ep)) + "[/color] EP", Color.WHITE)

	if effect.has("heal"):
		player.heal(int(effect.heal))
		_float_text("+" + str(int(effect.heal)), player.position + Vector2(40, -30), Color.GREEN)
		battle_hud.add_log("恢复 [color=#3BFF8C]" + str(int(effect.heal)) + "[/color] HP", Color.WHITE)

	if effect.has("conditional_heal"):
		if player_damaged_last_turn:
			var heal_amt = int(effect.conditional_heal)
			player.heal(heal_amt)
			_float_text("+" + str(heal_amt) + " 回滚", player.position + Vector2(40, -30), Color.GREEN)
			battle_hud.add_log("回滚触发！恢复 [color=#3BFF8C]" + str(heal_amt) + "[/color] HP", Color.WHITE)
		else:
			battle_hud.add_log("回滚未触发（上回合未受伤）", Color("#888888"))

	if effect.has("reflect"):
		var ref_dmg = int(effect.reflect)
		enemy.current_hp = max(0, enemy.current_hp - ref_dmg)
		enemy.hp_changed.emit(enemy.current_hp, enemy.max_hp)
		_float_damage(ref_dmg, enemy.position + Vector2(-50, -30))
		_float_text("反弹!", enemy.position + Vector2(-50, -50), Color.ORANGE)
		battle_hud.play_enemy_hit("damage")
		battle_hud.add_log("反弹 [color=#FF6B35]" + str(ref_dmg) + "[/color] 伤害", Color.WHITE)

	if effect.has("barrier"):
		player.add_barrier(int(effect.barrier))
		_float_text("屏障+" + str(int(effect.barrier)), player.position + Vector2(60, -30), Color.CYAN)
		battle_hud.add_log("获得 [color=#00FFFF]" + str(int(effect.barrier)) + "[/color] 屏障", Color.WHITE)

	if effect.has("barrier_if_crash") and enemy.crash_stacks > 0:
		var bar_amt = int(effect.barrier_if_crash)
		player.add_barrier(bar_amt)
		_float_text("屏障+" + str(bar_amt), player.position + Vector2(60, -10), Color.CYAN)
		battle_hud.add_log("崩溃触发屏障 [color=#00FFFF]+" + str(bar_amt) + "[/color]", Color.WHITE)

	if effect.has("clear_self_vulnerable") and player.vulnerable_stacks > 0:
		var cleared = player.vulnerable_stacks
		player.vulnerable_stacks = 0
		_float_text("脆弱清除!", player.position + Vector2(40, -10), Color.GREEN)
		battle_hud.add_log("清除 [color=#3BFF8C]" + str(cleared) + "[/color] 层脆弱", Color.WHITE)

	# === Crash apply (AFTER damage so it benefits future attacks) ===
	if effect.has("crash"):
		var crash_amt = int(effect.crash)
		enemy.add_crash(crash_amt)
		battle_hud.update_enemy_crash(enemy.crash_stacks)
		_float_text("崩溃+" + str(crash_amt), enemy.position + Vector2(50, 20), Color("#FF3B8B"))
		battle_hud.add_log("施加 [color=#FF3B8B]" + str(crash_amt) + "[/color] 层崩溃（当前 " + str(enemy.crash_stacks) + "）", Color.WHITE)

	# === Next attack bonus buffer (non-damage cards) ===
	if effect.has("next_attack_bonus") and not effect.has("damage"):
		next_attack_bonus += int(effect.next_attack_bonus)
		battle_hud.show_message("弱点扫描：下次攻击+" + str(int(effect.next_attack_bonus)))
		battle_hud.add_log("下次攻击伤害 [color=#FFD700]+" + str(int(effect.next_attack_bonus)) + "[/color]", Color.WHITE)

	if effect.has("inject_target"):
		var inject_amount = int(effect.inject_target)
		for hc in hand:
			if hc != card and hc.card_def.get("evolution_family", "") != "" and hc.card_def.get("ep_to_evolve", -1) > 0:
				ep_manager.inject_to_card_free(hc, inject_amount)
				hc.update_evolution_progress(ep_manager.get_card_ep_progress(hc))
				hc.update_ep_text(ep_manager.get_card_ep_text(hc))
				battle_hud.show_message("快速注入 → " + hc.card_def.get("name", "卡牌"))
				battle_hud.add_log("快速注入 [color=#FFD700]+" + str(inject_amount) + "[/color] EP → " + hc.card_def.get("name", "卡牌"), Color.WHITE)
				_animate_inject(hc)
				break

	if effect.has("inject_program"):
		var inject_amount = int(effect.inject_program)
		for hc in hand:
			if hc != card and hc.card_def.get("type", -1) == CardDatabase.CardType.PROGRAM and hc.card_def.get("ep_to_evolve", -1) > 0:
				ep_manager.inject_to_card_free(hc, inject_amount)
				hc.update_evolution_progress(ep_manager.get_card_ep_progress(hc))
				hc.update_ep_text(ep_manager.get_card_ep_text(hc))
				battle_hud.show_message("注入程序 → " + hc.card_def.get("name", "卡牌"))
				battle_hud.add_log("注入程序 [color=#00BFFF]+" + str(inject_amount) + "[/color] EP → " + hc.card_def.get("name", "卡牌"), Color.WHITE)
				_animate_inject(hc)
				break

	var was_bloom = card.is_bloom
	var card_id = card.card_def.get("card_id", "")

	_animate_play_card(card)
	card.is_bloom = false
	card.cost_override = -1

	hand.erase(card)
	discard.append(card_id)
	_reposition_hand()

	if was_bloom:
		extra_play_available = true
		battle_hud.show_message("⚡ 进化绽放！可额外行动一次！")

func _animate_play_card(card: CardUI):
	var target = Vector2(960, 380)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(card, "position", target, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "scale", Vector2(1.4, 1.4), 0.12)
	tween.tween_property(card, "modulate:a", 0.0, 0.35).set_delay(0.15)
	_create_particles(card.global_position, card.card_def.get("type", 0))
	tween.finished.connect(card.queue_free)

func _animate_inject(card: CardUI):
	var tween = create_tween()
	tween.tween_property(card, "scale", Vector2(1.12, 1.12), 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_IN)
	card.modulate = Color.CYAN
	tween.tween_property(card, "modulate", Color.WHITE, 0.25)

func _animate_ep_flow_to_reserve(amount: int):
	var start_pos = Vector2(645, 64)
	var end_pos = Vector2(960, 67)

	for i in range(amount):
		var dot = ColorRect.new()
		dot.size = Vector2(10, 10)
		dot.color = Color("#FFD700")
		dot.position = start_pos
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		float_layer.add_child(dot)

		var tween = create_tween().set_parallel(true)
		tween.tween_property(dot, "position", end_pos + Vector2(randf_range(-30, 30), randf_range(-15, 15)), 0.6).set_delay(i * 0.08).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(dot, "scale", Vector2(0.3, 0.3), 0.6).set_delay(i * 0.08)
		tween.tween_property(dot, "modulate:a", 0.0, 0.3).set_delay(i * 0.08 + 0.3)
		tween.finished.connect(dot.queue_free)

func _float_damage(amount: int, pos: Vector2):
	var label = Label.new()
	label.text = "-" + str(amount)
	label.add_theme_color_override("font_color", Color("#FF3B3B"))
	label.add_theme_font_size_override("font_size", 48)
	label.position = pos
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_layer.add_child(label)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 100, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.finished.connect(label.queue_free)

func _float_block(amount: int, pos: Vector2):
	var label = Label.new()
	label.text = "+" + str(amount)
	label.add_theme_color_override("font_color", Color("#3B8CFF"))
	label.add_theme_font_size_override("font_size", 42)
	label.position = pos
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_layer.add_child(label)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 80, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tween.finished.connect(label.queue_free)

func _float_text(text: String, pos: Vector2, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 28)
	label.position = pos
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_layer.add_child(label)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.1)
	tween.finished.connect(label.queue_free)

func _create_particles(pos: Vector2, card_type: int):
	var colors = [
		Color("#FF3B3B"),
		Color("#3B8CFF"),
		Color("#B03BFF"),
		Color("#00BFFF"),
	]
	var color = colors[card_type] if card_type < colors.size() else Color.WHITE

	for i in range(16):
		var rect = ColorRect.new()
		rect.size = Vector2(8, 8)
		rect.color = color
		rect.position = pos
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		float_layer.add_child(rect)

		var angle = randf_range(0, TAU)
		var dist = randf_range(50, 150)
		var tween = create_tween().set_parallel(true)
		tween.tween_property(rect, "position", Vector2(pos.x + cos(angle) * dist, pos.y + sin(angle) * dist), 0.5)
		tween.tween_property(rect, "modulate:a", 0.0, 0.5)
		tween.tween_property(rect, "scale", Vector2.ZERO, 0.5)
		tween.finished.connect(rect.queue_free)

func _bloom_screen_flash():
	var flash = ColorRect.new()
	flash.size = Vector2(1920, 1080)
	flash.color = Color.WHITE
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.8, 0.06)
	tween.tween_property(flash, "modulate:a", 0.0, 0.5)
	tween.tween_callback(flash.queue_free)

# === Phase Transition Effect (Boss) ===

func _on_enemy_phase_changed(new_phase: int):
	if new_phase == 2:
		_phase_transition_effect()

func _phase_transition_effect():
	# Red flash
	var flash = ColorRect.new()
	flash.size = Vector2(1920, 1080)
	flash.color = Color("#FF0000")
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 150
	add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.6, 0.15)
	tween.tween_property(flash, "modulate:a", 0.0, 0.5)
	tween.tween_callback(flash.queue_free)

	# Screen shake
	var original_pos = position
	var shake_tween = create_tween()
	for i in range(10):
		var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		shake_tween.tween_property(self, "position", original_pos + offset, 0.05)
	shake_tween.tween_property(self, "position", original_pos, 0.05)

	# Red particles burst
	for i in range(24):
		var rect = ColorRect.new()
		rect.size = Vector2(6, 6)
		rect.color = Color("#FF1A1A")
		rect.position = enemy.position
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		float_layer.add_child(rect)

		var angle = randf_range(0, TAU)
		var dist = randf_range(80, 200)
		var p_tween = create_tween().set_parallel(true)
		p_tween.tween_property(rect, "position", Vector2(enemy.position.x + cos(angle) * dist, enemy.position.y + sin(angle) * dist), 0.8)
		p_tween.tween_property(rect, "modulate:a", 0.0, 0.8)
		p_tween.tween_property(rect, "scale", Vector2.ZERO, 0.8)
		p_tween.finished.connect(rect.queue_free)

	battle_hud.show_message("⚠ 湮灭协议 进入 Phase 2！终极模式启动！")

# === End Turn & Enemy Turn ===

func _on_deck_btn_pressed():
	"""Handle deck viewer button — show current deck as a popup overlay."""
	# Disable card hand interaction while deck viewer is open
	card_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for card in card_hand.get_children():
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var current_deck = _build_evolved_deck()
	battle_hud.show_deck_viewer(current_deck, ep_manager)

	# Restore card interaction when the viewer closes
	if not battle_hud.deck_viewer_closed.is_connected(_on_deck_viewer_closed):
		battle_hud.deck_viewer_closed.connect(_on_deck_viewer_closed)


func _on_deck_viewer_closed():
	"""Restore card hand interaction after deck viewer is closed."""
	card_hand.mouse_filter = Control.MOUSE_FILTER_STOP
	for card in card_hand.get_children():
		card.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_end_turn():
	if not is_player_turn or battle_over:
		return
	if discard_selection_mode:
		battle_hud.show_message("请先弃掉多余手牌！")
		return

	_deselect_card()
	battle_hud.add_log("── 结束回合 ──", Color("#888888"))

	if ep_manager.current_ep > 0:
		var remaining = ep_manager.current_ep
		_animate_ep_flow_to_reserve(remaining)
		await get_tree().create_timer(0.5).timeout
		ep_manager.inject_to_reserve()
		battle_hud.show_message("剩余 EP 已注入储备池")
		battle_hud.add_log("剩余 [color=#FFD700]" + str(remaining) + " EP[/color] → 储备池", Color.WHITE)

	# 屏障转化: convert leftover barrier to max HP
	if RunRewardState.has_protocol("屏障转化"):
		RunRewardState.apply_barrier_protocol(player)

	is_player_turn = false
	_enemy_turn()

func _enemy_turn():
	var hp_before_enemy = player.current_hp
	enemy.advance_cycle()
	var action = enemy.execute_intent()
	var action_desc = action.get("desc", "未知行动")
	battle_hud.add_log("▶ [color=#FF6B35]" + enemy.enemy_name + "[/color]: " + action_desc, Color("#FF6B35"))

	match action.type:
		"attack", "heavy", "shock", "data_slash", "corrode", "suppress":
			# Standard damage actions
			battle_hud.play_enemy_attack()
			var had_block = player.block > 0
			var had_barrier = player.barrier > 0
			var had_shield = player.energy_shield > 0
			var barrier_before = player.barrier
			var block_before = player.block
			var _hp_before = player.current_hp
			if had_block:
				_float_text("格挡", player.position + Vector2(40, -60), Color("#3B8CFF"))
			var pierce = action.get("pierce_shield", 0)
			var actual = player.take_damage(action.damage, pierce)
			if actual > 0:
				_float_damage(actual, player.position + Vector2(50, -30))
				battle_hud.play_player_hit("damage")
				battle_hud.add_log("受到 [color=#FF3B3B]" + str(actual) + "[/color] 点伤害", Color.WHITE)
			elif had_barrier and player.barrier < barrier_before:
				battle_hud.play_player_hit("barrier")
				battle_hud.add_log("伤害被 [color=#00FFFF]屏障[/color] 吸收", Color.WHITE)
			elif had_block and player.block < block_before:
				battle_hud.play_player_hit("block")
				battle_hud.add_log("伤害被 [color=#3B8CFF]格挡[/color] 吸收", Color.WHITE)
			elif had_shield:
				battle_hud.play_player_hit("energy_shield")
				battle_hud.add_log("伤害被 [color=#FFD700]能量护盾[/color] 减免", Color.WHITE)
			battle_hud.update_player_hp(player.current_hp, player.max_hp)
			battle_hud.show_message(enemy.enemy_name + " 造成 " + str(action.damage) + " 点伤害！")

			# Corrode: apply vulnerable to player
			if action.type == "corrode":
				var vuln = enemy.current_intent.get("vulnerable", 1)
				player.vulnerable_stacks += vuln
				battle_hud.show_message(enemy.enemy_name + " 造成 " + str(action.damage) + " 伤 + 脆弱" + str(vuln) + "！")

			# Suppress: apply vulnerable to player
			if action.type == "suppress":
				var vuln = enemy.current_intent.get("vulnerable", 1)
				player.vulnerable_stacks += vuln
				battle_hud.show_message(enemy.enemy_name + " 协议·压制！" + str(action.damage) + " 伤 + 脆弱" + str(vuln))

		"defend", "recharge", "reconstruct":
			# Shield/block actions
			battle_hud.update_enemy_shield(enemy.shield)
			battle_hud.show_message(enemy.enemy_name + " 获得 " + str(action.block) + " 点护盾！")
			# Recharge: enemy gains self-vulnerable
			if action.type == "recharge":
				battle_hud.show_message(enemy.enemy_name + " 充电中！获得 " + str(action.block) + " 护盾，但自身脆弱！")

		"buff":
			battle_hud.show_message(enemy.enemy_name + " 力量 +" + str(action.damage) + "！")

		"charge":
			battle_hud.show_message(enemy.enemy_name + " 正在蓄力...下一击将是毁灭性的！")

		"overload_burst":
			# High damage + remove own shield
			battle_hud.play_enemy_attack()
			if player.block > 0:
				_float_text("格挡", player.position + Vector2(40, -60), Color("#3B8CFF"))
			var pierce = action.get("pierce_shield", 0)
			var actual = player.take_damage(action.damage, pierce)
			if actual > 0:
				_float_damage(actual, player.position + Vector2(50, -30))
				battle_hud.play_player_hit("damage")
			battle_hud.update_player_hp(player.current_hp, player.max_hp)
			battle_hud.update_enemy_shield(enemy.shield)
			battle_hud.show_message(enemy.enemy_name + " 过载爆发！" + str(action.damage) + " 伤害，护盾已清除！")

		"pollute":
			# Data pollution: reduce player barrier gain next turn
			var barrier_reduce = enemy.current_intent.get("barrier_reduce", 2)
			barrier_reduction_next_turn += barrier_reduce
			battle_hud.show_message(enemy.enemy_name + " 数据污染！下回合屏障获取 -" + str(barrier_reduce))

		"overload":
			# Boss overload: high damage + self damage
			battle_hud.play_enemy_attack()
			if player.block > 0:
				_float_text("格挡", player.position + Vector2(40, -60), Color("#3B8CFF"))
			var pierce = action.get("pierce_shield", 0)
			var actual = player.take_damage(action.damage, pierce)
			if actual > 0:
				_float_damage(actual, player.position + Vector2(50, -30))
				battle_hud.play_player_hit("damage")
			battle_hud.update_player_hp(player.current_hp, player.max_hp)
			battle_hud.update_enemy_hp(enemy.current_hp, enemy.max_hp)
			battle_hud.show_message(enemy.enemy_name + " 协议·过载！" + str(action.damage) + " 伤害（自损3）！")

		"signal_jam":
			# Void beacon: damage + discard highest cost card
			battle_hud.play_enemy_attack()
			if player.block > 0:
				_float_text("格挡", player.position + Vector2(40, -60), Color("#3B8CFF"))
			var pierce = action.get("pierce_shield", 0)
			var actual = player.take_damage(action.damage, pierce)
			if actual > 0:
				_float_damage(actual, player.position + Vector2(50, -30))
				battle_hud.play_player_hit("damage")
			battle_hud.update_player_hp(player.current_hp, player.max_hp)
			var discard_count = enemy.current_intent.get("discard", 1)
			_force_discard_highest_cost(discard_count)
			battle_hud.show_message(enemy.enemy_name + " 信号干扰！" + str(action.damage) + " 伤 + 弃牌！")

		"void_drain":
			# Void beacon: damage + heal
			battle_hud.play_enemy_attack()
			if player.block > 0:
				_float_text("格挡", player.position + Vector2(40, -60), Color("#3B8CFF"))
			var pierce = action.get("pierce_shield", 0)
			var actual = player.take_damage(action.damage, pierce)
			if actual > 0:
				_float_damage(actual, player.position + Vector2(50, -30))
				battle_hud.play_player_hit("damage")
			battle_hud.update_player_hp(player.current_hp, player.max_hp)
			battle_hud.update_enemy_hp(enemy.current_hp, enemy.max_hp)
			var heal_amt = enemy.current_intent.get("heal", 5)
			_float_text("+" + str(heal_amt), enemy.position + Vector2(40, -30), Color.GREEN)
			battle_hud.show_message(enemy.enemy_name + " 虚空汲取！" + str(action.damage) + " 伤 + 回复" + str(heal_amt) + "！")

		"annihilate":
			# Boss annihilate: bypasses barrier (still blocked by block and energy shield)
			battle_hud.play_enemy_attack()
			var raw_dmg = action.damage + player.vulnerable_stacks
			var pierce = action.get("pierce_shield", 0)
			var effective_shield = max(0, player.energy_shield - pierce)
			var after_es = max(0, raw_dmg - effective_shield)
			var blocked = min(player.block, after_es)
			player.block -= blocked
			player.block_changed.emit(player.block)
			var final_dmg = after_es - blocked
			player.current_hp = max(0, player.current_hp - final_dmg)
			player.hp_changed.emit(player.current_hp, player.max_hp)
			if final_dmg > 0:
				_float_damage(final_dmg, player.position + Vector2(50, -30))
				battle_hud.play_player_hit("damage")
			if blocked > 0:
				_float_text("格挡", player.position + Vector2(40, -60), Color("#3B8CFF"))
				battle_hud.play_player_hit("block")
			elif player.energy_shield > 0:
				battle_hud.play_player_hit("energy_shield")
			battle_hud.update_player_hp(player.current_hp, player.max_hp)
			battle_hud.show_message(enemy.enemy_name + " 终极·湮灭！" + str(action.damage) + " 伤害（无视屏障）！")
			if player.current_hp <= 0:
				player.player_died.emit()

		"nihil":
			# Boss nihil: clear player energy shields + damage
			battle_hud.play_enemy_attack()
			battle_hud.play_player_hit("energy_shield")
			player.energy_shield = 0
			player.energy_shield_changed.emit(player.energy_shield)
			if player.block > 0:
				_float_text("格挡", player.position + Vector2(40, -60), Color("#3B8CFF"))
			var pierce = action.get("pierce_shield", 0)
			var actual = player.take_damage(action.damage, pierce)
			if actual > 0:
				_float_damage(actual, player.position + Vector2(50, -30))
				battle_hud.play_player_hit("damage")
			battle_hud.update_player_hp(player.current_hp, player.max_hp)
			battle_hud.show_message(enemy.enemy_name + " 终极·虚无！能量护盾已清除！" + str(action.damage) + " 伤害！")

	turn_ended.emit()
	# 追踪玩家是否在敌人回合受到了实际HP伤害（D06回滚用）
	player_damaged_last_turn = (player.current_hp < hp_before_enemy)
	await get_tree().create_timer(0.5).timeout
	if not battle_over:
		_start_player_turn()

# === Player Info Overlay ===

func _create_player_info_overlay():
	player_info_overlay = Control.new()
	player_info_overlay.name = "PlayerInfoOverlay"
	player_info_overlay.anchor_right = 1.0
	player_info_overlay.anchor_bottom = 1.0
	player_info_overlay.visible = false
	player_info_overlay.z_index = 200
	add_child(player_info_overlay)

	var dim_bg = ColorRect.new()
	dim_bg.size = Vector2(1920, 1080)
	dim_bg.color = Color(0, 0, 0, 0.7)
	player_info_overlay.add_child(dim_bg)

	var panel = Panel.new()
	panel.position = Vector2(460, 190)
	panel.size = Vector2(1000, 750)
	var char_info = CardDatabase.get_character_info(RunRewardState.selected_character)
	var char_color = char_info.get("color", Color("#00F0FF"))
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#0A0E27")
	panel_style.border_color = char_color
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	player_info_overlay.add_child(panel)

	var title = Label.new()
	title.text = char_info.get("name", "渗透者")
	title.position = Vector2(50, 30)
	title.size = Vector2(900, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", char_color)
	panel.add_child(title)

	var sep = ColorRect.new()
	sep.position = Vector2(100, 90)
	sep.size = Vector2(800, 2)
	sep.color = char_color
	panel.add_child(sep)

	var char_hp = char_info.get("hp", 70)
	var stats_text = "HP: " + str(char_hp) + "  |  EP/回合: 3  |  手牌上限: 5"
	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.position = Vector2(50, 110)
	stats_label.size = Vector2(900, 36)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 22)
	stats_label.add_theme_color_override("font_color", Color("#FFD700"))
	panel.add_child(stats_label)

	# 角色特有机制 + 通用机制
	var mechanics = []
	if RunRewardState.selected_character == "crasher":
		mechanics = [
			["崩溃", "给敌人叠加崩溃层数，每层使下次攻击伤害+3，攻击命中后清零（上限5层）"],
			["崩溃诱导", "0费施加崩溃，为后续攻击做铺垫"],
			["数据撕裂", "若敌有崩溃，伤害大幅提升"],
			["递归打击", "伤害+复制崩溃层数，维持崩溃不断"],
			["弱点扫描", "本回合下次攻击获得额外伤害"],
			["数据收割", "崩溃≥3层时引爆，造成巨额伤害"],
		]
	else:
		mechanics = [
			["穿甲", "无视敌人ICE减伤，直接造成伤害"],
			["屏障", "每次注入 EP 获得 2 点屏障，吸收伤害优先于格挡，下回合消失"],
			["注入进化", "右键点击程序牌注入 EP，累积到阈值自动进化"],
			["进化绽放", "程序牌达到 Lv.3 时触发：费用变为 0，可额外行动一次"],
		]
	# 通用机制
	mechanics.append_array([
		["打出卡牌", "左键点击手牌，消耗 EP 执行卡牌效果"],
		["格挡", "使用技能牌获得，吸收本回合伤害，下回合消失"],
		["能量护盾", "储备池达到 5/10/15 时获得，每层永久减免 1 点所有伤害"],
		["EP 储备池", "回合结束时剩余 EP 自动注入储备池（上限 15），达到 5/10 获得护盾"],
	])

	var y_offset = 160
	for m in mechanics:
		var name_lbl = Label.new()
		name_lbl.text = "■ " + m[0]
		name_lbl.position = Vector2(60, y_offset)
		name_lbl.size = Vector2(220, 28)
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color("#00BFFF"))
		panel.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = m[1]
		desc_lbl.position = Vector2(290, y_offset)
		desc_lbl.size = Vector2(650, 28)
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", Color("#CCCCCC"))
		panel.add_child(desc_lbl)

		y_offset += 50

	var back_btn = Button.new()
	back_btn.text = "返回战斗"
	back_btn.position = Vector2(380, 680)
	back_btn.size = Vector2(240, 52)
	back_btn.add_theme_font_size_override("font_size", 22)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#3B3B6B")
	btn_style.border_color = char_color
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	back_btn.add_theme_stylebox_override("normal", btn_style)
	back_btn.pressed.connect(_hide_player_info)
	panel.add_child(back_btn)

func _on_info_icon_hover(icon: Button, entered: bool):
	if entered:
		var tween = create_tween()
		tween.tween_property(icon, "scale", Vector2(1.35, 1.35), 0.1).set_ease(Tween.EASE_OUT)
	else:
		var tween = create_tween()
		tween.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN)

func _show_player_info():
	player_info_overlay.visible = true

func _hide_player_info():
	player_info_overlay.visible = false

# === Signal Handlers ===

func _on_player_hp_changed(current: int, max_hp: int):
	battle_hud.update_player_hp(current, max_hp)

func _on_player_block_changed(block: int):
	battle_hud.update_block(block)

func _on_player_barrier_changed(barrier: int):
	battle_hud.update_barrier(barrier)

func _on_player_energy_shield_changed(shields: int):
	battle_hud.update_energy_shield(shields)

func _on_enemy_hp_changed(current: int, max_hp: int):
	battle_hud.update_enemy_hp(current, max_hp)

func _on_enemy_ice_changed(ice: int):
	battle_hud.update_ice(ice)

func _on_enemy_crash_changed(crash_stacks: int):
	battle_hud.update_enemy_crash(crash_stacks)

func _on_enemy_intent_changed(intent: Dictionary):
	battle_hud.update_intent(intent)

func _on_ep_changed(current: int, max_ep: int):
	battle_hud.update_ep(current, max_ep)

func _on_reserve_changed(current: int, max_reserve: int):
	battle_hud.update_reserve(current, max_reserve)
	_sync_shield_from_reserve()

func _sync_shield_from_reserve():
	"""Dynamically sync energy shield layers based on current reserve pool level."""
	var pool = ep_manager.reserve_pool
	var expected = 0
	if pool >= 15:
		expected = 3
	elif pool >= 10:
		expected = 2
	elif pool >= 5:
		expected = 1
	if player.energy_shield < expected:
		player.add_energy_shield(expected - player.energy_shield)
	elif player.energy_shield > expected:
		player.energy_shield = expected
		player.energy_shield_changed.emit(player.energy_shield)

func _on_card_evolved(_card_id: String, new_def: Dictionary, is_bloom: bool):
	var card_name = new_def.get("name", "???")
	var level = new_def.get("level", 1)
	battle_hud.show_message("⚡ 卡牌进化！ → " + card_name)
	battle_hud.add_log("⚡ 卡牌进化！→ [color=#FFD700]" + card_name + "[/color] (Lv." + str(level) + ")", Color("#FFD700"))
	if is_bloom:
		battle_hud.show_message("✦ 进化绽放！费用变为 0，可额外行动一次！")
		battle_hud.add_log("✦ [color=#FF6BFF]进化绽放！[/color]费用变为0", Color("#FF6BFF"))
		_bloom_screen_flash()
	# Refresh deck viewer if open (real-time update)
	var current_deck = _build_evolved_deck()
	battle_hud.refresh_deck_viewer(current_deck, ep_manager)

func _on_barrier_granted(amount: int):
	player.add_barrier(amount)
	_float_text("屏障+" + str(amount), player.position + Vector2(60, -30), Color.CYAN)
	battle_hud.add_log("注入获得 [color=#00FFFF]+" + str(amount) + " 屏障[/color]", Color.WHITE)
	if barrier_reduction_next_turn > 0:
		battle_hud.show_message("数据污染！屏障获取 -" + str(barrier_reduction_next_turn))

func _on_milestone_reached(threshold: int):
	var shield_level = threshold / 5
	battle_hud.show_message("储备池达到 " + str(threshold) + "！能量护盾提升（全伤害-" + str(shield_level) + "）")
	battle_hud.add_log("⚡ 储备池里程碑 [color=#FFD700]" + str(threshold) + "[/color]！能量护盾提升", Color("#FFD700"))
	if threshold == 15:
		battle_hud.show_message("储备池已满！可免费升级手牌中一张程序牌！")

func _on_free_upgrade_available():
	battle_hud.show_message("选择一张程序牌免费升级！")

func _on_turn_started():
	battle_hud.show_message("你的回合 — 左键打出卡牌 | 右键注入 EP 进化")
	turn_count += 1
	battle_hud.add_log("═══ 第 [color=#00F0FF]" + str(turn_count) + "[/color] 回合 ═══", Color("#00F0FF"))

	# 超限跃迁: lose 5 HP at start of first turn each battle
	if RunRewardState.has_protocol("超限跃迁"):
		if player.current_hp > 5:
			player.current_hp -= 5
		else:
			player.current_hp = 1
		player.hp_changed.emit(player.current_hp, player.max_hp)
		battle_hud.update_player_hp(player.current_hp, player.max_hp)
		_float_text("-5 HP (超限跃迁)", player.position + Vector2(40, -30), Color.RED)
		battle_hud.add_log("超限跃迁协议：失去 [color=#FF3B3B]5 HP[/color]", Color("#FF6B35"))

func _on_battle_won():
	if battle_over:
		return  # Guard against duplicate signal (multi-hit cards)
	battle_over = true
	is_player_turn = false
	_deselect_card()
	# Clear temp bonuses from the battle that just ended (they were applied at battle start)
	RunRewardState.clear_next_battle_bonus(ep_manager)

	# v1.6: Sync evolution state and HP back to RunRewardState
	if RunRewardState.run_active:
		RunRewardState.sync_from_ep_manager(ep_manager)
		RunRewardState.sync_hp_from_player(player)
		# Calculate data fragments earned
		var is_elite = RunRewardState.pending_battle.get("is_elite", false)
		var fragments = randi_range(40, 50) if is_elite else randi_range(20, 30)
		RunRewardState.add_fragments(fragments)
		RunRewardState.fragments_earned = fragments
		battle_hud.add_log("💠 获得 [color=#00BFFF]" + str(fragments) + " 数据碎片[/color]", Color("#00BFFF"))

	battle_hud.show_message("胜利！击溃了 " + enemy.enemy_name + "！")
	battle_hud.add_log("✅ 胜利！击溃 [color=#3BFF8C]" + enemy.enemy_name + "[/color]", Color("#3BFF8C"))

	for card in hand:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Show reward panel after short delay
	await get_tree().create_timer(1.5).timeout
	_show_reward_panel()

func _on_battle_won_internal():
	pass

# === Reward System ===

func _show_reward_panel():
	var reward_panel = RewardPanel.new()
	reward_panel.name = "RewardPanel"
	reward_panel.anchor_right = 1.0
	reward_panel.anchor_bottom = 1.0
	add_child(reward_panel)
	reward_panel.setup(ep_manager)
	reward_panel.reward_chosen.connect(_on_reward_chosen)
	reward_panel.show_panel()

func _on_reward_chosen(reward_type: String, extra_data: Dictionary):
	# Guard against duplicate reward processing
	if reward_pending:
		return
	reward_pending = true

	var reward_name = _get_reward_name(reward_type)
	battle_hud.add_log("🎁 选择奖励：[color=#FFD700]" + reward_name + "[/color]", Color("#FFD700"))

	# Apply immediate effects
	match reward_type:
		"heal":
			var amount = extra_data.get("amount", 25)
			player.heal(amount)
			_float_text("+" + str(amount), player.position + Vector2(40, -30), Color.GREEN)
			battle_hud.update_player_hp(player.current_hp, player.max_hp)
			battle_hud.add_log("  → 恢复 [color=#3BFF8C]" + str(amount) + "[/color] HP", Color("#3BFF8C"))
		"evolution_module":
			var mode = extra_data.get("mode", "")
			if mode == "family":
				_handle_reward_evolution(extra_data)
				var family = extra_data.get("family", "")
				var amount = extra_data.get("amount", 8)
				battle_hud.add_log("  → [color=#FFD700]+" + str(amount) + " EP[/color] 注入进度", Color("#FFD700"))
		"energy_core":
			battle_hud.add_log("  → 储备池 [color=#FFD700]+5[/color]", Color("#FFD700"))
		"tactical_protocol":
			battle_hud.add_log("  → 下场战斗 [color=#00FFFF]+6 屏障[/color] [color=#3B8CFF]+2 格挡[/color]", Color("#00FFFF"))
		"overclock_chip":
			battle_hud.add_log("  → 下场战斗 [color=#FFD700]每回合+1 EP[/color]", Color("#FFD700"))
		"max_hp_up":
			# Immediately apply permanent bonus so sync_hp_from_player captures it
			RunRewardState.apply_permanent_bonus(player)
			battle_hud.update_player_hp(player.current_hp, player.max_hp)
			battle_hud.add_log("  → [color=#9B3BFF]永久+10 最大HP[/color]", Color("#9B3BFF"))
		"random_card":
			var card_id = extra_data.get("card_id", "")
			battle_hud.add_log("  → 获得新卡牌 [color=#00F0FF]" + card_id + "[/color]", Color("#00F0FF"))
		"copy_card":
			var card_id = extra_data.get("card_id", "")
			battle_hud.add_log("  → 复制卡牌 [color=#00F0FF]" + card_id + "[/color]", Color("#00F0FF"))

	battle_hud.show_message("获得奖励：" + reward_name)

	# v1.6: Sync final state and return to map
	if RunRewardState.run_active:
		RunRewardState.sync_from_ep_manager(ep_manager)
		RunRewardState.sync_hp_from_player(player)
		RunRewardState.last_battle_won = true

	await get_tree().create_timer(0.8).timeout

	if RunRewardState.run_active:
		# v1.6: Return to map screen (map handles node completion, chapter transitions)
		get_tree().change_scene_to_file("res://scenes/map_screen.tscn")
	else:
		# Legacy fallback: linear battle sequence
		current_battle_index += 1
		if current_battle_index < battle_sequence.size():
			if current_battle_index == 6 and current_chapter == 1:
				_show_core_breakthrough()
			else:
				battle_hud.show_message("新的敌人出现了！")
				await get_tree().create_timer(1.0).timeout
				_start_next_battle()
		else:
			battle_hud.show_message("所有敌人已被击败！你赢得了胜利！")
			battle_hud.add_log("🏆 恭喜！所有敌人已被击败！", Color("#FFD700"))

	reward_pending = false

func _show_core_breakthrough():
	"""Show core breakthrough protocol selection after Chapter 1 boss."""
	var protocol_panel = RewardPanel.new()
	protocol_panel.name = "CoreBreakthroughPanel"
	protocol_panel.anchor_right = 1.0
	protocol_panel.anchor_bottom = 1.0
	add_child(protocol_panel)
	protocol_panel.show_core_breakthrough()
	protocol_panel.reward_chosen.connect(_on_core_breakthrough_chosen)


func _on_core_breakthrough_chosen(_reward_type: String, extra_data: Dictionary):
	"""Handle core breakthrough protocol selection."""
	# Guard against duplicate processing
	if reward_pending:
		return
	reward_pending = true

	var protocol_name = extra_data.get("protocol_name", "")
	if protocol_name != "":
		RunRewardState.add_protocol(protocol_name)
		battle_hud.show_message("已激活突破协议：" + protocol_name)

	# Apply immediate protocol effects
	if protocol_name == "基因飞升":
		var base_deck = CardDatabase.get_starting_deck_for_character(RunRewardState.selected_character)
		for card_id in base_deck:
			var def_entry = CardDatabase.get_card_def(card_id)
			var family = def_entry.get("evolution_family", "")
			if family != "":
				ep_manager.card_ep_by_family[family] = 8
				ep_manager.family_max_level[family] = 2

	await get_tree().create_timer(0.5).timeout

	# Start Chapter 2
	current_chapter = 2
	current_battle_index = 6  # enemy_g index

	# Clean up protocol panel
	var panel = get_node_or_null("CoreBreakthroughPanel")
	if panel:
		panel.queue_free()

	battle_hud.show_message("===== 第二章：深层网络 =====")
	await get_tree().create_timer(1.0).timeout
	_start_next_battle()

	reward_pending = false


func _handle_reward_evolution(extra_data: Dictionary):
	"""Handle EP injection from evolution module reward — injects through first matching card for proper evolution."""
	var family = extra_data.get("family", "")
	var amount = extra_data.get("amount", 8)
	if family == "":
		return

	# Find all matching cards in hand
	var matching_cards = []
	for card in hand:
		if card.card_def.get("evolution_family", "") == family:
			matching_cards.append(card)

	if matching_cards.is_empty():
		# No cards in hand — track EP and update evolution level for next battle
		ep_manager.add_progress_to_family(family, amount)
		# Check if accumulated EP crosses an evolution threshold
		var total = ep_manager.card_ep_by_family.get(family, 0)
		if total >= 20:
			ep_manager.family_max_level[family] = 3
		elif total >= 8:
			ep_manager.family_max_level[family] = 2
		battle_hud.show_message("EP 进度 +" + str(amount))
		return

	# Inject EP via the first matching card (handles evolution properly)
	var old_card_id = matching_cards[0].card_def.get("card_id", "")
	ep_manager.inject_to_card_free(matching_cards[0], amount)
	var new_card_id = matching_cards[0].card_def.get("card_id", "")
	var evolved = (new_card_id != old_card_id)

	if evolved:
		# Sync all other matching cards to the evolved version
		var new_def = CardDatabase.get_card_def(new_card_id)
		if not new_def.is_empty():
			for i in range(1, matching_cards.size()):
				var card = matching_cards[i]
				card.card_def = new_def.duplicate()
				card.refresh_display()
				card.injected_ep = 0
				if new_def.get("level", 1) >= 3:
					card.is_bloom = true
					card.cost_override = 0
				card.play_evolution_animation()

		# Update deck entries to the new card_id
		for i in range(deck.size()):
			var deck_def = CardDatabase.get_card_def(deck[i])
			if deck_def.get("evolution_family", "") == family:
				deck[i] = new_card_id

		battle_hud.show_message("卡牌已进化！")
	else:
		# Update progress display on all matching cards
		for card in matching_cards:
			card.update_evolution_progress(ep_manager.get_card_ep_progress(card))
			card.update_ep_text(ep_manager.get_card_ep_text(card))
		battle_hud.show_message("EP 进度 +" + str(amount))

func _get_reward_name(reward_type: String) -> String:
	match reward_type:
		"evolution_module": return "进化模块"
		"energy_core": return "能源核心"
		"tactical_protocol": return "战术协议"
		"overclock_chip": return "超频芯片"
		"heal": return "纳米修复"
		"max_hp_up": return "基因强化"
		"random_card": return "随机卡牌"
		"copy_card": return "复制卡牌"
		_: return reward_type

func _apply_enemy_strength_bonus(bonus: int):
	"""Apply strength bonus to enemy attack intents (from events like 'report merchant')."""
	if not enemy or bonus <= 0:
		return
	# Increase current intent value if it's an attack type
	if enemy.current_intent.has("value"):
		var intent_type = enemy.current_intent.get("type", "")
		var attack_types = ["attack", "shock", "corrode", "data_slash", "heavy",
						   "overload_burst", "suppress", "overload", "annihilate",
						   "devour", "regurgitate", "format", "grid_overload",
						   "berserk_overwrite", "signal_jam", "void_drain",
						   "suppress_barrier"]
		if intent_type in attack_types:
			enemy.current_intent["value"] += bonus
			battle_hud.update_intent(enemy.current_intent)

func _start_next_battle():
	# NOTE: Do NOT clear temp bonuses here — they must persist through the battle
	# they were chosen for. Old bonuses are cleared at battle end (_on_battle_won / _on_battle_lost).
	# Rebuild deck from base + evolutions, discard old state
	deck = _build_evolved_deck()
	deck.shuffle()
	discard.clear()

	# Apply chapter 2 protocol effects
	if RunRewardState.has_protocol("超限跃迁"):
		MAX_HAND_SIZE = 6
	if RunRewardState.has_protocol("涌动核心"):
		RunRewardState.apply_reserve_protocol(ep_manager)

	hand.clear()
	for child in card_hand.get_children():
		child.queue_free()

	battle_over = false
	barrier_reduction_next_turn = 0
	ep_manager.set_barrier_reduction(0)
	_setup_current_enemy()
	ep_manager.milestones_reached.clear()

	# Log new battle start
	battle_hud.add_log("═══════════════════════════", Color("#444444"))
	battle_hud.add_log("⚔️ 新战斗：对阵 [color=#FF6B35]" + enemy.enemy_name + "[/color]", Color("#FF6B35"))

	# Apply permanent bonuses (max HP)
	RunRewardState.apply_permanent_bonus(player)
	battle_hud.update_player_hp(player.current_hp, player.max_hp)

	# Apply next battle bonuses (barrier, block, EP)
	RunRewardState.apply_next_battle_bonus(player, ep_manager)

	_start_player_turn()


func _build_evolved_deck() -> Array:
	"""Rebuild the deck, upgrading cards to their evolved versions.
	v1.6: Uses RunRewardState.player_deck (supports added/removed cards)."""
	var base_ids
	if RunRewardState.run_active and RunRewardState.player_deck.size() > 0:
		base_ids = RunRewardState.player_deck
	else:
		base_ids = CardDatabase.get_starting_deck()
	var result = []
	for card_id in base_ids:
		var evolved_id = ep_manager.get_evolved_card_id_for_family(card_id)
		result.append(evolved_id)
	return result

func _on_battle_lost():
	if battle_over:
		return  # Guard against duplicate signal
	battle_over = true
	is_player_turn = false
	_deselect_card()
	# Clear temp bonuses from the battle that just ended
	RunRewardState.clear_next_battle_bonus(ep_manager)

	# v1.6: Check if we're in a roguelite run (before clearing run_active)
	var was_roguelite = RunRewardState.run_active and RunRewardState.current_map_data.size() > 0

	# Mark run as failed
	RunRewardState.run_active = false
	RunRewardState.last_battle_won = false

	battle_hud.show_message("败北...再来一次吧！")
	var char_name = CardDatabase.get_character_info(RunRewardState.selected_character).get("name", "渗透者")
	battle_hud.add_log("❌ 败北..." + char_name + "已阵亡", Color("#FF3B3B"))

	for card in hand:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# v1.6: In roguelite mode, transition to map for game-over screen
	if was_roguelite:
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/map_screen.tscn")
		return

	# Legacy fallback: show game over overlay
	await get_tree().create_timer(1.5).timeout
	_show_game_over()

func _show_game_over():
	"""Display a game over overlay with stats and a restart button."""
	var overlay = Control.new()
	overlay.name = "GameOverOverlay"
	overlay.layout_mode = 1
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.z_index = 300
	add_child(overlay)

	# Dim background
	var dim_bg = ColorRect.new()
	dim_bg.size = Vector2(1920, 1080)
	dim_bg.color = Color(0, 0, 0, 0.85)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim_bg)

	# Main panel
	var panel = Panel.new()
	panel.position = Vector2(460, 220)
	panel.size = Vector2(1000, 640)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#0A0E27")
	panel_style.border_color = Color("#FF3B3B")
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.shadow_size = 30
	panel_style.shadow_color = Color("#FF3B3B", 0.5)
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)

	# Title
	var title = Label.new()
	title.text = "游戏结束"
	title.position = Vector2(0, 50)
	title.size = Vector2(1000, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#FF3B3B"))
	panel.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "你的进化之旅到此结束"
	subtitle.position = Vector2(0, 120)
	subtitle.size = Vector2(1000, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color("#CCCCCC"))
	panel.add_child(subtitle)

	# Separator
	var sep = ColorRect.new()
	sep.position = Vector2(150, 180)
	sep.size = Vector2(700, 2)
	sep.color = Color("#FF3B3B")
	panel.add_child(sep)

	# Stats section
	var stats_y = 220
	var enemies_defeated = current_battle_index
	var chapter_text = "第一章" if current_chapter == 1 else "第二章"

	var stats_label = Label.new()
	stats_label.text = chapter_text + "  —  击败敌人：" + str(enemies_defeated) + " / " + str(battle_sequence.size())
	stats_label.position = Vector2(0, stats_y)
	stats_label.size = Vector2(1000, 40)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 24)
	stats_label.add_theme_color_override("font_color", Color("#FFD700"))
	panel.add_child(stats_label)

	# Restart button
	var restart_btn = Button.new()
	restart_btn.text = "🔄 重新开始"
	restart_btn.position = Vector2(300, 450)
	restart_btn.size = Vector2(400, 60)
	restart_btn.add_theme_font_size_override("font_size", 28)
	restart_btn.add_theme_color_override("font_color", Color("#FFFFFF"))

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#3B1A1A")
	btn_style.border_color = Color("#FF3B3B")
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.corner_radius_top_left = 12
	btn_style.corner_radius_top_right = 12
	btn_style.corner_radius_bottom_left = 12
	btn_style.corner_radius_bottom_right = 12
	restart_btn.add_theme_stylebox_override("normal", btn_style)

	var hover_style = btn_style.duplicate()
	hover_style.bg_color = Color("#5B2A2A")
	hover_style.border_color = Color("#FF6B6B")
	hover_style.shadow_size = 12
	hover_style.shadow_color = Color("#FF3B3B")
	restart_btn.add_theme_stylebox_override("hover", hover_style)

	restart_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	restart_btn.mouse_entered.connect(func():
		var t = create_tween()
		t.tween_property(restart_btn, "scale", Vector2(1.08, 1.08), 0.1)
	)
	restart_btn.mouse_exited.connect(func():
		var t = create_tween()
		t.tween_property(restart_btn, "scale", Vector2(1.0, 1.0), 0.1)
	)
	restart_btn.pressed.connect(_restart_game)
	panel.add_child(restart_btn)

	# Fade-in animation
	overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)

func _restart_game():
	"""Fully reset all game state and start a new run from the beginning."""
	# Remove game over overlay
	var game_over = get_node_or_null("GameOverOverlay")
	if game_over:
		game_over.queue_free()

	_deselect_card()
	# Log restart
	battle_hud.clear_log()
	battle_hud.add_log("🔄 游戏重新开始", Color("#00F0FF"))

	# Clear hand UI nodes
	for child in card_hand.get_children():
		child.queue_free()
	hand.clear()

	# Reset player
	player.max_hp = 70
	player.current_hp = 70
	player.block = 0
	player.barrier = 0
	player.energy_shield = 0
	player.vulnerable_stacks = 0
	player.block_persist = false
	player.hp_changed.emit(player.current_hp, player.max_hp)
	player.block_changed.emit(player.block)
	player.barrier_changed.emit(player.barrier)
	player.energy_shield_changed.emit(player.energy_shield)

	# Reset EP manager
	ep_manager.full_reset()

	# Reset cross-battle reward state
	RunRewardState.reset()

	# Reset battle manager state
	deck = CardDatabase.get_starting_deck()
	deck.shuffle()
	discard.clear()
	current_battle_index = 0
	current_chapter = 1
	turn_count = 0
	battle_over = false
	is_player_turn = false
	extra_play_available = false
	ep_penalty_next_turn = 0
	barrier_reduction_next_turn = 0
	discard_selection_mode = false
	pending_discard_count = 0
	reward_pending = false
	MAX_HAND_SIZE = 5

	# Reset enemy to first encounter
	_setup_current_enemy()

	# Refresh HUD
	battle_hud.update_player_hp(player.current_hp, player.max_hp)
	battle_hud.update_enemy_hp(enemy.current_hp, enemy.max_hp)
	battle_hud.update_enemy_name(enemy.enemy_name)
	battle_hud.update_ice(enemy.ice)
	battle_hud.update_ep(ep_manager.current_ep, ep_manager.max_ep)

	# Start first turn
	_start_player_turn()

func _on_battle_lost_internal():
	pass

# === External API for TCP Bridge (Training Mode) ===

func set_fast_mode(enabled: bool):
	fast_mode = enabled

func get_bridge_snapshot() -> Dictionary:
	var scene_type = "battle"
	if battle_over:
		if player.current_hp <= 0:
			scene_type = "game_over"
		else:
			scene_type = "battle_won"

	var snapshot = {
		"sceneType": scene_type,
		"turn": turn_count,
		"battle": {
			"turn": turn_count,
			"battleEnded": battle_over,
			"isPlayerTurn": is_player_turn,
			"discardSelectionMode": discard_selection_mode,
			"pendingDiscardCount": pending_discard_count,
			"fastMode": fast_mode,
			"player": _get_player_snapshot(),
			"enemy": _get_enemy_snapshot(),
			"ep": _get_ep_snapshot(),
			"hand": _get_hand_snapshot(),
			"drawPileCount": deck.size(),
			"discardPileCount": discard.size(),
			"battleIndex": current_battle_index,
			"totalBattles": battle_sequence.size(),
		},
		"run": _get_run_snapshot(),
		"reward": _get_reward_snapshot(),
	}
	return snapshot

func _get_player_snapshot() -> Dictionary:
	return {
		"hp": player.current_hp,
		"maxHp": player.max_hp,
		"block": player.block,
		"barrier": player.barrier,
		"energyShield": player.energy_shield,
		"vulnerable": player.vulnerable_stacks,
	}

func _get_enemy_snapshot() -> Dictionary:
	var intent = enemy.current_intent
	return {
		"name": enemy.enemy_name,
		"hp": enemy.current_hp,
		"maxHp": enemy.max_hp,
		"ice": enemy.ice,
		"shield": enemy.shield,
		"vulnerable": enemy.vulnerable_stacks,
		"intentType": intent.get("type", "unknown"),
		"intentValue": intent.get("value", 0),
		"intentDesc": intent.get("desc", ""),
		"phase": enemy.phase,
	}

func _get_ep_snapshot() -> Dictionary:
	var card_progress = {}
	for family in ep_manager.card_ep_by_family:
		card_progress[family] = ep_manager.card_ep_by_family[family]
	var family_levels = {}
	for family in ep_manager.family_max_level:
		family_levels[family] = ep_manager.family_max_level[family]
	return {
		"current": ep_manager.current_ep,
		"max": ep_manager.max_ep,
		"reserve": ep_manager.reserve_pool,
		"maxReserve": ep_manager.max_reserve,
		"cardProgress": card_progress,
		"familyLevels": family_levels,
	}

func _get_hand_snapshot() -> Array:
	var hand_data = []
	for i in range(hand.size()):
		var card = hand[i]
		var card_def = card.card_def
		var family = card_def.get("evolution_family", "")
		var ep_injected = 0
		if family != "" and ep_manager.card_ep_by_family.has(family):
			ep_injected = ep_manager.card_ep_by_family[family]
		hand_data.append({
			"handIndex": i,
			"cardId": card_def.get("card_id", ""),
			"name": card_def.get("name", ""),
			"type": card_def.get("type", 0),
			"cost": card.cost_override if card.cost_override >= 0 else card_def.get("cost", 0),
			"baseCost": card_def.get("cost", 0),
			"isPlayable": is_player_turn and not battle_over and not discard_selection_mode and ep_manager.can_afford(card.cost_override if card.cost_override >= 0 else card_def.get("cost", 0)),
			"isBloom": card.is_bloom,
			"level": card_def.get("level", 1),
			"family": family,
			"epInjected": ep_injected,
			"epToEvolve": card_def.get("ep_to_evolve", -1),
			"effect": card_def.get("effect", {}),
			"description": card_def.get("description", ""),
		})
	return hand_data

func _get_run_snapshot() -> Dictionary:
	return {
		"playerHp": player.current_hp,
		"maxHp": player.max_hp,
		"battlesWon": current_battle_index,
		"protocols": RunRewardState.chapter_protocols.duplicate(),
	}

func _get_reward_snapshot():
	# Check if reward panel is showing
	var reward_panel = get_node_or_null("RewardPanel")
	if reward_panel and reward_panel.has_method("get_bridge_state"):
		return reward_panel.get_bridge_state()
	var breakthrough_panel = get_node_or_null("CoreBreakthroughPanel")
	if breakthrough_panel and breakthrough_panel.has_method("get_bridge_state"):
		return breakthrough_panel.get_bridge_state()
	return null

func execute_bridge_action(action: Dictionary) -> Dictionary:
	var kind = action.get("kind", "")
	match kind:
		"play_card":
			return _external_play_card(action.get("handIndex", -1))
		"inject_ep":
			return _external_inject_ep(action.get("handIndex", -1))
		"end_turn":
			return _external_end_turn()
		"discard_card":
			return _external_discard_card(action.get("handIndex", -1))
		"choose_reward":
			return _external_choose_reward(action.get("rewardType", ""))
		"choose_reward_card":
			return _external_choose_reward_card(action.get("optionIndex", -1))
		"choose_protocol":
			return _external_choose_protocol(action.get("protocolName", ""))
		"start_battle":
			return _external_start_battle()
		"restart_game":
			_restart_game()
			return {"ok": true, "message": "Game restarted"}
		_:
			return {"ok": false, "message": "Unknown action: " + kind}

func _external_play_card(hand_index: int) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size():
		return {"ok": false, "message": "Invalid hand index"}
	if not is_player_turn or battle_over:
		return {"ok": false, "message": "Not player turn or battle over"}
	if discard_selection_mode:
		return {"ok": false, "message": "Must discard first"}

	var card = hand[hand_index]
	var cost = card.cost_override if card.cost_override >= 0 else card.card_def.get("cost", 0)
	if not ep_manager.can_afford(cost):
		return {"ok": false, "message": "Not enough EP"}

	ep_manager.spend_ep(cost)
	_play_card_sync(card)
	return {"ok": true, "message": ""}

func _external_inject_ep(hand_index: int) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size():
		return {"ok": false, "message": "Invalid hand index"}
	if not is_player_turn or battle_over:
		return {"ok": false, "message": "Not player turn or battle over"}
	if discard_selection_mode:
		return {"ok": false, "message": "Must discard first"}

	var card = hand[hand_index]
	if card.card_def.get("ep_to_evolve", -1) <= 0:
		return {"ok": false, "message": "Card already max level"}
	if not ep_manager.can_afford(1):
		return {"ok": false, "message": "Not enough EP"}

	if ep_manager.inject_to_card(card):
		card.injected_ep += 1
		card.update_evolution_progress(ep_manager.get_card_ep_progress(card))
		card.update_ep_text(ep_manager.get_card_ep_text(card))
		if not fast_mode:
			_animate_inject(card)
		return {"ok": true, "message": ""}
	return {"ok": false, "message": "Injection failed"}

func _external_end_turn() -> Dictionary:
	if not is_player_turn or battle_over:
		return {"ok": false, "message": "Not player turn or battle over"}
	if discard_selection_mode:
		return {"ok": false, "message": "Must discard first"}
	_end_turn_sync()
	return {"ok": true, "message": ""}

func _external_discard_card(hand_index: int) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size():
		return {"ok": false, "message": "Invalid hand index"}
	if not discard_selection_mode:
		return {"ok": false, "message": "Not in discard mode"}
	var card = hand[hand_index]
	_discard_card_from_hand(card)
	return {"ok": true, "message": ""}

func _external_choose_reward(reward_type: String) -> Dictionary:
	var reward_panel = get_node_or_null("RewardPanel")
	if not reward_panel:
		return {"ok": false, "message": "No reward panel"}
	if reward_panel.has_method("external_choose_reward"):
		return reward_panel.external_choose_reward(reward_type)
	return {"ok": false, "message": "Reward panel not ready"}

func _external_choose_reward_card(option_index: int) -> Dictionary:
	var reward_panel = get_node_or_null("RewardPanel")
	if not reward_panel:
		return {"ok": false, "message": "No reward panel"}
	if reward_panel.has_method("external_choose_reward_card"):
		return reward_panel.external_choose_reward_card(option_index)
	return {"ok": false, "message": "Reward panel not ready"}

func _external_choose_protocol(protocol_name: String) -> Dictionary:
	var panel = get_node_or_null("CoreBreakthroughPanel")
	if not panel:
		return {"ok": false, "message": "No breakthrough panel"}
	if panel.has_method("external_choose_protocol"):
		return panel.external_choose_protocol(protocol_name)
	return {"ok": false, "message": "Breakthrough panel not ready"}

func _external_start_battle() -> Dictionary:
	if not battle_over:
		return {"ok": false, "message": "Battle still in progress"}
	# If player died, restart the game instead of starting next battle
	if player.current_hp <= 0:
		_restart_game()
		return {"ok": true, "message": "Game restarted"}
	_start_next_battle()
	return {"ok": true, "message": ""}

func get_legal_actions() -> Array:
	var actions = []
	if battle_over:
		var reward_panel = get_node_or_null("RewardPanel")
		var breakthrough_panel = get_node_or_null("CoreBreakthroughPanel")
		if reward_panel and reward_panel.has_method("get_legal_actions_bridge"):
			return reward_panel.get_legal_actions_bridge()
		if breakthrough_panel and breakthrough_panel.has_method("get_legal_actions_bridge"):
			return breakthrough_panel.get_legal_actions_bridge()
		# Game over screen showing — offer restart action
		if player.current_hp <= 0:
			actions.append({"kind": "restart_game", "label": "Restart game", "parameters": {}})
		return actions

	if discard_selection_mode:
		for i in range(hand.size()):
			actions.append({
				"kind": "discard_card",
				"label": "Discard " + hand[i].card_def.get("name", ""),
				"parameters": {"handIndex": i}
			})
		return actions

	if is_player_turn:
		for i in range(hand.size()):
			var card = hand[i]
			var cost = card.cost_override if card.cost_override >= 0 else card.card_def.get("cost", 0)
			if ep_manager.can_afford(cost):
				actions.append({
					"kind": "play_card",
					"label": "Play " + card.card_def.get("name", ""),
					"parameters": {"handIndex": i, "cost": cost}
				})
			if ep_manager.can_afford(1) and card.card_def.get("ep_to_evolve", -1) > 0:
				actions.append({
					"kind": "inject_ep",
					"label": "Inject " + card.card_def.get("name", ""),
					"parameters": {"handIndex": i}
				})
		actions.append({"kind": "end_turn", "label": "End Turn", "parameters": {}})

	return actions

# === Sync versions (no animations) for training ===

func _play_card_sync(card: CardUI):
	var effect = card.card_def.get("effect", {})

	# === PRE-DAMAGE: conditional bonuses and crash_copy save ===
	var crash_copy_saved: int = 0
	if effect.get("crash_copy", false):
		crash_copy_saved = enemy.crash_stacks

	var bonus_damage: int = 0
	if effect.has("bonus_if_crash") and enemy.crash_stacks > 0:
		bonus_damage += int(effect.bonus_if_crash)
		enemy.crash_stacks = 0
		enemy.crash_changed.emit(0)

	if effect.has("bonus_if_crash_ge"):
		var ge_config = effect.bonus_if_crash_ge
		if enemy.crash_stacks >= ge_config.get("threshold", 3):
			bonus_damage += int(ge_config.get("bonus", 0))
			enemy.crash_stacks = 0
			enemy.crash_changed.emit(0)

	var attack_bonus_apply: int = 0
	if effect.has("damage") and next_attack_bonus > 0:
		attack_bonus_apply = next_attack_bonus
		next_attack_bonus = 0

	if effect.has("damage"):
		var dmg = int(effect.damage) + bonus_damage + attack_bonus_apply
		var pierce = effect.get("pierce", 0)
		enemy.take_damage(dmg, pierce)
		battle_hud.update_enemy_hp(enemy.current_hp, enemy.max_hp)
		battle_hud.update_enemy_shield(enemy.shield)
		battle_hud.update_enemy_crash(enemy.crash_stacks)

	# === POST-DAMAGE: crash_copy re-apply ===
	if effect.get("crash_copy", false) and crash_copy_saved > 0:
		var copy_bonus = effect.get("crash_copy_bonus", 0)
		enemy.add_crash(crash_copy_saved + copy_bonus)
		battle_hud.update_enemy_crash(enemy.crash_stacks)

	# === kill_ep ===
	if effect.has("kill_ep") and enemy.is_dead:
		ep_manager.current_ep = min(ep_manager.max_ep, ep_manager.current_ep + int(effect.kill_ep))
		battle_hud.update_ep(ep_manager.current_ep, ep_manager.max_ep)

	if effect.has("block"):
		player.add_block(int(effect.block))

	if effect.get("block_persist", false):
		player.block_persist = true

	if effect.has("vulnerable"):
		enemy.add_vulnerable(int(effect.vulnerable))

	if effect.has("self_vulnerable"):
		player.vulnerable_stacks += int(effect.self_vulnerable)

	if effect.has("draw"):
		_draw_cards_sync(int(effect.draw))

	if effect.has("ep_penalty"):
		ep_penalty_next_turn += int(effect.ep_penalty)

	if effect.has("gain_ep"):
		ep_manager.current_ep = min(ep_manager.max_ep, ep_manager.current_ep + int(effect.gain_ep))
		battle_hud.update_ep(ep_manager.current_ep, ep_manager.max_ep)

	if effect.has("heal"):
		player.heal(int(effect.heal))

	if effect.has("conditional_heal") and player_damaged_last_turn:
		player.heal(int(effect.conditional_heal))

	if effect.has("reflect"):
		var ref_dmg = int(effect.reflect)
		enemy.current_hp = max(0, enemy.current_hp - ref_dmg)
		enemy.hp_changed.emit(enemy.current_hp, enemy.max_hp)
		battle_hud.update_enemy_hp(enemy.current_hp, enemy.max_hp)

	if effect.has("barrier"):
		player.add_barrier(int(effect.barrier))

	if effect.has("barrier_if_crash") and enemy.crash_stacks > 0:
		player.add_barrier(int(effect.barrier_if_crash))

	if effect.has("clear_self_vulnerable"):
		player.vulnerable_stacks = 0

	if effect.has("crash"):
		enemy.add_crash(int(effect.crash))
		battle_hud.update_enemy_crash(enemy.crash_stacks)

	if effect.has("next_attack_bonus") and not effect.has("damage"):
		next_attack_bonus += int(effect.next_attack_bonus)

	if effect.has("inject_target"):
		var inject_amount = int(effect.inject_target)
		for hc in hand:
			if hc != card and hc.card_def.get("evolution_family", "") != "" and hc.card_def.get("ep_to_evolve", -1) > 0:
				ep_manager.inject_to_card_free(hc, inject_amount)
				hc.update_evolution_progress(ep_manager.get_card_ep_progress(hc))
				hc.update_ep_text(ep_manager.get_card_ep_text(hc))
				break

	if effect.has("inject_program"):
		var inject_amount = int(effect.inject_program)
		for hc in hand:
			if hc != card and hc.card_def.get("type", -1) == CardDatabase.CardType.PROGRAM and hc.card_def.get("ep_to_evolve", -1) > 0:
				ep_manager.inject_to_card_free(hc, inject_amount)
				hc.update_evolution_progress(ep_manager.get_card_ep_progress(hc))
				hc.update_ep_text(ep_manager.get_card_ep_text(hc))
				break

	var was_bloom = card.is_bloom
	var card_id = card.card_def.get("card_id", "")

	if not fast_mode:
		_animate_play_card(card)
	else:
		card.queue_free()

	card.is_bloom = false
	card.cost_override = -1

	hand.erase(card)
	discard.append(card_id)
	_reposition_hand_sync()

	if was_bloom:
		extra_play_available = true

func _draw_cards_sync(count: int):
	for i in range(count):
		if deck.is_empty():
			_reshuffle_discard()
		if deck.is_empty():
			break

		var card_id = deck.pop_front()
		var card_def = CardDatabase.get_card_def(card_id)
		if card_def.is_empty():
			continue

		var card_ui = CardUIScene.instantiate()
		card_ui.setup_card(card_def.duplicate())
		card_ui.fast_mode = fast_mode
		card_ui.card_clicked.connect(_on_card_clicked)
		card_ui.inject_clicked.connect(_on_inject_clicked)

		var family = card_def.get("evolution_family", "")
		if family != "" and ep_manager.card_ep_by_family.has(family):
			card_ui.update_evolution_progress(ep_manager.get_card_ep_progress(card_ui))

		var idx = hand.size()
		card_ui.hand_index = idx
		card_ui.z_index = idx
		card_hand.add_child(card_ui)
		hand.append(card_ui)

	_check_hand_limit_sync()

func _check_hand_limit_sync():
	if hand.size() > MAX_HAND_SIZE and not discard_selection_mode:
		pending_discard_count = hand.size() - MAX_HAND_SIZE
		discard_selection_mode = true

func _reposition_hand_sync():
	for i in range(hand.size()):
		var card = hand[i]
		var pos = _get_arc_position(i, hand.size())
		card.hand_index = i
		card.z_index = 100 if card.selected else i
		card.rest_y = pos.y
		var target_y = pos.y - 30 if card.selected else pos.y
		card.position = Vector2(pos.x, target_y)
		card.rotation = pos.theta

func _end_turn_sync():
	if ep_manager.current_ep > 0:
		ep_manager.inject_to_reserve()

	if RunRewardState.has_protocol("屏障转化"):
		RunRewardState.apply_barrier_protocol(player)

	_deselect_card()
	is_player_turn = false
	_enemy_turn_sync()

func _enemy_turn_sync():
	var hp_before_enemy = player.current_hp
	enemy.advance_cycle()
	var action = enemy.execute_intent()

	# Simplified enemy action resolution
	match action.type:
		"attack", "heavy", "shock", "data_slash", "corrode", "suppress", "overload_burst", "overload", "signal_jam", "void_drain":
			var dmg = action.get("damage", action.get("value", 0))
			player.take_damage(dmg)
			if action.type == "corrode" or action.type == "suppress":
				var vuln = enemy.current_intent.get("vulnerable", 1)
				player.vulnerable_stacks += vuln
			if action.type == "signal_jam":
				var dc = enemy.current_intent.get("discard", 1)
				_force_discard_highest_cost(dc)
			if action.type == "void_drain":
				var heal_amt = enemy.current_intent.get("heal", 5)
				enemy.current_hp = min(enemy.max_hp, enemy.current_hp + heal_amt)

		"defend", "recharge", "reconstruct":
			pass  # Shield already added by execute_intent

		"buff":
			pass  # Buff already applied

		"charge":
			pass

		"pollute":
			var barrier_reduce = enemy.current_intent.get("barrier_reduce", 2)
			barrier_reduction_next_turn += barrier_reduce

		"annihilate":
			var raw_dmg = action.damage + player.vulnerable_stacks
			var after_es = max(0, raw_dmg - player.energy_shield)
			var blocked = min(player.block, after_es)
			player.block -= blocked
			var final_dmg = after_es - blocked
			player.current_hp = max(0, player.current_hp - final_dmg)

		"nihil":
			player.energy_shield = 0
			player.take_damage(action.damage)

	turn_ended.emit()
	player_damaged_last_turn = (player.current_hp < hp_before_enemy)

	if not battle_over and not fast_mode:
		await get_tree().create_timer(0.3).timeout

	if not battle_over:
		_start_player_turn_sync()

func _start_player_turn_sync():
	is_player_turn = true
	_deselect_card()
	turn_count += 1
	ep_manager.reset_turn()

	if ep_penalty_next_turn > 0:
		ep_manager.apply_ep_penalty(ep_penalty_next_turn)
		ep_penalty_next_turn = 0

	ep_manager.set_barrier_reduction(barrier_reduction_next_turn)
	barrier_reduction_next_turn = 0

	player.reset_turn()
	enemy.reset_turn()
	extra_play_available = false
	next_attack_bonus = 0
	player_damaged_last_turn = false
	_draw_cards_sync(5)
	turn_started.emit()
