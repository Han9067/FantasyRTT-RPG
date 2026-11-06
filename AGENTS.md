# Project conventions

- Current release: 0.0.19; next completed update: 0.0.20. Increment only the patch once per delivered game update. Never change the first two components unless asked.
- Validate playable changes, push editable source to main, and publish builds/web to gh-pages for the existing GitHub Pages site.
- The visual source of truth is the purchased user-supplied MedievalFantasyCharacters.zip. Read docs/character-design.md before changing characters.
- Preserve loose source PNGs in art/medieval (.gdignore). Build assets/medieval atlases/catalog with tools/build_medieval_atlas.py; do not hand-edit generated images. Runtime uses only needed parts. Preserve original RGBA; no AI redraws, recolouring or resampling.
- The creator has personal details only at the top, and a portrait on the lower left with two columns of part selectors without scrolling (beard/beard color/weapon at upper right) on the right. Gender is independent of appearance. Creator is human-only; hats/gloves/race have no selectors. Bare hands follow skin. The weapon selector cycles only axe_01.png, blunt_01.png, sword_01.png in that order. Keep headgear/glove source assets for future equipment; mounts remain excluded.
- Compose 128x96 frames at integer coordinates; preserve the original 80x56 starter preview crop/scale, expand one shared crop only for larger equipment. Idle/walk/run have 4/8/8 frames; attack has 6 frames at 10fps, matching the weapon-specific chop_attack_sample.gif or thrust_attack_sample.gif with fixed body/head and no extra recovery pause. spear is thrust_attack; every other held weapon uses chop_attack. Preview controls are idle/walk/attack; respect per-frame durations. Head/accessory offsets follow the body. Use nearest filtering. World feet remain at y=320.
- Legacy assets/characters, assets/adventurers, tests/fixtures, and tools/references were explicitly removed by the user. Do not restore them.
- Keep the world map non-interactive and preserve the city/terrain scale and design.
- Run meaningful smoke checks for source integrity, selector boundaries/dependencies, layout, preview animations, and world continuity, then verify the web UI in a browser before publishing.

- Current source tree contains 4,573 files: the cleaned character ZIP with its weapons subtree replaced by the latest weapons.zip (406 PNGs). Numbered filenames replace __rNN_cNN. Full ZIP imports validate in staging and replace old trees; never merge removed files back. Guides live only in art/medieval/Animation Guide.
