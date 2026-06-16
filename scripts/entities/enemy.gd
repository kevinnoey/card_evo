class_name Enemy
extends Node2D
## Enemy entity - HP, ICE, intent patterns, behavior cycles
## AI types: "random", "cycle", "weighted_random", "smart", "multi_phase"

signal hp_changed(current_hp: int, max_hp: int)
signal ice_changed(ice: int)
signal intent_changed(intent: Dictionary)
signal enemy_died()
signal phase_changed(new_phase: int)
signal devolve_player_cards()  # 格式化巨兽: trigger de-evolution
signal crash_changed(crash_stacks: int)

var enemy_name: String = "防火墙哨兵"
var max_hp: int = 35
var current_hp: int = 35
var ice: int = 0
var vulnerable_stacks: int = 0
var is_dead: bool = false
var crash_stacks: int = 0  # 崩溃层数（代码崩溃者机制）
const MAX_CRASH_STACKS: int = 5
const CRASH_DAMAGE_PER_STACK: int = 3  # 每层崩溃使下次攻击+3伤害

# Intent system
var current_intent: Dictionary = {}
var turn_count: int = 0
var ai_type: String = "cycle"

# Enemy A (random): buff tracking
var power_buff: int = 0
var was_buff_last_turn: bool = false
var random_pool: Array = []

# Cycle-based enemies
var behavior_cycle: Array = []
var cycle_index: int = 0
var shield: int = 0

# Weighted random (数据腐化体)
var weighted_pool: Array = []  # [{"intent": {...}, "weight": 70}, ...]

# Smart AI (虚空信标) - needs reference to get hand count
var smart_rules: Array = []  # [{"condition": "hand_ge/hand_le", "value": N, "intent": {...}}, ...]
var fallback_intent: Dictionary = {}
var _get_player_hand_count: Callable = func(): return 3

# Multi-phase (湮灭协议)
var phase: int = 1
var phase_hp_threshold: float = 0.5  # Switch at 50% HP
var phase1_cycle: Array = []
var phase2_cycle: Array = []
var phase2_turn_count: int = 0
var annihilate_interval: int = 2  # Every 2 turns force 湮灭

# Chapter 2 enemy tracking
var heal_buff: int = 0
var attack_buff: int = 0
var last_turn_damage_taken: bool = false
var ice_restore_amount: int = 2

# Layer-based difficulty scaling (added to damaging intents based on map layer tier)
var bonus_damage: int = 0

func setup_enemy(config: Dictionary):
	enemy_name = config.get("name", enemy_name)
	max_hp = config.get("hp", max_hp)
	current_hp = max_hp
	ice = config.get("ice", ice)
	ai_type = config.get("ai_type", "cycle")
	behavior_cycle = config.get("behavior_cycle", [])
	shield = 0
	turn_count = 0
	cycle_index = 0
	power_buff = 0
	was_buff_last_turn = false
	vulnerable_stacks = 0
	is_dead = false
	phase = 1
	phase2_turn_count = 0
	heal_buff = 0
	attack_buff = 0
	last_turn_damage_taken = false
	crash_stacks = 0
	bonus_damage = 0

	# Setup based on AI type
	if ai_type == "random" and behavior_cycle.size() >= 2:
		random_pool = [behavior_cycle[0], behavior_cycle[1]]
	else:
		random_pool = []

	weighted_pool = config.get("weighted_pool", [])
	smart_rules = config.get("smart_rules", [])
	fallback_intent = config.get("fallback_intent", {})
	phase1_cycle = config.get("phase1_cycle", behavior_cycle)
	phase2_cycle = config.get("phase2_cycle", [])
	phase_hp_threshold = config.get("phase_hp_threshold", 0.5)
	annihilate_interval = config.get("annihilate_interval", 2)

	if config.has("get_player_hand_count"):
		_get_player_hand_count = config["get_player_hand_count"]

	hp_changed.emit(current_hp, max_hp)
	ice_changed.emit(ice)
	_generate_intent()


func apply_layer_scaling(hp_mult: float, dmg_bonus: int):
	"""Apply layer-based difficulty scaling to HP and damage."""
	if hp_mult != 1.0:
		max_hp = roundi(max_hp * hp_mult)
		current_hp = max_hp
		hp_changed.emit(current_hp, max_hp)
	bonus_damage = dmg_bonus

func _generate_intent():
	if ai_type == "multi_phase":
		_generate_phase_intent()
		return

	if behavior_cycle.is_empty() and weighted_pool.is_empty() and smart_rules.is_empty():
		current_intent = {"type": "attack", "value": 6, "icon": "⚔️", "desc": "攻击 6"}
	elif not behavior_cycle.is_empty():
		current_intent = behavior_cycle[cycle_index].duplicate()
		if power_buff > 0 and current_intent.get("type") in ["attack", "heavy"]:
			current_intent["value"] = current_intent.get("value", 0) + power_buff
	intent_changed.emit(current_intent)

func _generate_phase_intent():
	var active_cycle = phase1_cycle if phase == 1 else phase2_cycle
	if active_cycle.is_empty():
		current_intent = {"type": "attack", "value": 8, "icon": "⚔️", "desc": "攻击 8"}
		intent_changed.emit(current_intent)
		return

	if phase == 2:
		# Phase 2: force annihilate every N turns
		phase2_turn_count += 1
		if phase2_turn_count % annihilate_interval == 0:
			# Find annihilate intent in cycle
			for intent in active_cycle:
				if intent.get("type") == "annihilate":
					current_intent = intent.duplicate()
					intent_changed.emit(current_intent)
					return

	current_intent = active_cycle[cycle_index % active_cycle.size()].duplicate()
	intent_changed.emit(current_intent)

func advance_cycle():
	turn_count += 1

	if ai_type == "random":
		_advance_random()
	elif ai_type == "weighted_random":
		_advance_weighted_random()
	elif ai_type == "smart":
		_advance_smart()
	elif ai_type == "multi_phase":
		_advance_multi_phase()
	elif not behavior_cycle.is_empty():
		cycle_index = (cycle_index + 1) % behavior_cycle.size()
		_generate_intent()

func _advance_random():
	if was_buff_last_turn:
		if behavior_cycle.size() >= 3:
			current_intent = behavior_cycle[2].duplicate()
			if power_buff > 0:
				current_intent["value"] = current_intent.get("value", 10) + power_buff
		was_buff_last_turn = false
	else:
		var pick = random_pool[randi() % random_pool.size()]
		current_intent = pick.duplicate()
		if pick.get("type") == "buff":
			was_buff_last_turn = true
		if power_buff > 0 and current_intent.get("type") in ["attack"]:
			current_intent["value"] = current_intent.get("value", 0) + power_buff
	intent_changed.emit(current_intent)

func _advance_weighted_random():
	# Weighted random selection (数据腐化体: 70% attack / 30% pollution)
	var total_weight = 0
	for entry in weighted_pool:
		total_weight += entry.get("weight", 50)
	var roll = randi() % total_weight
	var cumulative = 0
	for entry in weighted_pool:
		cumulative += entry.get("weight", 50)
		if roll < cumulative:
			current_intent = entry["intent"].duplicate()
			break
	intent_changed.emit(current_intent)

func _advance_smart():
	# Smart AI based on player hand count (虚空信标)
	var hand_count = _get_player_hand_count.call()
	for rule in smart_rules:
		var cond = rule.get("condition", "")
		var val = rule.get("value", 0)
		var matched = false
		match cond:
			"hand_ge":
				matched = hand_count >= val
			"hand_le":
				matched = hand_count <= val
		if matched:
			current_intent = rule["intent"].duplicate()
			intent_changed.emit(current_intent)
			return
	# Fallback
	current_intent = fallback_intent.duplicate()
	intent_changed.emit(current_intent)

func _advance_multi_phase():
	# Check phase transition
	if phase == 1 and current_hp <= max_hp * phase_hp_threshold:
		phase = 2
		phase2_turn_count = 0
		cycle_index = 0
		shield = 0  # Clear shields on phase transition
		phase_changed.emit(phase)
		# Play transition effect (handled by battle_manager)

	var active_cycle = phase1_cycle if phase == 1 else phase2_cycle
	if active_cycle.is_empty():
		return

	if phase == 2:
		phase2_turn_count += 1
		if phase2_turn_count % annihilate_interval == 0:
			for intent in active_cycle:
				if intent.get("type") == "annihilate":
					current_intent = intent.duplicate()
					intent_changed.emit(current_intent)
					return

	cycle_index = (cycle_index + 1) % active_cycle.size()
	_generate_intent()

func execute_intent() -> Dictionary:
	var result = {"type": current_intent.get("type", "attack"), "damage": 0, "block": 0, "pierce_shield": 0}

	match current_intent.get("type", "attack"):
		"attack":
			result.damage = current_intent.get("value", 6)
		"heavy":
			result.damage = current_intent.get("value", 10)
			power_buff = 0
		"defend":
			var val = current_intent.get("value", 15)
			shield += val
			result.block = val
		"buff":
			var val = current_intent.get("value", 2)
			power_buff += val
			result.damage = val
		"charge":
			result.damage = 0
		"shock":
			# 脉冲中继器: 电击
			result.damage = current_intent.get("value", 5)
		"recharge":
			# 脉冲中继器: 充电 (获得护盾+自身脆弱)
			var val = current_intent.get("value", 8)
			shield += val
			result.block = val
			vulnerable_stacks += current_intent.get("self_vulnerable", 1)
		"overload_burst":
			# 脉冲中继器: 过载爆发 (伤害+移除自身护盾)
			result.damage = current_intent.get("value", 9)
			shield = 0
		"corrode":
			# 数据腐化体: 腐蚀爪击 (伤害+给玩家脆弱)
			result.damage = current_intent.get("value", 7)
		"pollute":
			# 数据腐化体: 数据污染 (无伤害, 给玩家屏障减少)
			result.damage = 0
		"data_slash":
			# 加密守护者: 数据切割
			result.damage = current_intent.get("value", 10)
		"signal_jam":
			# 虚空信标: 信号干扰 (伤害+弃牌)
			result.damage = current_intent.get("value", 4)
		"void_drain":
			# 虚空信标: 虚空汲取 (伤害+回血)
			result.damage = current_intent.get("value", 7)
			var heal_amt = current_intent.get("heal", 5)
			current_hp = min(max_hp, current_hp + heal_amt)
			hp_changed.emit(current_hp, max_hp)
		"suppress":
			# 湮灭协议: 协议·压制 (伤害+脆弱)
			result.damage = current_intent.get("value", 8)
		"reconstruct":
			# 湮灭协议: 协议·重构 (护盾+清debuff)
			var val = current_intent.get("value", 10)
			shield += val
			result.block = val
			vulnerable_stacks = 0
		"overload":
			# 湮灭协议: 协议·过载 (高伤害+自伤)
			result.damage = current_intent.get("value", 12)
			var self_dmg = current_intent.get("self_damage", 3)
			current_hp = max(1, current_hp - self_dmg)
			hp_changed.emit(current_hp, max_hp)
		"annihilate":
			# 湮灭协议: 终极·湮灭 (无视屏障)
			result.damage = current_intent.get("value", 18)
		"nihil":
			# 湮灭协议: 终极·虚无 (清除护盾+伤害)
			result.damage = current_intent.get("value", 5)
		"berserk_overwrite":
			# 格式化巨兽: 狂暴覆写 (无视屏障+格挡)
			result.damage = current_intent.get("value", 22)
			result.ignore_barrier = true
			result.ignore_block = true
		"devour":
			# 内存吞噬者: 数据吞食 (伤害+弃牌)
			result.damage = current_intent.get("value", 8)
			result.discard_lowest = 1
		"digest":
			# 内存吞噬者: 消化增殖 (回血+maxHP)
			var heal_val = current_intent.get("heal", 10)
			current_hp = min(max_hp, current_hp + heal_val)
			heal_buff += current_intent.get("max_hp_gain", 10)
			max_hp += current_intent.get("max_hp_gain", 10)
			hp_changed.emit(current_hp, max_hp)
		"regurgitate":
			# 内存吞噬者: 反刍打击 (条件脆弱)
			result.damage = current_intent.get("value", 15)
			if not last_turn_damage_taken:
				result.vulnerable = 1
		"restore_ice":
			# 矩阵哨卫: 自适应装甲 (恢复ICE)
			ice = min(4, ice + ice_restore_amount)
			ice_changed.emit(ice)
		"beam":
			# 矩阵哨卫: 高频射线 (3x4=12)
			result.damage = current_intent.get("value", 12)
		"suppress_barrier":
			# 矩阵哨卫: 镇压协议 (封锁屏障)
			result.damage = current_intent.get("value", 12)
			result.block_barrier = true
		"format":
			# 格式化巨兽: 底层格式化 (清空储备池)
			result.damage = current_intent.get("value", 10)
			result.clear_reserve = true
		"grid_overload":
			# 格式化巨兽: 过载电网
			result.damage = current_intent.get("value", 15)
		"defense_matrix":
			# 格式化巨兽: 防御矩阵 (护盾+攻击buff)
			var val = current_intent.get("value", 20)
			shield += val
			result.block = val
			attack_buff += current_intent.get("attack_buff", 5)
		"system_restart":
			# 格式化巨兽: 系统重启 (清debuff+退化)
			vulnerable_stacks = 0
			attack_buff = 0
			result.devolve = true

	# Apply layer-based difficulty bonus damage to damaging intents
	if bonus_damage != 0 and result.damage > 0:
		result.damage = maxi(1, result.damage + bonus_damage)

	return result

func take_damage(raw_damage: int, pierce: int = 0) -> int:
	# 崩溃加成：每层崩溃使本次攻击伤害+3，命中后清零
	var crash_bonus = crash_stacks * CRASH_DAMAGE_PER_STACK
	var crash_before = crash_stacks
	crash_stacks = 0
	if crash_before > 0:
		crash_changed.emit(crash_stacks)

	var ice_reduction = max(0, ice - pierce)
	var effective = max(0, raw_damage + crash_bonus + vulnerable_stacks - ice_reduction)

	if shield > 0:
		var sh_absorb = min(shield, effective)
		shield -= sh_absorb
		effective -= sh_absorb

	current_hp = max(0, current_hp - effective)
	hp_changed.emit(current_hp, max_hp)

	# Check phase transition after taking damage
	if ai_type == "multi_phase" and phase == 1 and current_hp <= max_hp * phase_hp_threshold:
		phase = 2
		phase2_turn_count = 0
		cycle_index = 0
		shield = 0
		phase_changed.emit(phase)

	if current_hp <= 0 and not is_dead:
		is_dead = true
		enemy_died.emit()
	return effective

func get_crash_bonus() -> int:
	return crash_stacks * CRASH_DAMAGE_PER_STACK

func add_crash(stacks: int):
	crash_stacks = min(MAX_CRASH_STACKS, crash_stacks + stacks)
	crash_changed.emit(crash_stacks)

func consume_crash() -> int:
	## 消耗所有崩溃层数并返回层数（不清零，由take_damage处理）
	var consumed = crash_stacks
	crash_stacks = 0
	return consumed

func add_vulnerable(stacks: int):
	vulnerable_stacks += stacks

func reset_turn():
	vulnerable_stacks = 0
	last_turn_damage_taken = false
	# 崩溃层数跨回合保留（不清零）
