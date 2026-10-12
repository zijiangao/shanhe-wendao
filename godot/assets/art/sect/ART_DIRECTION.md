# Qingyun Sect art direction

Generated on 2026-10-12 with the built-in `image_gen` tool in imagegen skill default mode. No CLI/API fallback was used. Each asset was generated with one tool call, copied from the returned generated-image path, and visually inspected. No cropping, recoloring, resizing or other image processing was applied.

## Assets and references

| Workspace asset | Pixels / format | Visual role |
| --- | --- | --- |
| `qingyun-estate.png` | 1672 × 941, RGB PNG | Empty symmetrical mountain estate: central main axis and paired stone platforms. Buildings must be separate runtime overlays. |
| `buildings-atlas.png` | 1254 × 1254, RGBA PNG | Nine separate building sprites. Genuine transparent alpha is preserved. |
| `../portrait-gu-changfeng.png` | 1086 × 1448, RGB PNG | Original master Gu Changfeng portrait with pale paper-and-mountain background. |

Existing references were inspected with `view_image` before generation:
- `../locations/qingyun-courtyard.png`: mountain atmosphere, blue-gray stone and roof colors, wood materials and painterly realism.
- `../portrait-shen-yu.png`: portrait brush texture, pale paper and mountain haze, muted palette.

The background also used the newly generated atlas as a perspective/material reference. References guide style only; the background does not bake in buildings and the new portrait represents a separate original character.

## Atlas usage

The requested layout was an equal 3 × 3 atlas; the generated result has nine isolated images in that ordering, but the first main hall is wider than a mathematical third of the canvas. **Do not use uniform 418 × 418 regions**, which would clip the main hall and pick up neighboring pixels. Use explicit nonuniform `AtlasTexture.region` rectangles on the unmodified atlas.

These visually inspected safe region bounds are a starting point (origin at the top left, x/y/width/height in pixels):

| Order | Building | Suggested rect |
| --- | --- | --- |
| 0 | 正殿 / main hall | `Rect2(0, 0, 500, 470)` |
| 1 | 藏经阁 / scripture library | `Rect2(500, 0, 350, 470)` |
| 2 | 炼药坊 / alchemy workshop | `Rect2(850, 0, 404, 470)` |
| 3 | 演武场 / training arena | `Rect2(0, 470, 449, 388)` |
| 4 | 锻造坊 / forge | `Rect2(449, 470, 401, 388)` |
| 5 | 客栈 / inn | `Rect2(850, 470, 404, 388)` |
| 6 | 药圃 / herb garden | `Rect2(0, 858, 449, 396)` |
| 7 | 山门 / mountain gate | `Rect2(449, 858, 401, 396)` |
| 8 | 营造亭 / construction pavilion | `Rect2(850, 858, 404, 396)` |

The generating source has a few thin red pixels along some base edges. They are source-image artifacts, not atlas region lines; the source was kept unprocessed. Review at the actual in-game sprite scale. All buildings remain separate and readable with the explicit regions.

## Original tool outputs

- Atlas: `C:/Users/gaozi/.codex/generated_images/01a12edd-4212-7763-9551-11122c59da5e/exec-f772ebfa-df8c-43cb-a019-f834734f49c2.png`
- Estate: `C:/Users/gaozi/.codex/generated_images/01a12edd-4212-7763-9551-11122c59da5e/exec-ae1b77e7-7629-48b3-8a5f-412b1dd67f27.png`
- Gu Changfeng: `C:/Users/gaozi/.codex/generated_images/01a12edd-4212-7763-9551-11122c59da5e/exec-fc025e3d-f5e5-4a98-8501-a98a93ba4f11.png`

## Final prompt: buildings-atlas.png

```text
Use case: stylized-concept
Asset type: one single square transparent 3-by-3 sprite atlas for the Chinese wuxia game Shanhe Wendao. This is a production game sprite sheet, NOT a scene or UI mockup.
Primary request: Draw nine distinct Qingyun Sect building sprites, each strictly centered within its own equally-sized square cell of an invisible 3 by 3 grid. The entire canvas is square. Nine cells, exactly three columns and three rows. Do not draw grid lines or labels. Every sprite has large transparent margins, and no sprite or shadow may cross or touch the boundaries of its cell.
Input image: qingyun-courtyard.png is a STYLE AND PALETTE REFERENCE ONLY; do not reproduce its full scene.
Required exact ordering, read left to right and top to bottom:
Row 1 column 1: the main hall, dignified two-tier Chinese wooden palace with blue-gray upturned tiled roof and stone entrance stairs.
Row 1 column 2: the scripture library, a compact tall two-story wooden pavilion with visible book shelves through an open doorway, blue-gray tiled roofs.
Row 1 column 3: the alchemy workshop, a compact single-story traditional house with clay medicine jars and a small bronze cauldron at its entrance.
Row 2 column 1: the training arena, a low square stone platform with three wooden martial arts training posts, no roof or enclosing building.
Row 2 column 2: the forge, an open-sided traditional workshop with a clearly visible glowing furnace, anvil and tools under a blue-gray tiled roof.
Row 2 column 3: the inn, a welcoming compact two-story wooden inn with warm lanterns and blue-gray tiled roof.
Row 3 column 1: the medicinal herb garden, ordered raised beds of green herbs, a few purple and pale flowers, low stone edging, no roof.
Row 3 column 2: the mountain gate, a freestanding three-opening wooden ceremonial Chinese paifang archway with blue-gray tiled roof on stone feet, absolutely no signs or writing.
Row 3 column 3: the construction pavilion, a small open-sided wooden roof shelter with timber stack, mallet, saw and stone blocks visibly stored beneath.
Style/medium: polished painterly realistic wuxia game concept art, delicate brush textures, crisp readable silhouettes at small scale, muted blue-gray roofs, weathered warm brown timber, pale gray stone bases and restrained amber lantern light. Match the reference atmosphere and materials.
Composition/framing: all nine buildings share the same elevated nearly isometric view, seen from the front at roughly 35 degrees downward; identical perspective and illumination. Each isolated sprite appears on its own modest rectangular/diamond-shaped pale stone base where applicable. Fit the entire shape comfortably within its equal cell, with about 18 percent clear transparent inset from every cell edge. Main hall may be broader but must not overlap adjacent cells.
Lighting/mood: soft daylight from upper left, restrained short ground shadows wholly within each sprite's cell.
Background: genuinely transparent alpha, including all margins and gutters. Do not paint a checkerboard, paper, sky or solid background.
Constraints: exactly nine sprites, exact grid ordering, square whole image, no people, no animals, no lettering, no numbers, no labels, no watermark, no frame; no extra assets outside the nine cells. These sprites will be cropped by fixed equal 3x3 cells without image editing.
```

Tool options: `transparent_background: true`; `referenced_image_paths: ["C:/Users/gaozi/OneDrive/Documents/game/godot/assets/art/locations/qingyun-courtyard.png"]`.

## Final prompt: qingyun-estate.png

```text
Use case: stylized-concept
Asset type: a panoramic wide 16:9 background image for a playable Chinese wuxia sect estate screen.
Primary request: An EMPTY Qingyun Sect mountaintop estate terrain prepared for independent building sprites to be overlaid later. Draw the mountain, gardens, stone platforms, central pathway and symmetrical stone steps, with absolutely NO BUILDINGS on any platform.
Input images: qingyun-courtyard.png is a reference for painterly realism, muted blue-gray materials, pine-covered mountain atmosphere and soft mist ONLY, not for the composition. buildings-atlas.png is a reference for the elevated view and compatible stone/material palette ONLY; no buildings from it may appear in this background.
Scene/backdrop: a spacious terraced Chinese mountain estate on a high plateau, surrounded by pine trees and layered misty mountains. Pale weathered stone paving with restrained decorative edging. Symmetrical central main axis rising from the bottom center toward the upper center; matching left and right terraces and steps.
Composition/framing: wide panoramic 16:9, elevated almost-isometric view from above front, approximately 35 degrees downward, to match isometric building sprites. Show a spacious central clear stone court in the center and several generous EMPTY rectangular stone platforms arranged in balanced left/right pairs. A large empty central upper platform is reserved for the main hall. Left middle and right middle open platforms each big enough for a compact pavilion. Left lower and right lower open platforms each big enough for another pavilion. Two additional empty side platforms and a central lower landing create a symmetrical planned estate. Keep the middle 75 percent of the frame uncluttered with usable paving to allow up to nine building sprites. Platforms must look empty; do not draw placeholder buildings, silhouettes or ruins.
Style/medium: polished painterly realistic wuxia game environment, subtle brush texture and delicate realistic stone, lush dark green pines concentrated around frame edges, soft cloud mountains in the top third. Compatible with the reference artwork.
Lighting/mood: soft warm morning light from upper left, quiet mountain calm, gentle blue mountain fog behind the plateau; clear and bright enough to read dark-roof building sprites.
Color palette: pale gray stone, subdued blue-green vegetation, blue-gray mountain mist, restrained cream sky. Buildings will have gray tiled roofs and brown timber, so leave light paving beneath them.
Constraints: absolutely no architectural buildings anywhere: no houses, palaces, pagodas, pavilions, archways, gates or roofs. No people, no animals, no banners, no text, no map labels, no user interface, no watermarks, no frame. Stone steps, stone terrace edges, paving, natural boulders and vegetation only. Symmetrical left/right spatial layout, open central axis.
```

Tool options: `transparent_background: false`; `referenced_image_paths: ["C:/Users/gaozi/OneDrive/Documents/game/godot/assets/art/locations/qingyun-courtyard.png", "C:/Users/gaozi/OneDrive/Documents/game/godot/assets/art/sect/buildings-atlas.png"]`.

## Final prompt: portrait-gu-changfeng.png

```text
Use case: stylized-concept
Asset type: original character portrait for the Chinese wuxia game Shanhe Wendao, portrait aspect ratio about 3:4.
Primary request: Qingyun Sect master Gu Changfeng (顾长风), an original Chinese male martial arts master aged 55 to 60, calm, experienced, dignified and authoritative without aggression.
Input image: portrait-shen-yu.png is a STYLE, TEXTURE AND COLOR REFERENCE ONLY. Make a clearly older distinct character with his own face, not an aged copy of the young man.
Subject: an East Asian Chinese man with a mature lean face, natural age lines at the eyes, intelligent calm dark brown eyes, long black hair streaked with silver-gray tied in a neat high traditional hair knot, a short neatly kept salt-and-pepper mustache and beard. He wears layered modest blue-gray Daoist robes, a pale inner collar and subtle traditional woven cloth detailing. No armor. Upright but relaxed posture, shoulders and upper torso visible, one hand lightly resting near his waist. His expression conveys patient guidance and the gravity of leadership.
Scene/backdrop: pale warm xuan paper with faint ink-wash distant mountain peaks and mist, low contrast and unobtrusive.
Style/medium: polished painterly realistic Chinese wuxia illustration with delicate brush texture and soft paper grain, detailed believable face and fabric, compatible with the reference image's muted tones and realism.
Composition/framing: vertical 3:4 portrait, waist-up half-body. Character centered with head comfortably below the top edge and both shoulders contained, face roughly in the upper third, slight three-quarter angle looking toward the viewer. Keep the head and beard fully visible. Clean silhouette against pale misty background.
Lighting/mood: soft diffuse daylight, restrained warm facial highlights, serene and dignified.
Color palette: slate blue-gray robes, soft aged ivory background, dark brown eyes, black and silver hair; restrained neutral materials.
Constraints: no weapons in hands, no armor, no extravagant gold crown, no young face, no smiles showing teeth, no other people, no text, no signatures, no logos, no watermark, no border. Original fictional character.
```

Tool options: `transparent_background: false`; `referenced_image_paths: ["C:/Users/gaozi/OneDrive/Documents/game/godot/assets/art/portrait-shen-yu.png"]`.

## Additional sect disciples

Generated with the same built-in tool on 2026-10-12, one call per original character portrait. These replace the practice of sharing another character's portrait. Both outputs were visually inspected and copied unchanged.

| Workspace asset | Pixels / format | Visual role |
| --- | --- | --- |
| `../portrait-zhou-mubai.png` | 1086 × 1448, RGB PNG | Zhou Mubai: adult male Qingyun swordsman, deep teal robes, calm steadfast expression and sheathed sword. |
| `../portrait-liu-ruyan.png` | 1086 × 1448, RGB PNG | Liu Ruyan: adult female Qingyun disciple, blue-green light robes, low tied hair and cloth ribbons. |

The existing `../portrait-lin-qingshuang.png` reference was also inspected with `view_image` before Liu Ruyan's generation. Previously inspected Shen Yu and the newly inspected/generated Gu Changfeng images were style references; the prompts explicitly requested new character identities.

Original tool outputs:
- Zhou Mubai: `C:/Users/gaozi/.codex/generated_images/01a12edd-4212-7763-9551-11122c59da5e/exec-fd46e7c7-9351-45d4-8217-0e4d28adb59f.png`
- Liu Ruyan: `C:/Users/gaozi/.codex/generated_images/01a12edd-4212-7763-9551-11122c59da5e/exec-2f710554-59a6-4fcc-9967-d5f107b59f9d.png`

## Final prompt: portrait-zhou-mubai.png

```text
Use case: stylized-concept
Asset type: original character portrait for the Chinese wuxia game Shanhe Wendao, vertical 3:4.
Primary request: Zhou Mubai (周慕白), an original adult Chinese man aged about 25, a Qingyun Sect swordsman known for steady protective defense and gentle determination.
Input images: portrait-shen-yu.png and portrait-gu-changfeng.png are STYLE AND PALETTE references only. Do not reuse either character identity or copy their face, pose, outfit or hair silhouette.
Subject: an East Asian Chinese adult man with a clearly distinct broad oval face, strong but friendly brow, calm almond-shaped brown eyes, a slightly squared jaw and a straight substantial nose; clean shaven. His dark hair is neat, fully pulled into a compact traditional topknot with a plain dark cloth tie, not loose windswept hair. He wears practical deep teal Qingyun sect robes over a cream inner collar, a broad woven cloth sash, restrained wrist wraps, no armor. A simple Qingfeng longsword remains safely sheathed at his waist, its understated steel-and-jade hilt visible. Upright composed bearing and a gentle resolute expression.
Scene/backdrop: aged ivory xuan paper, pale ink-wash distant mountain peaks and soft cloud mist.
Style/medium: painterly realistic Chinese wuxia portrait, delicate traditional brush texture, natural subtle paper grain, highly readable original face and believable cloth; match the references' restrained slate and teal colors.
Composition/framing: waist-up half-body portrait, both shoulders and the head fully inside the 3:4 frame. Slightly turned torso, nearly front-facing head looking calmly at the viewer. Face in the upper third and generous pale background around the head. Sword is sheathed at the lower side, no combat pose.
Lighting/mood: soft diffuse mountain daylight with warm skin highlights, calm and trustworthy.
Constraints: original fictional adult character, different face from Shen Yu and Gu Changfeng; no text, writing, logo, signature, watermark, border, other characters, exaggerated muscles, ornate armor or giant weapon.
```

Tool options: `transparent_background: false`; `referenced_image_paths: ["C:/Users/gaozi/OneDrive/Documents/game/godot/assets/art/portrait-shen-yu.png", "C:/Users/gaozi/OneDrive/Documents/game/godot/assets/art/portrait-gu-changfeng.png"]`.

## Final prompt: portrait-liu-ruyan.png

```text
Use case: stylized-concept
Asset type: original character portrait for the Chinese wuxia game Shanhe Wendao, vertical 3:4.
Primary request: Liu Ruyan (柳如烟), an original adult Chinese woman aged about 23, a Qingyun Sect disciple with an agile composed bearing.
Input images: portrait-lin-qingshuang.png and portrait-gu-changfeng.png are STYLE AND PALETTE references only. Do not copy Lin Qingshuang's identity, facial features, costume, high hair ornament, silhouette or pose.
Subject: an East Asian Chinese adult woman with a distinct softly rounded heart-shaped face, warm brown monolid/almond eyes, a small rounded nose, softly arched eyebrows and a quietly confident neutral mouth. Her long black hair is tied into a low ponytail with simple muted green cloth ribbons; wisps frame the cheeks, no crown or metallic hair ornament. She wears lightweight layered blue-green/teal martial arts robes with a simple ivory collar, fitted woven sash and practical soft cloth wrist bindings. A fine slim flexible jian sword is sheathed at her waist; show only the modest narrow hilt and a little slender scabbard. Her posture is poised and relaxed, conveying alert intelligence and calm rather than an exaggerated action pose.
Scene/backdrop: pale warm ivory xuan paper with a few distant ink-wash mountain shapes and soft drifting cloud mist.
Style/medium: polished painterly realistic Chinese wuxia portrait with subtle brush strokes, realistic face and delicate paper grain, compatible with the references.
Composition/framing: vertical 3:4, waist-up half-body; face in the upper third, head and both shoulders comfortably contained in the frame. Slight three-quarter turn of torso and a gentle direct gaze, the low ponytail and cloth ribbons distinguish her silhouette from the reference heroine.
Lighting/mood: soft diffuse daylight, serene and quietly lively.
Color palette: muted blue-green light robes, ivory cloth, black hair and warm brown eyes, pale cream mist background.
Constraints: original fictional adult woman, distinct face and silhouette from Lin Qingshuang; modest practical robe silhouette, no bare midriff, no elaborate armor, no open sword blade, no text, logos, signatures, watermark, border or other people.
```

Tool options: `transparent_background: false`; `referenced_image_paths: ["C:/Users/gaozi/OneDrive/Documents/game/godot/assets/art/portrait-lin-qingshuang.png", "C:/Users/gaozi/OneDrive/Documents/game/godot/assets/art/portrait-gu-changfeng.png"]`.
