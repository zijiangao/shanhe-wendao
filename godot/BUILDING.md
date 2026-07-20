# Building 山河问道

## Requirements

- Godot 4.7.1 stable
- Godot 4.7.1 Windows export templates

## Run automated tests

From the repository root, run each test scene headlessly:

```powershell
$godot = "C:\path\to\Godot_v4.7.1-stable_win64_console.exe"
$project = Join-Path $PWD "godot"
$tests = @(
    "test_game_state.gd",
    "test_save_manager.gd",
    "test_battle_rules.gd",
    "test_battle_engine.gd",
    "test_combat_feedback.gd",
    "test_encounter_rules.gd",
    "test_battle_scene_spec.gd",
    "test_settings_manager.gd",
    "test_difficulty_rules.gd",
    "test_location_art.gd",
    "test_release_credits.gd",
    "test_store_capture_spec.gd",
    "test_onboarding_spec.gd",
    "test_growth_rules.gd",
	"test_crafting_rules.gd",
	"test_herbarium_rules.gd",
	"test_mineralogy_rules.gd",
    "test_training_minigame_rules.gd",
	"test_training_event_rules.gd",
    "test_reward_rules.gd",
    "test_navigation_rules.gd",
    "test_tutorial_rules.gd",
    "test_cue_synth.gd",
    "test_steam_service.gd",
    "test_demo_policy.gd",
	"test_qingyun_spar.gd",
	"test_sparring_rules.gd",
	"test_training_keyboard_input.gd",
	"test_shop_rules.gd",
	"test_choice_view_icon.gd"
)

foreach ($test in $tests) {
    & $godot --headless --path $project --script ("res://tests/" + $test)
    if ($LASTEXITCODE -ne 0) { throw "$test failed" }
}
```

Run the independent SteamPipe preparation regression test after the Godot suite:

```powershell
& .\steamworks\scripts\test_prepare_steampipe.ps1
```

## Preview the battle reward choice

Capture the save-backed three-way reward screen at 1280×720 for visual QA:

```powershell
& $godot --path $project --script res://tests/test_reward_choice_view.gd
```

Godot writes `reward_choice_preview.png` to the project user-data folder and exits non-zero if the pending reward state is missing.

Render the complete settings panel after UI changes:

```powershell
& $godot --path $project --script res://tests/test_settings_view.gd
```

Godot writes `settings_preview.png` to the project user-data folder and verifies that fullscreen, screen-shake, and combat-flash controls are present.

`controls_preview.png` verifies the dedicated keyboard-binding screen. Direction keys and controller navigation remain available alongside four persistent physical-key bindings; conflicts swap keys, while Enter and Esc stay reserved for confirm/cancel.

Capture a live martial-skill impact frame after changing combat presentation:

```powershell
& $godot --path $project --script res://tests/test_combat_feedback_view.gd

& $godot --path $project --script res://tests/test_training_minigame_view.gd

& $godot --path $project --script res://tests/test_crafting_view.gd

& $godot --path $project --script res://tests/test_pause_view.gd

& $godot --path $project --script res://tests/test_achievements_view.gd

& $godot --path $project --script res://tests/test_defense_tutorial_view.gd

& $godot --path $project --script res://tests/test_controls_view.gd

& $godot --path $project --script res://tests/test_character_view.gd

& $godot --path $project --script res://tests/test_training_menu_view.gd

& $godot --path $project --script res://tests/test_market_view.gd

& $godot --path $project --script res://tests/test_backpack_view.gd

& $godot --path $project --script res://tests/test_map_view.gd
```

`test_crafting_view.gd` also confirms the workshop's fourth "离开工坊" option stays enabled and actually returns to `location` when every real recipe is disabled (a fresh save has zero herbs/ore, so this is the default state for a new player, not an edge case) — the workshop reuses the generic `choice` screen, which `NAVIGATION_RULES.back_action()` deliberately blocks from any back/cancel action since most `choice` screens are one-way story decisions. Without that fixed fourth option, a player who can't yet afford any recipe has no way to leave the screen.

`test_training_keyboard_input.gd` runs in the main headless suite (it asserts on game state and injected `InputEventKey`s rather than rendering anything) and guards against a real keyboard/controller-input regression in `training_minigame_view.gd`: its four direction buttons must stay `focus_mode = FOCUS_NONE` so Godot's own UI focus-navigation can never intercept a `ui_up`/`ui_down`/`ui_left`/`ui_right` press before it reaches the view's `_unhandled_input`, and `setup()` must call `get_viewport().gui_release_focus()` so a focused control anywhere else on screen (e.g. a header nav button) can't do the same via its own focus-navigation. Either gap independently reproduces the reported symptom: presses sometimes needing several tries, or jumping focus to an unrelated button, while mouse clicks worked fine (they never go through focus-navigation). Its Case 2 deliberately re-grabs focus onto the leftmost header button (simulating focus landing there again after `setup()`'s one-time release, e.g. a stray Tab) and then presses whichever direction the round's second target happens to require; because that button has a real right-neighbor, a `ui_right` press specifically would otherwise be swallowed by the header's own focus-navigation. `_process()` now re-releases focus every frame the round view is alive (not just once at construction) to close that gap for good — a one-time release only protects the instant a round starts, not its whole duration. That per-frame release is scoped to focus landing *outside* this view (`not is_ancestor_of(focus_owner)`) rather than any focus at all — an earlier version released unconditionally, which also stole focus back from the result screen's own "收功" button before a keyboard confirm or even a mouse click could complete its press/release cycle, making it silently inert by any input method (a real softlock: finishing a training session left no way off the result screen). Case 3 plays a full session to completion, focuses that button, and confirms a real `KEY_ENTER` press actually returns to `location`.
`_show_training_round_ready()` in `main.gd` (called on every round start and round advance) shows the challenge immediately but leaves `training_started_ms` at its `0` "pending" sentinel — and `training_minigame_view.gd` disables the four direction buttons and shows "准备中…" — until `TRAINING_READY_DELAY` (0.6s) elapses, so timing starts once the player can actually act instead of the instant a multi-step prompt appears (the first round of a session was otherwise nearly unscoreable-perfect, since reading time counted against it). Both `test_training_keyboard_input.gd` and the training previews below account for this delay before driving input.

`test_training_menu_view.gd` covers the same gap on the Qingyun training menu, which shares the same generic `choice` screen: a top-level "暂不修炼" option that returns to `location` without spending a week, and a "返回" option on the nested sparring weapon-choice sub-menu that returns to the training menu rather than exiting the training flow entirely. `ChoiceView` itself now wraps its option list in a `ScrollContainer` — with the two escape options added, the training menu can show six options at once, enough to risk the same fixed-height overflow the character sheet hit.

`test_character_view.gd` requires the trailing skill-mastery line to actually be reachable inside the info panel's `ScrollContainer` after scrolling to the bottom, not merely present in the node tree — the panel's content (specialties, skills, inventory, herbarium/mineralogy, companions, faction relations, mastery) is long enough to overflow a fixed 1280x720 layout without it.

## Shop system (西市 · 洛阳)

洛阳城's "西市 · 商旅云集" hotspot (previously a one-line static dialogue) opens a real shop: `scripts/progression/shop_rules.gd` defines a small hand-authored catalog of three weapons and three armors (`ShopRules.WEAPONS`/`ARMORS`, flat `attack_bonus`/`defense_bonus` each) plus per-unit buy/sell prices for the four existing tradeable goods (herbs, ore, healing_powder, thunder_stone). It reuses the existing `ChoiceView` + nested `choice_event` sub-menu pattern that the training menu's `spar_focus` sub-menu established — `market` → `market_weapons`/`market_armor`/`market_goods`, each with a "返回" back to its parent — rather than a new dedicated view class, since a single-list-of-buttons-with-disabled-state is exactly what crafting's workshop already proved out for a very similar "browse options, spend a resource" flow.

Weapons and armor are real equipped items (`GameState.data.equipped_weapon`/`equipped_armor`, plus `owned_weapons`/`owned_armors` arrays), independent of and additive with the pre-existing `forge_level` tempering mechanic (0-3, from the workshop's "淬炼青锋" recipe) — a player's total attack bonus is tempering *plus* whatever weapon is equipped, not one replacing the other. Buying a weapon/armor immediately equips it; owning more than one lets a later choice-screen visit re-equip an older piece via `equip_weapon`/`equip_armor`; selling the currently equipped piece refunds half its price and leaves the hero bare-handed/unarmored rather than silently falling back to a different owned piece.

**Armor is a genuinely new combat mechanic, not an extension of an existing one** — before this, the player had zero persistent damage mitigation; only the temporary "运气护体" (`hero_guard`) resource existed. `BattleEngine.enemy_turn()` gained a fourth parameter, `hero_armor: int = 0`, **appended after `rng` rather than inserted before it** — `test_battle_engine.gd` has roughly twenty call sites that pass `rng` as a bare third positional argument, and inserting a parameter ahead of it would have silently fed those calls' RNG objects into the wrong slot. Armor is subtracted from an incoming hit before `hero_guard` absorbs whatever remains (mirroring how enemy armor already works against the player: a permanent flat layer, with any temporary shield stacked on top), and only ever applies to hits landing on the hero — 林清霜 keeps her own separate `guard` stat and is untouched by the hero's personal gear. `test_shop_rules.gd` covers the buy/equip/sell state machine directly; `test_battle_engine.gd`'s `_test_equipped_gear_bonuses()` covers the combat-formula integration, including an explicit check that calling `enemy_turn()` with only three positional arguments (every pre-existing call site's shape) still behaves as zero armor.

The training result screen also lists a per-round breakdown (elapsed time, feedback tier, and score for each of the session's rounds, from `training_round_details` in `main.gd`) beneath the summary card, so a player can see exactly which hit cost them the grade rather than only the total.

## Backpack screen and item icons (背包)

A new "背包" header nav button (between 人物 and 成就) opens `_show_backpack()`: equipped weapon and armor shown first and highlighted, then any other owned-but-unequipped weapons/armor (each with a "装备" button that switches it in directly via `SHOP_RULES.equip_weapon`/`equip_armor`), then the four tradeable goods with their carried counts — reusing the achievements screen's `framed_panel` + scrollable icon-row pattern rather than inventing a new layout. Buying and selling still only happen at 西市 (kept there as the single source of truth for the shop's economy), but switching between already-owned gear works from either screen now. `test_backpack_view.gd` covers full-inventory scroll reachability the same way `test_character_view.gd` already does for the character sheet, plus a direct equip-button press-and-verify check — watch for stale node references there: pressing the button triggers `_show_backpack()`, which rebuilds the whole screen and frees the previously-found label/scroll nodes, so any check that needs those results must capture them into plain booleans *before* the press, not re-read the (by-then-freed) Control references afterward.

Item icons are optional everywhere they appear (backpack rows and the market's `ChoiceView` option rows, via an optional 5th tuple slot) — `UITheme.item_icon(id)` looks up `res://assets/ui/item_<id>.png` with `load()` + `ResourceLoader.exists()` rather than `preload()`, so the project keeps compiling and every screen renders correctly even if an id's art is missing. All 10 catalog items (`item_iron_sword.png` through `item_thunder_stone.png`) now ship real ink-brush icon art, extracted from a single AI-generated multi-subject sheet via the same border-flood-fill chroma-key pipeline as the nav icons/achievement badges, extended to a two-stage 2D grid split (row-band clustering along y, then per-row column clustering along x) since every prior multi-subject sheet this project has processed was a single row or column. `test_choice_view_icon.gd` exercises the icon-rendering branch directly with a stand-in texture, independent of whichever items happen to have real art at any given time.

洛阳城's map marker is deliberately reachable from the very start of a new game (`_show_map()`'s `places` array includes `"luoyang"` unconditionally, NOT gated by `_luoyang_unlocked()` the way every other location is) — the shop/backpack economy is meant to be usable throughout a playthrough, not just after the story reaches Luoyang. `_luoyang_unlocked()` itself is untouched and still gates the quest-journal chapter-text ladder in `_show_quests()`, a genuinely different concern ("has the main story reached Luoyang") from "can the player currently walk there" — `test_map_view.gd` guards both halves of that split explicitly, since a careless fix could easily make the quest journal jump straight to "洛阳风云" on a fresh save. Location-level story gates (e.g. 太守府 requiring `quest_stage == "luoyang_investigate"`) are untouched and still protect against sequence-breaking the main story from an early visit.

The character sheet's "已装备" line no longer hardcodes "青锋剑" as though it were always equipped — before the shop shipped, `forge_level` (from the workshop's "淬炼青锋" recipe) was the only weapon-strength mechanic, so showing it as "已装备：青锋剑（淬炼 X/3）" was accurate; once real equippable weapons existed alongside it, that framing became misleading (it visually contradicted a genuinely bare-handed `equipped_weapon == ""` state). The line now shows the real equipped weapon/armor status (defaulting to "赤手"/"无护具" like the backpack always has), with tempering broken out onto its own line ("淬炼层数：X/3") since it's a real, separate, still-additive bonus that applies regardless of which weapon (if any) is equipped — not a property of a specific named sword.

The training preview covers the advanced three-technique sword sequence, the short-echo mining window, and the final mining score/reward card with rank-up and personal-best banners, mineral discovery, and encounter panels. Each discipline introduces an advanced variant after round one. Training streaks begin at 85 points and grant capped combo bonuses; the packaged verifier checks a three-round 315-point streak. Exact records persist for all four disciplines. Specialty levels cross stable thresholds at 3/6/10 for 熟手/精通/大成. At 大成, sword training reduces Flowing Cloud Sword from eight to six qi, blade training makes normal attacks create two exposure layers, herbalism adds five healing to powder, and mining reduces weapon-tempering silver from eight to five. The tactical battle panel derives its action labels, enablement rules, pre-armor normal damage range, armor-ignoring sword range, exposure gain, qi cost, and exact healing amount from the same shipping formulas. Character and workshop screens also show the effective dynamic values instead of stale base costs.

The weekly training focus rotates deterministically through sword, blade, herbalism, and mining. Following the highlighted focus grants three extra cultivation points. The Qingyun training action, character overview, training choice, and result verdict all expose the current focus so the recommendation never depends on hidden knowledge.

The hero combat action 运气护体 spends one action point to gain constitution-scaled guard and recover three qi. Incoming attacks consume this guard before health, including boss sweeps, while the tactical status and hit feedback expose both remaining and blocked amounts.

Godot writes `combat_feedback_preview.png` to the project user-data folder after exercising the real skill-impact animation path.

Verify the packaged one-time reward flow from either exported executable:

```powershell
& "..\build\windows\ShanheWendao.exe" -- --verify-reward-flow
```

Verify packaged feedback tiers, heavy-impact events, and accessibility settings:

```powershell
& "..\build\windows\ShanheWendao.exe" -- --verify-combat-feedback
```

The save-manager test deliberately feeds malformed and future-version save files to verify recovery, so warning/error log lines from those fixtures are expected.

The main scene also provides a release presentation verifier. It instantiates the real tactical battle view, plays movement, attack, damage, guard, and boss-technique events, then exits with a non-zero code if the input lock was not released:

```powershell
& $godot --headless --path $project -- --verify-battle-presentation
```

The onboarding verifier checks the shipping new-game route from Qingyun mission acceptance through unlocking the first Blackreed battle:

```powershell
& $godot --headless --path $project -- --verify-onboarding-flow

& $godot --headless --path $project -- --verify-training-flow

& $godot --headless --path $project -- --verify-crafting-flow

& $godot --headless --path $project -- --verify-pause-flow
```

The exported-build Steam data verifier checks that all 20 achievement definitions have stable API names and complete metadata. Besides story and ending progress, the set includes persistent milestones for training, specialty mastery, complete herb and mineral collections, field medicine, and weapon tempering; `STAT_HIGHEST_SPECIALTY` mirrors the player's strongest specialty. Locked mastery and collection achievements show progress reconstructed from the current save:

```powershell
& "..\build\windows\ShanheWendao.exe" -- --verify-steam-data
```

## Export Windows Release

```powershell
New-Item -ItemType Directory -Force -Path (Join-Path $PWD "build/windows") | Out-Null
& $godot --headless --path $project --export-release "Windows Desktop"
New-Item -ItemType Directory -Force -Path (Join-Path $PWD "build/windows-demo") | Out-Null
& $godot --headless --path $project --export-release "Windows Demo"
```

The Windows release is written to `build/windows/ShanheWendao.exe` with `ShanheWendao.pck` beside it. Both files are required. Keeping game content separate improves SteamPipe patch behavior. The `build` directory is intentionally ignored by Git.

The demo is written separately to `build/windows-demo/ShanheWendaoDemo.exe` with `ShanheWendaoDemo.pck`. Its `demo` custom feature enforces the Blackreed victory boundary; the full preset has no such feature.

The Qingyun training menu also offers a repeatable, nonlethal sparring battle. It spends one week, returns to Qingyun after a lightweight reward choice, and never advances the main quest or triggers the demo boundary.

Run `res://tests/test_qingyun_spar_view.gd` without `--headless` to capture `qingyun_spar_preview.png` at 1280×720 and verify that the shipping battle UI shows the rotating lesson and chosen weapon focus.

To visually review the second first-battle tutorial page from the shipping UI, run the full build with `--capture-tactical-tutorial`. It writes `tactical_tutorial_preview.png` to the Godot user-data folder and exits non-zero if the expected tutorial page was not active.

## Capture Steam store screenshots

After exporting the full Windows release, run the shipping executable with `--capture-store-screenshots`. It creates eight deterministic 1920×1080 gameplay PNGs under the Godot user-data folder in `store_screenshots`. These are candidate captures from the actual release UI; visually review every image before uploading it to Steam.

```powershell
& "..\build\windows\ShanheWendao.exe" -- --capture-store-screenshots
```

Before a public Steam release, review `ASSET_PROVENANCE.md` and `THIRD_PARTY_NOTICES.md`, replace the current provisional application icon only after the final brand and art-rights review, and configure code signing in the Windows export preset.
