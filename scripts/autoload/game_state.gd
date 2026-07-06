extends Node
## Player stats, gold, and story flags. The RF rule lives in spend_rp():
## actions always happen; missing RP is paid in HP.

const BASE_MAX_HP := 100
const BASE_MAX_RP := 100
const BASE_ATTACK := 5
const HP_PER_LEVEL := 5
const RP_PER_LEVEL := 5
const ATTACK_PER_LEVEL := 1
const STARTING_GOLD := 500

var level := 1
var xp := 0
var gold := STARTING_GOLD
var max_hp := BASE_MAX_HP
var hp := BASE_MAX_HP
var max_rp := BASE_MAX_RP
var rp := BASE_MAX_RP
var attack := BASE_ATTACK
var flags := {}

## Craft Stride 1: cooked buff-food attack bonus. 0 = no buff active. Set by
## player.gd's _eat() (REPLACES, never stacks — bible: "stacking replaced,
## not added"); cleared by DayFlow on sleep/collapse. Deliberately NOT
## persisted (see to_dict/from_dict): the buff dies with the day, same as the
## save model itself (saves only happen at sleep, so a mid-day quit already
## loses unsaved progress — losing an active buff on a quit-without-sleeping
## is consistent with that, not a new tradeoff).
var temp_attack := 0


func reset_new_game() -> void:
	level = 1
	xp = 0
	gold = STARTING_GOLD
	max_hp = BASE_MAX_HP
	hp = max_hp
	max_rp = BASE_MAX_RP
	rp = max_rp
	attack = BASE_ATTACK
	flags = {}
	temp_attack = 0
	EventBus.stats_changed.emit()
	EventBus.money_changed.emit(gold)


func xp_to_next() -> int:
	return 20 + (level - 1) * 15


func add_xp(amount: int) -> void:
	assert(amount >= 0, "add_xp expects non-negative amount")
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		_level_up()
	EventBus.stats_changed.emit()


func _level_up() -> void:
	level += 1
	max_hp += HP_PER_LEVEL
	max_rp += RP_PER_LEVEL
	attack += ATTACK_PER_LEVEL
	hp = max_hp
	rp = max_rp
	EventBus.player_leveled.emit(level)


func spend_rp(cost: int) -> void:
	var hp_cost := maxi(0, cost - rp)
	rp = maxi(0, rp - cost)
	EventBus.stats_changed.emit()
	if hp_cost > 0:
		take_damage(hp_cost)


func try_spend_rp(cost: int) -> bool:
	## Hard-gated variant: fails (no cost) when RP is fully empty.
	## Shortfall beyond available RP still drains HP, like spend_rp.
	if rp <= 0:
		return false
	spend_rp(cost)
	return true


func take_damage(amount: int) -> void:
	var was_alive := hp > 0
	hp = maxi(0, hp - amount)
	EventBus.stats_changed.emit()
	if was_alive and hp == 0:
		EventBus.player_died.emit()


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	EventBus.stats_changed.emit()


func restore_rp(amount: int) -> void:
	rp = mini(max_rp, rp + amount)
	EventBus.stats_changed.emit()


func add_gold(amount: int) -> void:
	gold += amount
	EventBus.money_changed.emit(gold)


func try_spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	EventBus.money_changed.emit(gold)
	return true


func sleep_restore(collapsed: bool) -> void:
	hp = max_hp
	rp = roundi(max_rp / 2.0) if collapsed else max_rp
	clear_temp_attack()
	EventBus.stats_changed.emit()


## ---- Craft Stride 1: buff food ----

func set_temp_attack(bonus: int) -> void:
	## REPLACES any existing buff (bible: "stacking replaced, not added").
	temp_attack = bonus
	EventBus.stats_changed.emit()


func clear_temp_attack() -> void:
	temp_attack = 0
	EventBus.stats_changed.emit()


func effective_attack() -> int:
	## Single accessor for "attack to use in a damage calc" — every swing-
	## damage site should read THIS, not `attack` directly, so the buff
	## applies everywhere without scattering `+ GameState.temp_attack` calls.
	return attack + temp_attack


func to_dict() -> Dictionary:
	return {
		"level": level, "xp": xp, "gold": gold,
		"max_hp": max_hp, "hp": hp, "max_rp": max_rp, "rp": rp,
		"attack": attack, "flags": flags.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	gold = int(d.get("gold", STARTING_GOLD))
	max_hp = int(d.get("max_hp", BASE_MAX_HP))
	hp = int(d.get("hp", max_hp))
	max_rp = int(d.get("max_rp", BASE_MAX_RP))
	rp = int(d.get("rp", max_rp))
	attack = int(d.get("attack", BASE_ATTACK))
	flags = d.get("flags", {}).duplicate(true)
	EventBus.stats_changed.emit()
	EventBus.money_changed.emit(gold)
