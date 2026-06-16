class_name EventDatabase
extends RefCounted
## Event definitions for the roguelite event system (v1.6)
## Each event has: title, story text, and 2-3 choices with effects.
## Effects are executed by MapScreen using RunRewardState APIs.

static func get_event(event_key: String) -> Dictionary:
	return EVENTS.get(event_key, {})

static func get_all_events() -> Dictionary:
	return EVENTS

const EVENTS = {
	"abandoned_database": {
		"title": "废弃数据库",
		"story": "发现一台破损终端，里面存有残留的进化数据。\n屏幕闪烁着微弱的蓝光，似乎还能读取一些信息。",
		"choices": [
			{
				"text": "扫描数据（随机卡牌 +8 EP 注入进度）",
				"effect": "random_ep_inject",
				"amount": 8,
				"result_text": "成功扫描数据，注入了 [color=#FFD700]8 EP[/color] 进化进度。"
			},
			{
				"text": "销毁终端（+20 数据碎片）",
				"effect": "add_fragments",
				"amount": 20,
				"result_text": "销毁了终端，回收到 [color=#00BFFF]20 数据碎片[/color]。"
			},
		]
	},
	"black_market": {
		"title": "黑市商人",
		"story": "一个兜售违禁芯片的商人从暗处现身。\n\"嘿，渗透者，来看看好货...\"\n他展示了几枚闪烁的芯片。",
		"choices": [
			{
				"text": "购买过载芯片（-25 碎片，永久 +1 EP/回合）",
				"effect": "buy_ep_per_turn",
				"cost": 25,
				"result_text": "芯片植入成功，每回合 [color=#FFD700]+1 EP[/color]。"
			},
			{
				"text": "购买纳米血清（-15 碎片，恢复 20 HP）",
				"effect": "buy_heal",
				"cost": 15,
				"amount": 20,
				"result_text": "注射血清，恢复了 [color=#3BFF8C]20 HP[/color]。"
			},
			{
				"text": "举报商人（+10 碎片，下场战斗敌人 +2 力量）",
				"effect": "report_merchant",
				"amount": 10,
				"result_text": "举报了商人，获得 [color=#00BFFF]10 碎片[/color]。\n但下一场战斗的敌人变得更强了..."
			},
		]
	},
	"clone_pod": {
		"title": "故障克隆舱",
		"story": "一台失控的克隆设备嗡嗡作响。\n它似乎能复制你的卡牌数据，但过程不太稳定。\n控制面板上闪烁着三个选项。",
		"choices": [
			{
				"text": "复制一张卡牌（选择一张加入牌库）",
				"effect": "copy_card",
				"result_text": "克隆成功，一张新的卡牌加入了你的牌库。"
			},
			{
				"text": "注入超载（随机卡牌 +4 EP 注入进度）",
				"effect": "random_ep_inject",
				"amount": 4,
				"result_text": "注入超载成功，随机一张卡牌获得 [color=#FFD700]4 EP[/color]。"
			},
			{
				"text": "砸毁设备（-5 HP，+15 碎片）",
				"effect": "smash_device",
				"hp_cost": 5,
				"amount": 15,
				"result_text": "砸毁了设备，失去 [color=#FF3B3B]5 HP[/color]，获得 [color=#00BFFF]15 碎片[/color]。"
			},
		]
	},
	"data_storm": {
		"title": "数据风暴",
		"story": "强烈的电磁脉冲席卷而来！\n你的系统防护罩正在承受巨大压力。\n必须立即做出决定。",
		"choices": [
			{
				"text": "抵抗风暴（-10 HP，EP 储备池 +5）",
				"effect": "resist_storm",
				"hp_cost": 10,
				"reserve_amount": 5,
				"result_text": "艰难抵抗了风暴。失去 [color=#FF3B3B]10 HP[/color]，储备池 [color=#FFD700]+5[/color]。"
			},
			{
				"text": "关闭防护（-8 HP，+30 碎片）",
				"effect": "lower_shield",
				"hp_cost": 8,
				"amount": 30,
				"result_text": "关闭防护吸收数据。失去 [color=#FF3B3B]8 HP[/color]，获得 [color=#00BFFF]30 碎片[/color]。"
			},
		]
	},
	"wandering_ai": {
		"title": "游荡 AI",
		"story": "一个友好的 AI 投影出现在你面前。\n\"你好，渗透者。我可以帮你优化系统。\"\n它分析了你的牌库，提出两个方案。",
		"choices": [
			{
				"text": "优化卡牌（永久移除一张卡牌）",
				"effect": "remove_card",
				"result_text": "AI 移除了你牌库中的一张卡牌。牌组更加精简了。"
			},
			{
				"text": "学习算法（随机卡牌 +8 EP 或升至 Lv.2）",
				"effect": "upgrade_card",
				"amount": 8,
				"result_text": "AI 优化了一张卡牌的数据。获得 [color=#FFD700]8 EP[/color] 注入进度。"
			},
		]
	},
	"abandoned_armory": {
		"title": "废弃军械库",
		"story": "发现一间被遗弃的装备库。\n架子上还残留着一些能量单元和防御模块。",
		"choices": [
			{
				"text": "全部回收（下场战斗 +3 EP/回合）",
				"effect": "temp_ep_bonus",
				"amount": 3,
				"result_text": "回收了能量单元。下场战斗每回合 [color=#FFD700]+3 EP[/color]。"
			},
			{
				"text": "拆解改装（+1 能量护盾层数）",
				"effect": "add_shield",
				"amount": 1,
				"result_text": "改装完成。获得 [color=#FFD700]1 层能量护盾[/color]（永久伤害减免）。"
			},
		]
	},
	"mysterious_altar": {
		"title": "神秘祭坛",
		"story": "一座散发幽光的数据祭坛矗立在前方。\n上面刻着古老的代码铭文：\n\"以血肉为代价，换取进化之力。\"",
		"choices": [
			{
				"text": "献祭 10 HP（随机卡牌 +12 EP）",
				"effect": "sacrifice_hp_ep",
				"hp_cost": 10,
				"amount": 12,
				"result_text": "献祭了 [color=#FF3B3B]10 HP[/color]，一张卡牌获得 [color=#FFD700]12 EP[/color] 注入进度！"
			},
			{
				"text": "献祭 20 HP（永久 +1 EP/回合）",
				"effect": "sacrifice_hp_ep_per_turn",
				"hp_cost": 20,
				"result_text": "献祭了 [color=#FF3B3B]20 HP[/color]，获得永久 [color=#FFD700]+1 EP/回合[/color]！"
			},
			{
				"text": "放弃离开",
				"effect": "leave",
				"result_text": "你转身离开了祭坛。"
			},
		]
	},
}
