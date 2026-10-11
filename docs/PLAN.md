# PLAN GRY (zamrożony)

> Ten plan zmieniamy tylko świadomie. Każdy nowy pomysł trafia do `POMYSLY.md`.

## Pomysł
Wyrzucony z drużyny „słabeusz” osiada w małej wiosce i zakłada własną gildię poszukiwaczy przygód.
W dniu 25. urodzin dostaje **System** (jak w Solo Leveling). Rozbudowuje gildię, sam chodzi do lochów i broni wioski.

- Gatunek: roguelike i budowanie gildii
- Walka: w czasie rzeczywistym (bez tur). Mapa lochu z obecnego kodu zostaje, walkę przerabiamy.
- Budujemy **tylko gildię**, a nie miasto
- Silnik: Godot 4.7, GDScript

## Główna pętla
1. **Gildia**: rekrutacja, zlecenia, kupowanie pokoi i budynków za złoto
2. **Loch**: sam albo z drużyną (obecny `dungeon.gd` i `main.gd`)
3. **Powrót**: doświadczenie idzie w System, materiały w crafting i wielkie dzieła
4. **Wydarzenia**: losowe rozmowy z NPC, burmistrz, ataki potworów na wioskę

## Systemy
- **Walka na żywo**: ruch, atak, unik (dash), 1 lub 2 umiejętności z cooldownem. Wrogowie mają czytelne zapowiedzi ataku.
- **Rozmowy z ukrytym czasem**: każda rozmowa ma limit czasu na odpowiedź, którego gracz nie widzi. Gdy minie, NPC uznaje, że go olewasz, i relacja spada. Czas zależy od charakteru (duże ego = krócej, spokojny = dłużej). Gra nie pauzuje w trakcie rozmowy.
- **System**: statystyki, umiejętności i drzewko rozwoju w jednym oknie. Działa tylko na gracza.
- **Klasy** (na start 2 lub 3):
  - Kowal: 100% craftingu, słabszy w walce
  - Rycerz: mocny w walce, bez magii, podstawowy crafting
  - Mag (opcjonalnie): magia, słaba obrona
- **Wielkie dzieła**: posągi i ołtarze z bonusem dla każdego, kto ich użyje (np. +2% HP po modlitwie). Bardzo drogie i może je robić tylko gracz.
- **Członkowie gildii**: AI pomaga w walce. Kto zginie, znika na zawsze. Każdy ma 1 lub 2 cechy charakteru.
- **Rangi F do S**: dla członków i dla gildii. Odblokowują trudniejsze lochy i lepsze zlecenia.
- **Ataki na wioskę**: duża arena z falami wrogów, co kilka dni.

## Relacje (punkty od -100 do 100)
| Kto | Dobra relacja | Zła relacja |
|---|---|---|
| Burmistrz | zniżki, zlecenia, zgody na budynki | podatki, blokada rozbudowy |
| Członkowie z ego | lojalność, bonusy | odchodzą, kradną, stają się wrogami |
| Losowi przybysze | rzadkie przedmioty, rekruci | zemsta, gorsza reputacja |

## Pokoje gildii (ceny przykładowe)
| Pokój | Koszt | Odblokowuje |
|---|---|---|
| Sala główna | 0 | tablica zleceń, rekrutacja |
| Kuźnia | 150 | crafting |
| Magazyn | 200 | więcej miejsca na materiały |
| Koszary | 250 | więcej członków |
| Lecznica | 300 | leczenie po lochu |
| Kaplica | 800 | wielkie dzieła |

## Fazy
- [x] **Faza 1 (MVP)**: obecny loch z walką przerobioną na czas rzeczywisty, ekran gildii z 2 lub 3 pokojami, złoto i zapis gry, proste okno Systemu, 1 klasa
  - Zrobione: `game_state.gd` (autoload + zapis), `balance.gd`, `guild.tscn`/`guild.gd` (Sala główna, Magazyn, Lecznica), `system_window.gd` (Siła/Wytrzymałość/Zręczność), walka na żywo w `main.gd` (atak, unik, Cięcie wirowe, zapowiedzi ataku wrogów), portal powrotny do gildii. Do przegrania i balansu.
- [ ] **Faza 2 (Członkowie)**: AI w lochu, permadeath, cechy, rangi F do S, tablica zleceń
- [ ] **Faza 3 (Relacje)**: burmistrz, losowe rozmowy z wyborami i ukrytym czasem, bunt członków z ego
- [ ] **Faza 4 (Obrona i dzieła)**: ataki na wioskę, wielkie dzieła, kaplica
- [ ] **Faza 5 (Rozwój)**: 2 lub 3 klasy, pełne drzewko, dawna drużyna jako rywal

Następną fazę zaczynamy dopiero, gdy poprzednia działa i jest grywalna.

## Na razie nie
- Budowanie całego miasta
- Dużo klas naraz
- Realistyczna ekonomia i handel
- Otwarty świat
- Walka turowa

## Architektura (propozycja do fazy 1)
- `game_state.gd` jako autoload: złoto, statystyki gracza, kupione pokoje, dzień. Zapis i odczyt w `user://save.json`.
- `guild.tscn` i `guild.gd`: ekran gildii z kupowaniem pokoi
- `main.tscn` (obecny loch) zostaje. Po wyjściu z lochu złoto trafia do `GameState`, potem wracasz do gildii.
- `balance.gd`: wszystkie ceny i liczby w jednym miejscu
