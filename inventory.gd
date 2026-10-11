extends RefCounted

var weapon: Dictionary = {}
var armor: Dictionary = {}
var pack: Array = []           # plecak: lista przedmiotów
var max_weight := 20           # tu zmienisz limit udźwigu


func reset() -> void:
	weapon = {}
	armor = {}
	pack = []


func attack_bonus() -> int:
	return weapon.get("atk", 0)


func defense() -> int:
	return armor.get("def", 0)


# Waga wszystkiego, co masz przy sobie (założone + plecak).
func total_weight() -> int:
	var w: int = 0
	if not weapon.is_empty():
		w += weapon["weight"]
	if not armor.is_empty():
		w += armor["weight"]
	for item in pack:
		w += item["weight"]
	return w


func can_carry(item: Dictionary) -> bool:
	return total_weight() + item["weight"] <= max_weight


# Dodaje do plecaka, jeśli się mieści. Zwraca true, gdy się udało.
func add(item: Dictionary) -> bool:
	if not can_carry(item):
		return false
	pack.append(item)
	return true


# Zakłada przedmiot z plecaka. Poprzednio założony wraca do plecaka.
func equip_from_pack(index: int) -> void:
	var item: Dictionary = pack[index]
	pack.remove_at(index)
	var old: Dictionary = {}
	if item["slot"] == "weapon":
		old = weapon
		weapon = item
	else:
		old = armor
		armor = item
	if not old.is_empty():
		pack.append(old)
