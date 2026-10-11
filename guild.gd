extends Node2D
# Ekran gildii: kupowanie pokoi, odpoczynek, okno Systemu i wyjście do lochu.

const Balance = preload("res://balance.gd")
const Items = preload("res://items.gd")
const SystemWindow = preload("res://system_window.gd")

const ORIGIN := Vector2(40, 50)

var cursor := 0
var system_open := false
var system_cursor := 0
var confirm_reset := false


func _ready() -> void:
	queue_redraw()


func options() -> Array:
	var list: Array = [{"type": "dungeon", "label": "Wyrusz do lochu"}]
	for room in Balance.ROOMS:
		if not GameState.has_room(room["id"]):
			list.append({"type": "buy", "room": room, "label": "Kup: %s (%d zł) - %s" % [room["name"], room["cost"], room["info"]]})
	list.append({"type": "rest", "label": "Odpocznij za %d zł (nowy dzień, leczenie)" % Balance.REST_COST})
	list.append({"type": "system", "label": "Otwórz okno Systemu (Tab)"})
	list.append({"type": "reset", "label": "Nowa gra (kasuje zapis)"})
	return list


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_TAB:
		system_open = not system_open
		system_cursor = 0
		queue_redraw()
		return
	if system_open:
		system_input(event.keycode)
		return
	var opts := options()
	match event.keycode:
		KEY_UP, KEY_W:
			cursor = (cursor - 1 + opts.size()) % opts.size()
			confirm_reset = false
		KEY_DOWN, KEY_S:
			cursor = (cursor + 1) % opts.size()
			confirm_reset = false
		KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_SPACE:
			choose(opts[cursor])
	cursor = clampi(cursor, 0, options().size() - 1)
	queue_redraw()


func choose(opt: Dictionary) -> void:
	match opt["type"]:
		"dungeon":
			# Od teraz do powrotu portalem lub śmierci trwa wyprawa. Zamknięcie gry w jej trakcie = śmierć.
			GameState.in_run = true
			GameState.save_game()
			get_tree().change_scene_to_file("res://main.tscn")
		"buy":
			var room: Dictionary = opt["room"]
			if GameState.buy_room(room):
				GameState.message = "Kupujesz pokój: %s!" % room["name"]
			else:
				GameState.message = "Brakuje Ci %d zł na: %s." % [room["cost"] - GameState.gold, room["name"]]
		"rest":
			if GameState.hp >= GameState.max_hp():
				GameState.message = "Jesteś w pełni sił - nocleg nie jest potrzebny."
			elif GameState.rest():
				GameState.save_game()
				GameState.message = "Odpoczywasz za %d zł. Dzień %d, HP %d/%d." % [
					Balance.REST_COST, GameState.day, GameState.hp, GameState.max_hp()]
			else:
				GameState.message = "Nocleg kosztuje %d zł, a masz %d zł." % [Balance.REST_COST, GameState.gold]
		"system":
			system_open = true
			system_cursor = 0
		"reset":
			if confirm_reset:
				GameState.delete_save()
				confirm_reset = false
				cursor = 0
			else:
				confirm_reset = true
				GameState.message = "Na pewno? Wybierz jeszcze raz, aby skasować zapis."


func system_input(keycode: int) -> void:
	match keycode:
		KEY_ESCAPE:
			system_open = false
		KEY_UP, KEY_W:
			system_cursor = (system_cursor - 1 + Balance.STATS.size()) % Balance.STATS.size()
		KEY_DOWN, KEY_S:
			system_cursor = (system_cursor + 1) % Balance.STATS.size()
		KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_SPACE:
			var stat: String = Balance.STATS[system_cursor]
			if GameState.spend_point(stat):
				GameState.save_game()
	queue_redraw()


# ---------- rysowanie ----------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.08, 0.1))

	draw_string(font, ORIGIN, "GILDIA \"Odrzuceni\"", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.95, 0.8, 0.35))
	draw_string(font, ORIGIN + Vector2(0, 36), "Dzień %d     Złoto: %d zł     HP: %d/%d     Poziom %d (%s)     Rekord: piętro %d" % [
		GameState.day, GameState.gold, GameState.hp, GameState.max_hp(), GameState.level, Balance.PLAYER_CLASS, GameState.best_floor],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

	# pokoje gildii
	var y := ORIGIN.y + 90
	draw_string(font, Vector2(ORIGIN.x, y), "Pokoje", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.7, 0.75))
	var x := ORIGIN.x
	for room in Balance.ROOMS:
		var owned: bool = GameState.has_room(room["id"])
		var box := Rect2(Vector2(x, y + 14), Vector2(220, 70))
		draw_rect(box, Color(0.22, 0.18, 0.12) if owned else Color(0.13, 0.13, 0.15))
		draw_rect(box, Color(0.95, 0.8, 0.35) if owned else Color(0.3, 0.3, 0.35), false, 2.0)
		draw_string(font, box.position + Vector2(12, 26), room["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color.WHITE if owned else Color(0.55, 0.55, 0.6))
		var status: String = "posiadany" if owned else "%d zł" % room["cost"]
		draw_string(font, box.position + Vector2(12, 52), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.6, 0.85, 0.5) if owned else Color(0.8, 0.6, 0.3))
		x += 236

	# menu
	y += 130
	draw_string(font, Vector2(ORIGIN.x, y), "Co robisz?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.7, 0.75))
	var opts := options()
	for i in opts.size():
		var selected := i == cursor
		var line_y := y + 32 + i * 30
		if selected:
			draw_rect(Rect2(Vector2(ORIGIN.x - 8, line_y - 21), Vector2(820, 28)), Color(0.25, 0.2, 0.1))
		draw_string(font, Vector2(ORIGIN.x, line_y), ("> " if selected else "   ") + opts[i]["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.95, 0.8, 0.35) if selected else Color(0.85, 0.85, 0.85))

	# ekwipunek
	var eq_y := y + 52 + opts.size() * 30
	draw_string(font, Vector2(ORIGIN.x, eq_y), "Broń: %s     Zbroja: %s     Plecak: %d szt." % [
		Items.describe(GameState.inv.weapon), Items.describe(GameState.inv.armor), GameState.inv.pack.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.7, 0.75))

	draw_string(font, Vector2(ORIGIN.x, eq_y + 40), GameState.message, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.9, 0.9, 0.6))
	if GameState.stat_points > 0:
		draw_string(font, Vector2(ORIGIN.x, eq_y + 68), "[SYSTEM] Masz %d punktów do rozdania - naciśnij Tab." % GameState.stat_points,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.75, 1.0))
	draw_string(font, Vector2(ORIGIN.x, size.y - 24), "W/S: wybór   Enter/E: zatwierdź   Tab: System",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.5, 0.55))

	if system_open:
		SystemWindow.draw_window(self, font, Rect2(Vector2(160, 70), Vector2(620, 420)), system_cursor)
