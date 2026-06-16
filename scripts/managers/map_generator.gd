class_name MapGenerator
extends RefCounted
## Generates procedural chapter maps for the roguelite system (v2.0)
## Network Infiltration Map - branching paths from entry to boss
## Each chapter has ~15 layers with branching/merging paths

# Node type constants
const BATTLE = "battle"
const ELITE = "elite"
const EVENT = "event"
const REST = "rest"
const SHOP = "shop"
const BOSS = "boss"

# Map structure constants
const TOTAL_LAYERS = 15  # 0=start, 1-3=split, 4-11=main, 12-13=merge, 14=boss
const MIN_NODES_PER_LAYER = 1
const MAX_NODES_PER_LAYER = 4
const NODE_MIN_SPACING = 0.15  # Minimum horizontal spacing (0-1 range)

# Node type weights (70% battle-focused)
const NODE_TYPE_POOL = [
	[BATTLE, 50],
	[ELITE, 20],
	[EVENT, 15],
	[REST, 10],
	[SHOP, 5]
]

# Enemy pools per chapter
const ENEMY_POOLS = {
	1: {
		"normal": ["enemy_a", "enemy_b", "enemy_c"],
		"elite": ["enemy_d", "enemy_e"],
		"boss": "enemy_f"
	},
	2: {
		"normal": ["enemy_g", "enemy_b_ch2", "enemy_c_ch2"],
		"elite": ["enemy_h", "enemy_d_ch2"],
		"boss": "enemy_i"
	}
}

# Repeatable enemies
const REPEATABLE_ENEMIES = {
	1: {
		"normal": ["enemy_a", "enemy_b"],
		"elite": []
	},
	2: {
		"normal": ["enemy_b_ch2"],
		"elite": []
	}
}

# Event pool
const EVENT_POOL = [
	"abandoned_database",
	"black_market",
	"clone_pod",
	"data_storm",
	"wandering_ai",
	"abandoned_armory",
	"mysterious_altar"
]

func generate_chapter(chapter: int, seed: int) -> Dictionary:
	"""Generate a complete chapter map with branching paths."""
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	var result = {"layers": [], "chapter": chapter}

	# Track used enemies per difficulty
	var used_normal: Array = []
	var used_elite: Array = []

	# Phase 1: Create empty node stubs for all layers (types assigned in Phase 2)
	var prev_layer_node_count = 1

	for layer_idx in range(TOTAL_LAYERS):
		var layer = {"nodes": [], "layer_index": layer_idx}

		# Determine node count for this layer based on progression
		var node_count = _get_node_count_for_layer(layer_idx, prev_layer_node_count, rng)

		# Generate X positions for nodes (evenly spaced)
		var x_positions = _generate_x_positions(node_count)

		for node_idx in range(node_count):
			var node = {
				"type": "",
				"x": x_positions[node_idx],  # Relative position 0-1
				"enemy_key": "",
				"event_key": "",
				"completed": false,
				"available": false,
				"layer": layer_idx,
				"index": node_idx,
				"connections": []  # Will be filled when next layer is generated
			}
			layer["nodes"].append(node)

		result["layers"].append(layer)
		prev_layer_node_count = node_count

	# Phase 2: Generate evenly-distributed type plan
	var type_plan = _generate_type_plan(result["layers"])

	# Phase 3: Assign types and enemy/event data from plan
	for layer_idx in range(TOTAL_LAYERS):
		for node_idx in range(result["layers"][layer_idx]["nodes"].size()):
			var node = result["layers"][layer_idx]["nodes"][node_idx]

			# Layer 0 is always battle; others use the pre-calculated plan
			if layer_idx == 0:
				node["type"] = BATTLE
			else:
				node["type"] = type_plan.get("%d,%d" % [layer_idx, node_idx], BATTLE)

			# Assign enemy/event based on type
			match node["type"]:
				BATTLE:
					node["enemy_key"] = _pick_enemy("normal", chapter, rng, used_normal)
				ELITE:
					node["enemy_key"] = _pick_enemy("elite", chapter, rng, used_elite)
				EVENT:
					node["event_key"] = EVENT_POOL[rng.randi_range(0, EVENT_POOL.size() - 1)]

	# Generate connections between layers
	_generate_connections(result["layers"], rng)

	# Add boss layer at the end
	var boss_layer = {
		"nodes": [{
			"type": BOSS,
			"x": 0.5,
			"enemy_key": ENEMY_POOLS.get(chapter, ENEMY_POOLS[1])["boss"],
			"event_key": "",
			"completed": false,
			"available": false,
			"layer": TOTAL_LAYERS,
			"index": 0,
			"connections": []
		}],
		"layer_index": TOTAL_LAYERS
	}
	result["layers"].append(boss_layer)

	# Connect last normal layer to boss
	var last_layer_idx = TOTAL_LAYERS - 1
	for node_idx in range(result["layers"][last_layer_idx]["nodes"].size()):
		result["layers"][last_layer_idx]["nodes"][node_idx]["connections"] = [0]

	return result


func _get_node_count_for_layer(layer_idx: int, prev_count: int, rng: RandomNumberGenerator) -> int:
	"""Determine node count based on layer progression."""
	if layer_idx == 0:
		return 1  # Starting node
	elif layer_idx <= 3:
		# Splitting phase: increase nodes
		return mini(layer_idx + 1, 3)
	elif layer_idx <= 11:
		# Main phase: 2-4 nodes
		return rng.randi_range(2, 4)
	elif layer_idx <= 13:
		# Merging phase: decrease nodes
		return maxi(3 - (layer_idx - 12), 1)
	else:
		return 1  # Boss


func _generate_x_positions(count: int) -> Array:
	"""Generate evenly spaced X positions (0-1 range) for nodes."""
	var positions = []
	if count == 1:
		positions.append(0.5)
	else:
		var spacing = 1.0 / (count + 1)
		for i in range(count):
			positions.append(spacing * (i + 1))
	return positions


func _generate_type_plan(layers: Array) -> Dictionary:
	"""Generate an evenly-distributed type plan using spaced-fill algorithm.
	Returns a Dict with key 'layer,idx' mapping to a type string.
	Layer 0 (start) and boss layer are excluded — they're hardcoded."""
	# Collect all non-layer-0 slots (layer 0 is always battle)
	var slots = []  # Array of {"layer": int, "index": int}
	for layer_idx in range(1, layers.size()):
		for node_idx in range(layers[layer_idx]["nodes"].size()):
			slots.append({"layer": layer_idx, "index": node_idx})

	if slots.is_empty():
		return {}

	var total = slots.size()

	# Calculate exact counts per type (excluding BATTLE which fills remaining)
	var counts = _calculate_type_counts(total)

	var plan = {}    # key: "layer,idx" -> type string
	var taken = []   # Array of slot indices already assigned

	# Place types in order of rarity (rarest first = best positions)
	var type_order = [SHOP, REST, EVENT, ELITE]

	for type_name in type_order:
		var count = counts.get(type_name, 0)
		if count <= 0:
			continue
		var spacing = float(total) / float(count)
		for i in range(count):
			var target_idx = int(floor(spacing / 2.0 + float(i) * spacing))
			target_idx = clampi(target_idx, 0, total - 1)
			var assigned = _find_nearest_free_slot(taken, target_idx, total)
			if assigned >= 0:
				taken.append(assigned)
				var slot = slots[assigned]
				plan["%d,%d" % [slot["layer"], slot["index"]]] = type_name

	return plan


func _calculate_type_counts(total: int) -> Dictionary:
	"""Calculate target counts per node type based on original weights (sum=100).
	BATTLE fills whatever slots remain after placing other types."""
	var raw = {}
	var placed = 0

	# Calculate non-battle types using full weight sum (=100)
	for entry in NODE_TYPE_POOL:
		var type_name = entry[0]
		var weight = entry[1]
		if type_name == BATTLE:
			continue
		raw[type_name] = round(float(total) * float(weight) / 100.0)
		placed += raw[type_name]

	# Clamp sum to total (prevent rounding overshoot at extreme values)
	if placed > total:
		for type_name in [ELITE, EVENT, REST, SHOP]:
			while placed > total and raw[type_name] > 0:
				raw[type_name] -= 1
				placed -= 1

	# Battle gets whatever remains
	raw[BATTLE] = total - placed

	return raw


func _find_nearest_free_slot(taken: Array, target: int, total: int) -> int:
	"""Find the closest free slot index to target, expanding outward."""
	if taken.size() >= total:
		return -1

	for offset in range(total):
		# Search forward
		var forward = target + offset
		if forward < total and not taken.has(forward):
			return forward
		# Search backward
		var backward = target - offset
		if backward >= 0 and not taken.has(backward):
			return backward

	return -1


func _generate_connections(layers: Array, rng: RandomNumberGenerator):
	"""Generate connections between nodes in adjacent layers."""
	for layer_idx in range(layers.size() - 1):
		var current_layer = layers[layer_idx]["nodes"]
		var next_layer = layers[layer_idx + 1]["nodes"]

		if next_layer.is_empty():
			continue

		# Each node connects to 1-2 nodes in the next layer
		# Ensure every node in next layer has at least one incoming connection
		var next_layer_connected: Array = []

		for i in range(current_layer.size()):
			var connections = []
			# Connect to the closest node(s) in next layer
			var primary = _find_closest_node_index(current_layer[i]["x"], next_layer, next_layer_connected)
			if primary >= 0:
				connections.append(primary)
				if not next_layer_connected.has(primary):
					next_layer_connected.append(primary)

				# 40% chance to also connect to an adjacent node
				if rng.randf() < 0.4 and next_layer.size() > 1:
					var secondary = _find_adjacent_node_index(primary, next_layer.size(), rng)
					if secondary >= 0 and not connections.has(secondary):
						connections.append(secondary)
						if not next_layer_connected.has(secondary):
							next_layer_connected.append(secondary)

			current_layer[i]["connections"] = connections

		# Ensure all next layer nodes have at least one incoming connection
		for j in range(next_layer.size()):
			if not next_layer_connected.has(j):
				# Find closest node in current layer and connect
				var closest = _find_closest_node_index(next_layer[j]["x"], current_layer, [])
				if closest >= 0:
					if not current_layer[closest]["connections"].has(j):
						current_layer[closest]["connections"].append(j)


func _find_closest_node_index(x: float, layer_nodes: Array, exclude: Array) -> int:
	"""Find the node in layer_nodes closest to x position, excluding certain indices."""
	var best_idx = -1
	var best_dist = 2.0

	for i in range(layer_nodes.size()):
		if exclude.has(i):
			continue
		var dist = abs(layer_nodes[i]["x"] - x)
		if dist < best_dist:
			best_dist = dist
			best_idx = i

	return best_idx


func _find_adjacent_node_index(primary: int, layer_size: int, rng: RandomNumberGenerator) -> int:
	"""Find an adjacent node index (left or right of primary)."""
	var options = []
	if primary > 0:
		options.append(primary - 1)
	if primary < layer_size - 1:
		options.append(primary + 1)

	if options.is_empty():
		return -1

	return options[rng.randi_range(0, options.size() - 1)]


func _pick_enemy(difficulty: String, chapter: int, rng: RandomNumberGenerator, used: Array) -> String:
	"""Pick a random enemy from the pool, avoiding repeats for non-repeatable enemies."""
	var pool = ENEMY_POOLS.get(chapter, ENEMY_POOLS[1]).get(difficulty, []).duplicate()
	var repeatable = REPEATABLE_ENEMIES.get(chapter, {}).get(difficulty, [])

	var available = []
	for e in pool:
		if repeatable.has(e):
			available.append(e)
		elif not used.has(e):
			available.append(e)

	if available.is_empty():
		used.clear()
		available = pool.duplicate()

	var pick = available[rng.randi_range(0, available.size() - 1)]
	if not repeatable.has(pick):
		used.append(pick)
	return pick
