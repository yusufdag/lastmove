# Last Move

A small, grid based **escape survival** game built with **Flutter + Flame**.

You are a token in a hostile arena. Every turn you may step one cell orthogonally
or wait. Cells turn amber one turn before they explode, and the whole point of the
game is this:

> **every move you make changes what the next few turns look like.**

Each level is a short, self contained puzzle with one clear goal:

```
survive the level's turn count
        ↓
LAST MOVE!  - the exit opens
        ↓
step onto the exit
        ↓
LEVEL COMPLETE  →  a harder level
```

There is no last level. Levels are generated from their number, so level 3 and
level 300 come out of the same code. The hazards are not simply chasing you: the
generator reads *where you are* and *which way you have been drifting over your
last few moves*, then decides where the next strikes land. Lead with your movement
and you end up fighting the board; double back and the board changes shape.

The feeling the whole prototype is built around is:

> "I should have gone the other way in the previous turn."

**This is a prototype.** It exists to answer one question: *is this mechanic fun
enough that I want to play it again?* There is no monetisation, no backend, no
accounts and no ads.

---

## Build facts

| | |
|---|---|
| Flutter | 3.35.4 (stable channel) |
| Dart | 3.9.2 (`sdk: ^3.9.2`) |
| Flame | `flame: ^1.35.1` (resolved 1.35.1) |
| SharedPreferences | `shared_preferences: ^2.5.5` (resolved 2.5.5) — used **only** for best score + best level |
| Android `compileSdk` | 36 |
| Android `targetSdk` | 36 (current Google Play requirement) |
| Android `minSdk` | 24 |
| Android `applicationId` | `com.nermalav.lastmove` (placeholder — see below) |
| Android NDK | Flutter default (`27.0.12077973`) |
| Orientation | portrait on phones; fully responsive so a desktop window can be any shape |

`flame 1.35.1` is the newest Flame that resolves against this Flutter SDK; newer
Flame releases already require a newer Flutter.

---

## Quick start

```bash
flutter pub get
dart format .
flutter analyze
flutter test
```

### Windows desktop

```bash
flutter run -d windows
# or, for a debug build:
flutter build windows --debug
# -> build\windows\x64\runner\Debug\last_move.exe
```

### Android emulator or device

```bash
flutter devices               # find your device id
flutter run -d <device-id>

# sanity check the Android toolchain:
flutter build apk --debug
# -> build\app\outputs\flutter-apk\app-debug.apk
```

---

## Controls

| Action | Desktop | Touch / mouse |
|---|---|---|
| Move up | `W` or `↑` | ▲ on the pad |
| Move down | `S` or `↓` | ▼ on the pad |
| Move left | `A` or `←` | ◀ on the pad |
| Move right | `D` or `→` | ▶ on the pad |
| Wait one turn | `Space` | **WAIT** button |
| Pause / resume | `Esc` or the ⏸ button in the HUD | ⏸ button |
| Restart | `R` | **RESTART** in the pause menu |
| Android back button | — | opens the pause menu first, never exits straight away |

The touch pad is visible on desktop too, so there is one control solution to test
everywhere. Movement into a wall or a sliding wall is simply refused: it costs no
turn (use **WAIT** when you actually want to spend the turn).

---

## The level loop

A run is one continuous chain of levels. Finishing a level **keeps the score and
the turn count** and rebuilds the arena for the next, harder one; only death (or
TRY AGAIN) ends the run.

### 1. Survive

Each level asks the player to survive a fixed number of turns. The HUD shows the
countdown (`EXIT IN  5`), so the goal is always visible:

> "a few more turns and the exit opens."

The first two turns of every level are always quiet, so a new level never opens by
killing the player outright.

### 2. LAST MOVE! - the exit opens

The moment the requirement is met the game calls out **LAST MOVE!** and a green
pulsing portal appears on the board. Its placement is not decorative:

* it is only ever placed on a cell the player **can actually walk to right now**,
  proven with a breadth first search over the 4-neighbourhood;
* never inside the part of the arena that the arena shrink will swallow;
* never on a cell that is currently lethal, telegraphed, walled or occupied;
* at least `exitMinDistance` steps away, and further away as levels go on;
* chosen with a weighted roll that peaks near the level's preferred distance, so it
  wanders instead of always landing in the same corner.

**The exit cell is sacred ground.** Hazards never target it, sliding walls never
park on it and the shrink never reaches it, so the goal can never be taken away
from the player.

### 3. Step onto it - that is the "last move"

Walking into the exit *is* the level's last move. It completes the level
immediately: no hazard, sliding wall or shrinking ring gets to resolve that turn.
Because the exit is never under the player's feet when it opens, the finishing move
is always a real move.

`LEVEL COMPLETE` appears for about a second (input locked), then the next level
starts. The transition is deliberately short - the loop should feel like "one more
level", not a results screen.

### 4. And again, but harder

Starting a level clears the previous one completely - hazards, warnings, sliding
walls, static walls and the shrink level - and builds the next one from its level
number.

---

## Level generation

`LevelSystem.configFor(level)` turns a level number into a `LevelConfig`. Nothing is
hand authored and nothing is random per attempt: the same level number always
produces the same configuration, so runs are reproducible and testable.

| Knob | How it scales |
|---|---|
| Grid | 7×7, 8×8 or 9×9 (cycles; never bigger, so tiles stay readable on a phone) |
| Survival turns | levels 1-3: 8 / 10 / 12, then `12 + (level-3)*3/2`, capped at **28** |
| Static walls | 0 at level 1, then slowly up, capped by arena area |
| Telegraph chance | 35% at level 1, rising to 100% by level ~15 |
| Telegraphs per turn | 1 → 2 from level 5 → 3 from level 15 |
| Warning length | 3 turns for levels 1-2, then 2, with a growing chance of a fast 1-turn warning from level 7 |
| Simultaneous hazards | `1 + level/3`, capped at 6 |
| Sliding walls | none before level 4, then 1 → 2 → 3, and faster (period 2) from level 12 |
| Arena shrink | specific levels only (see modifiers), capped at 1-2 rings |
| Exit distance | `2 + (level-1)/3`, capped at the grid size |

Everything is **stepped and soft capped** rather than exponential, which is what
keeps level 500 readable instead of a wall of fire.

### Level modifiers

To stop levels feeling identical, the number also picks a flavour, shown as a short
subtitle in the level intro card (`LEVEL 7   TIGHT ARENA`):

| Modifier | What changes |
|---|---|
| `NORMAL` | baseline |
| `MOVING WALLS` | +1 sliding wall |
| `TIGHT ARENA` | 9×9 grid, arena shrink enabled, one fewer hazard at a time, no sliding walls |
| `HAZARD RUSH` | +15% telegraph chance, +1 telegraph per turn, no sliding walls |
| `GAUNTLET` | +1 wall, +1 sliding wall |

The first three levels are always plain `NORMAL` so the player can learn the loop.

---

## Board and cell types

An arena of 7×7 to 9×9 (level dependent). Cell size is computed from the space the
HUD and the controls leave free and the board is centred in it - never a fixed pixel
layout - so it stays correct on a phone and on a resized desktop window.

| Cell | Meaning |
|---|---|
| **Safe** | dark navy tile |
| **Warning** (amber, pulsing) | becomes lethal on a later turn. Standing here is still safe *now* |
| **Danger** (red, pulsing) | lethal. If a turn ends with you here, the run ends |
| **Block** (grey) | a wall - you cannot walk into it |
| **Moving block** (steel, with an arrow) | a wall that steps and bounces off obstacles. It never crushes you: it just refuses to move onto your cell |
| **Exit** (green portal, pulsing) | the level goal, open once the survival requirement is met |
| **Shrink warning** (dark orange ring) | the next ring of the arena about to become permanently lethal |
| **Shrink** (dark red ring) | permanently lethal, capped so the arena never closes on the exit |

### Turn order

One action = one turn. The turn system applies the step and then advances the world:

1. the player's move is applied (or the level completes, if it landed on the exit);
2. sliding walls take their step;
3. resolved hazards are cleared away;
4. the arena loses a ring, on levels that ask for it, up to its cap;
5. freshly telegraphed cells are planted - **placement depends on what you just did**;
6. score goes up by 10;
7. survival is checked;
8. the exit opens if the level's turn count is met;
9. the exit's route is re-checked and repaired if a sliding wall sealed it.

Nothing in the game runs on a timer. The Flame update loop only drives rendering and
animation, so gameplay can never be tied to the frame rate.

### The generator steers around you

When a new telegraph is planted, each candidate cell gets a weight:

* cells next to the player are strongly preferred, distance 2-3 mildly so, and the
  player's own cell only slightly - so it *pressures* you instead of mirroring you;
* cells in the direction you have been drifting over your last three moves get a
  further bonus, and cells behind you are damped;
* the roll itself comes from a seeded xorshift stream, so it is random but fully
  reproducible.

Two fairness passes then run:

* **Deadly trap guard** - if the freshly created telegraphs would make an upcoming
  turn an inescapable death (your own cell lethal *and* every escape blocked), the
  newest hazard involved is dropped again.
* **Exit route recovery** - once the exit is open, if sliding walls have sealed the
  route to it, the most recently spawned wall steps aside until a route exists.

Difficulty should come from reading the board, never from an unwinnable position.

---

## Teaching the player

Nothing in the game is explained by trial and error. There are three teaching
surfaces, and none of them holds up play for more than a moment.

### HOW TO PLAY (main menu)

A button under **PLAY** opens a dedicated screen: the goal, MOVE, WAIT, a **tile
legend** and the two Game Over buttons. It is a single vertical scroll, so it
cannot overflow on any phone, and **every legend row renders a real miniature of
the board tile** (`TileSwatch`) using the same `GameColors` and the same shape
language as `ArenaComponent` - the legend physically cannot drift out of sync with
what the player sees in game. It stays reachable forever, however many runs you
have played.

### First run tutorial

The very first time **PLAY** is pressed, five short cards walk through the loop:

| # | Card | Line | Visual |
|---|---|---|---|
| 1 | MOVE | Every move advances one turn. | controls icon |
| 2 | WARNING | Leave warning tiles before they become dangerous. | warning tile |
| 3 | PREVIEW | Check the next turns before you move. | preview icon |
| 4 | LAST MOVE | Survive until the Exit opens. | hourglass icon |
| 5 | EXIT | Reach the Exit to complete the level. | exit tile |

NEXT / SKIP move through them and the last card says START. While it is up the
controller refuses input - the world cannot move underneath the player - but the
status stays `playing`, so no other overlay (pause, game over) gets involved.
Closing it hands over with the level intro card, so the goal is on screen the
instant the walkthrough disappears. Android back skips it.

`hasSeenTutorial` is stored with SharedPreferences. Finishing **or** skipping both
write it, so the walkthrough appears exactly once per device, and the rules screen
stays available for anyone who wants a refresher.

### Contextual nudges

A player who has never been through the tutorial gets **one** extra call-out on
their very first run: the first time a warning appears, the banner says
`WARNING!  Move away before it activates.` Once per run, first run only - a
returning player never sees it. Opening the exit always calls out
`LAST MOVE!` with `Reach the Exit.` beneath it, at every level, so "what do I do
now?" never comes up.

### Game Over

Each button carries a one line caption - `Restart from Level 1` under TRY AGAIN,
`Go back 3 turns` under SECOND CHANCE - so the difference between them is obvious
without turning the panel into an essay.

---

## Score and records

| Event | Points |
|---|---|
| Surviving a turn | **+10** (the finishing move onto the exit counts too) |
| Clearing level `n` | **+100 × n** |

So level 1 alone is worth 80 + 100 = 180, and by level 10 you are banking 1000 for
a clear - finishing a level always feels worth more than a few idle turns, which is
what pushes the player to keep going for the exit instead of hiding.

`BEST SCORE` and `BEST LEVEL` are stored locally with SharedPreferences (the only
thing that package is used for). They are never reset - only the current run is.

---

## Second Chance

When you die, the Game Over panel reports **SCORE**, **LEVEL REACHED**,
**BEST SCORE** and **BEST LEVEL**, and offers **SECOND CHANCE**, **TRY AGAIN** and
**MAIN MENU**.

Second Chance is a real rewind, not a teleport:

* every finished turn pushes a complete `GameSnapshot` - player position, turn,
  score, **level number, level turn and the exit state**, every hazard, warnings,
  static walls, sliding walls, the arena shrink level, the last actions and the exact
  random stream state - into a history buffer of 8 frames;
* pressing Second Chance asks `RewardService` for a reward, then restores the frame
  from **3 turns ago** and truncates the newer frames, because the timeline branches
  from that point;
* **the history is restarted at every level start**, so a rewind can only ever land
  inside the level the player died on - never back in an earlier level;
* the exit state comes back with the snapshot: rewind to a turn after the exit
  opened and it is still open on the same cell; rewind to before it opened and it is
  correctly closed again;
* the restored world continues deterministically - repeat the same mistakes and you
  will die the same way, which is exactly the "learn from your last move" loop.

If the run was too short to have any history the button is hidden and a short note
is shown instead.

**TRY AGAIN** resets the *run*: level 1, score 0, fresh history, level 1's easiest
configuration. Best score and best level are untouched.

### Rewards / ads (deliberately not wired up)

`RewardService.requestSecondChance()` is the seam where
*"watch an ad → continue"* will plug in later. The prototype ships
`MockRewardService`, which returns `true` immediately. **No ad SDK is included** -
swapping in an AdMob backed implementation later needs no changes anywhere else.

---

## Future preview

Above the controls there is a `NEXT  +1  +2  +3` strip. Each card reports
**categories and counts only** - never exact cells:

* `2 DANGER` - that many telegraphs fire on that turn;
* `2 WARN` - that many new warnings appear;
* `WALL MOVE` - a sliding wall steps;
* `SHRINK` / `SHRINK SOON` - the arena loses a ring.

It is a real simulation: the state is cloned, the world is advanced three turns with
the cloned random stream and only aggregates are reported. The clone assumes you
stand still, so the strip *changes the moment you move somewhere else*. Once the exit
is open it stays just as useful - "if I set off towards the exit now, will that cell
be on fire two turns from now?" is exactly the kind of question it answers.

---

## Project structure

```
lib/
  main.dart                     entry point (portrait lock on mobile only)
  app.dart                      MaterialApp + theme
  theme/
    game_colors.dart            every colour in one place
    game_theme.dart             Material theme + shared text styles
  game/
    game_controller.dart        owns the run: level flow, banners, best run, no Flame
    last_move_game.dart         the FlameGame: turns state into pixels
    components/
      board_layout.dart         grid coordinates -> pixels (responsive)
      arena_component.dart      paints the board, hazards, walls and the exit
      player_component.dart     the token + slide/hop animation
    models/
      level_config.dart         LevelConfig + LevelModifier
      game_rules.dart           run wide constants (score, timings)
      game_state.dart           the mutable world (plain Dart)
      game_snapshot.dart        one complete turn, used for rewinding
      hazard.dart / moving_block.dart
      tile_position.dart / player_action.dart / game_status.dart
      seeded_random.dart        xorshift32 with a snapshot-able state
      turn_event.dart / future_turn_preview.dart
    systems/
      level_system.dart         level table, per turn profile, DifficultyProfile
      exit_system.dart          BFS placement + route repair for the exit
      turn_system.dart          applies an action and advances the world
      hazard_system.dart        the weighted, player-influenced generator
      history_system.dart       the rewind buffer
      future_preview_system.dart  "what if I did nothing" simulation
    services/
      reward_service.dart       the future ad seam (mock for now)
      score_service.dart        best score + best level via SharedPreferences
      tutorial_service.dart     the hasSeenTutorial flag
  ui/
    overlay_names.dart / ui_metrics.dart
    tile_legend.dart            tile miniatures + legend data, shared by both
    tutorial_overlay.dart       the five first run cards
    game_hud.dart               score, level, exit countdown, best, pause
    level_banner_overlay.dart   LEVEL n / LAST MOVE! / WARNING! call-outs
    future_preview_widget.dart  the NEXT / +1 / +2 / +3 strip
    controls_overlay.dart       D-pad + WAIT
    pause_overlay.dart / game_over_overlay.dart
    screens/main_menu_screen.dart / screens/game_screen.dart
    screens/how_to_play_screen.dart
    widgets/action_button.dart / widgets/modal_scaffold.dart
test/
  helpers/game_test_helpers.dart   shared fixtures + a cautious simulated player
  helpers/ui_test_helpers.dart     app pumping + tutorial driving
  game_logic_test.dart             models, turn rules, exit flow, level table
  level_system_test.dart           run flow, records, first run hints, balance
  second_chance_test.dart          snapshot round-trip, preview, rewind
  app_smoke_test.dart              UI: menu, HUD, level transition, game over, layout
  tutorial_test.dart               HOW TO PLAY + the first run walkthrough
```

A few notes on the layout choices:

* **The gameplay layer is plain Dart.** `GameState` and the systems import nothing
  from Flutter or Flame, which is why the rules can be unit tested and why the
  preview can clone and fast-forward the world.
* **The exit is a first class citizen of the world, not a UI sticker.** Its
  placement, its immunity from hazards and the route repair all live in
  `ExitSystem` + `GameState`, so they are testable without a renderer.
* **The whole board is one `PositionComponent`.** A component per cell would mean up
  to 81 nodes to update and render every frame for zero visual gain; the arena paints
  itself with a handful of reused `Paint` objects instead.
* **The arena lives in `camera.viewport`.** Viewport children are drawn in screen
  space, so board coordinates are simply pixels - no camera zoom or anchor
  special-casing.
* **Flame draws, Flutter presents.** The HUD, the level banner, the preview strip,
  the controls and the two modals are Flame overlays built from ordinary Flutter
  widgets, so layout, animation and safe-area handling are all standard Flutter.
* **Vertical space is negotiated.** `GameScreen` tells the game how much room the HUD
  and the bottom block take; the board is sized and centred in whatever is left,
  which is what keeps it centred on desktop and overflow free on phones.

---

## Tests

```bash
flutter test        # 72 tests
flutter analyze     # clean
```

Covered by the suite:

* **teaching**: the menu offers HOW TO PLAY, the screen opens with the goal stated
  first, every legend entry has a name and a plain language description and a real
  tile miniature, it closes back to the menu, the first PLAY opens the walkthrough
  instead of the board, every card steps with NEXT and ends with START, finishing
  **and** skipping both persist `hasSeenTutorial`, a second PLAY goes straight to
  the board, the rules stay reachable afterwards, and the walkthrough persists
  across a fresh launch;
* level 1 is a real tutorial: 8×8, no walls, no sliding walls, no shrink, one
  telegraph at a time, three turns of warning, exit two steps away;
* the same level number always produces the same configuration, levels 2 and 3 are
  measurably harder than 1, and the curve keeps climbing towards level 40;
* every knob stays inside its safety cap for levels 1-200, and levels 50/100/250/1000
  still build a sane, playable board (the grid never leaves 7×7-9×9);
* level variety: at least four modifiers and all three grid sizes appear between
  levels 4 and 40;
* moving, walls, arena edges, turn counter, level counter and score;
* a warning becomes lethal on the right turn and clears afterwards;
* ending a turn on a lethal cell ends the run; nothing advances while paused, dead or
  mid level transition;
* the opening turns are quiet for every seed;
* the exit opens on exactly the turn the survival requirement is met;
* walking into the exit is the last move: it clears the level without resolving a
  world turn, and awards the level bonus on top of the turn score;
* the exit is always placed on reachable, safe ground outside the shrink cap (40 seeds);
* the exit is never telegraphed, blocked, occupied by a sliding wall or shrunk away;
* hazards land near the player far more than chance, never on a wall, never twice on
  one cell, and the drift direction shifts where they land;
* walls never seal the player into a pocket (60 seeds);
* crash-proof: a dozen levels cleared in a row, and a full simulated level at level 50;
* the completion bonus scales with the level number;
* the previous level is fully wiped when the next one starts, while score and turn
  carry over;
* TRY AGAIN resets level and score but keeps the records;
* death reports the level reached and stores best score + best level (in memory and on
  disk), and a worse run never lowers them;
* a brand new player is nudged once when the first warning appears, and a returning
  player (tutorial finished *or* skipped) never is;
* the future preview keeps working across a level change and never touches the live game;
* a snapshot restores the world exactly - including the level, the exit and the random
  stream - and both copies keep evolving identically;
* Second Chance rewinds three turns **inside the same level**, an already open exit
  survives the rewind, and rewinding to before it opened restores it as closed;
* UI: the menu and its best run panel, `PLAY` opening the arena with a working control
  pad, `LEVEL COMPLETE` → `LEVEL 2` with input locked, the Game Over panel, and no
  layout overflow at 320×568 (small phone) or 1600×900 (wide desktop) - including the
  HOW TO PLAY screen and all five tutorial cards.

### Balance measurement

`level_system_test.dart` also drives a **simulated cautious player** - a one turn
lookahead that never steps onto a cell that will be lethal, prefers untelegraphed
cells, keeps escape routes open and heads for the exit once it is up. Over 20 seeds it
reaches:

| Reached level | Runs |
|---|---|
| 3 | 20 / 20 |
| 5 | 20 / 20 |
| 8 | 19 / 20 |
| 12 | 12 / 20 |
| 20 | 2 / 20 |

Which matches the tuning goal: a new player should see the first three levels without
much trouble, and someone who has the hang of it should push into the teens. A human
who plans two or three turns ahead will do better than this robot.

---

## Building a Google Play release later

The Android project is already set up for it:

```bash
flutter build appbundle
# -> build/app/outputs/bundle/release/app-release.aab   (~38 MB, verified)
```

That works today because release builds are signed with the **debug keystore** (see
`android/app/build.gradle.kts`) - fine for internal testing, not for publishing.
Before uploading:

1. Create an upload keystore and an `android/key.properties` file.
2. Point `buildTypes.release` at it instead of the debug signing config.
3. Change `applicationId` from the `com.nermalav.lastmove` placeholder to the final id
   - it cannot be changed after the first upload.
4. Bump `version:` in `pubspec.yaml` (`versionName+versionCode`).

`targetSdk` and `compileSdk` are pinned to **36** and `minSdk` to **24**, which matches
the current Google Play requirements.

---

## Notes, caveats and known issues

* **Prototype scope.** No ads, Firebase, accounts, leaderboards, shop, skins or
  analytics - deliberately. The dependency list is only `flame`, `shared_preferences`
  and their own transitive packages.
* **Two SharedPreferences keys only:** `last_move.best_score` / `last_move.best_level`
  for the records and `last_move.has_seen_tutorial` for the walkthrough. Nothing else
  is written to disk.
* **The teaching layer never invents UI.** `TileSwatch` draws the legend entries with
  the same `GameColors` palette and the same proportions `ArenaComponent` uses, so a
  re-skin of the board automatically re-skins the legend.
* **Tuning lives in one place.** Difficulty is `LevelSystem`'s level table
  (`lib/game/systems/level_system.dart`); the run wide numbers (score per turn, level
  bonus, banner timings, rewind depth) are in `game_rules.dart`; the per level knobs are
  fields on `LevelConfig`. Nothing about difficulty is hard coded in the UI.
* **Kotlin incremental compilation is disabled** (`android/gradle.properties`). When the
  pub cache and the project sit on different Windows drives, Kotlin's incremental cache
  throws *"this and base files have different roots"*. The build still produced a valid
  APK, but the flag keeps the output clean and deterministic. Remove it if your pub cache
  and project share a drive.
* **Portrait lock is mobile only.** `main.dart` skips the `SystemChrome` calls on desktop
  so the window can be resized freely; the responsive layout is what makes that safe.
* **Text scaling is clamped to 1.25×** inside the game screen. The HUD and controls use
  fixed heights so the board can be laid out precisely, and clamping avoids RenderFlex
  overflow on devices with very large system fonts.
* **A blocked move costs nothing.** Walking into a wall or a sliding wall is refused and
  no turn passes - **WAIT** is the explicit way to spend a turn. Walking into a lethal
  cell *is* allowed, and kills you: that is the mistake the game is built on.
* **The endgame is bounded on purpose.** Survival turns cap at 28, live hazards at 6, the
  grid at 9×9 and the shrink at 1-2 rings, so level 500 is a *hard* level, not an
  unplayable one. Beating it needs better play, not more luck.
* **The `windows` and `android` targets were built and verified here** (debug APK,
  release AAB, and the desktop executable was launched). `ios`, `linux`, `macos` and
  `web` are the untouched Flutter defaults.
