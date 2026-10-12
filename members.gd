extends RefCounted
# System guild members: data, recruitment, traits, ranks.

const Balance = preload("res://balance.gd")

const CLASSES := ["Knight", "Hunter", "Mage"]
const TRAITS := ["brave", "cowardly", "loyal", "greedy", "calm", "aggressive", "intelligent", "stupid"]

const NAMES_MALE := ["Kael", "Thorn", "Bran", "Gareth", "Darius", "Roran", "Edric", "Torin", "Varen", "Eldrin"]
const NAMES_FEMALE := ["Lyra", "Mara", "Elara", "Kira", "Sera", "Nyla", "Vera", "Tara", "Rina", "Eira"]


# Generate new member with random stats.
func generate_member(floor_requirement: int = 1) -> Dictionary:
	var is_male: bool = randf() < 0.5
	var name: String = NAMES_MALE.pick_random() if is_male else NAMES_FEMALE.pick_random()
	var class_type: String = CLASSES.pick_random()
	var rank_idx: int = randi_range(0, 1)
	var rank: String = Balance.RANKS[rank_idx]
	
	var hp: int = Balance.BASE_HP + randi_range(0, 5)
	var attack: int = randi_range(1, 3)
	var defense: int = randi_range(0, 2)
	
	var traits_count: int = randi_range(1, 2)
	var traits: Array = []
	var pool: Array = TRAITS.duplicate()
	for _i in traits_count:
		if pool.is_empty():
			break
		var t: String = pool.pick_random()
		traits.append(t)
		pool.erase(t)
	
	return {
		"id": str(randi()),
		"name": name,
		"class": class_type,
		"rank": rank,
		"hp": hp,
		"max_hp": hp,
		"xp": Balance.MEMBER_RANK_XP[rank_idx],
		"attack": attack,
		"defense": defense,
		"traits": traits,
		"floor_req": floor_requirement,
		"cost": recruit_cost(rank_idx),
		"alive": true,
		"in_party": false,
	}


# Recruitment cost depends on rank.
func recruit_cost(rank_idx: int) -> int:
	return 50 + rank_idx * 50


# Return member description.
func describe(member: Dictionary) -> String:
	if not member.get("alive", true):
		return "%s (dead)" % member["name"]
	var rank_name: String = Balance.RANK_NAMES.get(member["rank"], "Unknown")
	return "%s - %s %s (Atk: %d, Def: %d)" % [member["name"], rank_name, member["class"], member["attack"], member["defense"]]


# Return traits text comma-separated.
func traits_text(member: Dictionary) -> String:
	var traits: Array = member.get("traits", [])
	if traits.is_empty():
		return "none"
	return ", ".join(PackedStringArray(traits))


# Check if member has given trait.
func has_trait(member: Dictionary, trait_name: String) -> bool:
	return trait_name in member.get("traits", [])


# Promote rank if conditions met. Returns true if promoted.
func promote_member(member: Dictionary, xp_gained: int) -> bool:
	if not member.get("alive", true) or xp_gained <= 0:
		return false
	
	var current_idx := Balance.RANKS.find(member["rank"])
	if current_idx == -1 or current_idx >= Balance.RANKS.size() - 1:
		return false
	var member_xp: int = int(member.get("xp", Balance.MEMBER_RANK_XP[current_idx])) + xp_gained
	member["xp"] = member_xp
	var promoted := false
	while current_idx < Balance.RANKS.size() - 1 and member_xp >= Balance.MEMBER_RANK_XP[current_idx + 1]:
		current_idx += 1
		member["rank"] = Balance.RANKS[current_idx]
		member["attack"] = int(member.get("attack", 0)) + Balance.MEMBER_ATTACK_PER_RANK
		member["max_hp"] = int(member.get("max_hp", member.get("hp", 1))) + Balance.MEMBER_HP_PER_RANK
		member["hp"] = mini(int(member.get("max_hp", 1)), int(member.get("hp", 1)) + Balance.MEMBER_HP_PER_RANK)
		promoted = true
	return promoted
