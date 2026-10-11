extends RefCounted
# Okno Systemu (jak w Solo Leveling): statystyki i rozdawanie punktów. Działa tylko na gracza.

const Balance = preload("res://balance.gd")

const BLUE := Color(0.4, 0.75, 1.0)


static func draw_window(canvas: CanvasItem, font: Font, panel: Rect2, cursor: int) -> void:
	canvas.draw_rect(panel, Color(0.02, 0.05, 0.1, 0.95))
	canvas.draw_rect(panel, BLUE, false, 2.0)
	var x := panel.position.x + 24
	var y := panel.position.y + 40
	canvas.draw_string(font, Vector2(x, y), "[ SYSTEM ]", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, BLUE)

	y += 40
	canvas.draw_string(font, Vector2(x, y), "Klasa: %s     Poziom: %d     XP: %d/%d" % [
		Balance.PLAYER_CLASS, GameState.level, GameState.xp, GameState.xp_to_next()], HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	y += 26
	canvas.draw_string(font, Vector2(x, y), "HP: %d/%d     Atak: +%d     Prędkość: %d     Unik co %.2fs" % [
		GameState.hp, GameState.max_hp(), GameState.attack_bonus(), GameState.move_speed(), GameState.dash_cooldown()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.8, 0.85))
	y += 34
	canvas.draw_string(font, Vector2(x, y), "Punkty do rozdania: %d" % GameState.stat_points, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color(0.95, 0.8, 0.35) if GameState.stat_points > 0 else Color(0.6, 0.6, 0.65))

	y += 20
	for i in Balance.STATS.size():
		var stat: String = Balance.STATS[i]
		var selected := i == cursor
		var row_y := y + 30 + i * 52
		if selected:
			canvas.draw_rect(Rect2(Vector2(x - 8, row_y - 22), Vector2(panel.size.x - 32, 46)), Color(0.08, 0.18, 0.3))
		canvas.draw_string(font, Vector2(x, row_y), ("> " if selected else "   ") + "%s: %d" % [Balance.STAT_NAMES[stat], GameState.stats[stat]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, BLUE if selected else Color.WHITE)
		canvas.draw_string(font, Vector2(x + 20, row_y + 18), Balance.STAT_INFO[stat], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.65, 0.75))

	canvas.draw_string(font, Vector2(x, panel.end.y - 20), "W/S: wybór   E/Enter: dodaj punkt   Tab/Esc: zamknij",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.6, 0.7))
