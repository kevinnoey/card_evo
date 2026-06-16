extends Node
## Bridge API - provides JSON string interface for C# TCP Bridge interop
## This node acts as the intermediary between C# and GDScript game logic.

var battle_manager = null

func _ready():
	# Find BattleManager parent
	var parent = get_parent()
	while parent:
		if parent.has_method("get_bridge_snapshot"):
			battle_manager = parent
			break
		parent = parent.get_parent()

	if not battle_manager:
		push_error("BridgeAPI: Could not find BattleManager parent")

## Get complete game state as JSON string
func get_bridge_snapshot_json() -> String:
	if not battle_manager:
		return JSON.stringify({"error": "BattleManager not found"})
	var snapshot = battle_manager.get_bridge_snapshot()
	snapshot["stateVersion"] = _get_state_version()
	snapshot["legalActions"] = battle_manager.get_legal_actions()
	return JSON.stringify(snapshot)

## Execute an action from JSON string, returns JSON string result
func execute_bridge_action_json(action_json: String) -> String:
	if not battle_manager:
		return JSON.stringify({"ok": false, "message": "BattleManager not found"})

	var action = JSON.parse_string(action_json)
	if action == null:
		return JSON.stringify({"ok": false, "message": "Invalid JSON"})

	var result = battle_manager.execute_bridge_action(action)

	# Build response with updated snapshot
	var response = {
		"ok": result.get("ok", false),
		"message": result.get("message", ""),
		"stateVersion": _get_state_version(),
	}

	# Include updated snapshot
	var snapshot = battle_manager.get_bridge_snapshot()
	snapshot["stateVersion"] = response["stateVersion"]
	snapshot["legalActions"] = battle_manager.get_legal_actions()
	response["snapshot"] = snapshot

	return JSON.stringify(response)

## Get legal actions as JSON string
func get_legal_actions_json() -> String:
	if not battle_manager:
		return "[]"
	var actions = battle_manager.get_legal_actions()
	return JSON.stringify(actions)

## Set fast mode for training (skip animations)
func set_fast_mode_json(enabled_json: String) -> String:
	var data = JSON.parse_string(enabled_json)
	if data != null and data.has("enabled"):
		_set_fast_mode_recursive(data["enabled"])
		return JSON.stringify({"ok": true})
	return JSON.stringify({"ok": false, "message": "Missing 'enabled' field"})

func _set_fast_mode_recursive(enabled: bool):
	if battle_manager:
		battle_manager.set_fast_mode(enabled)
		# Also set on all card UIs
		for card in battle_manager.hand:
			if card.has_method("set") and "fast_mode" in card:
				card.fast_mode = enabled

## Get state version (increments on each action)
var _state_version: int = 0

func _get_state_version() -> int:
	return _state_version

func increment_state_version():
	_state_version += 1
