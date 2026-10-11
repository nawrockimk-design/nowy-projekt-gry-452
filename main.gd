extends Node2D
# Loch z walką w czasie rzeczywistym. Mapa i generator pokoi z dungeon.gd zostają bez zmian.

const Items = preload("res://items.gd")
const Dungeon = preload("res://dungeon.gd")
const Balance = preload("res://balance.gd")

const TILE := 48
const ORIGIN := Vector2(24, 24)
const MINI_ORIGIN := Vector2(800, 40)

var dungeon = Dungeon.new()
var inv = GameState.inv
var floor_num := 1
var run_gold := 0
var log_text := ""
var log_timer := 0.0
var game_over := false
var inv_open := false
var inv_cursor := 0

# gracz (współrzędne w pikselach wewnątrz pokoju)
var player_pos := Vector2.ZERO
var facing := Vector2.RIGHT
var player_hp := 10
var attack_cd := 0.0
var swing_timer := 0.0
var dash_cd := 0.0
var dash_timer := 0.0
var dash_dir := Vector2.ZERO
var skill_cd := 0.0
var skill_fx := 0.0
var invuln := 0.0
var hurt_flash := 0.0
var death_timer := 0.0
var floats: Array = []               # latające napisy: {"pos", "text", "color", "t"}


func _ready() -> void:
	randomize()
	floor_num = 1
	run_gold = 0
	player_hp = GameState.hp
	inv_open = false
	start_floor()
	say("WASD = ruch, J/Spacja = atak, Shift = unik, K = %s, E = podnieś, I = plecak, F = portal do gildii." % Balance.SKILL_NAME, 8.0)


func start_floor() -> void:
	dungeon.generate(floor_num)
	player_pos = tile_center(Vector2i(Dungeon.CX, Dungeon.CY))
	prepare_room(dungeon.current_room())
	queue_redraw()


func say(text: String, duration: float = 3.0) -> void:
	log_text = text
	log_timer = duration


func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t * TILE) + Vector2(TILE, TILE) * 0.5


func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


# Wrogowie z generatora mają tylko pozycję na kratce - tu dostają stan do walki na żywo.
func prepare_room(room: Dictionary) -> void:
	for e in room["enemies"]:
		if e.has("p"):
			continue
		e["p"] = tile_center(e["pos"])
		e["hp"] = Balance.ENEMY_BASE_HP + floor_num * Balance.ENEMY_HP_PER_FLOOR
		e["max_hp"] = e["hp"]
		e["state"] = "chase"
		e["t"] = randf_range(0.3, 0.8)  # krótka chwila na reakcję po wejściu
		e["flash"] = 0.0
		e["aim"] = Vector2.ZERO


# ---------- sterowanie ----------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if game_over:
		return
	if inv_open:
		inventory_input(event.keycode)
		return
	match event.keycode:
		KEY_I:
			inv_open = true
			inv_cursor = 0
		KEY_E:
			take_item()
		KEY_F:
			try_portal()
		KEY_J, KEY_SPACE:
			basic_attack()
		KEY_K:
			use_skill()
		KEY_SHIFT:
			start_dash()


func input_direction() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		d.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		d.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		d.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		d.x += 1
	return d.normalized()


# ---------- pętla gry ----------

func _process(delta: float) -> void:
	update_floats(delta)
	if log_timer > 0.0:
		log_timer -= delta
	if game_over:
		death_timer -= delta
		if death_timer <= 0.0:
			GameState.die_in_dungeon(run_gold, floor_num)
			get_tree().change_scene_to_file("res://guild.tscn")
		queue_redraw()
		return
	if inv_open:
		return  # plecak pauzuje walkę

	attack_cd = maxf(0.0, attack_cd - delta)
	swing_timer = maxf(0.0, swing_timer - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	skill_fx = maxf(0.0, skill_fx - delta)
	invuln = maxf(0.0, invuln - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)

	var room: Dictionary = dungeon.current_room()
	update_player(room, delta)
	update_enemies(room, delta)
	check_transitions(room)
	queue_redraw()


func update_player(room: Dictionary, delta: float) -> void:
	var dir := input_direction()
	if dir != Vector2.ZERO:
		facing = dir
	var velocity := dir * GameState.move_speed()
	if dash_timer > 0.0:
		dash_timer -= delta
		velocity = dash_dir * Balance.DASH_SPEED
	player_pos = move_circle(room, player_pos, velocity * delta, Balance.PLAYER_RADIUS, true)
	auto_pickup(room)


func check_transitions(room: Dictionary) -> void:
	var t := tile_of(player_pos)
	var door_dir: Vector2i = dungeon.door_direction(t)
	if door_dir != Vector2i.ZERO and room["doors"].has(door_dir) and room["enemies"].is_empty():
		enter_room(dungeon.current + door_dir, door_dir)
		return
	if dungeon.current == dungeon.stairs_cell and t == Vector2i(Dungeon.CX, Dungeon.CY) and room["enemies"].is_empty():
		next_floor()


# Ruch kółka po siatce: najpierw oś X, potem Y, dzięki temu gracz ślizga się po ścianach.
func move_circle(room: Dictionary, pos: Vector2, motion: Vector2, radius: float, can_use_doors: bool) -> Vector2:
	var next := Vector2(pos.x + motion.x, pos.y)
	if not circle_blocked(room, next, radius, can_use_doors):
		pos = next
	next = Vector2(pos.x, pos.y + motion.y)
	if not circle_blocked(room, next, radius, can_use_doors):
		pos = next
	return pos


func circle_blocked(room: Dictionary, p: Vector2, r: float, can_use_doors: bool) -> bool:
	for corner in [Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r), Vector2(r, r)]:
		if tile_blocked(room, tile_of(p + corner), can_use_doors):
			return true
	return false


func tile_blocked(room: Dictionary, t: Vector2i, can_use_doors: bool) -> bool:
	if can_use_doors:
		var dd: Vector2i = dungeon.door_direction(t)
		if dd != Vector2i.ZERO and room["doors"].has(dd) and room["enemies"].is_empty():
			return false
	return dungeon.is_blocked(room, t)


# ---------- walka gracza ----------

func basic_attack() -> void:
	if attack_cd > 0.0 or dash_timer > 0.0:
		return
	attack_cd = Balance.ATTACK_COOLDOWN
	swing_timer = 0.12
	var room: Dictionary = dungeon.current_room()
	for e in room["enemies"].duplicate():
		var to_enemy: Vector2 = e["p"] - player_pos
		if to_enemy.length() > Balance.ATTACK_RANGE + Balance.ENEMY_RADIUS:
			continue
		if to_enemy.length() > 4.0 and to_enemy.normalized().dot(facing) < Balance.ATTACK_ARC_DOT:
			continue
		var dmg := randi_range(Balance.ATTACK_MIN_DMG, Balance.ATTACK_MAX_DMG) + GameState.attack_bonus()
		damage_enemy(room, e, dmg)


func use_skill() -> void:
	if skill_cd > 0.0:
		say("%s się ładuje (%.1fs)." % [Balance.SKILL_NAME, skill_cd], 1.5)
		return
	skill_cd = Balance.SKILL_COOLDOWN
	skill_fx = 0.25
	var room: Dictionary = dungeon.current_room()
	for e in room["enemies"].duplicate():
		if e["p"].distance_to(player_pos) <= Balance.SKILL_RADIUS + Balance.ENEMY_RADIUS:
			var dmg := (randi_range(Balance.ATTACK_MIN_DMG, Balance.ATTACK_MAX_DMG) + GameState.attack_bonus()) * Balance.SKILL_DMG_MULT
			damage_enemy(room, e, dmg)


func start_dash() -> void:
	if dash_cd > 0.0:
		return
	var dir := input_direction()
	dash_dir = dir if dir != Vector2.ZERO else facing
	dash_timer = Balance.DASH_TIME
	dash_cd = GameState.dash_cooldown()
	invuln = maxf(invuln, Balance.DASH_TIME + 0.05)


func damage_enemy(room: Dictionary, e: Dictionary, dmg: int) -> void:
	e["hp"] -= dmg
	e["flash"] = 0.12
	add_float(e["p"], str(dmg), Color(1, 0.9, 0.4))
	var push: Vector2 = (e["p"] - player_pos).normalized() * Balance.KNOCKBACK
	e["p"] = move_circle(room, e["p"], push, Balance.ENEMY_RADIUS, false)
	if e["hp"] <= 0:
		kill_enemy(room, e)


func kill_enemy(room: Dictionary, e: Dictionary) -> void:
	var dead_tile := tile_of(e["p"])
	room["enemies"].erase(e)
	var gold := randi_range(Balance.GOLD_MIN, Balance.GOLD_MAX) + floor_num * Balance.GOLD_PER_FLOOR
	run_gold += gold
	add_float(e["p"] + Vector2(0, -16), "+%d zł" % gold, Color(0.95, 0.8, 0.35))
	var levels: int = GameState.add_xp(Balance.XP_BASE + floor_num * Balance.XP_PER_FLOOR)
	if levels > 0:
		player_hp += levels * Balance.HP_PER_LEVEL
		say("[SYSTEM] Poziom %d! Punkty do rozdania w gildii (Tab)." % GameState.level, 4.0)
		add_float(player_pos + Vector2(0, -28), "POZIOM!", Color(0.4, 0.75, 1.0))
	if randf() < 0.25:
		room["items"].append({"pos": dead_tile, "item": Items.potion()})
	if randf() < 0.15:
		room["items"].append({"pos": dead_tile, "item": Items.random_item(floor_num)})
	if room["enemies"].is_empty():
		say("Pokój oczyszczony - drzwi otwarte!")


# ---------- wrogowie ----------

func update_enemies(room: Dictionary, delta: float) -> void:
	var speed := Balance.ENEMY_BASE_SPEED + floor_num * Balance.ENEMY_SPEED_PER_FLOOR
	for e in room["enemies"]:
		e["flash"] = maxf(0.0, e["flash"] - delta)
		e["t"] -= delta
		var to_player: Vector2 = player_pos - e["p"]
		match e["state"]:
			"chase":
				if e["t"] > 0.0:
					continue
				if to_player.length() <= Balance.ENEMY_ATTACK_RANGE + Balance.PLAYER_RADIUS:
					e["state"] = "windup"
					e["t"] = Balance.ENEMY_WINDUP
					e["aim"] = to_player.normalized()
				else:
					var motion: Vector2 = to_player.normalized() * speed * delta + separation(room, e) * delta
					e["p"] = move_circle(room, e["p"], motion, Balance.ENEMY_RADIUS, false)
			"windup":
				if e["t"] <= 0.0:
					enemy_strike(e)
					e["state"] = "recover"
					e["t"] = Balance.ENEMY_RECOVER
			"recover":
				if e["t"] <= 0.0:
					e["state"] = "chase"
		if game_over:
			return


# Lekkie odpychanie wrogów od siebie, żeby nie stali w jednym miejscu.
func separation(room: Dictionary, e: Dictionary) -> Vector2:
	var push := Vector2.ZERO
	for other in room["enemies"]:
		if other == e:
			continue
		var d: Vector2 = e["p"] - other["p"]
		var dist := d.length()
		if dist > 0.01 and dist < Balance.ENEMY_RADIUS * 2.5:
			push += d / dist * 60.0
	return push


func enemy_strike(e: Dictionary) -> void:
	if e["p"].distance_to(player_pos) > Balance.ENEMY_HIT_RANGE + Balance.PLAYER_RADIUS:
		return
	if invuln > 0.0:
		add_float(player_pos + Vector2(0, -20), "unik!", Color(0.6, 0.9, 1.0))
		return
	var max_dmg := Balance.ENEMY_BASE_DMG + floori(floor_num / 3.0)
	var dmg: int = maxi(1, randi_range(1, max_dmg) - inv.defense())
	player_hp -= dmg
	invuln = Balance.HIT_INVULN
	hurt_flash = 0.2
	add_float(player_pos + Vector2(0, -20), "-%d" % dmg, Color(1, 0.3, 0.3))
	if player_hp <= 0:
		player_hp = 0
		game_over = true
		inv_open = false
		death_timer = 2.5
		say("Padasz na piętrze %d..." % floor_num, 3.0)


# ---------- przedmioty na podłodze ----------

# Mikstury wchodzą do plecaka same, jeśli starczy udźwigu.
func auto_pickup(room: Dictionary) -> void:
	var t := tile_of(player_pos)
	var list: Array = room["items"]
	var i := list.size() - 1
	while i >= 0:
		var entry: Dictionary = list[i]
		if entry["pos"] == t and entry["item"]["slot"] == "potion" and not entry.get("dropped", false):
			if inv.add(entry["item"]):
				say("Zbierasz: %s." % Items.describe(entry["item"]))
				list.remove_at(i)
			else:
				entry["dropped"] = true
				say("Za ciężko! Mikstura zostaje na podłodze (udźwig %d/%d)." % [inv.total_weight(), inv.max_weight])
		i -= 1


func take_item() -> void:
	var room: Dictionary = dungeon.current_room()
	var idx: int = dungeon.item_index(room, tile_of(player_pos))
	if idx == -1:
		say("Nie ma tu nic do podniesienia.")
		return
	var found: Dictionary = room["items"][idx]["item"]
	if not inv.add(found):
		say("Za ciężkie! Udźwig %d/%d - wyrzuć coś w plecaku (I)." % [inv.total_weight(), inv.max_weight])
		return
	room["items"].remove_at(idx)
	say("Podnosisz: %s." % Items.describe(found))


# ---------- plecak (pauzuje grę) ----------

func inventory_input(keycode: int) -> void:
	var room: Dictionary = dungeon.current_room()
	var n: int = inv.pack.size()
	match keycode:
		KEY_I, KEY_ESCAPE:
			inv_open = false
		KEY_UP, KEY_W:
			if n > 0:
				inv_cursor = (inv_cursor - 1 + n) % n
		KEY_DOWN, KEY_S:
			if n > 0:
				inv_cursor = (inv_cursor + 1) % n
		KEY_E:
			if n > 0:
				use_pack_item(inv_cursor)
		KEY_X:
			if n > 0:
				drop_pack_item(room, inv_cursor)
	queue_redraw()


func use_pack_item(idx: int) -> void:
	var item: Dictionary = inv.pack[idx]
	if item["slot"] == "potion":
		if player_hp >= GameState.max_hp():
			say("Masz pełne HP - mikstura nie jest teraz potrzebna.")
			return
		inv.pack.remove_at(idx)
		var healed: int = mini(item["heal"], GameState.max_hp() - player_hp)
		player_hp += healed
		say("Pijesz miksturę (+%d HP)." % healed)
	else:
		inv.equip_from_pack(idx)
		say("Zakładasz: %s." % Items.describe(item))
	inv_cursor = clampi(inv_cursor, 0, maxi(inv.pack.size() - 1, 0))


func drop_pack_item(room: Dictionary, idx: int) -> void:
	var item: Dictionary = inv.pack[idx]
	inv.pack.remove_at(idx)
	room["items"].append({"pos": tile_of(player_pos), "item": item, "dropped": true})
	say("Wyrzucasz: %s." % Items.describe(item))
	inv_cursor = clampi(inv_cursor, 0, maxi(inv.pack.size() - 1, 0))


# ---------- pokoje, piętra, powrót ----------

func on_portal() -> bool:
	return dungeon.current == dungeon.start_cell and tile_of(player_pos) == Vector2i(Dungeon.CX, Dungeon.CY)


func try_portal() -> void:
	if not on_portal():
		say("Portal do gildii jest na środku pierwszego pokoju piętra.")
		return
	GameState.return_from_dungeon(run_gold, floor_num, player_hp)
	get_tree().change_scene_to_file("res://guild.tscn")


func enter_room(cell: Vector2i, dir: Vector2i) -> void:
	dungeon.current = cell
	var room: Dictionary = dungeon.current_room()
	room["visited"] = true
	prepare_room(room)
	player_pos = tile_center(dungeon.entry_position(dir))
	if room["enemies"].is_empty():
		say("Pusty pokój.")
	else:
		say("Drzwi się zatrzaskują! Pokonaj wrogów.")
	floats.clear()


func next_floor() -> void:
	floor_num += 1
	player_hp = mini(player_hp + 3, GameState.max_hp())
	start_floor()
	floats.clear()
	say("Piętro %d. Leczysz się o 3. Portal (F) na środku tego pokoju." % floor_num, 4.0)


# ---------- efekty ----------

func add_float(pos: Vector2, text: String, color: Color) -> void:
	floats.append({"pos": pos, "text": text, "color": color, "t": 0.8})


func update_floats(delta: float) -> void:
	var i := floats.size() - 1
	while i >= 0:
		floats[i]["t"] -= delta
		floats[i]["pos"] += Vector2(0, -30 * delta)
		if floats[i]["t"] <= 0.0:
			floats.remove_at(i)
		i -= 1


# ---------- rysowanie ----------

func cell_rect(pos: Vector2i, margin: float = 0.0) -> Rect2:
	return Rect2(
		ORIGIN + Vector2(pos * TILE) + Vector2(margin, margin),
		Vector2(TILE - margin * 2, TILE - margin * 2))


func bar(pos: Vector2, size: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos, size), Color(0.15, 0.15, 0.18))
	draw_rect(Rect2(pos, Vector2(size.x * clampf(ratio, 0.0, 1.0), size.y)), color)


func _draw() -> void:
	if dungeon.layout.is_empty():
		return
	var rw: int = Dungeon.ROOM_W
	var rh: int = Dungeon.ROOM_H
	var cx: int = Dungeon.CX
	var cy: int = Dungeon.CY
	var room: Dictionary = dungeon.current_room()
	var cleared: bool = room["enemies"].is_empty()
	var font := ThemeDB.fallback_font

	# podłoga
	draw_rect(Rect2(ORIGIN, Vector2(rw * TILE, rh * TILE)), Color(0.1, 0.1, 0.12))

	# ściany i drzwi
	for x in rw:
		for y in rh:
			if x == 0 or y == 0 or x == rw - 1 or y == rh - 1:
				var pos := Vector2i(x, y)
				var color := Color(0.35, 0.35, 0.4)
				var dd: Vector2i = dungeon.door_direction(pos)
				if dd != Vector2i.ZERO and room["doors"].has(dd):
					color = Color(0.55, 0.4, 0.2) if cleared else Color(0.7, 0.15, 0.15)
				draw_rect(cell_rect(pos), color)

	# przeszkody
	for op in room["obstacles"]:
		draw_rect(cell_rect(op, 4), Color(0.25, 0.25, 0.3))

	# portal do gildii
	if dungeon.current == dungeon.start_cell:
		var pc := ORIGIN + tile_center(Vector2i(cx, cy))
		draw_circle(pc, 18, Color(0.25, 0.45, 0.9, 0.35))
		draw_arc(pc, 18, 0, TAU, 32, Color(0.45, 0.7, 1.0), 2.0)

	# schody
	if dungeon.current == dungeon.stairs_cell:
		var sc := Color(0.2, 0.7, 0.3) if cleared else Color(0.15, 0.3, 0.18)
		draw_rect(cell_rect(Vector2i(cx, cy), 3), sc)
		draw_string(font, cell_rect(Vector2i(cx, cy)).position + Vector2(18, 33), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 26)

	# przedmioty na podłodze
	for it in room["items"]:
		draw_rect(cell_rect(it["pos"], 13), Items.color_of(it["item"]))

	# wrogowie: zapowiedź ataku rośnie aż do ciosu
	for e in room["enemies"]:
		var ep: Vector2 = ORIGIN + e["p"]
		if e["state"] == "windup":
			var progress: float = 1.0 - e["t"] / Balance.ENEMY_WINDUP
			var reach := Balance.ENEMY_HIT_RANGE + Balance.PLAYER_RADIUS
			draw_circle(ep, reach * progress, Color(1, 0.2, 0.1, 0.18))
			draw_arc(ep, reach, 0, TAU, 32, Color(1, 0.3, 0.2, 0.7), 2.0)
		var col := Color(0.85, 0.2, 0.2)
		if e["flash"] > 0.0:
			col = Color.WHITE
		elif e["state"] == "windup":
			col = Color(1.0, 0.5, 0.2)
		elif e["state"] == "recover":
			col = Color(0.55, 0.15, 0.15)
		draw_circle(ep, Balance.ENEMY_RADIUS, col)
		if e["hp"] < e["max_hp"]:
			bar(ep + Vector2(-16, -26), Vector2(32, 4), float(e["hp"]) / e["max_hp"], Color(0.9, 0.25, 0.25))

	# gracz
	var pp := ORIGIN + player_pos
	if skill_fx > 0.0:
		draw_circle(pp, Balance.SKILL_RADIUS, Color(0.4, 0.75, 1.0, 0.25))
		draw_arc(pp, Balance.SKILL_RADIUS, 0, TAU, 48, Color(0.5, 0.85, 1.0), 3.0)
	if swing_timer > 0.0:
		var a := facing.angle()
		draw_arc(pp, Balance.ATTACK_RANGE, a - 1.1, a + 1.1, 16, Color(1, 1, 0.8), 4.0)
	var player_color := Color(0.9, 0.8, 0.2)
	if game_over:
		player_color = Color(0.4, 0.4, 0.4)
	elif hurt_flash > 0.0:
		player_color = Color(1, 0.3, 0.3)
	elif dash_timer > 0.0:
		player_color = Color(1, 1, 0.7, 0.5)
	elif invuln > 0.0 and int(invuln * 20) % 2 == 0:
		player_color = Color(0.9, 0.8, 0.2, 0.5)
	draw_circle(pp, Balance.PLAYER_RADIUS, player_color)
	draw_line(pp, pp + facing * (Balance.PLAYER_RADIUS + 6), Color(0.2, 0.15, 0.05), 3.0)

	for f in floats:
		var c: Color = f["color"]
		c.a = clampf(f["t"] / 0.4, 0.0, 1.0)
		draw_string(font, ORIGIN + f["pos"] + Vector2(-12, 0), f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)

	draw_hud(font, rh)
	draw_minimap(font)
	if inv_open:
		draw_inventory(font)


func draw_hud(font: Font, rh: int) -> void:
	var hud_y := ORIGIN.y + rh * TILE + 20
	var max_hp := GameState.max_hp()
	bar(Vector2(ORIGIN.x, hud_y), Vector2(220, 16), float(player_hp) / max_hp, Color(0.8, 0.2, 0.25))
	draw_string(font, Vector2(ORIGIN.x + 6, hud_y + 13), "HP %d/%d" % [player_hp, max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	bar(Vector2(ORIGIN.x, hud_y + 20), Vector2(220, 6), float(GameState.xp) / GameState.xp_to_next(), Color(0.4, 0.75, 1.0))

	draw_string(font, Vector2(ORIGIN.x + 240, hud_y + 14), "Piętro %d   Poz. %d   Złoto z wyprawy: %d zł   Udźwig %d/%d" % [
		floor_num, GameState.level, run_gold, inv.total_weight(), inv.max_weight], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)

	var dash_ready := dash_cd <= 0.0
	var skill_ready := skill_cd <= 0.0
	draw_string(font, Vector2(ORIGIN.x, hud_y + 50), "Unik [Shift]: %s" % ("gotowy" if dash_ready else "%.1fs" % dash_cd),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.9, 0.6) if dash_ready else Color(0.6, 0.6, 0.6))
	draw_string(font, Vector2(ORIGIN.x + 200, hud_y + 50), "%s [K]: %s" % [Balance.SKILL_NAME, "gotowe" if skill_ready else "%.1fs" % skill_cd],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.5, 0.8, 1.0) if skill_ready else Color(0.6, 0.6, 0.6))
	if on_portal():
		draw_string(font, Vector2(ORIGIN.x + 460, hud_y + 50), "F: wróć do gildii z łupem",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.45, 0.7, 1.0))

	if log_timer > 0.0:
		draw_string(font, Vector2(ORIGIN.x, hud_y + 76), log_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)


func draw_minimap(font: Font) -> void:
	draw_string(font, MINI_ORIGIN + Vector2(0, -12), "Mapa piętra", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	for cell in dungeon.layout:
		var r: Dictionary = dungeon.layout[cell]
		var seen: bool = r["visited"]
		if not seen:
			for dd2 in r["doors"]:
				var nb: Vector2i = cell + dd2
				if dungeon.layout.has(nb) and dungeon.layout[nb]["visited"]:
					seen = true
		if not seen:
			continue
		var col := Color(0.3, 0.3, 0.35) if r["visited"] else Color(0.15, 0.15, 0.18)
		if cell == dungeon.start_cell:
			col = Color(0.25, 0.4, 0.75)
		if cell == dungeon.stairs_cell and r["visited"]:
			col = Color(0.2, 0.6, 0.3)
		if cell == dungeon.current:
			col = Color(0.9, 0.8, 0.2)
		draw_rect(Rect2(MINI_ORIGIN + Vector2(cell.x * 34, cell.y * 26), Vector2(30, 22)), col)

	draw_string(font, MINI_ORIGIN + Vector2(0, 160), "Czerwone drzwi: pokonaj wrogów", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, MINI_ORIGIN + Vector2(0, 182), "Pomarańczowy wróg: zaraz uderzy - uciekaj!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, MINI_ORIGIN + Vector2(0, 204), "Zielone pole >: schody w dół", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, MINI_ORIGIN + Vector2(0, 226), "Niebieski krąg: portal do gildii (F)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

	draw_string(font, MINI_ORIGIN + Vector2(0, 272), "Założone (I = plecak)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_string(font, MINI_ORIGIN + Vector2(0, 296), "Broń: %s" % Items.describe(inv.weapon), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, MINI_ORIGIN + Vector2(0, 318), "Zbroja: %s" % Items.describe(inv.armor), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, MINI_ORIGIN + Vector2(0, 340), "W plecaku: %d szt." % inv.pack.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, MINI_ORIGIN + Vector2(0, 372), "Śmierć = utrata złota z wyprawy i plecaka.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.5, 0.5))


func draw_inventory(font: Font) -> void:
	var panel := Rect2(ORIGIN + Vector2(60, 24), Vector2(600, 384))
	draw_rect(panel, Color(0, 0, 0, 0.92))
	draw_rect(panel, Color(0.5, 0.5, 0.55), false, 2.0)
	var x := panel.position.x + 20
	var y := panel.position.y + 34
	draw_string(font, Vector2(x, y), "Plecak (pauza)     Udźwig: %d/%d" % [inv.total_weight(), inv.max_weight], HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	var n: int = inv.pack.size()
	if n == 0:
		draw_string(font, Vector2(x, y + 40), "Plecak jest pusty.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var first: int = clampi(inv_cursor - 4, 0, maxi(n - 9, 0))
	for row in mini(9, n - first):
		var i: int = first + row
		var item: Dictionary = inv.pack[i]
		var line_y := y + 36 + row * 26
		var prefix := "> " if i == inv_cursor else "   "
		draw_string(font, Vector2(x, line_y), prefix + Items.describe(item), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Items.color_of(item))
	draw_string(font, Vector2(x, panel.end.y - 16), "W/S lub strzałki: wybór   E: użyj/załóż   X: wyrzuć   I: zamknij", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
