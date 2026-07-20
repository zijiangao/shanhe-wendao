# Asset provenance

This register documents the production origin of visual and audio assets shipped with **Shanhe Wendao**. It is maintained for release review and must be updated whenever a shipping asset is added or replaced.

## Visual assets

All files below were created specifically for this project under human art direction using OpenAI's built-in image-generation tool, then selected and integrated by the project developer. They are not scans, screenshots, or copies of third-party games, films, paintings, brands, or characters.

| Shipping files | Production purpose | Prompt direction summary |
| --- | --- | --- |
| `assets/art/jianghu-world-map.png` | World map | Wide Chinese ink-wash jianghu map with readable travel nodes and parchment texture |
| `assets/art/luoyang-battle-rain.png` | Tactical battle backdrop | Empty ancient Luoyang plaza at night in rain, dark readable center, warm lantern accents |
| `assets/art/portrait-*.png` | Original character portraits | Original wuxia characters, consistent painterly rendering, no existing-person likeness requested |
| `assets/art/battle-tokens.png` | Tactical unit atlas | Original simplified unit tokens prepared for grid readability |
| `assets/art/ui-source/title-wordmark-black.png` | Title-screen wordmark source | Original four-character ink-brush calligraphy with a subtle gold rim on flat black |
| `assets/art/ui-source/panel-frame-chroma.png` | Stretchable UI panel source | Aged parchment and lacquer frame with restrained gold corners on chroma green |
| `assets/art/ui-source/button-states-chroma.png` | Three-state button atlas source | Matching normal, hover, and pressed ink-wash frames on chroma green |
| `assets/art/ui-source/map-marker-states-black.png` | World-map marker atlas source | Original inactive, current, and unknown painted banner markers on flat black |
| `assets/art/ui-source/top-nav-icons-black.png` | Top-navigation icon atlas source | Six original monochrome ink-brush navigation symbols on flat black |
| `assets/art/ui-source/achievement-badge-states-black.png` | Achievement frame atlas source | Matching locked and unlocked ornamental medallion frames on flat black |
| `assets/art/ui-source/item-icons-sheet-black.png` | Shop/backpack item icon atlas source | Ten original monochrome ink-brush icons (three weapons, three armors, four tradeable goods matching the shop's item catalog) on flat black |
| `assets/art/locations/qingyun-courtyard.png` | Qingyun location | Cool dawn mountain sect courtyard with lower-center interaction space |
| `assets/art/locations/luoyang-market.png` | Luoyang location | Warm late-afternoon ancient city market and governor residence |
| `assets/art/locations/huashan-terrace.png` | Huashan location | Cool daylight cliff-top sword trial terrace and sea of clouds |
| `assets/art/locations/emei-summit.png` | Emei location | Golden sunrise summit temple and subtly sealed mountain passage |
| `assets/icon/app_icon.png`, `assets/icon/app_icon.ico` | Provisional application icon | Original project icon; replace only after final brand review |

Shared constraints for generated visual assets: no text, logo, watermark, modern objects, third-party characters, or copied brand elements unless the asset's production role explicitly requires project-owned typography.

### Processed UI derivatives

The six `ui-source/*.png` files above were generated on a flat chroma backdrop (green or black) for easy background removal, matching this project's existing `battle-tokens-chroma.png` → `battle-tokens.png` workflow. Each was processed into one or more shipping files under `assets/ui/` using a border-flood-fill chroma key (only background pixels connected to the image edge are removed, so dark ink/gold detail inside the artwork itself is preserved) with green-spill suppression where needed, then cropped to its final bounds. Multi-subject sheets were split into individual files by clustering their connected components. No new prompting, generation, or creative content was introduced in this step — it is mechanical background removal and cropping of the six source files.

| Shipping files | Derived from |
| --- | --- |
| `assets/ui/logo_wordmark.png` | `ui-source/title-wordmark-black.png` |
| `assets/ui/panel_frame.png` | `ui-source/panel-frame-chroma.png` |
| `assets/ui/button_frame_normal.png`, `button_frame_hover.png`, `button_frame_pressed.png` | `ui-source/button-states-chroma.png` (3-way split) |
| `assets/ui/map_marker_visited.png`, `map_marker_current.png`, `map_marker_locked.png` | `ui-source/map-marker-states-black.png` (3-way split) |
| `assets/ui/achievement_badge_locked.png`, `achievement_badge_unlocked.png` | `ui-source/achievement-badge-states-black.png` (2-way split) |
| `assets/ui/nav_icon_map.png`, `nav_icon_quest.png`, `nav_icon_character.png`, `nav_icon_achievement.png`, `nav_icon_save.png`, `nav_icon_settings.png` | `ui-source/top-nav-icons-black.png` (6-way split) |
| `assets/ui/item_iron_sword.png`, `item_cold_crow_blade.png`, `item_dragon_etched_sword.png`, `item_hedgehog_mail.png`, `item_dark_iron_armor.png`, `item_cold_jade_armor.png`, `item_herbs.png`, `item_ore.png`, `item_healing_powder.png`, `item_thunder_stone.png` | `ui-source/item-icons-sheet-black.png` (10-way split) |

## Audio assets

The current build does not ship third-party music or sound-effect libraries. Runtime ambience and feedback cues are synthesized by `scripts/audio/cue_synth.gd` and coordinated by `autoload/audio_feedback.gd`.

## Review procedure

Before a public release, visually inspect every shipping image at native resolution, verify this register matches the export, and retain the selected source files and production prompts in the project's controlled development records.
