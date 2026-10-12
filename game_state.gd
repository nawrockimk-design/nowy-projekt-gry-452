extends Node
# Autoload "GameState": wszystko, co przetrwa między gildią a lochem. Zapis w user://save.json.

const Balance = preload("res://balance.gd")
const Inventory = preload("res://inventory.gd")
const Quests = preload("res://quests.gd")
const Members = preload("res://members.gd")

var quest_system = Quests.new()
var member_system = Members.new()

const RANKS := ["F", "E", "D", "C", "B", "A", "S"]

const SAVE_PATH := "user://save.json"
const SAVE_TMP := "user://save.json.tmp"

var gold := 0
var day := 1
var player_class := ""
var intro_complete := false
var level := 1
var xp := 0
var stat_points := 0
var stats := {"str": 0, "vit": 0, "agi": 0}
var hp := Balance.BASE_HP
var rooms: Array = ["hall"]
var best_floor := 0
var inv = Inventory.new()
var members: Array = []             # lista członków gildii
var guild_rank := "F"              # ranga gildii
var guild_xp := 0
var quests: Array = []             # dostępne zlecenia
var active_quest: Dictionary = {}  # aktualnie aktywne zlecenie
var message := ""                   # komunikat do pokazania w gildii
var in_run := false                 # true od wejścia do lochu do powrotu portalem lub śmierci


func _ready() -> void:
	if not load_game():
		reset()
	else:
		if quests.is_empty():
			generate_quests()


func reset() -> void:
	gold = 0
	day = 1
	player_class = ""
	intro_complete = false
	level = 1
	xp = 0
	stat_points = 0
	stats = {"str": 0, "vit": 0, "agi": 0}
	rooms = ["hall"]
	best_floor = 0
	in_run = false
	inv.reset()
	refresh_inventory()
	members = []
	guild_rank = "F"
	guild_xp = 0
	quests = []
	active_quest = {}
	hp = max_hp()
	generate_quests()
	message = "Dziś kończysz 18 lat. Coś w Twojej głowie mówi: [SYSTEM AKTYWNY]."


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


# Zwraca liczbę zdobytych poziomów. HP w lochu śledzi main.gd (player_hp),
# więc tu tylko poziom i punkty; HP wraca do GameState przy powrocie lub śmierci.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		stat_points += Balance.POINTS_PER_LEVEL
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


# ---------- członkowie gildii ----------

func recruit_member(member: Dictionary) -> bool:
	if gold < member["cost"]:
		return false
	gold -= member["cost"]
	members.append(member)
	save_game()
	return true


func remove_member(member_id: String) -> void:
	for i: int in members.size():
		if members[i]["id"] == member_id:
			members.remove_at(i)
			break
	save_game()


func kill_member(member_id: String) -> void:
	for m in members:
		if m["id"] == member_id:
			m["alive"] = false
			m["in_party"] = false
			break
	save_game()


func get_party_members() -> Array:
	var party := []
	for m in members:
		if m.get("alive", true) and m.get("in_party", false):
			party.append(m)
	return party


func clear_party() -> void:
	for m: Dictionary in members:
		m["in_party"] = false


func max_party_size() -> int:
	return Balance.MAX_PARTY_SIZE if has_room("barracks") else 0


func guild_xp_to_next() -> int:
	var idx: int = Balance.RANKS.find(guild_rank)
	if idx == -1 or idx >= Balance.RANKS.size() - 1:
		return 999999
	return Balance.GUILD_RANK_XP[idx + 1]


func add_guild_xp(amount: int) -> bool:
	if amount <= 0:
		return false
	guild_xp += amount
	var current_idx := Balance.RANKS.find(guild_rank)
	if current_idx == -1:
		current_idx = 0
	var original_rank := guild_rank
	while current_idx < Balance.RANKS.size() - 1 and guild_xp >= Balance.GUILD_RANK_XP[current_idx + 1]:
		current_idx += 1
		guild_rank = Balance.RANKS[current_idx]
	return guild_rank != original_rank


func award_party_member_xp(amount: int) -> Array[String]:
	var promoted_names: Array[String] = []
	if amount <= 0:
		return promoted_names
	for member in members:
		if not member.get("alive", true) or not member.get("in_party", false):
			continue
		if member_system.promote_member(member, amount):
			promoted_names.append(str(member.get("name", "Członek gildii")))
	return promoted_names


# ---------- zlecenia ----------

func generate_quests() -> void:
	quests = []
	var count := 3 + floori(best_floor / 2.0)
	var guild_rank_idx := maxi(0, Balance.RANKS.find(guild_rank))
	for _i in count:
		var q: Dictionary = quest_system.generate_quest(best_floor + 1, guild_rank_idx)
		quests.append(q)


func accept_quest(quest_id: String) -> bool:
	if not active_quest.is_empty():
		return false
	for i in quests.size():
		var q: Dictionary = quests[i]
		if q["id"] == quest_id:
			active_quest = q.duplicate()
			quest_system.start_quest(active_quest)
			quests.remove_at(i)
			save_game()
			return true
	return false


func complete_quest() -> int:
	if active_quest.is_empty() or not active_quest.get("completed", false):
		return 0
	var quest_id: String = str(active_quest.get("id", ""))
	var reward: int = int(active_quest.get("reward", 0))
	gold += reward
	add_guild_xp(Balance.GUILD_XP_PER_QUEST)
	active_quest = {}
	
	# Czyść również stare zapisy, w których przyjęte zlecenie zostało na tablicy.
	for i in quests.size():
		if quests[i].get("id", "") == quest_id:
			quests.remove_at(i)
			break
	
	save_game()
	return reward


func update_quest_progress(amount: int = 1) -> void:
	if not active_quest.is_empty():
		quest_system.update_progress(active_quest, amount)


# Nowy dzień z leczeniem: z Lecznicą pełne, bez niej część HP.
func next_day() -> void:
	day += 1
	if has_room("infirmary"):
		hp = max_hp()
	else:
		hp = mini(max_hp(), hp + ceili(max_hp() * Balance.REST_HEAL_PCT))
	
	# generuj nowe zlecenia co kilka dni
	if day % 3 == 1:
		generate_quests()


# Płatny nocleg w gildii. Zwraca false, gdy brakuje złota.
func rest() -> bool:
	if gold < Balance.REST_COST:
		return false
	gold -= Balance.REST_COST
	next_day()
	return true


# Bezpieczny powrót z lochu: złoto do skarbca, nowy dzień (darmowy).
func return_from_dungeon(run_gold: int, floor_reached: int, player_hp: int) -> void:
	in_run = false
	gold += run_gold
	best_floor = maxi(best_floor, floor_reached)
	hp = player_hp
	# Wyjście od razu po wejściu (bez łupu i bez zejścia niżej) nie daje darmowego dnia ani leczenia.
	if run_gold > 0 or floor_reached > 1:
		next_day()
		var promotions := award_party_member_xp(maxi(0, floor_reached - 1) * Balance.MEMBER_XP_PER_FLOOR)
		message = "Wracasz z piętra %d z %d zł. Nowy dzień: %d." % [floor_reached, run_gold, day]
		if not promotions.is_empty():
			message += " Awans: %s." % ", ".join(PackedStringArray(promotions))
	else:
		message = "Wracasz do gildii bez wyprawy. Dzień się nie zmienił."
	save_game()


# Śmierć: tracisz złoto z wyprawy i plecak, założony sprzęt zostaje.
func die_in_dungeon(run_gold: int, floor_reached: int) -> void:
	in_run = false
	best_floor = maxi(best_floor, floor_reached)
	inv.pack = []
	day += 1
	hp = maxi(1, ceili(max_hp() * Balance.DEATH_HP_PCT))
	message = "Ledwo żywego wynieśli Cię z piętra %d. Przepadło %d zł i plecak." % [floor_reached, run_gold]
	save_game()


# Gra zamknięta w trakcie wyprawy liczy się jak śmierć, żeby nie dało się uciec przed karą.
func abandon_run() -> void:
	in_run = false
	inv.pack = []
	day += 1
	hp = maxi(1, ceili(max_hp() * Balance.DEATH_HP_PCT))
	message = "Wyprawa urwała się w połowie. Przepadło złoto z wyprawy i plecak. Dzień %d." % day
	save_game()


# ---------- zapis ----------

func save_game() -> void:
	var data := {
		"version": Balance.SAVE_VERSION,
		"gold": gold, "day": day, "player_class": player_class, "intro_complete": intro_complete,
		"level": level, "xp": xp, "stat_points": stat_points,
		"stats": stats, "hp": hp, "rooms": rooms, "best_floor": best_floor,
		"weapon": inv.weapon, "armor": inv.armor, "pack": inv.pack, "in_run": in_run,
		"members": members, "guild_rank": guild_rank, "guild_xp": guild_xp, "quests": quests, "active_quest": active_quest,
	}
	# Zapis atomowy: najpierw plik tymczasowy, potem podmiana, żeby crash w trakcie nie psuł save'a.
	var f := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_TMP), ProjectSettings.globalize_path(SAVE_PATH))


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
	player_class = str(data.get("player_class", ""))
	intro_complete = bool(data.get("intro_complete", true))
	if not player_class.is_empty() and player_class not in Balance.PLAYER_CLASSES:
		player_class = "Rycerz"
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
	in_run = false
	
	# członkowie gildii
	members = data.get("members", [])
	guild_rank = data.get("guild_rank", "F")
	if not Balance.RANKS.has(guild_rank):
		guild_rank = "F"
	var saved_rank_idx: int = Balance.RANKS.find(guild_rank)
	guild_xp = int(data.get("guild_xp", Balance.GUILD_RANK_XP[maxi(0, saved_rank_idx)]))
	for member in members:
		var member_rank_idx: int = Balance.RANKS.find(member.get("rank", "F"))
		if member_rank_idx < 0:
			member_rank_idx = 0
			member["rank"] = "F"
		member["xp"] = int(member.get("xp", Balance.MEMBER_RANK_XP[member_rank_idx]))
	if not has_room("barracks"):
		clear_party()
	
	# zlecenia
	quests = data.get("quests", [])
	active_quest = data.get("active_quest", {})
	
	message = "Wczytano zapis. Dzień %d." % day
	if bool(data.get("in_run", false)) and Balance.QUIT_IN_RUN_IS_DEATH:
		abandon_run()
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
