extends RefCounted
# Rysowanie pokoju w lochu: podłoga, ściany, przedmioty, wrogowie, gracz.
# Dane bierze z węzła main.gd (parametr m), niczego nie zmienia.

const Items = preload("res://items.gd")
const Dungeon = preload("res://dungeon.gd")
const Balance = preload("res://balance.gd")

const TILE := 48
const ORIGIN := Vector2(24, 24)
const MINI_ORIGIN := Vector2(800, 40)


static func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t * TILE) + Vector2(TILE, TILE) * 0.5


static func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


static func cell_rect(pos: Vector2i, margin: float = 0.0) -> Rect2:
	return Rect2(
		ORIGIN + Vector2(pos * TILE) + Vector2(margin, margin),
		Vector2(TILE - margin * 2, TILE - margin * 2))


static func draw_bar(canvas: CanvasItem, pos: Vector2, size: Vector2, ratio: float, color: Color) -> void:
	canvas.draw_rect(Rect2(pos, size), Color(0.15, 0.15, 0.18))
	canvas.draw_rect(Rect2(pos, Vector2(size.x * clampf(ratio, 0.0, 1.0), size.y)), color)


static func draw_room(canvas: CanvasItem, m, font: Font) -> void:
	var dungeon = m.dungeon
	var rw: int = Dungeon.ROOM_W
	var rh: int = Dungeon.ROOM_H
	var cx: int = Dungeon.CX
	var cy: int = Dungeon.CY
	var room: Dictionary = dungeon.current_room()
	var cleared: bool = room["enemies"].is_empty()

	var player_pos: Vector2 = m.player_pos
	var facing: Vector2 = m.facing
	var skill_fx: float = m.skill_fx
	var swing_timer: float = m.swing_timer
	var hurt_flash: float = m.hurt_flash
	var dash_timer: float = m.dash_timer
	var invuln: float = m.invuln
	var game_over: bool = m.game_over
	var floats: Array = m.floats
	var allies: Array = m.current_allies

	# podłoga
	canvas.draw_rect(Rect2(ORIGIN, Vector2(rw * TILE, rh * TILE)), Color(0.1, 0.1, 0.12))

	# ściany i drzwi
	for x in rw:
		for y in rh:
			if x == 0 or y == 0 or x == rw - 1 or y == rh - 1:
				var pos := Vector2i(x, y)
				var color := Color(0.35, 0.35, 0.4)
				var dd: Vector2i = dungeon.door_direction(pos)
				if dd != Vector2i.ZERO and room["doors"].has(dd):
					color = Color(0.55, 0.4, 0.2) if cleared else Color(0.7, 0.15, 0.15)
				canvas.draw_rect(cell_rect(pos), color)

	# przeszkody
	for op in room["obstacles"]:
		canvas.draw_rect(cell_rect(op, 4), Color(0.25, 0.25, 0.3))

	# portal do gildii
	if dungeon.current == dungeon.start_cell:
		var pc := ORIGIN + tile_center(Vector2i(cx, cy))
		canvas.draw_circle(pc, 18, Color(0.25, 0.45, 0.9, 0.35))
		canvas.draw_arc(pc, 18, 0, TAU, 32, Color(0.45, 0.7, 1.0), 2.0)

	# schody
	if dungeon.current == dungeon.stairs_cell:
		var sc := Color(0.2, 0.7, 0.3) if cleared else Color(0.15, 0.3, 0.18)
		canvas.draw_rect(cell_rect(Vector2i(cx, cy), 3), sc)
		canvas.draw_string(font, cell_rect(Vector2i(cx, cy)).position + Vector2(18, 33), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 26)

	# przedmioty na podłodze
	for it in room["items"]:
		canvas.draw_rect(cell_rect(it["pos"], 13), Items.color_of(it["item"]))

	# wrogowie: zapowiedź ataku rośnie aż do ciosu
	for e in room["enemies"]:
		var ep: Vector2 = ORIGIN + e["p"]
		if e["state"] == "windup":
			var progress: float = 1.0 - e["t"] / Balance.ENEMY_WINDUP
			var reach := Balance.ENEMY_HIT_RANGE + Balance.PLAYER_RADIUS
			canvas.draw_circle(ep, reach * progress, Color(1, 0.2, 0.1, 0.18))
			canvas.draw_arc(ep, reach, 0, TAU, 32, Color(1, 0.3, 0.2, 0.7), 2.0)
		var col := Color(0.85, 0.2, 0.2)
		if e["flash"] > 0.0:
			col = Color.WHITE
		elif e["state"] == "windup":
			col = Color(1.0, 0.5, 0.2)
		elif e["state"] == "recover":
			col = Color(0.55, 0.15, 0.15)
		canvas.draw_circle(ep, Balance.ENEMY_RADIUS, col)
		if e["hp"] < e["max_hp"]:
			draw_bar(canvas, ep + Vector2(-16, -26), Vector2(32, 4), float(e["hp"]) / e["max_hp"], Color(0.9, 0.25, 0.25))

	# gracz
	var pp := ORIGIN + player_pos
	if skill_fx > 0.0:
		canvas.draw_circle(pp, Balance.SKILL_RADIUS, Color(0.4, 0.75, 1.0, 0.25))
		canvas.draw_arc(pp, Balance.SKILL_RADIUS, 0, TAU, 48, Color(0.5, 0.85, 1.0), 3.0)
	if swing_timer > 0.0:
		var a := facing.angle()
		canvas.draw_arc(pp, Balance.ATTACK_RANGE, a - 1.1, a + 1.1, 16, Color(1, 1, 0.8), 4.0)
	var player_color := Color(0.9, 0.8, 0.2)
	if game_over:
		player_color = Color(0.4, 0.4, 0.4)
	elif hurt_flash > 0.0:
		player_color = Color(1, 0.3, 0.3)
	elif dash_timer > 0.0:
		player_color = Color(1, 1, 0.7, 0.5)
	elif invuln > 0.0 and int(invuln * 20) % 2 == 0:
		player_color = Color(0.9, 0.8, 0.2, 0.5)
	canvas.draw_circle(pp, Balance.PLAYER_RADIUS, player_color)
	canvas.draw_line(pp, pp + facing * (Balance.PLAYER_RADIUS + 6), Color(0.2, 0.15, 0.05), 3.0)

	# sojusznicy
	for ally in allies:
		if not ally.get("alive", true):
			continue
		var ap: Vector2 = ORIGIN + ally["p"]
		var ally_color := Color(0.4, 0.6, 0.9)
		if ally["flash"] > 0.0:
			ally_color = Color.WHITE
		elif ally["state"] == "windup":
			ally_color = Color(0.6, 0.8, 1.0)
		elif ally["state"] == "recover":
			ally_color = Color(0.3, 0.4, 0.6)
		canvas.draw_circle(ap, Balance.ENEMY_RADIUS, ally_color)
		if ally["hp"] < ally["max_hp"]:
			draw_bar(canvas, ap + Vector2(-16, -26), Vector2(32, 4), float(ally["hp"]) / ally["max_hp"], Color(0.4, 0.6, 1.0))

	# latające napisy
	for f in floats:
		var c: Color = f["color"]
		c.a = clampf(f["t"] / 0.4, 0.0, 1.0)
		canvas.draw_string(font, ORIGIN + f["pos"] + Vector2(-12, 0), f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
