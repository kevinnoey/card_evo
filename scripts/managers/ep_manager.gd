class_name EPManager
extends Node
## EP Manager - handles evolution points, reserve pool, card injection

signal ep_changed(current: int, max_ep: int)
signal reserve_changed(current: int, max_reserve: int)
signal card_evolved(card_id: String, new_def: Dictionary, is_bloom: bool)
signal barrier_granted(amount: int)
signal milestone_reached(threshold: int)
signal free_upgrade_available()

var current_ep: int = 3
var max_ep: int = 3
var reserve_pool: int = 0
var max_reserve: int = 15
var milestone_thresholds: Array = [5, 10, 15]  # Can be expanded to [5,10,15,20] by 涌动核心

# Milestones already reached this battle
var milestones_reached: Array[int] = []

# Track per-card-family accumulated EP (keyed by evolution_family)
var card_ep_by_family: Dictionary = {}

# Track highest evolution level reached per family (1, 2, or 3)
var family_max_level: Dictionary = {}

# Barrier reduction from enemy pollution (数据腐化体)
var barrier_reduction: int = 0

func reset_turn():
	current_ep = max_ep
	ep_changed.emit(current_ep, max_ep)

func full_reset():
	"""Reset all EP state to initial values for a fresh game run."""
	current_ep = 3
	max_ep = 3
	reserve_pool = 0
	max_reserve = 15
	milestone_thresholds = [5, 10, 15]
	milestones_reached = []
	card_ep_by_family = {}
	family_max_level = {}
	barrier_reduction = 0
	ep_changed.emit(current_ep, max_ep)
	reserve_changed.emit(reserve_pool, max_reserve)

func can_afford(cost: int) -> bool:
	return current_ep >= cost

func spend_ep(amount: int) -> bool:
	if current_ep >= amount:
		current_ep -= amount
		ep_changed.emit(current_ep, max_ep)
		return true
	return false

func add_ep(amount: int):
	"""Add EP to current pool, capped at max_ep. Used by card effects (e.g. EP增幅)."""
	current_ep = min(max_ep, current_ep + amount)
	ep_changed.emit(current_ep, max_ep)

func inject_to_card(card_instance) -> bool:
	if current_ep <= 0:
		return false

	# Use evolution_family, fall back to card_id
	var family = card_instance.card_def.get("evolution_family", "")
	if family == "":
		family = card_instance.card_def.get("card_id", "")
	if family == "":
		return false

	var ep_needed = card_instance.card_def.get("ep_to_evolve", -1)
	if ep_needed <= 0:
		return false  # Already max level

	if not card_ep_by_family.has(family):
		card_ep_by_family[family] = 0

	card_ep_by_family[family] += 1
	current_ep -= 1
	ep_changed.emit(current_ep, max_ep)

	# Inject grants 2 barrier (reduced by pollution)
	var barrier_amount = max(0, 2 - barrier_reduction)
	if barrier_amount > 0:
		barrier_granted.emit(barrier_amount)

	# Check if card should evolve
	if card_ep_by_family[family] >= ep_needed:
		_evolve_card(card_instance, family)

	return true

func inject_to_card_free(card_instance, amount: int):
	var family = card_instance.card_def.get("evolution_family", "")
	if family == "":
		family = card_instance.card_def.get("card_id", "")
	if family == "":
		return

	var ep_needed = card_instance.card_def.get("ep_to_evolve", -1)
	if ep_needed <= 0:
		return

	if not card_ep_by_family.has(family):
		card_ep_by_family[family] = 0

	card_ep_by_family[family] += amount

	if card_ep_by_family[family] >= ep_needed:
		_evolve_card(card_instance, family)

func inject_to_reserve() -> bool:
	if current_ep <= 0:
		return false
	var amount = current_ep
	reserve_pool = min(max_reserve, reserve_pool + amount)
	current_ep = 0
	ep_changed.emit(current_ep, max_ep)
	reserve_changed.emit(reserve_pool, max_reserve)
	_check_milestones()
	return true

func _check_milestones():
	for threshold in milestone_thresholds:
		if reserve_pool >= threshold and not milestones_reached.has(threshold):
			milestones_reached.append(threshold)
			milestone_reached.emit(threshold)
			if threshold == 15:
				free_upgrade_available.emit()

func consume_reserve_for_upgrade() -> bool:
	if reserve_pool >= milestone_thresholds[-1]:
		reserve_pool = 0
		reserve_changed.emit(reserve_pool, max_reserve)
		return true
	return false

func clear_reserve_pool():
	"""Clear the EP reserve pool (used by 格式化巨兽's 底层格式化)."""
	reserve_pool = 0
	reserve_changed.emit(reserve_pool, max_reserve)

func _evolve_card(card_instance, family: String):
	var card_def = card_instance.card_def
	var chain = card_def.get("evolution_chain", [])
	var current_level = card_def.get("level", 1)

	if current_level >= chain.size():
		return

	var next_id = chain[current_level]
	var new_def = CardDatabase.get_card_def(next_id)
	if new_def.is_empty():
		return

	var is_bloom = (new_def.get("level", 1) == 3)
	var new_level = new_def.get("level", current_level + 1)

	# Track max evolution level reached for this family
	family_max_level[family] = max(family_max_level.get(family, 1), new_level)

	# Reset per-card injected EP (family EP already consumed by evolution)
	card_instance.injected_ep = 0

	# Store overflow EP for this family
	var current_ep_stored = card_ep_by_family.get(family, 0)
	card_ep_by_family.erase(family)

	# Update card
	card_instance.card_def = new_def.duplicate()
	card_instance.refresh_display()

	card_evolved.emit(next_id, new_def, is_bloom)

	if is_bloom:
		card_instance.is_bloom = true
		card_instance.cost_override = 0
		var ep_for_this_level = card_def.get("ep_to_evolve", 0)
		var overflow = current_ep_stored - ep_for_this_level
		if overflow > 0:
			reserve_pool = min(max_reserve, reserve_pool + overflow)
			reserve_changed.emit(reserve_pool, max_reserve)
			_check_milestones()

	# Play evolution animation on the card
	card_instance.play_evolution_animation()

func get_card_ep_progress(card_instance) -> float:
	var family = card_instance.card_def.get("evolution_family", "")
	if family == "":
		return 0.0
	var accumulated = card_ep_by_family.get(family, 0)
	var needed = card_instance.card_def.get("ep_to_evolve", -1)
	if needed <= 0:
		return 1.0
	return min(1.0, float(accumulated) / float(needed))

func get_card_ep_text(card_instance) -> String:
	var family = card_instance.card_def.get("evolution_family", "")
	if family == "":
		return ""
	var accumulated = card_ep_by_family.get(family, 0)
	var needed = card_instance.card_def.get("ep_to_evolve", -1)
	if needed <= 0:
		return "MAX"
	return str(accumulated) + "/" + str(needed)

func apply_ep_penalty(amount: int):
	current_ep = max(0, current_ep - amount)
	ep_changed.emit(current_ep, max_ep)

func set_barrier_reduction(amount: int):
	barrier_reduction = amount

# === Reward System Methods ===

func add_reserve_progress(amount: int):
	"""Add progress directly to the reserve pool (from rewards). Triggers milestones."""
	reserve_pool = min(max_reserve, reserve_pool + amount)
	reserve_changed.emit(reserve_pool, max_reserve)
	_check_milestones()

func add_progress_to_family(family: String, amount: int) -> bool:
	"""Add EP progress to a card family (from 进化模块 reward)."""
	if not card_ep_by_family.has(family):
		card_ep_by_family[family] = 0
	card_ep_by_family[family] += amount
	return true

func get_evolved_card_id_for_family(card_id: String) -> String:
	"""Get the correct evolved card_id for a card based on its family's max evolution level."""
	var def_entry = CardDatabase.get_card_def(card_id)
	if def_entry.is_empty():
		return card_id
	var family = def_entry.get("evolution_family", "")
	if family == "":
		return card_id
	var max_level = family_max_level.get(family, 1)
	var chain = def_entry.get("evolution_chain", [])
	if chain.size() >= 3 and max_level >= 3:
		return chain[2]
	elif chain.size() >= 2 and max_level >= 2:
		return chain[1]
	return card_id

func get_family_progress(family: String) -> Dictionary:
	"""Get current progress for a card family."""
	var accumulated = card_ep_by_family.get(family, 0)
	var def = CardDatabase.get_card_def(family)
	if def.is_empty():
		# Try to find any card with this family
		for key in CardDatabase.CARD_DATABASE:
			var d = CardDatabase.CARD_DATABASE[key]
			if d.get("evolution_family", "") == family:
				def = d
				break
	if def.is_empty():
		return {"accumulated": 0, "needed": 0, "level": 0}
	var needed = def.get("ep_to_evolve", -1)
	var level = def.get("level", 1)
	return {"accumulated": accumulated, "needed": needed, "level": level}
