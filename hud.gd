extends RefCounted
# Interfejs lochu: paski i podpowiedzi, mapa piętra, plecak.
# Dane bierze z węzła main.gd (parametr m), niczego nie zmienia.

const Items = preload("res://items.gd")
const Dungeon = preload("res://dungeon.gd")
const Balance = preload("res://balance.gd")
const RoomView = preload("res://room_view.gd")


static func draw_hud(canvas: CanvasItem, m, font: Font) -> void:
	var origin: Vector2 = RoomView.ORIGIN
	var hud_y: float = origin.y + Dungeon.ROOM_H * RoomView.TILE + 20
	var player_hp: int = m.player_hp
	var floor_num: int = m.floor_num
	var run_gold: int = m.run_gold
	var dash_cd: float = m.dash_cd
	var skill_cd: float = m.skill_cd
	var log_timer: float = m.log_timer
	var log_text: String = m.log_text
	var inv = m.inv

	var max_hp: int = GameState.max_hp()
	RoomView.draw_bar(canvas, Vector2(origin.x, hud_y), Vector2(220, 16), float(player_hp) / max_hp, Color(0.8, 0.2, 0.25))
	canvas.draw_string(font, Vector2(origin.x + 6, hud_y + 13), "HP %d/%d" % [player_hp, max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	RoomView.draw_bar(canvas, Vector2(origin.x, hud_y + 20), Vector2(220, 6), float(GameState.xp) / GameState.xp_to_next(), Color(0.4, 0.75, 1.0))

	canvas.draw_string(font, Vector2(origin.x + 240, hud_y + 14), "Piętro %d   Poz. %d   Złoto z wyprawy: %d zł   Udźwig %d/%d" % [
		floor_num, GameState.level, run_gold, inv.total_weight(), inv.max_weight], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)

	var dash_ready := dash_cd <= 0.0
	var skill_ready := skill_cd <= 0.0
	canvas.draw_string(font, Vector2(origin.x, hud_y + 50), "Unik [Shift]: %s" % ("gotowy" if dash_ready else "%.1fs" % dash_cd),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.9, 0.6) if dash_ready else Color(0.6, 0.6, 0.6))
	canvas.draw_string(font, Vector2(origin.x + 200, hud_y + 50), "%s [K]: %s" % [Balance.SKILL_NAME, "gotowe" if skill_ready else "%.1fs" % skill_cd],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.5, 0.8, 1.0) if skill_ready else Color(0.6, 0.6, 0.6))
	if m.on_portal():
		canvas.draw_string(font, Vector2(origin.x + 460, hud_y + 50), "F: wróć do gildii z łupem",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.45, 0.7, 1.0))
	elif m.on_stairs():
		canvas.draw_string(font, Vector2(origin.x + 460, hud_y + 50), "F: zejdź piętro niżej",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.4, 0.85, 0.5))

	if log_timer > 0.0:
		canvas.draw_string(font, Vector2(origin.x, hud_y + 76), log_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)


static func draw_minimap(canvas: CanvasItem, m, font: Font) -> void:
	var dungeon = m.dungeon
	var inv = m.inv
	var mini_origin: Vector2 = RoomView.MINI_ORIGIN

	canvas.draw_string(font, mini_origin + Vector2(0, -12), "Mapa piętra", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
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
		canvas.draw_rect(Rect2(mini_origin + Vector2(cell.x * 34, cell.y * 26), Vector2(30, 22)), col)

	canvas.draw_string(font, mini_origin + Vector2(0, 160), "Czerwone drzwi: pokonaj wrogów", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	canvas.draw_string(font, mini_origin + Vector2(0, 182), "Pomarańczowy wróg: zaraz uderzy - uciekaj!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	canvas.draw_string(font, mini_origin + Vector2(0, 204), "Zielone pole >: schody w dół (F)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	canvas.draw_string(font, mini_origin + Vector2(0, 226), "Niebieski krąg: portal do gildii (F)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

	canvas.draw_string(font, mini_origin + Vector2(0, 272), "Założone (I = plecak)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	canvas.draw_string(font, mini_origin + Vector2(0, 296), "Broń: %s" % Items.describe(inv.weapon), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	canvas.draw_string(font, mini_origin + Vector2(0, 318), "Zbroja: %s" % Items.describe(inv.armor), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	canvas.draw_string(font, mini_origin + Vector2(0, 340), "W plecaku: %d szt." % inv.pack.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	canvas.draw_string(font, mini_origin + Vector2(0, 372), "Śmierć = utrata złota z wyprawy i plecaka.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.5, 0.5))


static func draw_inventory(canvas: CanvasItem, m, font: Font) -> void:
	var inv = m.inv
	var inv_cursor: int = m.inv_cursor
	var panel := Rect2(RoomView.ORIGIN + Vector2(60, 24), Vector2(600, 384))
	canvas.draw_rect(panel, Color(0, 0, 0, 0.92))
	canvas.draw_rect(panel, Color(0.5, 0.5, 0.55), false, 2.0)
	var x := panel.position.x + 20
	var y := panel.position.y + 34
	canvas.draw_string(font, Vector2(x, y), "Plecak (pauza)     Udźwig: %d/%d" % [inv.total_weight(), inv.max_weight], HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	var n: int = inv.pack.size()
	if n == 0:
		canvas.draw_string(font, Vector2(x, y + 40), "Plecak jest pusty.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var first: int = clampi(inv_cursor - 4, 0, maxi(n - 9, 0))
	for row in mini(9, n - first):
		var i: int = first + row
		var item: Dictionary = inv.pack[i]
		var line_y := y + 36 + row * 26
		var prefix := "> " if i == inv_cursor else "   "
		canvas.draw_string(font, Vector2(x, line_y), prefix + Items.describe(item), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Items.color_of(item))
	canvas.draw_string(font, Vector2(x, panel.end.y - 16), "W/S lub strzałki: wybór   E: użyj/załóż   X: wyrzuć   I: zamknij", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
