extends Node
# Autoload "GameState": wszystko, co przetrwa między gildią a lochem. Zapis w user://save.json.

const Balance = preload("res://balance.gd")
const Inventory = preload("res://inventory.gd")

const SAVE_PATH := "user://save.json"

var gold := 0
var day := 1
var level := 1
var xp := 0
var stat_points := 0
var stats := {"str": 0, "vit": 0, "agi": 0}
var hp := Balance.BASE_HP
var rooms: Array = ["hall"]
var best_floor := 0
var inv = Inventory.new()
var message := ""                   # komunikat do pokazania w gildii


func _ready() -> void:
	if not load_game():
		reset()


func reset() -> void:
	gold = 0
	day = 1
	level = 1
	xp = 0
	stat_points = 0
	stats = {"str": 0, "vit": 0, "agi": 0}
	rooms = ["hall"]
	best_floor = 0
	inv.reset()
	refresh_inventory()
	hp = max_hp()
	message = "Dziś kończysz 25 lat. Coś w Twojej głowie mówi: [SYSTEM AKTYWNY]."


# ---------- statystyki ----------

func max_hp() -> int:
	return Balance.BASE_HP + stats["vit"] * Balance.HP_PER_VIT + (level - 1) * Balance.HP_PER_LEVEL


func attack_bonus() -> int:
	return stats["str"] + inv.attack_bonus()


func move_speed() -> float:
	return Balance.BASE_SPEED + stats["agi"] * Balance.SPEED_PER_AGI


func dash_cooldown() -> float:
	return maxf(Balance.DASH_MIN_COOLDOWN, Balance.DASH_COOLDOWN - stats["agi"] * Balance.DASH_CD_PER_AGI)


func xp_to_next() -> int:
	return Balance.XP_PER_LEVEL * level


# Zwraca liczbę zdobytych poziomów.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		stat_points += Balance.POINTS_PER_LEVEL
		hp += Balance.HP_PER_LEVEL
		gained += 1
	return gained


func spend_point(stat: String) -> bool:
	if stat_points <= 0 or not stats.has(stat):
		return false
	stat_points -= 1
	stats[stat] += 1
	if stat == "vit":
		hp += Balance.HP_PER_VIT
	return true


# ---------- gildia ----------

func has_room(id: String) -> bool:
	return rooms.has(id)


func buy_room(room: Dictionary) -> bool:
	if has_room(room["id"]) or gold < room["cost"]:
		return false
	gold -= room["cost"]
	rooms.append(room["id"])
	refresh_inventory()
	save_game()
	return true


func refresh_inventory() -> void:
	inv.max_weight = Balance.BASE_WEIGHT
	if has_room("storage"):
		inv.max_weight += Balance.STORAGE_WEIGHT_BONUS


func rest() -> void:
	day += 1
	if has_room("infirmary"):
		hp = max_hp()
	else:
		hp = mini(max_hp(), hp + ceili(max_hp() * Balance.REST_HEAL_PCT))


# Bezpieczny powrót z lochu: złoto do skarbca, nowy dzień.
func return_from_dungeon(run_gold: int, floor_reached: int, player_hp: int) -> void:
	gold += run_gold
	best_floor = maxi(best_floor, floor_reached)
	hp = player_hp
	rest()
	message = "Wracasz z piętra %d z %d zł. Nowy dzień: %d." % [floor_reached, run_gold, day]
	save_game()


# Śmierć: tracisz złoto z wyprawy i plecak, założony sprzęt zostaje.
func die_in_dungeon(run_gold: int, floor_reached: int) -> void:
	best_floor = maxi(best_floor, floor_reached)
	inv.pack = []
	day += 1
	hp = maxi(1, ceili(max_hp() * Balance.DEATH_HP_PCT))
	message = "Ledwo żywego wynieśli Cię z piętra %d. Przepadło %d zł i plecak." % [floor_reached, run_gold]
	save_game()


# ---------- zapis ----------

func save_game() -> void:
	var data := {
		"gold": gold, "day": day, "level": level, "xp": xp, "stat_points": stat_points,
		"stats": stats, "hp": hp, "rooms": rooms, "best_floor": best_floor,
		"weapon": inv.weapon, "armor": inv.armor, "pack": inv.pack,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	# JSON zwraca liczby jako float, więc wszystko rzutujemy na int.
	gold = int(data.get("gold", 0))
	day = int(data.get("day", 1))
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	stat_points = int(data.get("stat_points", 0))
	var s: Dictionary = data.get("stats", {})
	stats = {"str": int(s.get("str", 0)), "vit": int(s.get("vit", 0)), "agi": int(s.get("agi", 0))}
	rooms = []
	for r in data.get("rooms", ["hall"]):
		rooms.append(str(r))
	best_floor = int(data.get("best_floor", 0))
	inv.weapon = clean_item(data.get("weapon", {}))
	inv.armor = clean_item(data.get("armor", {}))
	inv.pack = []
	for it in data.get("pack", []):
		inv.pack.append(clean_item(it))
	refresh_inventory()
	hp = clampi(int(data.get("hp", max_hp())), 1, max_hp())
	message = "Wczytano zapis. Dzień %d." % day
	return true


func clean_item(raw) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or raw.is_empty():
		return {}
	var item := {}
	for key in raw:
		var v = raw[key]
		item[key] = int(v) if typeof(v) == TYPE_FLOAT else v
	return item


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	reset()
