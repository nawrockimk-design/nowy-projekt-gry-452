extends RefCounted

const WEAPONS := ["Patyk", "Sztylet", "Miecz", "Topór bojowy", "Legendarny miecz"]
const WEAPON_WEIGHTS := [2, 2, 4, 6, 5]
const ARMORS := ["Szmaty", "Skórzana kurtka", "Kolczuga", "Płytowa zbroja", "Zbroja smoka"]
const ARMOR_WEIGHTS := [1, 3, 5, 7, 8]


# Im głębsze piętro, tym lepsze przedmioty (tier 0-4).
static func random_item(floor_num: int) -> Dictionary:
	var tier := clampi(randi_range(0, 1) + floori(floor_num / 3.0), 0, 4)
	if randf() < 0.5:
		return {"slot": "weapon", "name": WEAPONS[tier], "atk": tier + 1, "def": 0, "weight": WEAPON_WEIGHTS[tier]}
	return {"slot": "armor", "name": ARMORS[tier], "atk": 0, "def": 1 + floori(tier / 2.0), "weight": ARMOR_WEIGHTS[tier]}


static func potion() -> Dictionary:
	return {"slot": "potion", "name": "Mikstura leczenia", "heal": 4, "weight": 1}


static func describe(item: Dictionary) -> String:
	if item.is_empty():
		return "brak"
	if item["slot"] == "weapon":
		return "%s (+%d atak, waga %d)" % [item["name"], item["atk"], item["weight"]]
	if item["slot"] == "armor":
		return "%s (+%d obrona, waga %d)" % [item["name"], item["def"], item["weight"]]
	return "%s (+%d HP, waga %d)" % [item["name"], item["heal"], item["weight"]]


static func color_of(item: Dictionary) -> Color:
	if item["slot"] == "weapon":
		return Color(0.95, 0.55, 0.15)
	if item["slot"] == "armor":
		return Color(0.2, 0.8, 0.8)
	return Color(0.3, 0.5, 1.0)
