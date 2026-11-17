# ЧЕРНОЗЁРЬЕ

Low-poly atmospheric 3D exploration game in Godot 4. A 2 × 2 km prototype based on the real geography of Черноозерский Кордон (Уфа, Башкортостан), with a fixed dusk atmosphere.

## Status
Godot sources are versioned in `godot/`; GitHub Actions builds the Web export for GitHub Pages. Online deployment is configured at https://blacklambcult.github.io/chernozerye/ (check Actions for the latest build status).

## Design constraints
- Geographical scale: 1 world unit = 1 meter.
- Keep real roads, buildings, woodland, lakes, river and fields geographically grounded; do not invent accuracy in places where open data are incomplete.
- Player and landmarks are provisional; real-world correctness must be validated from permitted sources.
- Godot 4, keyboard and mouse FPS exploration; no enemies or combat in the earliest version.
- Web deployment: GitHub Actions → GitHub Pages (after the full project is committed).

## Planned workflow
1. Commit the working Godot project and `world_data.json`.
2. Add a web export preset with Godot Compatibility renderer and a GitHub Actions build.
3. Validate the overhead plan and geodata independently from in-game aesthetics.
4. Gradually improve terrain, forests, buildings and footpaths.

## Sources and licensing
OpenStreetMap data © OpenStreetMap contributors, licensed under ODbL: https://www.openstreetmap.org/copyright

Google Maps imagery is for permitted visual reference only. Do not redistribute or trace copyrighted imagery into project assets without appropriate permission.

## Prototype 0.7 — geographic blockout

New `godot/geography_v07.gd` adds a provisional low-poly settlement, expanded woodland, open meadow, dark river, lake and supplementary narrow streets. The previous sparse/inaccurate OSM buildings and OSM-only forest placement have been disabled. The original OSM road network remains an anchor.

**Accuracy warning:** roads derived from OpenStreetMap are geographically referenced; manually interpreted supplementary streets, house placement, river and forest are *illustrative approximations*, not survey-accurate buildings or shorelines. Screenshots from Google Maps were used only as visual references, not copied into assets or imported as geometry. This release is a recognizable blockout, not a verified 1:1 reconstruction of individual properties.

Check GitHub Actions for export status after pushing. The current in-game M overview image may still represent older OSM geometry and is not authoritative for the new blockout.

## Prototype 0.8 — live overhead map

Press **M** to toggle a live top-down schematic showing roads, approximate settlements, field, river, lake, landmarks, and the player's real position. It is drawn from in-game geometry instead of the outdated static `map_overview.png`. Press **F3** to toggle technical input diagnostics.

This overhead view is a **blockout assessment tool**, not a reproduction of satellite imagery or a surveyed base map. Do not infer individual property coordinates from its approximate polygons.

## Prototype 0.9 — reduced provisional house density

- Maximum generated house count lowered from 900 to 420.
- Candidates are sampled across all neighborhoods rather than filling early streets to the cap; spacing and minimum separation are increased, leaving open plots.
- Houses on the M map are shown as small rotated footprint rectangles rather than uniform point symbols.
- While the map is open press **H** (same physical key as Russian **Р**) to show/hide *provisional* houses and inspect the OSM road geometry independently.

These homes are artist-generated placeholders, **not a confirmed building inventory** or accurate individual footprints. Use permissively licensed sources or independently verified placement data for further correction. The public site needs the GitHub Actions workflow to finish before updates are visible.

## Prototype 1.0 — landscape blockout

This update completes the first review cycle of user-provided visual references for sectors A, B, C, the river, Lake Chyornoye, the southern field and highway M5. See the review notes under `docs/geography/`.

Changes:
- Larger, more natural-looking **approximate field** silhouette and forest island in both 3D and the live M map.
- Sparse low-poly shrubs and a provisional field track in the open ground.
- Softer river polyline and asymmetrical lake outline, kept in sync between 3D and the overview.
- The existing **OSM trunk M5** gets a distinct asphalt colour from the dirt/settlement roads.
- Existing house layer toggle, player movement, project scale and Godot web build are preserved.

**Important:** 1:1 refers to the intended terrain *scale*, not verified per-house or per-shoreline accuracy. The added landforms are illustrative, not traced from Google Maps. Visual source images are not distributed in the repository; for precise asset placement use appropriately licensed geodata or independently measured coordinates.
