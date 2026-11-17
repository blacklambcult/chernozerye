# ЧЕРНОЗЁРЬЕ

Low-poly atmospheric 3D exploration game in Godot 4. A 2 × 2 km prototype based on the real geography of Черноозерский Кордон (Уфа, Башкортостан), with a fixed dusk atmosphere.

## Status
Migration to GitHub is underway. The Godot project and its geodata will live in `godot/`. No web deployment is live yet.

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
