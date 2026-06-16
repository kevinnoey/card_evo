class_name Player
extends Node2D
## Player entity - HP, block, barrier, energy_shield, vulnerable stacks

signal hp_changed(current_hp: int, max_hp: int)
signal block_changed(block: int)
signal barrier_changed(barrier: int)
signal energy_shield_changed(shields: int)
signal player_died()

var max_hp: int = 70
var current_hp: int = 70
var block: int = 0
var barrier: int = 0
var energy_shield: int = 0
var vulnerable_stacks: int = 0
var block_persist: bool = false
var last_turn_damage_taken: bool = false  # D06回滚: 上回合是否受到实际HP伤害

func take_damage(raw_damage: int, pierce_shield: int = 0) -> int:
	var actual = raw_damage + vulnerable_stacks

	# Energy shield reduces all damage by a flat amount (pierce_shield ignores N layers)
	var effective_shield = max(0, energy_shield - pierce_shield)
	if effective_shield > 0:
		actual = max(0, actual - effective_shield)

	# Barrier absorbs damage before block
	if barrier > 0:
		var bar_absorb = min(barrier, actual)
		barrier -= bar_absorb
		actual -= bar_absorb
		barrier_changed.emit(barrier)

	# Block absorbs remaining damage
	if block > 0:
		var blocked = min(block, actual)
		block -= blocked
		actual -= blocked
		block_changed.emit(block)

	current_hp = max(0, current_hp - actual)
	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		player_died.emit()
	return actual

func heal(amount: int):
	current_hp = min(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)

func add_block(amount: int):
	block += amount
	block_changed.emit(block)

func reset_block():
	block = 0
	block_changed.emit(block)

func add_barrier(amount: int):
	barrier += amount
	barrier_changed.emit(barrier)

func add_energy_shield(amount: int):
	energy_shield += amount
	energy_shield_changed.emit(energy_shield)

func reset_turn():
	vulnerable_stacks = 0
	# Barrier expires at turn start
	barrier = 0
	barrier_changed.emit(barrier)
	# Block clears at turn start unless persist flag is set
	if not block_persist:
		block = 0
		block_changed.emit(block)
	block_persist = false
