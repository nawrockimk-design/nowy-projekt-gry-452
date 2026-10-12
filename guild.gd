extends Node2D
# Ekran gildii: kupowanie pokoi, odpoczynek, okno Systemu i wyjście do lochu.

const Balance = preload("res://balance.gd")
const Items = preload("res://items.gd")
const SystemWindow = preload("res://system_window.gd")
const MembersWindow = preload("res://members_window.gd")
const QuestsWindow = preload("res://quests_window.gd")
const Members = preload("res://members.gd")

var member_system = Members.new()

const GOLD := Color(0.95, 0.8, 0.35)

const ORIGIN := Vector2(40, 50)

var cursor := 0
var system_open := false
var system_cursor := 0
var confirm_reset := false
var members_open := false
var members_cursor := 0
var members_page := 0
var quests_open := false
var quests_cursor := 0
var intro_page := 0
var class_cursor := 0

const INTRO_PAGES := [
	[
		"Od dwunastego roku życia próbujesz znaleźć miejsce w drużynie.",
		"Znana drużyna Cedrica Vane'a przyjmuje Cię jako maskotkę,",
		"lecz po zdobyciu sławy zastępuje Cię silniejszym członkiem."
	],
	[
		"Po wyrzuceniu z drużyny trafiasz do Dębowej Doliny.",
		"Emerytowany mistrz gildii Edrian Voss uczy Cię walki",
		"i przetrwania przez około półtora roku."
	],
	[
		"Dzień przed Twoimi osiemnastymi urodzinami Edrian umiera.",
		"We śnie spotykasz jego duszę w Aetherionie. Opowiada Ci",
		"o bogach i Systemie. W dniu osiemnastych urodzin",
		"zaczyna się właściwa rozgrywka."
	]
]


func _ready() -> void:
	queue_redraw()


func options() -> Array:
	var list: Array = [{"type": "dungeon", "label": "Wyrusz do lochu"}]
	for room in Balance.ROOMS:
		if not GameState.has_room(room["id"]):
			list.append({"type": "buy", "room": room, "label": "Kup: %s (%d zł) - %s" % [room["name"], room["cost"], room["info"]]})
	list.append({"type": "rest", "label": "Odpocznij za %d zł (nowy dzień, leczenie)" % Balance.REST_COST})
	list.append({"type": "members", "label": "Zarządzaj członkami (M)"})
	list.append({"type": "quests", "label": "Tablica zleceń (Q)"})
	if not GameState.active_quest.is_empty() and GameState.active_quest.get("completed", false):
		list.append({"type": "claim", "label": "Odbierz nagrodę za zlecenie"})
	list.append({"type": "system", "label": "Otwórz okno Systemu (Tab)"})
	list.append({"type": "reset", "label": "Nowa gra (kasuje zapis)"})
	return list


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if GameState.player_class.is_empty():
		onboarding_input(event.keycode)
		return
	if event.keycode == KEY_TAB:
		system_open = not system_open
		system_cursor = 0
		members_open = false
		quests_open = false
		queue_redraw()
		return
	if event.keycode == KEY_M:
		members_open = not members_open
		members_cursor = 0
		members_page = 0
		system_open = false
		quests_open = false
		queue_redraw()
		return
	if event.keycode == KEY_Q:
		quests_open = not quests_open
		quests_cursor = 0
		system_open = false
		members_open = false
		queue_redraw()
		return
	if system_open:
		system_input(event.keycode)
		return
	if members_open:
		members_input(event.keycode)
		return
	if quests_open:
		quests_input(event.keycode)
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


func onboarding_input(keycode: int) -> void:
	if not GameState.intro_complete:
		if keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_SPACE]:
			intro_page += 1
			if intro_page >= INTRO_PAGES.size():
				GameState.intro_complete = true
	else:
		match keycode:
			KEY_UP, KEY_W:
				class_cursor = (class_cursor - 1 + Balance.PLAYER_CLASSES.size()) % Balance.PLAYER_CLASSES.size()
			KEY_DOWN, KEY_S:
				class_cursor = (class_cursor + 1) % Balance.PLAYER_CLASSES.size()
			KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_SPACE:
				GameState.player_class = Balance.PLAYER_CLASSES[class_cursor]
				GameState.message = "Wybrana klasa: %s. Jej umiejętności można rozwinąć później." % GameState.player_class
				GameState.save_game()
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
		"members":
			members_open = true
			members_cursor = 0
			members_page = 0
		"quests":
			quests_open = true
			quests_cursor = 0
		"claim":
			var old_rank: String = GameState.guild_rank
			var reward := GameState.complete_quest()
			GameState.message = "Odbierasz nagrodę: %d zł!" % reward
			if GameState.guild_rank != old_rank:
				GameState.message += " Ranga gildii wzrasta: %s → %s." % [
					old_rank, GameState.guild_rank]
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


func members_input(keycode: int) -> void:
	var members_list: Array = GameState.members
	match keycode:
		KEY_ESCAPE:
			members_open = false
		KEY_UP, KEY_W:
			members_cursor = maxi(members_cursor - 1, 0)
		KEY_DOWN, KEY_S:
			if not members_list.is_empty():
				members_cursor = mini(members_cursor + 1, members_list.size() - 1)
		KEY_PAGEUP:
			members_cursor = maxi(members_cursor - 6, 0)
		KEY_PAGEDOWN:
			if not members_list.is_empty():
				members_cursor = mini(members_cursor + 6, members_list.size() - 1)
		KEY_R:
			# rekrutacja
			var new_member: Dictionary = member_system.generate_member(GameState.best_floor + 1)
			if GameState.recruit_member(new_member):
				GameState.message = "Rekrutujesz: %s!" % new_member["name"]
			else:
				GameState.message = "Brakuje %d zł na rekrutację." % (new_member["cost"] - GameState.gold)
		KEY_P:
			# dodaj/usuń z drużyny
			if members_cursor < members_list.size():
				var m: Dictionary = members_list[members_cursor]
				if not m.get("alive", true):
					GameState.message = "Nie możesz dodać poległego członka do drużyny."
				elif m.get("in_party", false):
					m["in_party"] = false
					GameState.message = "%s opuszcza drużynę." % m["name"]
					GameState.save_game()
				else:
					var current_party := GameState.get_party_members()
					if current_party.size() >= GameState.max_party_size():
						GameState.message = "Drużyna pełna! Maksimum: %d." % GameState.max_party_size()
					else:
						m["in_party"] = true
						GameState.message = "%s dołącza do drużyny." % m["name"]
						GameState.save_game()
		KEY_X:
			# zwolnij
			if members_cursor < members_list.size():
				var m: Dictionary = members_list[members_cursor]
				if m.get("in_party", false):
					GameState.message = "Najpierw usuń %s z drużyny (P)." % m["name"]
				else:
					var member_name: String = m["name"]
					GameState.remove_member(m["id"])
					GameState.message = "Zwalniasz: %s." % member_name
					members_cursor = clampi(members_cursor, 0, maxi(members_list.size() - 1, 0))
	members_cursor = clampi(members_cursor, 0, maxi(members_list.size() - 1, 0))
	members_page = floori(members_cursor / 6.0)
	queue_redraw()


func quests_input(keycode: int) -> void:
	var quests := GameState.quests
	match keycode:
		KEY_ESCAPE:
			quests_open = false
		KEY_UP, KEY_W:
			if quests_cursor > 0:
				quests_cursor -= 1
		KEY_DOWN, KEY_S:
			if quests_cursor < quests.size() - 1:
				quests_cursor += 1
		KEY_ENTER, KEY_KP_ENTER, KEY_E:
			if quests_cursor < quests.size():
				var q: Dictionary = quests[quests_cursor]
				if GameState.accept_quest(q["id"]):
					GameState.message = "Przyjmujesz zlecenie."
				else:
					GameState.message = "Masz już aktywne zlecenie. Ukończ je najpierw."
	queue_redraw()


# ---------- rysowanie ----------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.08, 0.1))

	if GameState.player_class.is_empty():
		draw_onboarding(font, size)
		return

	draw_string(font, ORIGIN, "GILDIA \"Odrzuceni\"", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.95, 0.8, 0.35))
	draw_string(font, ORIGIN + Vector2(0, 36), "Dzień %d     Złoto: %d zł     HP: %d/%d     Poziom %d (%s)     Rekord: piętro %d" % [
		GameState.day, GameState.gold, GameState.hp, GameState.max_hp(), GameState.level, GameState.player_class, GameState.best_floor],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(font, ORIGIN + Vector2(0, 60), "Ranga gildii: %s (%s)     XP: %d/%s" % [
		GameState.guild_rank, Balance.RANK_NAMES.get(GameState.guild_rank, "?"), GameState.guild_xp,
		str(GameState.guild_xp_to_next()) if GameState.guild_xp_to_next() < 999999 else "MAX"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.75, 0.75, 0.8))

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
	draw_string(font, Vector2(ORIGIN.x, size.y - 24), "W/S: wybór   Enter/E: zatwierdź   Tab: System   M: Członkowie   Q: Zlecenia",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.5, 0.55))

	if system_open:
		SystemWindow.draw_window(self, font, Rect2(Vector2(160, 70), Vector2(620, 420)), system_cursor)
	
	if members_open:
		MembersWindow.draw_window(self, font, Rect2(Vector2(160, 70), Vector2(620, 450)), members_cursor, members_page)
	
	if quests_open:
		QuestsWindow.draw_window(self, font, Rect2(Vector2(160, 70), Vector2(620, 400)), quests_cursor)


func draw_onboarding(font: Font, size: Vector2) -> void:
	var panel_size := Vector2(minf(760.0, size.x - 32.0), minf(440.0, size.y - 32.0))
	var panel := Rect2((size - panel_size) * 0.5, panel_size)
	draw_rect(panel, Color(0.02, 0.05, 0.1, 0.98))
	draw_rect(panel, Color(0.95, 0.8, 0.35), false, 2.0)
	var x := panel.position.x + 28.0
	var y := panel.position.y + 48.0

	if not GameState.intro_complete:
		draw_string(font, Vector2(x, y), "WPROWADZENIE", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(0.95, 0.8, 0.35))
		y += 62.0
		for line in INTRO_PAGES[intro_page]:
			draw_string(font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.92))
			y += 34.0
		draw_string(font, Vector2(x, panel.end.y - 28.0), "Enter/E/Spacja: dalej (%d/%d)" % [
			intro_page + 1, INTRO_PAGES.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.65, 0.72))
		return

	draw_string(font, Vector2(x, y), "WYBIERZ KLASĘ", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(0.95, 0.8, 0.35))
	y += 34.0
	draw_string(font, Vector2(x, y), "Na razie wybór zapisuje klasę; unikalne umiejętności nie są jeszcze dodane.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.65, 0.7, 0.78))
	y += 36.0
	for i in Balance.PLAYER_CLASSES.size():
		var column := floori(i / 4.0)
		var row := i % 4
		var item_pos := Vector2(x + column * 300.0, y + row * 42.0)
		if i == class_cursor:
			draw_rect(Rect2(item_pos - Vector2(10.0, 22.0), Vector2(270.0, 34.0)), Color(0.25, 0.2, 0.1))
		draw_string(font, item_pos, ("> " if i == class_cursor else "  ") + Balance.PLAYER_CLASSES[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.95, 0.8, 0.35) if i == class_cursor else Color.WHITE)
	draw_string(font, Vector2(x, panel.end.y - 28.0), "W/S: wybór   Enter/E: zatwierdź",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.65, 0.72))
