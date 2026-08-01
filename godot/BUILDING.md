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
	"test_choice_view_icon.gd",
	"test_wuxue_rules.gd"
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

& $godot --path $project --script res://tests/test_manuals_view.gd
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

青云工坊 (`scripts/progression/crafting_rules.gd`, `CraftingRules`) gained four attribute-pill recipes — "悟性丹"/"臂力丹"/"身法丹"/"根骨丹" (`insight_pill`/`strength_pill`/`agility_pill`/`constitution_pill`, each 3 herbs + 15 silver), permanently raising the matching stat by 1 the instant one is crafted. Unlike 淬炼青锋's `MAX_FORGE_LEVEL` cap, there is deliberately **no ceiling** on how many of any pill can be crafted, mirroring how `train()` (the existing strength/insight/constitution attribute-training action) has no cap either — **身法丹 is actually the first way to raise agility at all**, since `train()`'s valid foci never included it and no other system touches `data.agility`. `constitution_pill` also grants the same `+3 max_hp`/`+3 current hp` that `GrowthRules.apply_training("constitution")` already does, keeping the pill's effect consistent with what training constitution already means, not just a bare stat bump. `CraftingRules.apply()`'s dispatch was converted from an `if/elif/else` (where the final `else` implicitly meant "must be `temper_blade`") to an explicit `match` over every recipe id — the old catch-all `else` would have silently mis-applied any of these four new pills as a weapon-tempering level instead of a stat increase, since they don't match any of the earlier `elif` branches. `CraftingRules.apply()`/`options()`/`inventory_text()` are the only places that needed new branches — `GameState.craft()`, the workshop's `_rebuild()`/`_resolve_choice()` wiring in `main.gd`, and the Steam-milestone lookup all already dispatch generically by recipe id, so no UI code changes were needed to make any of these recipes appear and function (the milestone lookup has no entries for any of the four pills, so none grant an achievement flag — intentional, not an oversight). `test_crafting_rules.gd` covers each pill's cost, its immediate uncapped effect (including constitution's extra hp grant), and that all four stay independently repeatable rather than blocked by any level ceiling.

**淬炼青锋 removed, workshop weapon/armor crafting added (0.81.0)**: the old `temper_blade` recipe (and its `forge_level` progression) is gone from the workshop entirely, replaced by four new recipes — "自铸铁刃"/"双刃寒锋" (weapons, `forged_iron_blade`/`twin_edge_saber`) and "藤甲护身"/"叠层甲胄" (armor, `rattan_guard`/`layered_iron_armor`) — that cost **materials only, never silver** (unlike 西市's weapons/armor, which are silver-only). `data.forge_level` itself is untouched and still contributes to every damage formula that already read it, so a save that had already tempered before this update keeps that bonus permanently; there's simply no way to raise it further now. These four items are a genuinely **separate catalog** from `ShopRules.WEAPONS`/`ARMORS` (living in `CraftingRules.RECIPES` instead, alongside the potions/pills, each carrying an `attack_bonus`/`defense_bonus` field) — not duplicates of the market's swords/armor with a different price tag — but they share the *exact same* `owned_weapons`/`equipped_weapon`/`owned_armors`/`equipped_armor` fields as market gear, so a player only ever wields one weapon at a time regardless of whether they bought or forged it, and the backpack/character-sheet/battle-formula code needed only a fallback lookup, not a parallel equip system.

That fallback lookup lives in **`ShopRules`, not `CraftingRules`** — `ShopRules` now `preload()`s `CraftingRules` (one-directional, no cycle) so `weapon_attack_bonus()`/`armor_defense_bonus()` can resolve an equipped id regardless of which catalog it came from, and `equip_weapon()`/`equip_armor()` were **simplified** to check ownership alone rather than re-validating catalog membership — safe, since `owned_weapons`/`owned_armors` can only ever be populated by `buy_weapon()`/`buy_armor()` (validated against `WEAPONS`/`ARMORS`) or `CraftingRules.apply()` (validated against its own catalog) in the first place. `sell_weapon()`/`sell_armor()` were deliberately **left unchanged** (still gated on `WEAPONS.has(id)`/`ARMORS.has(id)`) — crafted gear was never sold there and stays that way, since no silver was ever spent on it. `GameState._migrate_and_validate()`'s ownership filters and `main.gd`'s `_backpack_equipment_row()`/character-sheet equipped-item lookups all needed the same fallback-to-`CraftingRules.RECIPES` merge.

**A real display bug, caught by extending `test_character_view.gd`/`test_backpack_view.gd` rather than by review**: `CraftingRules.RECIPES[id].title` is an *action-button label* meant for the workshop's own options list (e.g. `"打造 · 自铸铁刃"`, matching `"炼制 · 悟性丹"`'s shape) — reusing it directly as the equipped-item's bare display name (as the first fallback-lookup draft did) made the character sheet and backpack read "已装备：打造 · 自铸铁刃" instead of "已装备：自铸铁刃", visibly leaking the crafting verb into a context that expects a bare noun (every `ShopRules.WEAPONS`/`ARMORS` entry's `.title` *is* already a bare name, so this asymmetry wasn't obvious until an equipped crafted item was actually rendered). Fixed by giving each of the four gear recipes its own `item_name` field (the bare noun) alongside `title` (the action label), and having both call sites prefer `item.get("item_name", item.get("title", fallback))`.

Mining mastery's 大成 perk was **repointed from a silver discount on 淬炼青锋 to an ore discount on workshop gear** — `TrainingMinigameRules.tempering_silver_discount()` was renamed to `craft_ore_discount()` (same 3-point discount at mining level 10, just reducing `ore` instead of `silver` now), and `perk_text("mining", ...)`'s description string was updated to match; leaving the old function name/description in place after the recipe it described was deleted would have shown players a perk that referenced a mechanic that no longer existed. The Steam achievement **`ACH_FIRST_TEMPER`** ("百炼成锋" / "在青云工坊首次淬炼兵刃") is repointed the same way — its title/description already read naturally as "first time forging a weapon at the workshop," so the `tempered_blade` flag it depends on is now granted by crafting either of the two new **weapons** (not the armor pair, matching the achievement's literal "兵刃" wording) in `GameState.craft()`'s milestone lookup, keeping a previously-shipped achievement reachable instead of orphaning it. `test_crafting_rules.gd`/`test_shop_rules.gd`/`test_game_state.gd` cover the new recipes' cost/ownership/equip/bonus resolution, the mining-mastery ore discount, and the repointed milestone flag; `test_character_view.gd`/`test_backpack_view.gd` specifically assert a crafted weapon's *bare* name renders correctly, guarding against the `item_name`-vs-`title` bug recurring.

## Wuxue system (武学秘籍) and full map access

洛阳城's 西市 gained a fourth stall, "秘籍阁" (`_show_market_manuals()`, `choice_event == "market_manuals"`), selling manuals for three categories defined in `scripts/progression/wuxue_rules.gd`: 招式 (`MOVES`, combat moves — max two equipped at once, `MAX_EQUIPPED_MOVES`), 内功 (`INTERNAL`, passive damage/healing bonuses), and 轻功 (`LIGHTNESS`, passive move-range bonuses) — each a single-slot category. Internal arts and lightness skills follow the **exact same "buy = auto-equip, replacing whatever was equipped" pattern as weapons/armor** (`learn_internal`/`learn_lightness` always set `equipped_internal`/`equipped_lightness` to the newly learned id), since there's only one slot each. Moves are **capacity-aware instead**: `learn_move` only auto-equips into `equipped_moves` if a slot is free, otherwise the move is learned but sits unequipped until the player frees a slot from the backpack (`equip_move`/`unequip_move`) — this is a deliberate difference from gear's "always auto-equip" behavior, not a bug, because unlike weapons/armor a player is expected to own more moves than they can use at once. `options_manuals()` renders all three categories plus one "返回" row through the same `_with_item_icons()` padding path the shop already established.

Both new battle-only moves are gated on `equipped_moves`, not just `learned_moves` — `BattleEngine.player_action()` fails with "尚未装备…" if the acting unit doesn't have the move equipped, and neither is usable by 林清霜 on her own turn (matching how she already can't use 流云剑法/断岳刀法). 裂石拳 (`_stone_splitting_fist`, 5 qi) hits once, **ignoring the target's armor entirely** — its damage is computed independently of `RULES.enemy_armor()`, unlike every other attack. 暗夜三刀 (`_night_triple_blade`, 9 qi) hits three times in one action, each hit independently re-reading and subtracting the enemy's *current* armor (so a `_blade_skill()` armor-break landing first still weakens all three hits, but the enemy's armor stat itself is never permanently reduced by this move the way 断岳刀法's is).

内功's damage bonus (`WUXUE_RULES.internal_damage_bonus()`) is added to every hero damage source: `normal_damage_range()`, `cloud_damage_range()`, `blade_damage_range()`, `stone_fist_damage_range()`, and `night_blade_hit_range()`. **Watch out**: `_attack()` (plain attacks) and `_cloud_skill()` (流云剑法) don't call `normal_damage_range()`/`cloud_damage_range()` for their actual damage roll — they duplicate the formula inline, only `_blade_skill()` calls its shared `blade_damage_range()` function directly. Adding a new hero damage bonus therefore requires updating **both** the `*_damage_range()` preview function (used by `hero_action_help()`'s in-battle help text) **and** the matching inline formula in `_attack()`/`_cloud_skill()` — this exact gap (the internal-art bonus was added only to the preview functions, silently never applying to real plain-attack/流云剑法 damage) was caught by `test_battle_engine.gd`'s `_test_wuxue_internal_and_lightness_bonuses()` and fixed before shipping. 轻功's move-range bonus (`WUXUE_RULES.lightness_move_bonus()`) works differently — through `BattleRules.can_move_to(battle, cell, bonus_range: int = 0)`, whose new parameter is **appended after `cell` with a default of zero**, the same append-only convention as `enemy_turn()`'s `hero_armor`, so every pre-existing two-argument call site keeps working unchanged. `BattleEngine._move()` gained a `player` parameter (needed to look up the bonus) and guards it to zero whenever `active_unit == "ally"`, so the hero's own lightness skill can never extend 林清霜's movement on her turn — mirroring how `_attack()` already keeps her damage formula entirely separate from the hero's gear/qi.

**Leveling (added 0.76.0)**: every learned move/internal art/lightness skill has its own level, 1 through `WuxueRules.MAX_LEVEL` (10), tracked per-id in `GameState.data.move_levels`/`internal_levels`/`lightness_levels` (missing/malformed entries default to level 1 via `move_level()`/`internal_level()`/`lightness_level()`'s `clampi`, and `_migrate_and_validate()` additionally drops any level entry whose id isn't actually in the matching `learned_*` list). Leveling is a direct silver purchase at 秘籍阁, not a training minigame — each learned entry's options row gains an extra "升级 · <name> Lv.X→X+1 · <cost>银" line (`upgrade_move`/`upgrade_internal`/`upgrade_lightness`), reading "已满级" and disabled once level 10 is reached. Cost scales with the target level (`WuxueRules.upgrade_cost() = catalog[id].upgrade_base * next_level`), so leveling 1→10 costs a steadily rising total rather than a flat repeated fee. The per-level bonus is **strictly additive above the level-1 baseline** (a freshly learned, unleveled item behaves identically to before leveling existed): moves gain `level_damage_bonus` per level above 1 via `WUXUE_RULES.move_damage_bonus()`, threaded into `stone_fist_damage_range()`/`night_blade_hit_range()` (both already funnel through these shared functions rather than an inline formula, so no separate "inline formula" fix was needed here the way the plain-attack internal-art bonus bug required); internal arts scale their existing `damage_bonus`/`healing_bonus` the same way. **轻功 is the one exception to "linear per level"**: scaling move range by a full tile every level would break a board only 6-8 tiles wide, so its bonus only ticks up by one tile every `LIGHTNESS_LEVEL_DIVISOR` (3) levels instead — a deliberate, documented deviation from the other two categories' per-level curve, not an inconsistency. `test_wuxue_rules.gd` covers the level state machine (cost scaling, the level-10 cap rejecting further upgrades, insufficient silver leaving level/silver untouched) directly; it also caught a real bug pre-ship — `upgrade_move/internal/lightness()`'s "ensure the levels dict exists" guard checked `typeof(state.get(key, {}))` instead of `state.has(key)`, so a state dict that was simply missing the key outright (as opposed to having it with the wrong type) crashed on the following line's write, since `.get()` with a default never actually creates the key on the dict. `test_battle_engine.gd` verifies a level-10 move/internal art deals exactly nine extra levels' worth of damage over an unleveled one in a real `player_action()` call, and that lightness's every-third-level tick actually opens up a cell that was out of range before. `test_game_state.gd` covers the leveling migration (missing fields, an orphaned level for a never-learned id, an out-of-range level clamped both above and below) and the `power()` contribution from leveling up. `test_manuals_view.gd` presses the "升级" button directly in the live shop screen and confirms both the level and the silver deduction.

**Training / 修炼 (added 0.77.0)**: a second, free-but-slow path to the same levels as the silver-based 升级 above. 青云门's training menu (`_show_training_menu()`) gained a "武学修炼" option — disabled with a hint if nothing has been learned yet, otherwise opening `_show_wuxue_training()` (`choice_event == "wuxue_training"`, built from `WuxueRules.options_training()`), which lists every *learned* move/internal art/lightness skill (regardless of equip state) with its current level and `<xp>/<xp_needed> 经验` progress, reading "已大成" and disabled once maxed. Selecting one spends a week and one energy — via `GameState.train_wuxue(category, id, xp_roll: int = -1)`, which mirrors `train()`/`complete_training()`'s existing "validate the target before calling `spend_week()`" ordering (`GameState.can_train_wuxue()` is checked first, so an invalid or already-maxed target never wastes a week/energy the way a naive `spend_week()`-then-validate order would) — and grants a random 8-15 xp (`WuxueRules.TRAIN_XP_MIN/MAX`; an explicit `xp_roll` argument bypasses the random roll for deterministic tests, the same pattern `complete_training()`'s `event_roll` already established) **plus** `WuxueRules.insight_xp_bonus()` (悟性/2, mirroring Flowing Cloud Sword's existing "every 2 points of insight" scaling in `cloud_damage_range()`) — the insight bonus is always added on top of whichever roll was used, including an explicit test `xp_roll`, so tests can hold the random component fixed while still exercising the stat scaling. `WuxueRules.xp_needed(level) = 20 * (level + 1)`, so reaching level 10 purely through free training costs roughly 1080 cumulative xp (~70-130 weeks at 8-15xp each) versus the shop's instant-but-costly `upgrade_cost()` — both paths feed the exact same `move_levels`/`internal_levels`/`lightness_levels` fields, so a player can freely mix silver purchases and training sessions on the same item. `train_move/internal/lightness()` roll over multiple levels in a single huge xp gain (a `while` loop, not a single `if`), capping at level 10 with leftover xp discarded rather than overshooting or accumulating unusably. `GameState.data.wuxue_xp` (a single dict shared across all three categories, safe since their ids never collide) is migrated the same way as the level dicts: non-dict repaired to empty, negative values clamped to zero, entries for ids that aren't (or are no longer) actually learned dropped. `test_wuxue_rules.gd` covers the xp accumulation/rollover/cap and the training-menu row text/disabled state; `test_game_state.gd` covers the week/energy cost (including that an invalid target is rejected *before* any week is spent) and the xp migration; `test_training_menu_view.gd` covers the live "武学修炼" option end-to-end (disabled with nothing learned, enabled and functional once something is, spending a real week/energy, and returning to the training menu).

Every location — 华山 and 峨眉山, not just 洛阳城 — is now unconditionally listed in `_show_map()`'s `places` array, the same precedent the shop system established for Luoyang: `_huashan_unlocked()`/`_emei_unlocked()` are untouched and still gate the quest-journal chapter-text ladder in `_show_quests()` (a fresh save still correctly reads "黑苇疑云", not "洛阳风云" or later chapters), and location-level story gates inside 华山/峨眉 itself are untouched, so visiting early can't sequence-break the main story — only reachability on the map changed. `test_map_view.gd` asserts all five locations are listed and travelable while the chapter text still reads correctly for a fresh save.

`test_wuxue_rules.gd` covers the learn/equip/unequip state machine (including the two-slot move cap and the single-slot auto-replace for internal/lightness) directly against `WuxueRules`, mirroring `test_shop_rules.gd`. `test_battle_engine.gd` covers both new moves' equip-gating, damage formulas (including 裂石拳 ignoring armor and 暗夜三刀 not), the internal-art damage/healing bonus, and the lightness move-range bonus (including the ally-immunity guard and an explicit check that `can_move_to()` called with only two positional arguments still behaves as zero bonus). `test_game_state.gd` covers wuxue save migration (missing fields, unrecognized ids, an oversized `equipped_moves` list) and the wuxue contribution to `power()`. `test_backpack_view.gd` covers the two new "已修炼武学"/"其余已习武学" sections and equipping a bumped-out internal art directly from the backpack. `test_manuals_view.gd` mirrors `test_market_view.gd` for 秘籍阁 specifically, including the "返回" round-trip — the exact class of screen a padding bug in `_with_item_icons()` crashed once before, so every new shop submenu re-verifies it rather than assuming safety by similarity.

The training preview covers the advanced three-technique sword sequence, the short-echo mining window, and the final mining score/reward card with rank-up and personal-best banners, mineral discovery, and encounter panels. Each discipline introduces an advanced variant after round one. Training streaks begin at 85 points and grant capped combo bonuses; the packaged verifier checks a three-round 315-point streak. Exact records persist for all four disciplines. Specialty levels cross stable thresholds at 3/6/10 for 熟手/精通/大成. At 大成, sword training reduces Flowing Cloud Sword from eight to six qi, blade training makes normal attacks create two exposure layers, herbalism adds five healing to powder, and mining reduces workshop-crafted gear's ore cost by 3 (`TrainingMinigameRules.craft_ore_discount()`, renamed from `tempering_silver_discount()` in 0.81.0 when 淬炼青锋 was retired). The tactical battle panel derives its action labels, enablement rules, pre-armor normal damage range, armor-ignoring sword range, exposure gain, qi cost, and exact healing amount from the same shipping formulas. Character and workshop screens also show the effective dynamic values instead of stale base costs.

The weekly training focus rotates deterministically through sword, blade, herbalism, and mining. Following the highlighted focus grants three extra cultivation points. The Qingyun training action, character overview, training choice, and result verdict all expose the current focus so the recommendation never depends on hidden knowledge.

**演武场/后山 split (0.82.0)**: 采药/挖矿 moved out of 演武场 (`train`, combat-only now: swordsmanship/bladesmanship) into a new dedicated 青云门 hotspot, 后山 (`gathering`, `_show_gathering_menu()`, `choice_event == "gathering"`). `TrainingMinigameRules.options()` was split into `options()` (combat) and `gathering_options()` (gathering) via a shared private `_discipline_options(state, disciplines)` helper — both still read/write the exact same `DISCIPLINES`/specialty-level/minigame machinery, this is purely a UI-level regrouping, not a new mechanic. `_location_action_requested()`'s `"gathering"` case mirrors `"train"`'s energy/deadline gate exactly, and `_resolve_choice()`'s `elif choice_event == "gathering":` branch mirrors `"training"`'s generic `_start_training(route)` dispatch (minus the 实战切磋/武学修炼 special cases, which stay combat-only). `weekly_focus()`'s 4-discipline rotation is untouched — each hotspot's label only surfaces "本周专精" when the rotating focus actually belongs to its own two disciplines, falling back to a generic label otherwise (`_location_actions("qingyun")`'s `train_text`/`gathering_text`). `test_training_minigame_rules.gd` covers the split catalog directly; `test_training_menu_view.gd` covers the live hotspot end-to-end (opens, lists exactly its own two disciplines, no cross-contamination either direction, leave button works).

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

As of 2026-08-01, 天下舆图's side panel lost its dark framed background entirely (0.98.0) -- the `PanelContainer` wrapper (and its `UI_THEME.panel_box(DARK_TINT)` stylebox) was replaced with a plain `VBoxContainer` at the same position/size, so the panel's text/buttons now sit directly over the map art with no boxed frame around them.

As of 2026-08-01, 天下舆图's side panel was reorganized (0.97.0): removed the redundant "当前所在 · X" title label (the current-location map marker already labels itself "当前所在"), and moved 江湖纪事 (the adventure log) from a fixed overlay panel in the map's bottom-left corner into a collapsible section at the bottom of the side panel -- collapsed by default (▸ 江湖纪事), click to expand/collapse in place (▾ 江湖纪事), matching every other panel's screen space rather than floating over the map art. `test_map_view.gd` extended to cover both changes.

As of 2026-08-01, the project's global default font was set to LXGW WenKai (霞鹜文楷, 0.96.0) -- the project previously had no font configured at all, so Godot fell back to its built-in font, which lacks a curated CJK glyph set and read inconsistently for the game's Chinese text. Downloaded `LXGWWenKai-Regular.ttf` from the font's official GitHub release (SIL Open Font License 1.1, freely embeddable/redistributable in commercial software -- see `ASSET_PROVENANCE.md`/`THIRD_PARTY_NOTICES.md`) into `assets/fonts/`, wrapped it in a new `Theme` resource (`assets/theme/default_theme.tres`) with `default_font` set, and pointed `project.godot`'s `gui/theme/custom` at that theme -- this is the correct Godot 4 mechanism for a true project-wide default font (setting a font directly on individual controls would only affect those controls). Required a `--headless --import` pass to generate the font's import metadata before the theme resource could resolve it. Verified via a rect-dump script (the same technique used to catch 0.88.0's real choice-screen overflow bug) that no label overflows its container with the new font's different glyph metrics on the character sheet, the screen with the most simultaneous body text.

As of 2026-07-25, 流云剑法/断岳刀法 were converted from innate combat techniques into normal learnable/equippable/levelable moves (0.95.0), reverting 0.94.0's special-cased treatment per user feedback that the distinction was unnecessary. Added `cloud_sword`/`blade_technique` entries to `WuxueRules.MOVES` (price 120 each, matching the game's cheapest existing move tier while staying above the 100-silver starting-poor test fixture to avoid an exact-match affordability coincidence); removed `WuxueRules.INNATE_MOVES` and its special-cased row in `options_library()` entirely, since these two now flow through the same learned_moves/equipped_moves path as 裂石拳/暗夜三刀. `_cloud_skill()`/`_blade_skill()` in `battle_engine.gd` gained the same `"X" not in Array(player.get("equipped_moves", []))` gate `_stone_splitting_fist()` already had; `cloud_damage_range()`/`blade_damage_range()` (and `_cloud_skill()`'s own inline duplicate formula) gained a `WUXUE_RULES.move_damage_bonus()` term so leveling these two now actually raises their damage, guarded by a same-seed-RNG before/after test matching this session's established pattern for catching "preview formula updated, inline formula forgotten" bugs. `tactical_battle_view.gd`'s action bar now only shows the 流云剑法/断岳刀法 buttons when equipped, exactly like it already did for 裂石拳/暗夜三刀.

**A fresh save now starts with zero equipped combat moves** (no 流云剑法, no 断岳刀法, no anything) until the player visits 秘籍阁 -- a deliberate, explicitly-accepted consequence of "make these exactly like every other wuxue art," not an oversight. `character sheet`'s "武学" card was reworded to describe whatever's actually equipped (or a "尚未装备" placeholder) instead of unconditionally describing 流云剑法/断岳刀法 as always-known.

Every test that called `player_action(..., "skill"/"blade_skill", ...)` or asserted the action-bar buttons' presence needed `equipped_moves` set explicitly first -- `test_battle_engine.gd`'s shared `_player_fixture()` helper now defaults to equipping both (individual equip-gate tests override it), while `test_combat_feedback_view.gd`/`test_qingyun_spar_view.gd`/`_capture_store_screenshots()` each equip what they specifically need. `test_wuxue_rules.gd`'s 藏经阁 tests and `test_manuals_view.gd`'s poor-affordability-gating count were both updated for the catalog's two new entries.

As of 2026-07-25, four changes shipped together in 0.94.0:

1. **淬炼/forge_level removed entirely.** It had been dead weight since 0.81.0 removed the only recipe (淬炼青锋) that could ever increment it -- new saves always had `forge_level: 0` with no way to raise it, only pre-0.81 saves carried a nonzero leftover value. Removed the field from `new_game()`/migration, its `* 2` contribution to `GameState.power()`, its addition in all 5 `battle_engine.gd` damage formulas, and its character-sheet display line. `CraftingRules.MAX_FORGE_LEVEL` (now unused) was deleted too.
2. **藏经阁 shows the two innate combat techniques.** 流云剑法/断岳刀法 are hardcoded always-available battle actions, never part of `WuxueRules.MOVES` -- added a new `WuxueRules.INNATE_MOVES` list and prepended their rows to `options_library()`, scaled by swordsmanship/bladesmanship specialty rank (via `TRAINING_RULES.specialty_rank_name()`) rather than a wuxue level, since that's what actually governs their strength.
3. **基础内功/基础身法 baseline arts.** Every hero now starts already knowing a baseline internal art (`foundational_qi`, +1 damage) and lightness skill (`basic_footwork`, +0 move bonus -- deliberately no bonus at all, so a real 秘籍阁 purchase stays a genuine upgrade rather than a sidegrade) via new entries in `WuxueRules.INTERNAL`/`LIGHTNESS` with `price: 0`. `new_game()` learns and equips both by default; `_migrate_and_validate()` retroactively grants them to existing saves as *learned* (never force-equipping over a save's real existing choice, only auto-equipping if nothing is currently equipped).
4. **Traveling between locations is free.** `GameState.travel()` no longer calls `spend_action()` -- moving between cities/locations on the world map never spends the week's one action, unlike training/gathering/crafting/battles. Still blocked once the two-year deadline is reached.

Tests touched extensively: `test_battle_engine.gd`/`test_crafting_rules.gd`/`test_character_view.gd` had stale `forge_level` fixture keys and a `淬炼层数` display assertion removed; `test_wuxue_rules.gd` gained coverage for the innate-technique rows and baseline-art bonus values, and its bare bulk `options_manuals()` affordability check was adjusted to exclude the two free (`price: 0`) baseline entries; `test_game_state.gd` gained a dedicated free-travel test and had three migration/power assertions updated to reflect the new baseline-art defaults (a save with no wuxue fields now equips the baseline art instead of staying blank, and a fresh save's `WUXUE_RULES.learn_internal()` power delta is now measured against the baseline's damage bonus, not zero).

As of 2026-07-25, a new independent character-level system was added (0.93.0), deliberately separate from the pre-existing 境界 (cultivation rank) system -- 境界 only ever grants an abstract `combat_bonus` baked into damage formulas, while the new level grants real, permanent attribute points. Both share the same 修为/xp resource, so every existing xp source (training, sparring, chapter rewards) feeds the new level automatically with zero new UI needed to earn it. `GrowthRules.LEVEL_XP_STEP := 25`; `character_level(xp)` is a pure display function of total xp (no cap, matching how other attribute sources are already uncapped); `grant_xp(state, amount)` is the new single choke point that adds xp AND applies +1 to all four base attributes (plus constitution's usual +3 max/current hp) for every level crossed, returning how many were gained. Every direct `xp +=`/`xp =` mutation across `game_state.gd`, `growth_rules.gd`'s own `apply_training()`, and `reward_rules.gd`'s `apply_choice()` was replaced with a `grant_xp()` call -- this was the main hunt of this change, since xp had previously been mutated directly from several different places.

A real migration subtlety, caught before shipping by tracing through the design rather than by a failing test: `state.character_level` tracks how many levels have already been PAID OUT in attributes, separate from `character_level(xp)`'s pure calculation -- a save from before this feature existed already has a lot of accumulated xp with zero levels ever paid out under the old model. If `grant_xp()` naively diffed "level implied by new total xp" against "level implied by old total xp" the very first time a legacy save gained any xp after this patch, it would retroactively back-pay a large, jarring pile of free attribute points all at once. Fixed by defaulting a missing `character_level` field to the level the **post-gain** xp total already implies (not to 1), so a legacy save simply starts tracking forward from wherever it already was, never receiving a retroactive lump payout. `new_game()` explicitly seeds `character_level: 1` so genuinely fresh saves never hit this fallback path at all; `_migrate_and_validate()` seeds it explicitly for old saves missing the field, matching the same lazy-default logic for consistency.

`test_growth_rules.gd` covers: no level/attribute change below a full xp step, exactly one level gained crossing exactly one step, multiple levels gained from a single large xp gain in one call, and the legacy-save no-back-pay case explicitly (a fixture with accumulated xp but no `character_level` field must gain 0 levels on its first xp gain after this patch). The character sheet (`_show_character()`) gained a new summary line showing the level and xp remaining to the next one.

As of 2026-07-25, 炼药坊/锻造坊 crafting now spends the week's one action too (0.92.0), matching every other time-consuming action -- it had been instant/unlimited since 0.70.0. `GameState.craft()` gained the same "validate before spending" guard already used by `complete_training()`/`train_wuxue()`: `can_craft(data, recipe_id)` is checked first, then `spend_action()`, so an unaffordable craft attempt never wastes the week. The two hotspot handlers in `main.gd` (`"workshop"`/`"forge"`) gained the same entry-level `acted_this_week` gate as `"train"`/`"gathering"`, and the failure toasts now mention "or you've already acted this week" alongside the existing material-shortage reasons. `_verify_crafting_flow()` and `test_game_state.gd` needed `end_week()` calls inserted between what used to be back-to-back craft/battle calls in the same week; `test_crafting_view.gd` gained a new section confirming a real craft blocks re-entering either building until `end_week()`.

As of 2026-07-25, 藏经阁 (`"library"` hotspot at 青云门) no longer opens the fixed one-off 玄铁令 story dialogue (0.91.0) -- it now opens a read-only `choice` screen (`choice_event == "library"`) listing every learned move/internal/lightness art via `WuxueRules.options_library()`, each row disabled (informational only, no train/equip/upgrade actions from here) and showing its level and equipped state. A placeholder row appears if nothing is learned yet. New test `tests/test_library_view.gd`; `test_wuxue_rules.gd` extended to cover the empty-state placeholder and the equipped-state label.

As of 2026-07-25, `HerbariumRules.collection_text()`/`MineralogyRules.collection_text()` no longer hide undiscovered specimens behind "？？？" (0.90.0) -- every specimen's real name is always shown, with its count (0 if not yet found). `test_herbarium_rules.gd`/`test_mineralogy_rules.gd` were updated accordingly.

As of 2026-07-25, `inventory_text_alchemy()`/`inventory_text_forge()`'s prompt lines merged their generic material count and named 药谱/矿谱 collection into a single "材料：" line each (0.89.0) -- previously shown as two separate concepts ("药材 N" on one line, "药谱：..." on another), which read as if generic herbs and named specimens were different resource pools even though both are just backpack materials to the player.

As of 2026-07-25, two real bugs shipped together in 0.88.0. First: `UI_THEME.action_button()` (shared by every `ChoiceView` screen) never wrapped its text or constrained its horizontal size, so once a row's combined title+description text grew long enough (as 炼药坊's specimen-note text did), the whole button -- and therefore its parent `VBoxContainer` panel, which auto-sizes to its widest child -- ballooned far past its intended 830px width, pushing content off the right edge of the 1280px window ("显示偏右"). Fixed by giving `action_button()` `size_flags_horizontal = Control.SIZE_EXPAND_FILL` and `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`, which lets the container clamp button width to its assigned size and wrap text within it instead of growing unbounded -- this is a shared helper, so the fix benefits every choice screen (market, training, workshop, forge), not just alchemy. Second: 霹雳石 (`thunder_stone`) was removed from `CraftingRules.RECIPES` entirely per "锻造坊拿掉霹雳石，淬炼" -- it remains purchasable at 西市's 杂货铺 (`ShopRules.GOODS` already listed it) and fully usable in battle, only the 锻造坊 forging path is gone. `inventory_text_forge()` also dropped its 霹雳石 count and 淬炼 (`forge_level`) line, since neither is tied to any recipe 锻造坊 still offers. `_verify_crafting_flow()` and `test_game_state.gd` were updated to buy 霹雳石 via `ShopRules.buy_good()` instead of crafting it.

As of 2026-07-25, `CraftingRules.inventory_text()` was split into `inventory_text_alchemy()`/`inventory_text_forge()` (0.87.0): 炼药坊's choice prompt shows only 药材/银两/回春散/attribute stats/药谱, never ore or 矿谱; 锻造坊's shows only 矿石/银两/霹雳石/淬炼层数/矿谱, never herbs or 药谱. `_gear_row()` (锻造坊's own weapon/armor row builder) also dropped its always-zero "药材0" prefix, now showing only "矿石N" per row.

As of 2026-07-25, 锻造坊's three gear recipes (`twin_edge_saber`/`rattan_guard`/`layered_iron_armor`) became ore-only (0.86.0) -- their herb costs were removed and folded into higher ore costs (e.g. 双刃寒锋 went from herbs2+ore8 to ore10 flat) so 炼药坊 consumes only herbs and 锻造坊 consumes only ore, matching the buildings' own verbs cleanly. `test_crafting_rules.gd`'s smith/armorer/master_smith blocks were updated to assert herbs alone can no longer afford any forge recipe.

As of 2026-07-25, 炼药坊/锻造坊 recipes gained named-specimen requirements (0.85.0): 悟性丹/身法丹 each need one 云纹叶 (`cloudleaf`), 根骨丹 needs both 云纹叶 and 赤阳参 (`sunroot`), 双刃寒锋 needs one 流银砂 (`silver_sand`), and 叠层甲胄 needs both 流银砂 and 赤火铜 (`fire_copper`) -- reusing the SAME named items 采药/挖矿 already roll into `state.herbarium`/`state.mineralogy` via `HerbariumRules.record()`/`MineralogyRules.record()` (previously pure collection/flavor XP with no crafting purpose). `CraftingRules.RECIPES[id].cost` gained a `specimens: {id: qty}` dict alongside the existing `herbs`/`ore`/`silver` fields -- most recipes have an empty dict (unaffected), a few need exactly one named specimen, and the two "advanced" gear recipes need two distinct specimens at once, deliberately mixing requirement shapes rather than picking one pattern for every recipe. `can_craft()`/`apply()` check/consume specimens via a `_collection_field(id)` helper that looks the id up in `HerbariumRules.SPECIMENS`/`MineralogyRules.SPECIMENS` to route to the right collection dict -- specimen ids are unique across both catalogs by construction, so no explicit "which collection" tag is stored per-recipe. The flat generic `herbs`/`ore` pool (still tradeable at 西市's 杂货铺, still granted by training events) is untouched and unrelated -- specimens are an ADDITIONAL requirement layered on top, not a replacement. `test_crafting_rules.gd` covers each specimen-gated recipe's block/unblock transition and that both specimens in a mixed recipe are required (one alone is insufficient) and both fully consumed on craft.

As of 2026-07-25, 青云工坊 was split into two separate buildings: 炼药坊 (alchemy, the herb-based "炼制" recipes -- healing_powder + the four attribute pills) and 锻造坊 (forge, the ore-based "打造" recipes -- thunder_stone + the four workshop weapons/armors), matching the verb the recipe titles already used. `CraftingRules.options()` was split into `options_alchemy()`/`options_forge()`; `RECIPES`/`apply()`/`can_craft()`/`effective_cost()` stayed a single shared dict/set of functions keyed by recipe id, since neither building needed its own data model, just its own filtered option list. Neither building consumes a weekly action (crafting was always instant, unlike training/gathering). The two Steam achievements that referenced "青云工坊" in their description text (`ACH_FIELD_APOTHECARY`/`ACH_FIRST_TEMPER`) were reworded to name the specific new building, since the old generic workshop no longer exists as a single place.

As of 2026-07-25, the hero may take exactly one time-consuming action per week (travel, training, wuxue practice, gathering, sparring, or any main-quest battle). `GameState.spend_action()` marks `data.acted_this_week = true` and does not advance `data.week` on its own; the player must press the persistent "结束本周" header button, which calls `GameState.end_week()`, to advance to the next week and clear the flag. This replaced the old `energy` pool (3 actions before a forced rest). `rest()` is now itself just another `spend_action()`-gated action rather than a special energy refill. Note this is unrelated to the in-battle "行动点" (2 AP per turn) system, which is unchanged.

To visually review the second first-battle tutorial page from the shipping UI, run the full build with `--capture-tactical-tutorial`. It writes `tactical_tutorial_preview.png` to the Godot user-data folder and exits non-zero if the expected tutorial page was not active.

## Capture Steam store screenshots

After exporting the full Windows release, run the shipping executable with `--capture-store-screenshots`. It creates eight deterministic 1920×1080 gameplay PNGs under the Godot user-data folder in `store_screenshots`. These are candidate captures from the actual release UI; visually review every image before uploading it to Steam.

```powershell
& "..\build\windows\ShanheWendao.exe" -- --capture-store-screenshots
```

Before a public Steam release, review `ASSET_PROVENANCE.md` and `THIRD_PARTY_NOTICES.md`, replace the current provisional application icon only after the final brand and art-rights review, and configure code signing in the Windows export preset.
