extends Node
## 全局行动日志 — 持久化存储整个 run 的所有操作记录
## 战斗场景和地图场景的日志面板都从该单例读取数据

signal entry_added(text: String, color: Color, time_str: String)

const MAX_ENTRIES = 100
var _entries: Array = []  # [{text: String, color: Color, time_str: String}]


func add_log(text: String, color: Color = Color.WHITE):
	"""添加一条日志并通知所有 UI 面板"""
	var time_str = _get_time_string()
	_entries.append({"text": text, "color": color, "time_str": time_str})
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	entry_added.emit(text, color, time_str)


func get_entries() -> Array:
	"""返回所有日志条目的副本（用于 UI 回放历史）"""
	return _entries.duplicate()


func clear_log():
	"""清空所有日志（新游戏开始时调用）"""
	_entries.clear()


func _get_time_string() -> String:
	"""获取当前时间，格式 HH:MM:SS"""
	var time = Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [time["hour"], time["minute"], time["second"]]
