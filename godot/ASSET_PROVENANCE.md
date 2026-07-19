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
| `assets/art/locations/qingyun-courtyard.png` | Qingyun location | Cool dawn mountain sect courtyard with lower-center interaction space |
| `assets/art/locations/luoyang-market.png` | Luoyang location | Warm late-afternoon ancient city market and governor residence |
| `assets/art/locations/huashan-terrace.png` | Huashan location | Cool daylight cliff-top sword trial terrace and sea of clouds |
| `assets/art/locations/emei-summit.png` | Emei location | Golden sunrise summit temple and subtly sealed mountain passage |
| `assets/icon/app_icon.png`, `assets/icon/app_icon.ico` | Provisional application icon | Original project icon; replace only after final brand review |

Shared constraints for generated visual assets: no text, logo, watermark, modern objects, third-party characters, or copied brand elements unless the asset's production role explicitly requires project-owned typography.

## Audio assets

The current build does not ship third-party music or sound-effect libraries. Runtime ambience and feedback cues are synthesized by `scripts/audio/cue_synth.gd` and coordinated by `autoload/audio_feedback.gd`.

## Review procedure

Before a public release, visually inspect every shipping image at native resolution, verify this register matches the export, and retain the selected source files and production prompts in the project's controlled development records.
