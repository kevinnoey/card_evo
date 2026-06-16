extends Node
## Run Reward State - Autoload singleton storing cross-battle state
## v1.6: Extended to serve as the central "Run Manager" for the roguelite system.
## Manages: deck, fragments, map data, evolution progress, chapter state, player HP.

# === Legacy Reward State (v1.4/v1.5) ===

var permanent_bonus = {
	"reserve_progress": 0,  # Accumulated reserve pool progress from rewards
	"max_hp_bonus": 0,      # Permanent max HP increase
}

var applied_max_hp_bonus: int = 0  # 已应用到 player 的 max_hp 加成量（增量追踪）

var next_battle_temp_bonus = {
	"barrier": 0,          # Opening barrier for next battle
	"block": 0,            # Opening block for next battle
	"ep_per_turn_add": 0,  # Extra EP per turn
}

func apply_permanent_bonus(player):
	"""Apply permanent bonuses at battle start (max HP). Only applies the delta since last call."""
	var new_amount = permanent_bonus.max_hp_bonus - applied_max_hp_bonus
	if new_amount > 0:
		player.max_hp += new_amount
		player.current_hp = min(player.max_hp, player.current_hp + new_amount)
		applied_max_hp_bonus = permanent_bonus.max_hp_bonus

func apply_next_battle_bonus(player, ep_manager):
	if next_battle_temp_bonus.barrier > 0:
		player.add_barrier(next_battle_temp_bonus.barrier)
	if next_battle_temp_bonus.block > 0:
		player.add_block(next_battle_temp_bonus.block)
	if next_battle_temp_bonus.ep_per_turn_add > 0:
		var old_max = ep_manager.max_ep
		ep_manager.max_ep = min(6, ep_manager.max_ep + next_battle_temp_bonus.ep_per_turn_add)
		# If called after reset_turn, current_ep was set to old max. Give the delta.
		ep_manager.current_ep = min(ep_manager.max_ep, ep_manager.current_ep + (ep_manager.max_ep - old_max))

func clear_next_battle_bonus(ep_manager):
	if next_battle_temp_bonus.ep_per_turn_add > 0:
		ep_manager.max_ep = max(3, ep_manager.max_ep - next_battle_temp_bonus.ep_per_turn_add)
	next_battle_temp_bonus = {"barrier": 0, "block": 0, "ep_per_turn_add": 0}

# === Chapter Breakthrough Protocols (v1.5) ===
var chapter_protocols: Array = []

func add_protocol(protocol_name: String):
	if not chapter_protocols.has(protocol_name):
		chapter_protocols.append(protocol_name)

func has_protocol(protocol_name: String) -> bool:
	return chapter_protocols.has(protocol_name)

func apply_turn_start_protocols(player):
	"""Applied at the start of each player turn for breakthrough effects."""
	if has_protocol("超限跃迁"):
		player.current_hp = max(1, player.current_hp - 5)
		print("超限跃迁: 失去 5 HP")

func apply_reserve_protocol(ep_manager):
	"""Apply reserve-related protocol overrides at battle start."""
	if has_protocol("涌动核心"):
		ep_manager.max_reserve = 20
		ep_manager.milestone_thresholds = [5, 10, 15, 20]

func apply_barrier_protocol(player):
	"""Check barrier conversion at turn end (屏障转化)."""
	if has_protocol("屏障转化"):
		if player.barrier > 0:
			var converted = floori(player.barrier / 2)
			if converted > 0:
				player.max_hp += converted
				player.current_hp = min(player.max_hp, player.current_hp + converted)

# === Roguelite Run State (v1.6) ===

var selected_character: String = "infiltrator"  # "infiltrator" or "crasher"
var run_active: bool = false
var current_chapter: int = 1
var data_fragments: int = 0
var map_seed: int = 0

# Player deck (array of base card_id strings, e.g., ["c01_basic_probe", ...])
var player_deck: Array = []

# Player HP persisted across scenes (battle scene destroyed between map visits)
var player_hp: int = 70
var player_max_hp: int = 70

# Player energy shield persisted across battles
var player_energy_shield: int = 0

# Persisted evolution progress (survives across battles)
var card_ep_by_family: Dictionary = {}
var family_max_level: Dictionary = {}

# Map state
var current_map_data: Dictionary = {}   # {layers: [{nodes: [...]}], chapter: int}
var completed_nodes: Array = []          # Vector2i(layer, index) of completed nodes
var current_layer: int = -1             # -1 = not started, 0 = first layer

# Battle config (set before scene change to battle.tscn)
var pending_battle: Dictionary = {}     # {enemy_key, node_type, node_layer, node_index, is_elite}

# Battle result (set by BattleManager after battle ends, read by MapScreen)
var last_battle_won: bool = false
var fragments_earned: int = 0

# Reserve pool persistence (carries across battles within a run)
var reserve_pool: int = 0

# Permanent EP per turn bonus (from events/shop, stacks, no cap)
var permanent_ep_bonus: int = 0

# Enemy strength debuff for next battle (from "report merchant" event)
var next_battle_enemy_bonus_strength: int = 0

func start_new_run(seed: int = -1):
	"""Initialize all state for a new roguelite run."""
	run_active = true
	current_chapter = 1
	data_fragments = 0
	map_seed = seed if seed >= 0 else randi()
	player_deck = _get_starting_deck()
	# 根据角色设置HP
	var char_info = CardDatabase.get_character_info(selected_character)
	var char_hp = char_info.get("hp", 70)
	player_hp = char_hp
	player_max_hp = char_hp
	player_energy_shield = 0
	card_ep_by_family = {}
	family_max_level = {}
	chapter_protocols.clear()
	permanent_bonus = {"reserve_progress": 0, "max_hp_bonus": 0}
	applied_max_hp_bonus = 0
	next_battle_temp_bonus = {"barrier": 0, "block": 0, "ep_per_turn_add": 0}
	reserve_pool = 0
	permanent_ep_bonus = 0
	next_battle_enemy_bonus_strength = 0
	permanent_ep_bonus = 0
	next_battle_enemy_bonus_strength = 0
	pending_battle = {}
	last_battle_won = false
	fragments_earned = 0
	_generate_map()

	# 初始化全局行动日志
	ActionLog.clear_log()
	var char_name = CardDatabase.get_character_info(selected_character).get("name", "渗透者")
	ActionLog.add_log("═══ 新游戏开始 — " + char_name + " ═══", Color("#00F0FF"))
	ActionLog.add_log("第一章 — 初始牌组 [color=#FFD700]%d[/color] 张卡牌" % player_deck.size(), Color("#888888"))

func _get_starting_deck() -> Array:
	"""Get the starting deck card IDs for the selected character."""
	return CardDatabase.get_starting_deck_for_character(selected_character)

func _generate_map():
	"""Generate the map for the current chapter using MapGenerator."""
	var gen = MapGenerator.new()
	current_map_data = gen.generate_chapter(current_chapter, map_seed + current_chapter)
	completed_nodes.clear()
	current_layer = -1
	_unlock_start_nodes()

func _unlock_start_nodes():
	"""Mark the starting node(s) as available."""
	current_layer = 0
	if current_map_data.has("layers") and current_map_data["layers"].size() > 0:
		for node in current_map_data["layers"][0]["nodes"]:
			node["available"] = true

func _unlock_connected_nodes(layer_idx: int, node_idx: int):
	"""Unlock nodes that are connected from the completed node."""
	if not current_map_data.has("layers") or layer_idx >= current_map_data["layers"].size():
		return

	var node = current_map_data["layers"][layer_idx]["nodes"][node_idx]
	var connections = node.get("connections", [])
	var next_layer_idx = layer_idx + 1

	if next_layer_idx < current_map_data["layers"].size():
		var next_layer = current_map_data["layers"][next_layer_idx]["nodes"]
		for conn_idx in connections:
			if conn_idx < next_layer.size():
				next_layer[conn_idx]["available"] = true
				# Update current_layer to the highest unlocked layer
				if next_layer_idx > current_layer:
					current_layer = next_layer_idx

func complete_node(layer_idx: int, node_idx: int):
	"""Mark a node as completed and unlock connected nodes."""
	if current_map_data.has("layers") and layer_idx < current_map_data["layers"].size():
		var node = current_map_data["layers"][layer_idx]["nodes"][node_idx]
		node["completed"] = true
		completed_nodes.append(Vector2i(layer_idx, node_idx))
		_unlock_connected_nodes(layer_idx, node_idx)

func is_boss_node(layer_idx: int, node_idx: int) -> bool:
	"""Check if a node is the boss node."""
	if current_map_data.has("layers") and layer_idx < current_map_data["layers"].size():
		var node = current_map_data["layers"][layer_idx]["nodes"][node_idx]
		return node.get("type", "") == "boss"
	return false

func is_chapter_complete() -> bool:
	"""Check if the boss layer has been completed."""
	if not current_map_data.has("layers"):
		return false
	var layers = current_map_data["layers"]
	var boss_layer_idx = layers.size() - 1
	if boss_layer_idx < 0:
		return false
	for node in layers[boss_layer_idx]["nodes"]:
		if node.get("completed", false):
			return true
	return false

# === Fragment Management ===

func add_fragments(amount: int):
	data_fragments += amount

func spend_fragments(amount: int) -> bool:
	if data_fragments >= amount:
		data_fragments -= amount
		return true
	return false

# === Deck Management ===

func add_card_to_deck(card_id: String):
	player_deck.append(card_id)

func remove_card_from_deck(index: int):
	if index >= 0 and index < player_deck.size():
		player_deck.remove_at(index)

func get_base_card_id(card_id: String) -> String:
	"""Get the base (Lv.1) card ID for any evolved card ID.
	Evolution family system: c01_basic_probe_l2 → c01_basic_probe"""
	# Strip level suffix if present
	if card_id.ends_with("_l2") or card_id.ends_with("_l3"):
		return card_id.rsplit("_", true, 1)[0]
	return card_id

# === EP/Evolution Persistence ===

func sync_from_ep_manager(ep_mgr):
	"""After battle ends, copy ep_manager state back to persistent storage."""
	card_ep_by_family = ep_mgr.card_ep_by_family.duplicate()
	family_max_level = ep_mgr.family_max_level.duplicate()
	reserve_pool = ep_mgr.reserve_pool

func restore_to_ep_manager(ep_mgr):
	"""Before battle starts, restore persisted evolution state into fresh ep_manager."""
	ep_mgr.card_ep_by_family = card_ep_by_family.duplicate()
	ep_mgr.family_max_level = family_max_level.duplicate()
	ep_mgr.reserve_pool = reserve_pool
	# Apply permanent EP bonus from events/shop
	if permanent_ep_bonus > 0:
		ep_mgr.max_ep = min(6, ep_mgr.max_ep + permanent_ep_bonus)

# === HP Persistence ===

func sync_hp_from_player(player):
	"""After battle ends, save player HP to persistent storage."""
	player_hp = player.current_hp
	player_max_hp = player.max_hp
	player_energy_shield = player.energy_shield

func restore_hp_to_player(player):
	"""Before battle starts, restore player HP from persistent storage."""
	player.max_hp = player_max_hp
	player.current_hp = min(player_hp, player_max_hp)
	player.energy_shield = player_energy_shield

# === Card Selection Helpers ===

func get_evolved_deck() -> Array:
	"""Get the current deck with evolution levels applied.
	Returns array of actual card IDs (possibly evolved versions)."""
	var CardDB = load("res://scripts/data/card_database.gd")
	var result = []
	for card_id in player_deck:
		var family = _get_family_for_card(card_id)
		var max_level = family_max_level.get(family, 1)
		if max_level >= 3:
			result.append(card_id + "_l3")
		elif max_level >= 2:
			result.append(card_id + "_l2")
		else:
			result.append(card_id)
	return result

func _get_family_for_card(card_id: String) -> String:
	"""Extract evolution family from a card ID. e.g., c01_basic_probe → c01"""
	var parts = card_id.split("_")
	if parts.size() > 0:
		return parts[0]
	return card_id

func heal_player(amount: int):
	"""Heal the player, capped at max_hp."""
	player_hp = min(player_max_hp, player_hp + amount)

func damage_player(amount: int):
	"""Damage the player, minimum 1 HP remaining (events shouldn't kill directly)."""
	player_hp = max(1, player_hp - amount)

func increase_max_hp(amount: int):
	"""Permanently increase max HP and heal by the same amount."""
	player_max_hp += amount
	player_hp = min(player_max_hp, player_hp + amount)

# === Reset ===

func reset():
	"""Full reset for game over / new game."""
	permanent_bonus = {"reserve_progress": 0, "max_hp_bonus": 0}
	applied_max_hp_bonus = 0
	next_battle_temp_bonus = {"barrier": 0, "block": 0, "ep_per_turn_add": 0}
	chapter_protocols.clear()
	run_active = false
	selected_character = "infiltrator"
	current_chapter = 1
	data_fragments = 0
	map_seed = 0
	player_deck = []
	player_hp = 70
	player_max_hp = 70
	player_energy_shield = 0
	card_ep_by_family = {}
	family_max_level = {}
	current_map_data = {}
	completed_nodes.clear()
	current_layer = -1
	pending_battle = {}
	last_battle_won = false
	fragments_earned = 0
	reserve_pool = 0
	permanent_ep_bonus = 0
	next_battle_enemy_bonus_strength = 0
