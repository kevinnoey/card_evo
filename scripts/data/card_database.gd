class_name CardDatabase
extends Node
## Card database - all 20 PRD card definitions with evolution chains
## ALL cards are evolvable (Lv2 at 8EP, Lv3 at 20EP)

enum CardType { ATTACK, SKILL, STRATEGY, PROGRAM }
enum Rarity { COMMON, UNCOMMON, RARE }

const TYPE_COLORS = {
	CardType.ATTACK: Color("#FF3B3B"),
	CardType.SKILL: Color("#3B8CFF"),
	CardType.STRATEGY: Color("#B03BFF"),
	CardType.PROGRAM: Color("#00BFFF"),
}

const TYPE_NAMES = {
	CardType.ATTACK: "攻击",
	CardType.SKILL: "技能",
	CardType.STRATEGY: "策略",
	CardType.PROGRAM: "程序",
}

static func get_card_def(id: String) -> Dictionary:
	return CARD_DATABASE.get(id, {})

static func get_starting_deck() -> Array:
	return [
		"c01_basic_probe", "c02_basic_probe_b", "c03_basic_probe_c",
		"c04_basic_firewall", "c05_basic_firewall_b", "c06_basic_firewall_c",
		"c07_data_overload", "c08_light_scan",
		"c09_deep_infiltrate", "c10_shield_reconstruct",
	]

static func get_starting_deck_crasher() -> Array:
	return [
		"d01_crash_pulse", "d02_data_rip", "d03_recursive_strike",
		"d04_basic_firewall_d", "d05_error_handler", "d06_rollback",
		"d07_crash_induce", "d08_weakness_scan",
		"d09_crash_protocol", "d10_data_harvest",
	]

static func get_starting_deck_for_character(character_id: String) -> Array:
	if character_id == "crasher":
		return get_starting_deck_crasher()
	return get_starting_deck()

static func get_character_info(character_id: String) -> Dictionary:
	match character_id:
		"infiltrator":
			return {
				"id": "infiltrator",
				"name": "渗透者",
				"hp": 70,
				"ep_per_turn": 3,
				"hand_size": 5,
				"color": Color("#00F0FF"),
				"mechanic": "穿甲 · 屏障 · 注入进化",
				"description": "攻防均衡，稳定成长。穿甲无视护甲，屏障吸收伤害，程序牌注入进化触发绽放。",
				"difficulty": "中等",
			}
		"crasher":
			return {
				"id": "crasher",
				"name": "代码崩溃者",
				"hp": 55,
				"ep_per_turn": 3,
				"hand_size": 5,
				"color": Color("#FF3B8C"),
				"mechanic": "崩溃叠层 · 终结爆发",
				"description": "高风险高回报。叠崩溃层数放大攻击伤害，命中后清零。需要精准计算斩杀线。",
				"difficulty": "较高",
			}
	return get_character_info("infiltrator")

const CARD_DATABASE = {
	# ===== C01: 基础刺探 (ATTACK, 1 EP) =====
	"c01_basic_probe": {
		"card_id": "c01_basic_probe", "name": "基础刺探", "type": CardType.ATTACK, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c01",
		"evolution_chain": ["c01_basic_probe", "c01_basic_probe_l2", "c01_basic_probe_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 造成 6 点伤害\nLv.2(8EP): 造成 9 伤\nLv.3(20EP): 造成 12 伤+抽1",
		"effect": {"damage": 6},
	},
	"c01_basic_probe_l2": {
		"card_id": "c01_basic_probe_l2", "name": "基础刺探+", "type": CardType.ATTACK, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c01",
		"evolution_chain": ["c01_basic_probe", "c01_basic_probe_l2", "c01_basic_probe_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 造成 9 点伤害\nLv.3(20EP): 造成 12 伤+抽1",
		"effect": {"damage": 9},
	},
	"c01_basic_probe_l3": {
		"card_id": "c01_basic_probe_l3", "name": "基础刺探MAX", "type": CardType.ATTACK, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c01",
		"evolution_chain": ["c01_basic_probe", "c01_basic_probe_l2", "c01_basic_probe_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 造成 12 点伤害，抽 1 张牌",
		"effect": {"damage": 12, "draw": 1},
	},

	# ===== C02: 强化刺探 (ATTACK, 1 EP) =====
	"c02_basic_probe_b": {
		"card_id": "c02_basic_probe_b", "name": "强化刺探", "type": CardType.ATTACK, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c02",
		"evolution_chain": ["c02_basic_probe_b", "c02_basic_probe_b_l2", "c02_basic_probe_b_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 造成 7 点伤害\nLv.2(8EP): 造成 10 伤\nLv.3(20EP): 造成 14 伤",
		"effect": {"damage": 7},
	},
	"c02_basic_probe_b_l2": {
		"card_id": "c02_basic_probe_b_l2", "name": "强化刺探+", "type": CardType.ATTACK, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c02",
		"evolution_chain": ["c02_basic_probe_b", "c02_basic_probe_b_l2", "c02_basic_probe_b_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 造成 10 点伤害\nLv.3(20EP): 造成 14 伤",
		"effect": {"damage": 10},
	},
	"c02_basic_probe_b_l3": {
		"card_id": "c02_basic_probe_b_l3", "name": "强化刺探MAX", "type": CardType.ATTACK, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c02",
		"evolution_chain": ["c02_basic_probe_b", "c02_basic_probe_b_l2", "c02_basic_probe_b_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 造成 14 点伤害",
		"effect": {"damage": 14},
	},

	# ===== C03: 精准刺探 (ATTACK, 1 EP) =====
	"c03_basic_probe_c": {
		"card_id": "c03_basic_probe_c", "name": "精准刺探", "type": CardType.ATTACK, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c03",
		"evolution_chain": ["c03_basic_probe_c", "c03_basic_probe_c_l2", "c03_basic_probe_c_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 造成 6 伤+穿甲1\nLv.2(8EP): 9伤+穿甲2\nLv.3(20EP): 12伤+穿甲3",
		"effect": {"damage": 6, "pierce": 1},
	},
	"c03_basic_probe_c_l2": {
		"card_id": "c03_basic_probe_c_l2", "name": "精准刺探+", "type": CardType.ATTACK, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c03",
		"evolution_chain": ["c03_basic_probe_c", "c03_basic_probe_c_l2", "c03_basic_probe_c_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 造成 9 伤+穿甲2\nLv.3(20EP): 12伤+穿甲3",
		"effect": {"damage": 9, "pierce": 2},
	},
	"c03_basic_probe_c_l3": {
		"card_id": "c03_basic_probe_c_l3", "name": "精准刺探MAX", "type": CardType.ATTACK, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c03",
		"evolution_chain": ["c03_basic_probe_c", "c03_basic_probe_c_l2", "c03_basic_probe_c_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 造成 12 伤+穿甲3",
		"effect": {"damage": 12, "pierce": 3},
	},

	# ===== C04: 基础防火墙 (SKILL, 1 EP) =====
	"c04_basic_firewall": {
		"card_id": "c04_basic_firewall", "name": "基础防火墙", "type": CardType.SKILL, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c04",
		"evolution_chain": ["c04_basic_firewall", "c04_basic_firewall_l2", "c04_basic_firewall_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 获得 5 格挡\nLv.2(8EP): 8格挡\nLv.3(20EP): 12格挡",
		"effect": {"block": 5},
	},
	"c04_basic_firewall_l2": {
		"card_id": "c04_basic_firewall_l2", "name": "基础防火墙+", "type": CardType.SKILL, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c04",
		"evolution_chain": ["c04_basic_firewall", "c04_basic_firewall_l2", "c04_basic_firewall_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 获得 8 格挡\nLv.3(20EP): 12格挡",
		"effect": {"block": 8},
	},
	"c04_basic_firewall_l3": {
		"card_id": "c04_basic_firewall_l3", "name": "基础防火墙MAX", "type": CardType.SKILL, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c04",
		"evolution_chain": ["c04_basic_firewall", "c04_basic_firewall_l2", "c04_basic_firewall_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 获得 12 格挡",
		"effect": {"block": 12},
	},

	# ===== C05: 强化防火墙 (SKILL, 1 EP) =====
	"c05_basic_firewall_b": {
		"card_id": "c05_basic_firewall_b", "name": "强化防火墙", "type": CardType.SKILL, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c05",
		"evolution_chain": ["c05_basic_firewall_b", "c05_basic_firewall_b_l2", "c05_basic_firewall_b_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 获得 6 格挡\nLv.2(8EP): 9格挡\nLv.3(20EP): 13格挡+屏障2",
		"effect": {"block": 6},
	},
	"c05_basic_firewall_b_l2": {
		"card_id": "c05_basic_firewall_b_l2", "name": "强化防火墙+", "type": CardType.SKILL, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c05",
		"evolution_chain": ["c05_basic_firewall_b", "c05_basic_firewall_b_l2", "c05_basic_firewall_b_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 获得 9 格挡\nLv.3(20EP): 13格挡+屏障2",
		"effect": {"block": 9},
	},
	"c05_basic_firewall_b_l3": {
		"card_id": "c05_basic_firewall_b_l3", "name": "强化防火墙MAX", "type": CardType.SKILL, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c05",
		"evolution_chain": ["c05_basic_firewall_b", "c05_basic_firewall_b_l2", "c05_basic_firewall_b_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 获得 13 格挡+屏障2",
		"effect": {"block": 13, "barrier": 2},
	},

	# ===== C06: 快速防火墙 (SKILL, 1 EP) =====
	"c06_basic_firewall_c": {
		"card_id": "c06_basic_firewall_c", "name": "快速防火墙", "type": CardType.SKILL, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c06",
		"evolution_chain": ["c06_basic_firewall_c", "c06_basic_firewall_c_l2", "c06_basic_firewall_c_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 4格挡+抽1\nLv.2(8EP): 6格挡+抽1\nLv.3(20EP): 8格挡+抽2",
		"effect": {"block": 4, "draw": 1},
	},
	"c06_basic_firewall_c_l2": {
		"card_id": "c06_basic_firewall_c_l2", "name": "快速防火墙+", "type": CardType.SKILL, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c06",
		"evolution_chain": ["c06_basic_firewall_c", "c06_basic_firewall_c_l2", "c06_basic_firewall_c_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 6格挡+抽1\nLv.3(20EP): 8格挡+抽2",
		"effect": {"block": 6, "draw": 1},
	},
	"c06_basic_firewall_c_l3": {
		"card_id": "c06_basic_firewall_c_l3", "name": "快速防火墙MAX", "type": CardType.SKILL, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c06",
		"evolution_chain": ["c06_basic_firewall_c", "c06_basic_firewall_c_l2", "c06_basic_firewall_c_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 获得 8 格挡，抽 2 张牌",
		"effect": {"block": 8, "draw": 2},
	},

	# ===== C07: 数据过载 (STRATEGY, 0 EP) =====
	"c07_data_overload": {
		"card_id": "c07_data_overload", "name": "数据过载", "type": CardType.STRATEGY, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c07",
		"evolution_chain": ["c07_data_overload", "c07_data_overload_l2", "c07_data_overload_l3"],
		"ep_to_evolve": 8, "cost": 0,
		"description": "Lv.1: 抽1+下回合EP-1\nLv.2(8EP): 抽2+下回合EP-1\nLv.3(20EP): 抽2(无惩罚)",
		"effect": {"draw": 1, "ep_penalty": 1},
	},
	"c07_data_overload_l2": {
		"card_id": "c07_data_overload_l2", "name": "数据过载+", "type": CardType.STRATEGY, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c07",
		"evolution_chain": ["c07_data_overload", "c07_data_overload_l2", "c07_data_overload_l3"],
		"ep_to_evolve": 20, "cost": 0,
		"description": "Lv.2: 抽2+下回合EP-1\nLv.3(20EP): 抽2(无惩罚)",
		"effect": {"draw": 2, "ep_penalty": 1},
	},
	"c07_data_overload_l3": {
		"card_id": "c07_data_overload_l3", "name": "数据过载MAX", "type": CardType.STRATEGY, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c07",
		"evolution_chain": ["c07_data_overload", "c07_data_overload_l2", "c07_data_overload_l3"],
		"ep_to_evolve": -1, "cost": 0,
		"description": "Lv.3 MAX: 抽 2 张牌（无惩罚）",
		"effect": {"draw": 2},
	},

	# ===== C08: 轻量扫描 (STRATEGY, 0 EP) =====
	"c08_light_scan": {
		"card_id": "c08_light_scan", "name": "轻量扫描", "type": CardType.STRATEGY, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c08",
		"evolution_chain": ["c08_light_scan", "c08_light_scan_l2", "c08_light_scan_l3"],
		"ep_to_evolve": 8, "cost": 0,
		"description": "Lv.1: 3伤+自身脆弱1\nLv.2(8EP): 5伤+自身脆弱1\nLv.3(20EP): 5伤+敌方脆弱2",
		"effect": {"damage": 3, "self_vulnerable": 1},
	},
	"c08_light_scan_l2": {
		"card_id": "c08_light_scan_l2", "name": "轻量扫描+", "type": CardType.STRATEGY, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c08",
		"evolution_chain": ["c08_light_scan", "c08_light_scan_l2", "c08_light_scan_l3"],
		"ep_to_evolve": 20, "cost": 0,
		"description": "Lv.2: 5伤+自身脆弱1\nLv.3(20EP): 5伤+敌方脆弱2",
		"effect": {"damage": 5, "self_vulnerable": 1},
	},
	"c08_light_scan_l3": {
		"card_id": "c08_light_scan_l3", "name": "轻量扫描MAX", "type": CardType.STRATEGY, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c08",
		"evolution_chain": ["c08_light_scan", "c08_light_scan_l2", "c08_light_scan_l3"],
		"ep_to_evolve": -1, "cost": 0,
		"description": "Lv.3 MAX: 造成 5 伤+敌方脆弱2",
		"effect": {"damage": 5, "vulnerable": 2},
	},

	# ===== C09: 深度渗透 (PROGRAM, 1 EP) =====
	"c09_deep_infiltrate": {
		"card_id": "c09_deep_infiltrate", "name": "深度渗透", "type": CardType.PROGRAM, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c09",
		"evolution_chain": ["c09_deep_infiltrate", "c09_deep_infiltrate_l2", "c09_deep_infiltrate_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 5伤\nLv.2(8EP): 7伤+抽1\nLv.3(20EP): 10伤+抽2",
		"effect": {"damage": 5},
	},
	"c09_deep_infiltrate_l2": {
		"card_id": "c09_deep_infiltrate_l2", "name": "深度渗透+", "type": CardType.PROGRAM, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c09",
		"evolution_chain": ["c09_deep_infiltrate", "c09_deep_infiltrate_l2", "c09_deep_infiltrate_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 7伤+抽1\nLv.3(20EP): 10伤+抽2",
		"effect": {"damage": 7, "draw": 1},
	},
	"c09_deep_infiltrate_l3": {
		"card_id": "c09_deep_infiltrate_l3", "name": "深度渗透MAX", "type": CardType.PROGRAM, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c09",
		"evolution_chain": ["c09_deep_infiltrate", "c09_deep_infiltrate_l2", "c09_deep_infiltrate_l3"],
		"ep_to_evolve": -1, "cost": 2,
		"description": "Lv.3 MAX: 造成 10 点伤害，抽 2 张牌",
		"effect": {"damage": 10, "draw": 2},
	},

	# ===== C10: 护盾重构 (PROGRAM, 1 EP) =====
	"c10_shield_reconstruct": {
		"card_id": "c10_shield_reconstruct", "name": "护盾重构", "type": CardType.PROGRAM, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c10",
		"evolution_chain": ["c10_shield_reconstruct", "c10_shield_reconstruct_l2", "c10_shield_reconstruct_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 4格挡\nLv.2(8EP): 7格挡+保留\nLv.3(20EP): 12格挡+反弹5",
		"effect": {"block": 4},
	},
	"c10_shield_reconstruct_l2": {
		"card_id": "c10_shield_reconstruct_l2", "name": "护盾重构+", "type": CardType.PROGRAM, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c10",
		"evolution_chain": ["c10_shield_reconstruct", "c10_shield_reconstruct_l2", "c10_shield_reconstruct_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 7格挡+保留\nLv.3(20EP): 12格挡+反弹5",
		"effect": {"block": 7, "block_persist": true},
	},
	"c10_shield_reconstruct_l3": {
		"card_id": "c10_shield_reconstruct_l3", "name": "护盾重构MAX", "type": CardType.PROGRAM, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c10",
		"evolution_chain": ["c10_shield_reconstruct", "c10_shield_reconstruct_l2", "c10_shield_reconstruct_l3"],
		"ep_to_evolve": -1, "cost": 2,
		"description": "Lv.3 MAX: 获得 12 格挡，反弹 5 点伤害",
		"effect": {"block": 12, "reflect": 5},
	},

	# ===== C11: 重击 (ATTACK, 2 EP) =====
	"c11_heavy_strike": {
		"card_id": "c11_heavy_strike", "name": "重击", "type": CardType.ATTACK, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c11",
		"evolution_chain": ["c11_heavy_strike", "c11_heavy_strike_l2", "c11_heavy_strike_l3"],
		"ep_to_evolve": 8, "cost": 2,
		"description": "Lv.1: 12伤\nLv.2(8EP): 16伤\nLv.3(20EP): 22伤",
		"effect": {"damage": 12},
	},
	"c11_heavy_strike_l2": {
		"card_id": "c11_heavy_strike_l2", "name": "重击+", "type": CardType.ATTACK, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c11",
		"evolution_chain": ["c11_heavy_strike", "c11_heavy_strike_l2", "c11_heavy_strike_l3"],
		"ep_to_evolve": 20, "cost": 2,
		"description": "Lv.2: 16伤\nLv.3(20EP): 22伤",
		"effect": {"damage": 16},
	},
	"c11_heavy_strike_l3": {
		"card_id": "c11_heavy_strike_l3", "name": "重击MAX", "type": CardType.ATTACK, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c11",
		"evolution_chain": ["c11_heavy_strike", "c11_heavy_strike_l2", "c11_heavy_strike_l3"],
		"ep_to_evolve": -1, "cost": 2,
		"description": "Lv.3 MAX: 造成 22 点伤害",
		"effect": {"damage": 22},
	},

	# ===== C12: 快速扫描 (STRATEGY, 0 EP) =====
	"c12_rapid_scan": {
		"card_id": "c12_rapid_scan", "name": "快速扫描", "type": CardType.STRATEGY, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c12",
		"evolution_chain": ["c12_rapid_scan", "c12_rapid_scan_l2", "c12_rapid_scan_l3"],
		"ep_to_evolve": 8, "cost": 0,
		"description": "Lv.1: 抽2\nLv.2(8EP): 抽3\nLv.3(20EP): 抽3+屏障1",
		"effect": {"draw": 2},
	},
	"c12_rapid_scan_l2": {
		"card_id": "c12_rapid_scan_l2", "name": "快速扫描+", "type": CardType.STRATEGY, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c12",
		"evolution_chain": ["c12_rapid_scan", "c12_rapid_scan_l2", "c12_rapid_scan_l3"],
		"ep_to_evolve": 20, "cost": 0,
		"description": "Lv.2: 抽3\nLv.3(20EP): 抽3+屏障1",
		"effect": {"draw": 3},
	},
	"c12_rapid_scan_l3": {
		"card_id": "c12_rapid_scan_l3", "name": "快速扫描MAX", "type": CardType.STRATEGY, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c12",
		"evolution_chain": ["c12_rapid_scan", "c12_rapid_scan_l2", "c12_rapid_scan_l3"],
		"ep_to_evolve": -1, "cost": 0,
		"description": "Lv.3 MAX: 抽 3 张牌+屏障1",
		"effect": {"draw": 3, "barrier": 1},
	},

	# ===== C13: EP 增幅 (STRATEGY, 0 EP) =====
	"c13_ep_boost": {
		"card_id": "c13_ep_boost", "name": "EP 增幅", "type": CardType.STRATEGY, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c13",
		"evolution_chain": ["c13_ep_boost", "c13_ep_boost_l2", "c13_ep_boost_l3"],
		"ep_to_evolve": 8, "cost": 0,
		"description": "Lv.1: +1 EP\nLv.2(8EP): +2 EP\nLv.3(20EP): +3 EP",
		"effect": {"gain_ep": 1},
	},
	"c13_ep_boost_l2": {
		"card_id": "c13_ep_boost_l2", "name": "EP 增幅+", "type": CardType.STRATEGY, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c13",
		"evolution_chain": ["c13_ep_boost", "c13_ep_boost_l2", "c13_ep_boost_l3"],
		"ep_to_evolve": 20, "cost": 0,
		"description": "Lv.2: +2 EP\nLv.3(20EP): +3 EP",
		"effect": {"gain_ep": 2},
	},
	"c13_ep_boost_l3": {
		"card_id": "c13_ep_boost_l3", "name": "EP 增幅MAX", "type": CardType.STRATEGY, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c13",
		"evolution_chain": ["c13_ep_boost", "c13_ep_boost_l2", "c13_ep_boost_l3"],
		"ep_to_evolve": -1, "cost": 0,
		"description": "Lv.3 MAX: +3 EP",
		"effect": {"gain_ep": 3},
	},

	# ===== C14: 过载脉冲 (ATTACK, 2 EP) =====
	"c14_overload_pulse": {
		"card_id": "c14_overload_pulse", "name": "过载脉冲", "type": CardType.ATTACK, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c14",
		"evolution_chain": ["c14_overload_pulse", "c14_overload_pulse_l2", "c14_overload_pulse_l3"],
		"ep_to_evolve": 8, "cost": 2,
		"description": "Lv.1: 8伤+自身脆弱1\nLv.2(8EP): 11伤+自身脆弱1\nLv.3(20EP): 15伤+自身脆弱1",
		"effect": {"damage": 8, "self_vulnerable": 1},
	},
	"c14_overload_pulse_l2": {
		"card_id": "c14_overload_pulse_l2", "name": "过载脉冲+", "type": CardType.ATTACK, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c14",
		"evolution_chain": ["c14_overload_pulse", "c14_overload_pulse_l2", "c14_overload_pulse_l3"],
		"ep_to_evolve": 20, "cost": 2,
		"description": "Lv.2: 11伤+自身脆弱1\nLv.3(20EP): 15伤+自身脆弱1",
		"effect": {"damage": 11, "self_vulnerable": 1},
	},
	"c14_overload_pulse_l3": {
		"card_id": "c14_overload_pulse_l3", "name": "过载脉冲MAX", "type": CardType.ATTACK, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c14",
		"evolution_chain": ["c14_overload_pulse", "c14_overload_pulse_l2", "c14_overload_pulse_l3"],
		"ep_to_evolve": -1, "cost": 2,
		"description": "Lv.3 MAX: 造成 15 伤+自身脆弱1",
		"effect": {"damage": 15, "self_vulnerable": 1},
	},

	# ===== C15: 加固 (SKILL, 1 EP) =====
	"c15_reinforce": {
		"card_id": "c15_reinforce", "name": "加固", "type": CardType.SKILL, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c15",
		"evolution_chain": ["c15_reinforce", "c15_reinforce_l2", "c15_reinforce_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 8格挡\nLv.2(8EP): 12格挡\nLv.3(20EP): 16格挡+屏障1",
		"effect": {"block": 8},
	},
	"c15_reinforce_l2": {
		"card_id": "c15_reinforce_l2", "name": "加固+", "type": CardType.SKILL, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c15",
		"evolution_chain": ["c15_reinforce", "c15_reinforce_l2", "c15_reinforce_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 12格挡\nLv.3(20EP): 16格挡+屏障1",
		"effect": {"block": 12},
	},
	"c15_reinforce_l3": {
		"card_id": "c15_reinforce_l3", "name": "加固MAX", "type": CardType.SKILL, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c15",
		"evolution_chain": ["c15_reinforce", "c15_reinforce_l2", "c15_reinforce_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 获得 16 格挡+屏障1",
		"effect": {"block": 16, "barrier": 1},
	},

	# ===== C16: 系统抽取 (ATTACK, 1 EP) =====
	"c16_system_drain": {
		"card_id": "c16_system_drain", "name": "系统抽取", "type": CardType.ATTACK, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c16",
		"evolution_chain": ["c16_system_drain", "c16_system_drain_l2", "c16_system_drain_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 4伤+回2HP\nLv.2(8EP): 6伤+回3HP\nLv.3(20EP): 8伤+回5HP",
		"effect": {"damage": 4, "heal": 2},
	},
	"c16_system_drain_l2": {
		"card_id": "c16_system_drain_l2", "name": "系统抽取+", "type": CardType.ATTACK, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c16",
		"evolution_chain": ["c16_system_drain", "c16_system_drain_l2", "c16_system_drain_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 6伤+回3HP\nLv.3(20EP): 8伤+回5HP",
		"effect": {"damage": 6, "heal": 3},
	},
	"c16_system_drain_l3": {
		"card_id": "c16_system_drain_l3", "name": "系统抽取MAX", "type": CardType.ATTACK, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c16",
		"evolution_chain": ["c16_system_drain", "c16_system_drain_l2", "c16_system_drain_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 造成 8 伤+回5HP",
		"effect": {"damage": 8, "heal": 5},
	},

	# ===== C17: 快速注入 (STRATEGY, 1 EP) =====
	"c17_quick_inject": {
		"card_id": "c17_quick_inject", "name": "快速注入", "type": CardType.STRATEGY, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c17",
		"evolution_chain": ["c17_quick_inject", "c17_quick_inject_l2", "c17_quick_inject_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 注入2EP\nLv.2(8EP): 注入3EP\nLv.3(20EP): 注入4EP+抽1",
		"effect": {"inject_target": 2},
	},
	"c17_quick_inject_l2": {
		"card_id": "c17_quick_inject_l2", "name": "快速注入+", "type": CardType.STRATEGY, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c17",
		"evolution_chain": ["c17_quick_inject", "c17_quick_inject_l2", "c17_quick_inject_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 注入3EP\nLv.3(20EP): 注入4EP+抽1",
		"effect": {"inject_target": 3},
	},
	"c17_quick_inject_l3": {
		"card_id": "c17_quick_inject_l3", "name": "快速注入MAX", "type": CardType.STRATEGY, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c17",
		"evolution_chain": ["c17_quick_inject", "c17_quick_inject_l2", "c17_quick_inject_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 注入4EP+抽1",
		"effect": {"inject_target": 4, "draw": 1},
	},

	# ===== C18: 镜像护盾 (SKILL, 2 EP) =====
	"c18_mirror_shield": {
		"card_id": "c18_mirror_shield", "name": "镜像护盾", "type": CardType.SKILL, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c18",
		"evolution_chain": ["c18_mirror_shield", "c18_mirror_shield_l2", "c18_mirror_shield_l3"],
		"ep_to_evolve": 8, "cost": 2,
		"description": "Lv.1: 6格挡+反弹3\nLv.2(8EP): 9格挡+反弹5\nLv.3(20EP): 12格挡+反弹8",
		"effect": {"block": 6, "reflect": 3},
	},
	"c18_mirror_shield_l2": {
		"card_id": "c18_mirror_shield_l2", "name": "镜像护盾+", "type": CardType.SKILL, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c18",
		"evolution_chain": ["c18_mirror_shield", "c18_mirror_shield_l2", "c18_mirror_shield_l3"],
		"ep_to_evolve": 20, "cost": 2,
		"description": "Lv.2: 9格挡+反弹5\nLv.3(20EP): 12格挡+反弹8",
		"effect": {"block": 9, "reflect": 5},
	},
	"c18_mirror_shield_l3": {
		"card_id": "c18_mirror_shield_l3", "name": "镜像护盾MAX", "type": CardType.SKILL, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c18",
		"evolution_chain": ["c18_mirror_shield", "c18_mirror_shield_l2", "c18_mirror_shield_l3"],
		"ep_to_evolve": -1, "cost": 2,
		"description": "Lv.3 MAX: 获得 12 格挡+反弹8",
		"effect": {"block": 12, "reflect": 8},
	},

	# ===== C19: 核心超频 (PROGRAM, 2 EP) =====
	"c19_core_overclock": {
		"card_id": "c19_core_overclock", "name": "核心超频", "type": CardType.PROGRAM, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c19",
		"evolution_chain": ["c19_core_overclock", "c19_core_overclock_l2", "c19_core_overclock_l3"],
		"ep_to_evolve": 8, "cost": 2,
		"description": "Lv.1: 8伤\nLv.2(8EP): 12伤\nLv.3(20EP): 18伤+抽1",
		"effect": {"damage": 8},
	},
	"c19_core_overclock_l2": {
		"card_id": "c19_core_overclock_l2", "name": "核心超频+", "type": CardType.PROGRAM, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c19",
		"evolution_chain": ["c19_core_overclock", "c19_core_overclock_l2", "c19_core_overclock_l3"],
		"ep_to_evolve": 20, "cost": 2,
		"description": "Lv.2: 12伤\nLv.3(20EP): 18伤+抽1",
		"effect": {"damage": 12},
	},
	"c19_core_overclock_l3": {
		"card_id": "c19_core_overclock_l3", "name": "核心超频MAX", "type": CardType.PROGRAM, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c19",
		"evolution_chain": ["c19_core_overclock", "c19_core_overclock_l2", "c19_core_overclock_l3"],
		"ep_to_evolve": -1, "cost": 3,
		"description": "Lv.3 MAX: 造成 18 点伤害，抽 1 张牌",
		"effect": {"damage": 18, "draw": 1},
	},

	# ===== C20: 屏障矩阵 (PROGRAM, 1 EP) =====
	"c20_barrier_matrix": {
		"card_id": "c20_barrier_matrix", "name": "屏障矩阵", "type": CardType.PROGRAM, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "c20",
		"evolution_chain": ["c20_barrier_matrix", "c20_barrier_matrix_l2", "c20_barrier_matrix_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 3格挡+1屏障\nLv.2(8EP): 5格挡+2屏障\nLv.3(20EP): 8格挡+3屏障",
		"effect": {"block": 3, "barrier": 1},
	},
	"c20_barrier_matrix_l2": {
		"card_id": "c20_barrier_matrix_l2", "name": "屏障矩阵+", "type": CardType.PROGRAM, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "c20",
		"evolution_chain": ["c20_barrier_matrix", "c20_barrier_matrix_l2", "c20_barrier_matrix_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 5格挡+2屏障\nLv.3(20EP): 8格挡+3屏障",
		"effect": {"block": 5, "barrier": 2},
	},
	"c20_barrier_matrix_l3": {
		"card_id": "c20_barrier_matrix_l3", "name": "屏障矩阵MAX", "type": CardType.PROGRAM, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "c20",
		"evolution_chain": ["c20_barrier_matrix", "c20_barrier_matrix_l2", "c20_barrier_matrix_l3"],
		"ep_to_evolve": -1, "cost": 2,
		"description": "Lv.3 MAX: 获得 8 格挡+3屏障",
		"effect": {"block": 8, "barrier": 3},
	},

	# ============================================================
	# ===== 代码崩溃者 (Crasher) 卡组 — D01~D20 =====
	# ============================================================

	# ===== D01: 崩溃脉冲 (ATTACK, 1 EP) =====
	"d01_crash_pulse": {
		"card_id": "d01_crash_pulse", "name": "崩溃脉冲", "type": CardType.ATTACK, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d01",
		"evolution_chain": ["d01_crash_pulse", "d01_crash_pulse_l2", "d01_crash_pulse_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 4伤+施加崩溃1\nLv.2(8EP): 6伤+施加崩溃1\nLv.3(20EP): 8伤+施加崩溃2",
		"effect": {"damage": 4, "crash": 1},
	},
	"d01_crash_pulse_l2": {
		"card_id": "d01_crash_pulse_l2", "name": "崩溃脉冲+", "type": CardType.ATTACK, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d01",
		"evolution_chain": ["d01_crash_pulse", "d01_crash_pulse_l2", "d01_crash_pulse_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 6伤+施加崩溃1\nLv.3(20EP): 8伤+施加崩溃2",
		"effect": {"damage": 6, "crash": 1},
	},
	"d01_crash_pulse_l3": {
		"card_id": "d01_crash_pulse_l3", "name": "崩溃脉冲MAX", "type": CardType.ATTACK, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d01",
		"evolution_chain": ["d01_crash_pulse", "d01_crash_pulse_l2", "d01_crash_pulse_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 造成 8 伤+施加崩溃2",
		"effect": {"damage": 8, "crash": 2},
	},

	# ===== D02: 数据撕裂 (ATTACK, 1 EP) =====
	"d02_data_rip": {
		"card_id": "d02_data_rip", "name": "数据撕裂", "type": CardType.ATTACK, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d02",
		"evolution_chain": ["d02_data_rip", "d02_data_rip_l2", "d02_data_rip_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 5伤(若敌有崩溃→8)\nLv.2(8EP): 7伤→11\nLv.3(20EP): 9伤→15",
		"effect": {"damage": 5, "bonus_if_crash": 3},
	},
	"d02_data_rip_l2": {
		"card_id": "d02_data_rip_l2", "name": "数据撕裂+", "type": CardType.ATTACK, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d02",
		"evolution_chain": ["d02_data_rip", "d02_data_rip_l2", "d02_data_rip_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 7伤(若敌有崩溃→11)\nLv.3(20EP): 9伤→15",
		"effect": {"damage": 7, "bonus_if_crash": 4},
	},
	"d02_data_rip_l3": {
		"card_id": "d02_data_rip_l3", "name": "数据撕裂MAX", "type": CardType.ATTACK, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d02",
		"evolution_chain": ["d02_data_rip", "d02_data_rip_l2", "d02_data_rip_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 9伤(若敌有崩溃→15)",
		"effect": {"damage": 9, "bonus_if_crash": 6},
	},

	# ===== D03: 递归打击 (ATTACK, 2 EP) =====
	"d03_recursive_strike": {
		"card_id": "d03_recursive_strike", "name": "递归打击", "type": CardType.ATTACK, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d03",
		"evolution_chain": ["d03_recursive_strike", "d03_recursive_strike_l2", "d03_recursive_strike_l3"],
		"ep_to_evolve": 8, "cost": 2,
		"description": "Lv.1: 6伤+复制崩溃层数\nLv.2(8EP): 8伤+复制崩溃\nLv.3(20EP): 10伤+复制崩溃+1",
		"effect": {"damage": 6, "crash_copy": true},
	},
	"d03_recursive_strike_l2": {
		"card_id": "d03_recursive_strike_l2", "name": "递归打击+", "type": CardType.ATTACK, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d03",
		"evolution_chain": ["d03_recursive_strike", "d03_recursive_strike_l2", "d03_recursive_strike_l3"],
		"ep_to_evolve": 20, "cost": 2,
		"description": "Lv.2: 8伤+复制崩溃层数\nLv.3(20EP): 10伤+复制崩溃+1",
		"effect": {"damage": 8, "crash_copy": true},
	},
	"d03_recursive_strike_l3": {
		"card_id": "d03_recursive_strike_l3", "name": "递归打击MAX", "type": CardType.ATTACK, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d03",
		"evolution_chain": ["d03_recursive_strike", "d03_recursive_strike_l2", "d03_recursive_strike_l3"],
		"ep_to_evolve": -1, "cost": 2,
		"description": "Lv.3 MAX: 10伤+复制崩溃层数+1",
		"effect": {"damage": 10, "crash_copy": true, "crash_copy_bonus": 1},
	},

	# ===== D04: 基础防火墙-D (SKILL, 1 EP) =====
	"d04_basic_firewall_d": {
		"card_id": "d04_basic_firewall_d", "name": "基础防火墙", "type": CardType.SKILL, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d04",
		"evolution_chain": ["d04_basic_firewall_d", "d04_basic_firewall_d_l2", "d04_basic_firewall_d_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 5格挡\nLv.2(8EP): 8格挡\nLv.3(20EP): 12格挡",
		"effect": {"block": 5},
	},
	"d04_basic_firewall_d_l2": {
		"card_id": "d04_basic_firewall_d_l2", "name": "基础防火墙+", "type": CardType.SKILL, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d04",
		"evolution_chain": ["d04_basic_firewall_d", "d04_basic_firewall_d_l2", "d04_basic_firewall_d_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 8格挡\nLv.3(20EP): 12格挡",
		"effect": {"block": 8},
	},
	"d04_basic_firewall_d_l3": {
		"card_id": "d04_basic_firewall_d_l3", "name": "基础防火墙MAX", "type": CardType.SKILL, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d04",
		"evolution_chain": ["d04_basic_firewall_d", "d04_basic_firewall_d_l2", "d04_basic_firewall_d_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 12格挡",
		"effect": {"block": 12},
	},

	# ===== D05: 错误处理 (SKILL, 1 EP) =====
	"d05_error_handler": {
		"card_id": "d05_error_handler", "name": "错误处理", "type": CardType.SKILL, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d05",
		"evolution_chain": ["d05_error_handler", "d05_error_handler_l2", "d05_error_handler_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 4格挡+清除自身脆弱\nLv.2(8EP): 6格挡+清除脆弱\nLv.3(20EP): 8格挡+清除脆弱+抽1",
		"effect": {"block": 4, "clear_self_vulnerable": true},
	},
	"d05_error_handler_l2": {
		"card_id": "d05_error_handler_l2", "name": "错误处理+", "type": CardType.SKILL, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d05",
		"evolution_chain": ["d05_error_handler", "d05_error_handler_l2", "d05_error_handler_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 6格挡+清除脆弱\nLv.3(20EP): 8格挡+清除脆弱+抽1",
		"effect": {"block": 6, "clear_self_vulnerable": true},
	},
	"d05_error_handler_l3": {
		"card_id": "d05_error_handler_l3", "name": "错误处理MAX", "type": CardType.SKILL, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d05",
		"evolution_chain": ["d05_error_handler", "d05_error_handler_l2", "d05_error_handler_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 8格挡+清除脆弱+抽1",
		"effect": {"block": 8, "clear_self_vulnerable": true, "draw": 1},
	},

	# ===== D06: 回滚 (SKILL, 1 EP) =====
	"d06_rollback": {
		"card_id": "d06_rollback", "name": "回滚", "type": CardType.SKILL, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d06",
		"evolution_chain": ["d06_rollback", "d06_rollback_l2", "d06_rollback_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 3格挡+若上回合受伤回3HP\nLv.2(8EP): 5格挡+回4HP\nLv.3(20EP): 7格挡+回6HP",
		"effect": {"block": 3, "conditional_heal": 3},
	},
	"d06_rollback_l2": {
		"card_id": "d06_rollback_l2", "name": "回滚+", "type": CardType.SKILL, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d06",
		"evolution_chain": ["d06_rollback", "d06_rollback_l2", "d06_rollback_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 5格挡+若上回合受伤回4HP\nLv.3(20EP): 7格挡+回6HP",
		"effect": {"block": 5, "conditional_heal": 4},
	},
	"d06_rollback_l3": {
		"card_id": "d06_rollback_l3", "name": "回滚MAX", "type": CardType.SKILL, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d06",
		"evolution_chain": ["d06_rollback", "d06_rollback_l2", "d06_rollback_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 7格挡+若上回合受伤回6HP",
		"effect": {"block": 7, "conditional_heal": 6},
	},

	# ===== D07: 崩溃诱导 (STRATEGY, 0 EP) =====
	"d07_crash_induce": {
		"card_id": "d07_crash_induce", "name": "崩溃诱导", "type": CardType.STRATEGY, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d07",
		"evolution_chain": ["d07_crash_induce", "d07_crash_induce_l2", "d07_crash_induce_l3"],
		"ep_to_evolve": 8, "cost": 0,
		"description": "Lv.1: 施加崩溃1\nLv.2(8EP): 施加崩溃2\nLv.3(20EP): 施加崩溃2+抽1",
		"effect": {"crash": 1},
	},
	"d07_crash_induce_l2": {
		"card_id": "d07_crash_induce_l2", "name": "崩溃诱导+", "type": CardType.STRATEGY, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d07",
		"evolution_chain": ["d07_crash_induce", "d07_crash_induce_l2", "d07_crash_induce_l3"],
		"ep_to_evolve": 20, "cost": 0,
		"description": "Lv.2: 施加崩溃2\nLv.3(20EP): 施加崩溃2+抽1",
		"effect": {"crash": 2},
	},
	"d07_crash_induce_l3": {
		"card_id": "d07_crash_induce_l3", "name": "崩溃诱导MAX", "type": CardType.STRATEGY, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d07",
		"evolution_chain": ["d07_crash_induce", "d07_crash_induce_l2", "d07_crash_induce_l3"],
		"ep_to_evolve": -1, "cost": 0,
		"description": "Lv.3 MAX: 施加崩溃2+抽1",
		"effect": {"crash": 2, "draw": 1},
	},

	# ===== D08: 弱点扫描 (STRATEGY, 0 EP) =====
	"d08_weakness_scan": {
		"card_id": "d08_weakness_scan", "name": "弱点扫描", "type": CardType.STRATEGY, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d08",
		"evolution_chain": ["d08_weakness_scan", "d08_weakness_scan_l2", "d08_weakness_scan_l3"],
		"ep_to_evolve": 8, "cost": 0,
		"description": "Lv.1: 本回合下次攻击+3\nLv.2(8EP): 下次攻击+5\nLv.3(20EP): 下次攻击+7",
		"effect": {"next_attack_bonus": 3},
	},
	"d08_weakness_scan_l2": {
		"card_id": "d08_weakness_scan_l2", "name": "弱点扫描+", "type": CardType.STRATEGY, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d08",
		"evolution_chain": ["d08_weakness_scan", "d08_weakness_scan_l2", "d08_weakness_scan_l3"],
		"ep_to_evolve": 20, "cost": 0,
		"description": "Lv.2: 本回合下次攻击+5\nLv.3(20EP): 下次攻击+7",
		"effect": {"next_attack_bonus": 5},
	},
	"d08_weakness_scan_l3": {
		"card_id": "d08_weakness_scan_l3", "name": "弱点扫描MAX", "type": CardType.STRATEGY, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d08",
		"evolution_chain": ["d08_weakness_scan", "d08_weakness_scan_l2", "d08_weakness_scan_l3"],
		"ep_to_evolve": -1, "cost": 0,
		"description": "Lv.3 MAX: 本回合下次攻击+7",
		"effect": {"next_attack_bonus": 7},
	},

	# ===== D09: 崩溃协议 (PROGRAM, 1 EP) =====
	"d09_crash_protocol": {
		"card_id": "d09_crash_protocol", "name": "崩溃协议", "type": CardType.PROGRAM, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d09",
		"evolution_chain": ["d09_crash_protocol", "d09_crash_protocol_l2", "d09_crash_protocol_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 施加崩溃2\nLv.2(8EP): 施加崩溃3+抽1\nLv.3(20EP): 施加崩溃4+抽1(费用→2)",
		"effect": {"crash": 2},
	},
	"d09_crash_protocol_l2": {
		"card_id": "d09_crash_protocol_l2", "name": "崩溃协议+", "type": CardType.PROGRAM, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d09",
		"evolution_chain": ["d09_crash_protocol", "d09_crash_protocol_l2", "d09_crash_protocol_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 施加崩溃3+抽1\nLv.3(20EP): 施加崩溃4+抽1(费用→2)",
		"effect": {"crash": 3, "draw": 1},
	},
	"d09_crash_protocol_l3": {
		"card_id": "d09_crash_protocol_l3", "name": "崩溃协议MAX", "type": CardType.PROGRAM, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d09",
		"evolution_chain": ["d09_crash_protocol", "d09_crash_protocol_l2", "d09_crash_protocol_l3"],
		"ep_to_evolve": -1, "cost": 2,
		"description": "Lv.3 MAX: 施加崩溃4+抽1",
		"effect": {"crash": 4, "draw": 1},
	},

	# ===== D10: 数据收割 (PROGRAM, 2 EP) =====
	"d10_data_harvest": {
		"card_id": "d10_data_harvest", "name": "数据收割", "type": CardType.PROGRAM, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d10",
		"evolution_chain": ["d10_data_harvest", "d10_data_harvest_l2", "d10_data_harvest_l3"],
		"ep_to_evolve": 8, "cost": 2,
		"description": "Lv.1: 6伤+若崩溃≥3额外8伤\nLv.2(8EP): 8伤+额外10伤\nLv.3(20EP): 10伤+额外14伤(费用→3)",
		"effect": {"damage": 6, "bonus_if_crash_ge": {"threshold": 3, "bonus": 8}},
	},
	"d10_data_harvest_l2": {
		"card_id": "d10_data_harvest_l2", "name": "数据收割+", "type": CardType.PROGRAM, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d10",
		"evolution_chain": ["d10_data_harvest", "d10_data_harvest_l2", "d10_data_harvest_l3"],
		"ep_to_evolve": 20, "cost": 2,
		"description": "Lv.2: 8伤+若崩溃≥3额外10伤\nLv.3(20EP): 10伤+额外14伤(费用→3)",
		"effect": {"damage": 8, "bonus_if_crash_ge": {"threshold": 3, "bonus": 10}},
	},
	"d10_data_harvest_l3": {
		"card_id": "d10_data_harvest_l3", "name": "数据收割MAX", "type": CardType.PROGRAM, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d10",
		"evolution_chain": ["d10_data_harvest", "d10_data_harvest_l2", "d10_data_harvest_l3"],
		"ep_to_evolve": -1, "cost": 3,
		"description": "Lv.3 MAX: 10伤+若崩溃≥3额外14伤",
		"effect": {"damage": 10, "bonus_if_crash_ge": {"threshold": 3, "bonus": 14}},
	},

	# ===== D11: 零日漏洞 (ATTACK, 2 EP) =====
	"d11_zero_day": {
		"card_id": "d11_zero_day", "name": "零日漏洞", "type": CardType.ATTACK, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d11",
		"evolution_chain": ["d11_zero_day", "d11_zero_day_l2", "d11_zero_day_l3"],
		"ep_to_evolve": 8, "cost": 2,
		"description": "Lv.1: 10伤(消耗崩溃)\nLv.2(8EP): 14伤\nLv.3(20EP): 18伤+崩溃1",
		"effect": {"damage": 10},
	},
	"d11_zero_day_l2": {
		"card_id": "d11_zero_day_l2", "name": "零日漏洞+", "type": CardType.ATTACK, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d11",
		"evolution_chain": ["d11_zero_day", "d11_zero_day_l2", "d11_zero_day_l3"],
		"ep_to_evolve": 20, "cost": 2,
		"description": "Lv.2: 14伤(消耗崩溃)\nLv.3(20EP): 18伤+崩溃1",
		"effect": {"damage": 14},
	},
	"d11_zero_day_l3": {
		"card_id": "d11_zero_day_l3", "name": "零日漏洞MAX", "type": CardType.ATTACK, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d11",
		"evolution_chain": ["d11_zero_day", "d11_zero_day_l2", "d11_zero_day_l3"],
		"ep_to_evolve": -1, "cost": 2,
		"description": "Lv.3 MAX: 18伤+施加崩溃1",
		"effect": {"damage": 18, "crash": 1},
	},

	# ===== D12: 系统注入 (STRATEGY, 1 EP) =====
	"d12_system_inject": {
		"card_id": "d12_system_inject", "name": "系统注入", "type": CardType.STRATEGY, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d12",
		"evolution_chain": ["d12_system_inject", "d12_system_inject_l2", "d12_system_inject_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 注入2崩溃\nLv.2(8EP): 注入3崩溃\nLv.3(20EP): 注入4崩溃",
		"effect": {"crash": 2},
	},
	"d12_system_inject_l2": {
		"card_id": "d12_system_inject_l2", "name": "系统注入+", "type": CardType.STRATEGY, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d12",
		"evolution_chain": ["d12_system_inject", "d12_system_inject_l2", "d12_system_inject_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 注入3崩溃\nLv.3(20EP): 注入4崩溃",
		"effect": {"crash": 3},
	},
	"d12_system_inject_l3": {
		"card_id": "d12_system_inject_l3", "name": "系统注入MAX", "type": CardType.STRATEGY, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d12",
		"evolution_chain": ["d12_system_inject", "d12_system_inject_l2", "d12_system_inject_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 注入4崩溃",
		"effect": {"crash": 4},
	},

	# ===== D13: EP劫持 (STRATEGY, 0 EP) =====
	"d13_ep_hijack": {
		"card_id": "d13_ep_hijack", "name": "EP劫持", "type": CardType.STRATEGY, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d13",
		"evolution_chain": ["d13_ep_hijack", "d13_ep_hijack_l2", "d13_ep_hijack_l3"],
		"ep_to_evolve": 8, "cost": 0,
		"description": "Lv.1: 自身脆弱1+2EP\nLv.2(8EP): 脆弱1+3EP\nLv.3(20EP): 3EP(无脆弱)",
		"effect": {"self_vulnerable": 1, "gain_ep": 2},
	},
	"d13_ep_hijack_l2": {
		"card_id": "d13_ep_hijack_l2", "name": "EP劫持+", "type": CardType.STRATEGY, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d13",
		"evolution_chain": ["d13_ep_hijack", "d13_ep_hijack_l2", "d13_ep_hijack_l3"],
		"ep_to_evolve": 20, "cost": 0,
		"description": "Lv.2: 自身脆弱1+3EP\nLv.3(20EP): 3EP(无脆弱)",
		"effect": {"self_vulnerable": 1, "gain_ep": 3},
	},
	"d13_ep_hijack_l3": {
		"card_id": "d13_ep_hijack_l3", "name": "EP劫持MAX", "type": CardType.STRATEGY, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d13",
		"evolution_chain": ["d13_ep_hijack", "d13_ep_hijack_l2", "d13_ep_hijack_l3"],
		"ep_to_evolve": -1, "cost": 0,
		"description": "Lv.3 MAX: +3EP",
		"effect": {"gain_ep": 3},
	},

	# ===== D14: 溢出攻击 (ATTACK, 1 EP) =====
	"d14_overflow_attack": {
		"card_id": "d14_overflow_attack", "name": "溢出攻击", "type": CardType.ATTACK, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d14",
		"evolution_chain": ["d14_overflow_attack", "d14_overflow_attack_l2", "d14_overflow_attack_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 3伤+击杀获得2EP\nLv.2(8EP): 5伤+获得2EP\nLv.3(20EP): 7伤+获得3EP",
		"effect": {"damage": 3, "kill_ep": 2},
	},
	"d14_overflow_attack_l2": {
		"card_id": "d14_overflow_attack_l2", "name": "溢出攻击+", "type": CardType.ATTACK, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d14",
		"evolution_chain": ["d14_overflow_attack", "d14_overflow_attack_l2", "d14_overflow_attack_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 5伤+击杀获得2EP\nLv.3(20EP): 7伤+获得3EP",
		"effect": {"damage": 5, "kill_ep": 2},
	},
	"d14_overflow_attack_l3": {
		"card_id": "d14_overflow_attack_l3", "name": "溢出攻击MAX", "type": CardType.ATTACK, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d14",
		"evolution_chain": ["d14_overflow_attack", "d14_overflow_attack_l2", "d14_overflow_attack_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 7伤+击杀获得3EP",
		"effect": {"damage": 7, "kill_ep": 3},
	},

	# ===== D15: 防火墙超载 (SKILL, 2 EP) =====
	"d15_firewall_overload": {
		"card_id": "d15_firewall_overload", "name": "防火墙超载", "type": CardType.SKILL, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d15",
		"evolution_chain": ["d15_firewall_overload", "d15_firewall_overload_l2", "d15_firewall_overload_l3"],
		"ep_to_evolve": 8, "cost": 2,
		"description": "Lv.1: 10格挡+自身脆弱2\nLv.2(8EP): 14格挡+自身脆弱1\nLv.3(20EP): 18格挡",
		"effect": {"block": 10, "self_vulnerable": 2},
	},
	"d15_firewall_overload_l2": {
		"card_id": "d15_firewall_overload_l2", "name": "防火墙超载+", "type": CardType.SKILL, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d15",
		"evolution_chain": ["d15_firewall_overload", "d15_firewall_overload_l2", "d15_firewall_overload_l3"],
		"ep_to_evolve": 20, "cost": 2,
		"description": "Lv.2: 14格挡+自身脆弱1\nLv.3(20EP): 18格挡",
		"effect": {"block": 14, "self_vulnerable": 1},
	},
	"d15_firewall_overload_l3": {
		"card_id": "d15_firewall_overload_l3", "name": "防火墙超载MAX", "type": CardType.SKILL, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d15",
		"evolution_chain": ["d15_firewall_overload", "d15_firewall_overload_l2", "d15_firewall_overload_l3"],
		"ep_to_evolve": -1, "cost": 2,
		"description": "Lv.3 MAX: 18格挡",
		"effect": {"block": 18},
	},

	# ===== D16: 内存泄漏 (ATTACK, 1 EP) =====
	"d16_memory_leak": {
		"card_id": "d16_memory_leak", "name": "内存泄漏", "type": CardType.ATTACK, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d16",
		"evolution_chain": ["d16_memory_leak", "d16_memory_leak_l2", "d16_memory_leak_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 4伤+自身脆弱1\nLv.2(8EP): 6伤+自身脆弱1\nLv.3(20EP): 9伤(无脆弱)",
		"effect": {"damage": 4, "self_vulnerable": 1},
	},
	"d16_memory_leak_l2": {
		"card_id": "d16_memory_leak_l2", "name": "内存泄漏+", "type": CardType.ATTACK, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d16",
		"evolution_chain": ["d16_memory_leak", "d16_memory_leak_l2", "d16_memory_leak_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 6伤+自身脆弱1\nLv.3(20EP): 9伤(无脆弱)",
		"effect": {"damage": 6, "self_vulnerable": 1},
	},
	"d16_memory_leak_l3": {
		"card_id": "d16_memory_leak_l3", "name": "内存泄漏MAX", "type": CardType.ATTACK, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d16",
		"evolution_chain": ["d16_memory_leak", "d16_memory_leak_l2", "d16_memory_leak_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 9伤",
		"effect": {"damage": 9},
	},

	# ===== D17: 快速注入-D (STRATEGY, 1 EP) =====
	"d17_quick_inject_d": {
		"card_id": "d17_quick_inject_d", "name": "快速注入", "type": CardType.STRATEGY, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d17",
		"evolution_chain": ["d17_quick_inject_d", "d17_quick_inject_d_l2", "d17_quick_inject_d_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 注入程序牌2EP\nLv.2(8EP): 注入3EP\nLv.3(20EP): 注入4EP+抽1",
		"effect": {"inject_program": 2},
	},
	"d17_quick_inject_d_l2": {
		"card_id": "d17_quick_inject_d_l2", "name": "快速注入+", "type": CardType.STRATEGY, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d17",
		"evolution_chain": ["d17_quick_inject_d", "d17_quick_inject_d_l2", "d17_quick_inject_d_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 注入程序牌3EP\nLv.3(20EP): 注入4EP+抽1",
		"effect": {"inject_program": 3},
	},
	"d17_quick_inject_d_l3": {
		"card_id": "d17_quick_inject_d_l3", "name": "快速注入MAX", "type": CardType.STRATEGY, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d17",
		"evolution_chain": ["d17_quick_inject_d", "d17_quick_inject_d_l2", "d17_quick_inject_d_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 注入程序牌4EP+抽1",
		"effect": {"inject_program": 4, "draw": 1},
	},

	# ===== D18: 递归护盾 (SKILL, 1 EP) =====
	"d18_recursive_shield": {
		"card_id": "d18_recursive_shield", "name": "递归护盾", "type": CardType.SKILL, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d18",
		"evolution_chain": ["d18_recursive_shield", "d18_recursive_shield_l2", "d18_recursive_shield_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 5格挡+若敌有崩溃屏障1\nLv.2(8EP): 7格挡+屏障1\nLv.3(20EP): 10格挡+屏障2",
		"effect": {"block": 5, "barrier_if_crash": 1},
	},
	"d18_recursive_shield_l2": {
		"card_id": "d18_recursive_shield_l2", "name": "递归护盾+", "type": CardType.SKILL, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d18",
		"evolution_chain": ["d18_recursive_shield", "d18_recursive_shield_l2", "d18_recursive_shield_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 7格挡+屏障1\nLv.3(20EP): 10格挡+屏障2",
		"effect": {"block": 7, "barrier_if_crash": 1},
	},
	"d18_recursive_shield_l3": {
		"card_id": "d18_recursive_shield_l3", "name": "递归护盾MAX", "type": CardType.SKILL, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d18",
		"evolution_chain": ["d18_recursive_shield", "d18_recursive_shield_l2", "d18_recursive_shield_l3"],
		"ep_to_evolve": -1, "cost": 1,
		"description": "Lv.3 MAX: 10格挡+屏障2",
		"effect": {"block": 10, "barrier_if_crash": 2},
	},

	# ===== D19: 零日协议 (PROGRAM, 2 EP) =====
	"d19_zero_day_protocol": {
		"card_id": "d19_zero_day_protocol", "name": "零日协议", "type": CardType.PROGRAM, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d19",
		"evolution_chain": ["d19_zero_day_protocol", "d19_zero_day_protocol_l2", "d19_zero_day_protocol_l3"],
		"ep_to_evolve": 8, "cost": 2,
		"description": "Lv.1: 8伤+施加崩溃2\nLv.2(8EP): 12伤+崩溃2\nLv.3(20EP): 16伤+崩溃3(费用→3)",
		"effect": {"damage": 8, "crash": 2},
	},
	"d19_zero_day_protocol_l2": {
		"card_id": "d19_zero_day_protocol_l2", "name": "零日协议+", "type": CardType.PROGRAM, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d19",
		"evolution_chain": ["d19_zero_day_protocol", "d19_zero_day_protocol_l2", "d19_zero_day_protocol_l3"],
		"ep_to_evolve": 20, "cost": 2,
		"description": "Lv.2: 12伤+施加崩溃2\nLv.3(20EP): 16伤+崩溃3(费用→3)",
		"effect": {"damage": 12, "crash": 2},
	},
	"d19_zero_day_protocol_l3": {
		"card_id": "d19_zero_day_protocol_l3", "name": "零日协议MAX", "type": CardType.PROGRAM, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d19",
		"evolution_chain": ["d19_zero_day_protocol", "d19_zero_day_protocol_l2", "d19_zero_day_protocol_l3"],
		"ep_to_evolve": -1, "cost": 3,
		"description": "Lv.3 MAX: 16伤+施加崩溃3",
		"effect": {"damage": 16, "crash": 3},
	},

	# ===== D20: 虚空护盾 (PROGRAM, 1 EP) =====
	"d20_void_shield": {
		"card_id": "d20_void_shield", "name": "虚空护盾", "type": CardType.PROGRAM, "rarity": Rarity.COMMON,
		"level": 1, "evolution_family": "d20",
		"evolution_chain": ["d20_void_shield", "d20_void_shield_l2", "d20_void_shield_l3"],
		"ep_to_evolve": 8, "cost": 1,
		"description": "Lv.1: 3格挡+自身脆弱1+屏障1\nLv.2(8EP): 5格挡+屏障2\nLv.3(20EP): 8格挡+屏障2(费用→2)",
		"effect": {"block": 3, "self_vulnerable": 1, "barrier": 1},
	},
	"d20_void_shield_l2": {
		"card_id": "d20_void_shield_l2", "name": "虚空护盾+", "type": CardType.PROGRAM, "rarity": Rarity.UNCOMMON,
		"level": 2, "evolution_family": "d20",
		"evolution_chain": ["d20_void_shield", "d20_void_shield_l2", "d20_void_shield_l3"],
		"ep_to_evolve": 20, "cost": 1,
		"description": "Lv.2: 5格挡+屏障2\nLv.3(20EP): 8格挡+屏障2(费用→2)",
		"effect": {"block": 5, "barrier": 2},
	},
	"d20_void_shield_l3": {
		"card_id": "d20_void_shield_l3", "name": "虚空护盾MAX", "type": CardType.PROGRAM, "rarity": Rarity.RARE,
		"level": 3, "evolution_family": "d20",
		"evolution_chain": ["d20_void_shield", "d20_void_shield_l2", "d20_void_shield_l3"],
		"ep_to_evolve": -1, "cost": 2,
		"description": "Lv.3 MAX: 8格挡+屏障2",
		"effect": {"block": 8, "barrier": 2},
	},
}
