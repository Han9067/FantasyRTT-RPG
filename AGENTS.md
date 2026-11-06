# Project conventions

- Current release: 0.0.12; next completed update: 0.0.13. Increment only the patch once per delivered game update. Never change the first two components unless asked.
- Validate playable changes, push editable source to main, and publish builds/web to gh-pages for the existing GitHub Pages site.
- The visual source of truth is the purchased user-supplied MedievalFantasyCharacters.zip. Read docs/character-design.md before changing characters.
- Preserve source PNG bytes/pixels in assets/medieval. catalog.json contains original hashes and Unity sprite rectangles converted to top-left origin. Use original parts; no AI redraws, recolouring or resampling.
- The creator has personal details only at the top, and a portrait on the lower left with vertically scrolling part selectors on the right. Gender is independent of appearance. Weapons/mounts are excluded from this editor.
- Compose 64x64 frames at integer coordinates. Idle/walk/run have 4/8/8 frames; head/accessory offsets follow the body. Use nearest filtering. World feet remain at y=320.
- Legacy assets/characters, assets/adventurers, tests/fixtures, and tools/references were explicitly removed by the user. Do not restore them.
- Keep the world map non-interactive and preserve the city/terrain scale and design.
- Run meaningful smoke checks for source integrity, selector boundaries/dependencies, layout, preview animations, and world continuity, then verify the web UI in a browser before publishing.
