# Poprawki po Fazie 1

Pliki z tego folderu podmieniasz w projekcie (`main.gd`, `dungeon.gd`, `game_state.gd`, `guild.gd`, `balance.gd`).
Ten plik możesz wrzucić do `docs/`. `PLAN.md` zostaje bez zmian.

## Co zmieniono
1. **Plecak (I)**: `main.gd` odświeża ekran od razu po otwarciu. Wcześniej panel mógł się nie pokazać do następnego klawisza.
2. **Schody**: nie zjeżdżają już same. Stań na środku pokoju ze schodami po oczyszczeniu i naciśnij **F** (ten sam klawisz co portal).
3. **Zamknięcie gry w lochu**: liczy się jak śmierć (utrata plecaka). Zapis ma flagę `in_run`. Stała `QUIT_IN_RUN_IS_DEATH` w `balance.gd` wyłącza to na czas testów w edytorze.
4. **Odpoczynek**: nocleg w gildii kosztuje `REST_COST` (10 zł) i nie działa przy pełnym HP. Powrót z lochu portalem leczy za darmo, jak wcześniej. Dzięki temu Lecznica ma sens.
5. **Porządki**: usunięte nieużywane pole `aim` wrogów, nieużywane `hp` wrogów w `dungeon.gd` i martwe doliczanie HP w `GameState.add_xp`.

## Nie zmieniono (do sprawdzenia w grze)
- Balans zbroi: przy obronie 2 lub więcej wrogowie na początkowych piętrach zadają zawsze 1 obrażeń.
- Wrogowie rosną w obrażenia o 1 na 3 piętra, a zbroja daje do 3 obrony.

## Lista kontrolna testu (około 15 minut)
- [ ] I otwiera plecak od razu. E zakłada lub używa, X wyrzuca, I zamyka.
- [ ] Przejście przez środek pokoju ze schodami nic nie robi. F na schodach schodzi piętro niżej.
- [ ] F na niebieskim kręgu wraca do gildii. Złoto z wyprawy trafia do skarbca.
- [ ] Zamknij grę w lochu i uruchom ponownie: plecak pusty, komunikat o urwanej wyprawie.
- [ ] Nocleg: pełne HP = komunikat, brak złota = komunikat, inaczej -10 zł i leczenie.
- [ ] Czy pierwsze piętro jest za łatwe albo za trudne? Daj znać, zmienię liczby w `balance.gd`.
