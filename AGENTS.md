# Project conventions

- Main menu and project.godot must show the same release. Current: 0.0.11; next completed update: 0.0.12. Increment only the patch once per delivered request. Never change the first two components without the user asking.
- Validate playable changes, push editable source to main, and publish builds/web to gh-pages for the existing GitHub Pages site.
- The new visual source of truth is the user's char.zip: assets/characters/male/01 and female/01. Read docs/character-design.md before changing characters.
- Only one appearance per gender. Each has one idle and four walking PNGs. Preserve walking1–4 order and the 0.84-second cycle.
- Preserve all uploaded PNG bytes and pixels. The files are 64x64 with identical used bounds (23,17,16,30), binary alpha and a 30-pixel-tall figure. No recolouring, quantizing, resampling, or separate frame fitting.
- These new PNGs are complete characters, not separate head/body layers. Load them directly; do not artificially split them to match an older implementation.
- Preview uses the same AtlasTexture region (20,14,22,36) for every frame. World scale is 1; feet stay at y=320. Use nearest filtering.
- Old assets/adventurers are archival originals only and excluded from export. The previous assets/adventurers_side and procedural generator were retired; do not restore them.
- Keep the world map non-interactive and preserve the city/terrain scale and design.
- Smoke checks must verify uploaded file hashes, exact imported pixels, 1/4 frame counts, both gender selections, preview and world transitions, and foot alignment.
