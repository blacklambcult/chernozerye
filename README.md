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

## Prototype 1.1 — overview clarity (live map)

- All on-screen roads and filled areas are clipped to the 2×2 km study frame; OSM road ways outside it are no longer drawn past the map border.
- The map draws OSM forest polygons in dark green **only where OSM actually has a mapped woodland polygon**. The neutral ground elsewhere indicates *unknown cover*, not necessarily open ground or forest. Source forest completeness is limited.
- Added/sketched roads have a different colour from OSM roads and are no longer overdrawn twice.
- The provisional field, river, lake, sector masks, houses and landmarks remain artistic approximations, not measured geometry.
- In-game map header: `CHERNOZERYE / LIVE MAP 1.1`; press M for map and H or the top-right button for approximate houses.

**Next accuracy milestone:** replace unsupported extra roads and settlement boundaries progressively with verified licensed geographic measurements, then refine each of A, B, C before detailed assets.

## Prototype 1.2 — 3D dacha neighbourhoods

The previous marker-like houses were uniform cubes. The scene now renders deterministic, low-poly *provisional* houses with pitched roofs in several muted colours. Lots have modest garden pads and occasional small sheds. Physical wall colliders prevent the player walking through the houses.

The previous settlement masks also excluded **all** trees; limited garden-tree groups are now allowed on empty parts of the housing blocks, at least 10 m from provisional house centres and 8 m from road centre lines. The result should better communicate a rural settlement where woodland reaches streets and gardens.

**Accuracy:** none of these additions are measured house-by-house. Roofs, garden pads, shed positions and trees are illustrative game geometry. The existing OSM roads, and the user-provided conceptual sector reviews, are not altered by this cosmetic/experiential iteration.

Verify the last GitHub Actions export before reviewing the browser build. In-game header is `CHERNOZERYE / LIVE MAP 1.2`. Assess the change from ground-level gameplay; map geometry changes only in presentation label.

## Prototype 1.3 — streetscape at walking height

The previous build spawned in an empty clearing. The prototype now starts at a nearby *existing OSM unclassified road* around projected point (130, 82), approximately 74 m from the former start. The in-game landmark and map start marker are moved to match. This does **not** assert the real-world bus stop's verified location.

- Muted gravel/earth shoulders around minor OSM road surfaces and clearer permanent-dusk lighting.
- Each provisional house has a door and two small windows; most have decorative fence segments, gates/gaps and small garden shrubs.
- Houses' long axes are aligned to their parent road segments; overview-map rotation is inverted to remain consistent with world coordinates.
- Mixed low-poly forest: two-stage fir crowns and rounded deciduous crowns; distant tree shadows are disabled for Web performance.
- Materials are reused via a palette cache rather than regenerated for every facade, fence and shrub.
- Live map header `CHERNOZERYE / LIVE MAP 1.3`; overview house button has shortened text to fit smaller viewports.

**Geographic disclaimer:** garden fences, facade and forest details remain stylized placeholders. A 2×2 km scale is retained, but this is not yet a property-accurate 1:1 reconstruction. Visual comparison with screenshots is qualitative only.

**Review checklist:** after the latest Actions job passes, hard-refresh the browser. Walk along the road immediately after spawning; check the dirt shoulder, gates, windows, mixed tree outlines and smooth mouse controls. Use M to confirm that the START marker is now located at the player's spawn; H toggles approximate house footprints.

## Prototype 1.4 — inhabited forest edge

This iteration addresses the 1.3 ground-level screenshot showing a largely empty plane, widely spaced houses, very few visible treetops, and hard-to-read roads.

- More provisional buildings along existing roads: cap 540, closer spacing and a higher chance of occupied garden lots. These are still **not surveyed real building coordinates**.
- Forest belts just **outside** the village blockout polygons, keeping streets, open meadow and mapped water clear. This makes the tree line visible from street level instead of sprinkling all trees evenly over 4 km².
- Up to 1,050 garden trees (conditional on enough free space), and an overall tree cap of 13,500. Existing low-poly mixed forest uses shared MultiMeshes for Web.
- Small cross-triangle grass tufts added to empty garden spaces and the meadow using a single MultiMesh. No interaction/collisions.
- Better unclassified/residential road legibility: 6 m base width, earth shoulders and wheel ruts. Highway retains a distinct appearance.
- Labels updated to `ЧЕРНОЗЁРЬЕ 1.4 FOREST EDGE` and `CHERNOZERYE / LIVE MAP 1.4`.
- GitHub Actions now checks script parsing for all gameplay/map GDScript sources before export.

**Important:** Landscape tree belts, houses and meadow are **artistic geometry** informed by general visual references, not a precise 1:1 terrain survey. The map still distinguishes OSM-mapped forest from unknown/unmapped cover. Existing movement, M overview and house layer button remain unchanged.

**Review:** when the build is green, hard-refresh GitHub Pages, inspect the 3D street from the spawn and walk around the village. Specifically look for visible woodland close to buildings, more enclosed roads and recognizable grass at walking height. Check performance in the browser.

## Prototype 1.5 — sector A geographic audit

Version 1.4.1 starts in the browser, but the 3D houses remain procedurally generated and cannot be trusted as a 1:1 reconstruction. To avoid adding more false detail, version 1.5 adds **a map inspection mode only**. The gameplay and 3D performance safeguards remain unchanged.

In the in-game overview (M), use the new buttons:

- **СЕКТОР A: ПРИБЛИЗИТЬ** to show a 680×680 m north-up inspection window covering western settlement polygon, forest boundary, and approaches. Click again to return to the entire 2×2 km map.
- **КОНТУРЫ OSM: ПОКАЗАТЬ** to draw OpenStreetMap building footprints in cyan, separate from the yellow *generated game-house* footprints toggled by **ДОМА: ПОКАЗАТЬ** (or H). The source data has only 63 mapped building ways **across the whole 2×2 km area**, and their individual accuracy has not been validated.

Use the two layers to observe incompleteness and discrepancies. This mode does **not** change or verify real house positions. Once we have reliably licensed building and road geometries (or independent survey), replace provisional building positions in sector A in a traceable, data-driven manner. Google Maps imagery in prior chat is visual context only; no coordinates or outline geometries are extracted from it into the repository.

## Prototype 1.6 — Overture Maps building audit

The 2×2 km study square centred on the project's UTM anchor now contains a second, independently published building-footprint source, obtained by `scripts/import_overture_buildings.py` from Overture Maps. The importer uses the public Overture `download --bbox` CLI, transforms coordinates to project-local EPSG:32640 metres, clips to the square and saves a small source-attributed `godot/overture_buildings.json`.

- This import returned **1,367 candidate building polygons** for the study square (644 centroid points lie in the sector A 680×680 m inspection window). Our old OpenStreetMap source includes **63 building ways** across the whole square.
- In the in-game map (M), **pink outlines** denote Overture candidates, **cyan outlines** are OSM, **yellow** indicates provisional generated houses. Click the top-right **OVERTURE** button to toggle the pink layer; the sector A zoom and other toggles are unchanged.
- The **3D scene remains the existing proven 1.4.1 game blockout**. No automatic replacement of homes with unverified aerial detections has been made. We will review positional coverage first.
- Overture has variable source data quality, including imagery-detected false positives, missing sheds, old footprints and potentially overlapping contributions. The 1,367 polygons are *not 1,367 verified residences*.
- Overture Maps Foundation and original contributors are credited; source data has per-source open licence terms (including CDLA/ODbL where applicable). Original dataset: https://docs.overturemaps.org/getting-data/
- Google Maps screenshots are exclusively visual reference material; no Google tiles or traced Google-derived contours have been imported.

The separate `geo-data.yml` workflow can repeat the extraction, while the regular Godot Web workflow checks scripts, boots the scene, and builds GitHub Pages. New building data is committed in version control for reproducibility.

## GEO LAB 2.0 — ручной конструктор Чернозёрья

Адрес конструктора: https://blacklambcult.github.io/chernozerye/map/

**Как пользоваться:**
1. Выбрать «Сектор A» или «Квартал A» и при необходимости отключить контуры Overture/OSM, чтобы они не мешали.
2. В блоке «Рисование географии» выбрать объект: **дорога, тропинка** (линии), **водоём, лес, граница участка, другой объект** (полигоны), **дом, сарай, баня, машина-контур** (полигоны) или **машина-метка** (точка).
3. Последовательно ставить вершины на карте; нажать **«Завершить» / Enter** для линии или полигона. **«− Точка» / Backspace** удаляет последнюю неподтверждённую вершину. **Esc** отменяет незавершённую фигуру.
4. Нажать на созданный объект, задать **название, тип и примечание**. Кнопка «Править точки» открывает перетаскиваемые вершины; «+ Вершина» добавляет новую вершину щелчком по ребру, «− Вершина» удаляет выделенную. Есть удаление выбранного объекта.
5. Изменения автоматически записываются в **localStorage текущего браузера**, но это не синхронизация между устройствами и не долговечное резервное хранилище. **Регулярно скачивать GeoJSON**. Кнопка «Загрузить GeoJSON» восстанавливает сохранённый набор (заменяет текущий с подтверждением).
6. По окончании работы скачать файл `chernozerye-sector-*.geojson` и прикрепить его в чат. Содержимое будет проверено, трансформировано из WGS84 в локальные метры Godot (`EPSG:32640`) и перенесено в игровой мир в отдельный слой, не меняя первоисточники OSM/Overture.

**Формат:** GeoJSON `FeatureCollection` со схемой `chernozerye-geo-constructor-1`. Каждый объект хранит `properties.category`, `name`, `notes`, `source=user_manual`, `id` и геометрию `LineString`, `Polygon` или `Point` с координатами `[longitude,latitude]`. Исходные OSM/Overture читаются только для справки и не изменяются при рисовании. Экспорт не содержит спутниковые изображения.

**Лицензии и точность:** пользователь должен иметь право оцифровывать сведения из выбранных источников. Esri World Imagery здесь — визуальная подложка; не предполагается, что её можно свободно обводить и затем распространять результаты. Для игрового переноса использовать собственные наблюдения либо данные с соответствующими правами. Ручная разметка не означает геодезическую достоверность; масштабы, дороги и границы проверяются отдельно.

**Проверки:** GitHub Actions выполняет `node --check` для `editor-core.js` и `editor.js`, unit-тесты нормализации координат / импорта / экспорта и прежнюю сборку Godot 1.8, а затем публикует конструктор в `/map/`.
