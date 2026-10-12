extends RefCounted
# Wszystkie ceny i liczby gry w jednym miejscu. Tu się balansuje.

# ---------- wybór klasy gracza ----------
const PLAYER_CLASSES := ["Wojownik", "Rycerz", "Mag", "Kapłan", "Łowca", "Inżynier", "Kowal", "Alchemik"]
const BASE_HP := 10
const HP_PER_VIT := 3
const HP_PER_LEVEL := 2
const BASE_SPEED := 210.0
const SPEED_PER_AGI := 10.0
const PLAYER_RADIUS := 14.0
const HIT_INVULN := 0.5             # nietykalność po otrzymaniu ciosu (s)

# atak podstawowy
const ATTACK_RANGE := 50.0
const ATTACK_ARC_DOT := 0.25         # im mniej, tym szerszy łuk ciosu
const ATTACK_COOLDOWN := 0.35
const ATTACK_MIN_DMG := 1
const ATTACK_MAX_DMG := 3
const KNOCKBACK := 22.0

# unik (dash)
const DASH_SPEED := 640.0
const DASH_TIME := 0.15
const DASH_COOLDOWN := 0.9
const DASH_CD_PER_AGI := 0.05
const DASH_MIN_COOLDOWN := 0.4

# umiejętność: Cięcie wirowe
const SKILL_NAME := "Cięcie wirowe"
const SKILL_COOLDOWN := 5.0
const SKILL_RADIUS := 85.0
const SKILL_DMG_MULT := 2

# ---------- System (rozwój) ----------
const XP_PER_LEVEL := 10             # próg = XP_PER_LEVEL * poziom
const POINTS_PER_LEVEL := 2
const STATS := ["str", "vit", "agi"]
const STAT_NAMES := {"str": "Siła", "vit": "Wytrzymałość", "agi": "Zręczność"}
const STAT_INFO := {
	"str": "+1 obrażeń każdego ciosu",
	"vit": "+3 maks. HP",
	"agi": "szybszy ruch i krótszy cooldown uniku",
}

# ---------- wrogowie ----------
const ENEMY_RADIUS := 14.0
const ENEMY_BASE_SPEED := 85.0
const ENEMY_SPEED_PER_FLOOR := 6.0
const ENEMY_BASE_HP := 3
const ENEMY_HP_PER_FLOOR := 2
const ENEMY_ATTACK_RANGE := 38.0     # z jakiej odległości zaczyna zamach
const ENEMY_HIT_RANGE := 50.0        # zasięg ciosu po zamachu
const ENEMY_WINDUP := 0.6            # czytelna zapowiedź ataku (s)
const ENEMY_RECOVER := 0.7
const ENEMY_BASE_DMG := 2

# ---------- nagrody ----------
const GOLD_MIN := 3
const GOLD_MAX := 6
const GOLD_PER_FLOOR := 2
const XP_BASE := 2
const XP_PER_FLOOR := 1

# ---------- gildia ----------
const BASE_WEIGHT := 20
const REST_HEAL_PCT := 0.3           # leczenie za dzień bez lecznicy (nocleg i powrót z lochu)
const REST_COST := 10                # cena noclegu w gildii (zł); powrót z lochu jest darmowy
const DEATH_HP_PCT := 0.3
const STORAGE_WEIGHT_BONUS := 10

# ---------- loch: leczenie i dropy ----------
const NEXT_FLOOR_HEAL := 3           # leczenie przy zejściu piętro niżej
const POTION_HEAL := 4
const DROP_POTION_CHANCE := 0.25     # z zabitego wroga
const DROP_ITEM_CHANCE := 0.15       # z zabitego wroga
const FLOOR_POTION_CHANCE := 0.4     # mikstura leżąca w pokoju
const FLOOR_ITEM_CHANCE := 0.35      # broń lub zbroja leżąca w pokoju
const ENEMY_SEPARATION := 60.0       # odpychanie wrogów od siebie (px/s)

const SAVE_VERSION := 1

# true: zamknięcie gry w trakcie wyprawy liczy się jak śmierć (utrata plecaka).
# Na czas testów w edytorze Godot (F8 zatrzymuje grę) ustaw false.
const QUIT_IN_RUN_IS_DEATH := true

const ROOMS := [
	{"id": "hall", "name": "Sala główna", "cost": 0, "info": "Serce gildii. Tablica zleceń i rekrutacja."},
	{"id": "storage", "name": "Magazyn", "cost": 200, "info": "+10 udźwigu w lochu."},
	{"id": "infirmary", "name": "Lecznica", "cost": 300, "info": "Pełne leczenie po każdym dniu."},
	{"id": "barracks", "name": "Koszary", "cost": 250, "info": "Możesz zabrać do lochu do 3 członków gildii."},
]

# ---------- członkowie gildii ----------
const GUILD_RANK_XP := [0, 500, 1500, 3500, 7000, 12000, 20000]  # próg XP dla rang F-S
const GUILD_XP_PER_QUEST := 100
const MEMBER_RANK_XP := [0, 20, 60, 120, 200, 320, 500]
const MEMBER_XP_PER_FLOOR := 10
const MEMBER_ATTACK_PER_RANK := 1
const MEMBER_HP_PER_RANK := 2
const MAX_PARTY_SIZE := 3  # maksymalna liczba członków gildii w drużynie z Koszarami

# ---------- zlecenia ----------
const QUEST_TYPES := ["hunt", "gather"]
const QUEST_REWARDS := [30, 50, 80, 120, 200]  # złoto za zlecenia różnych rang

# ---------- rangi (używane przez członków i zlecenia) ----------
const RANKS := ["F", "E", "D", "C", "B", "A", "S"]
const RANK_NAMES := {
	"F": "Nowicjusz",
	"E": "Początkujący",
	"D": "Średni",
	"C": "Zaawansowany",
	"B": "Ekspert",
	"A": "Mistrz",
	"S": "Legenda"
}
