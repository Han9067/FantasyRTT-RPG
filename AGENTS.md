# Project conventions

- The main menu displays the current release as `버전 : 0.0.N`.
- Current release: 0.0.5. For each subsequent completed user-requested update, increment the last component by one (next: 0.0.6). One increment per delivered update, not per commit or build attempt.
- Never change either of the first two version components unless the user explicitly requests it.
- Keep the project.godot application version and main menu display in sync.
- Deliver playable changes to the existing GitHub Pages site by updating the `gh-pages` branch after validation; keep editable source on `main`.
- Use the user-supplied adventurer artwork in assets/adventurers without redrawing, reshaping, or recolouring it unless explicitly requested. The source orientation supersedes the earlier custom side-profile designs.
- Keep the selection to male 01–04 and female 01–04. The other original layer sheets are retained for future use.
- The body and head are separate aligned 32×36 layers. Compose body then head at (0,0), preserving alpha and nearest filtering.
- Each appearance has 2 idle and 4 walking frames, sampled from the supplied originals. Preserve the original cycle duration.
- The world map is a non-interactive prototype. Preserve the approved city/terrain scale and detailed pixel style.
