# Fearless Knights of the Cordon

### PRE-ALPHA 0.7.0 — authored permanent world items / Quest Lab 0.4

- Quest Lab now supports independent `worldItems` in its existing v1 JSON project. The library has two categories: `note` and `item`. Each has a stable ID, title, full text/description, an optional Geo Lab `objectId`, and a WGS84 target point. Select **«Находки в мире»**, create a note or item, then click **«Разместить находку»** on the map or bind it to a manually drawn Geo Lab object. Existing user projects are still valid: absent `worldItems` becomes an empty list, and browser localStorage is preserved.
- `scripts/convert_questlab.py` now compiles world finds separately from mission sequences. A standalone, reviewed `data/questlab_world_items.json` (same Quest Lab project format) contains three placed findings near the default player start and a fourth by the Geo Lab house `4499fe7a-c031-469c-aac4-96636c23eea8`. CI converts it to `godot/world_items.json` independently of F6/F7 and validates real map anchors.
- `godot/world_document.gd` now instantiates all published finds as separate game-world 3D nodes, not temporary F7 markers. Within 2.8 m, **E** reads a note or collects an item. Notes use the full-screen aged-paper reader; ordinary items show pickup feedback and appear in the **J** journal's item list, where they can be inspected.
- The persistent `NoteArchive` now stores both documents and collectible items in the existing, backward-compatible `user://chernozerye_field_documents_v1.json`. Picked-up objects vanish from the world and remain collected across game reloads. F7's demo no longer owns the normal-world collectible.
- Current visuals are simple low-poly placeholders (paper / rusty key) and do **not** import the Model Lab's GLB assets yet. A browser-only Quest Lab edit does not automatically publish to the game: export the JSON, add it to the repository's authored content, then redeploy Web. Game pre-alpha 0.7.0 and Quest Lab 0.4 are tracked in the Studio release journal.
- New Node/Python/Godot tests verify project backwards compatibility, multiple world placements, Geo Lab ID resolution, valid data, collecting, reading and saving both kinds of findings.

### Pre-alpha 0.5.7 — field documents and readable notebook pages

- **E** near the home note, world note or a Quest Lab collectible with a `document` opens a dedicated aged-paper reading overlay. **E** closes it; the game is locked while the paper is on screen. The note's text is never shown as an automatic gameplay subtitle.
- **J** opens the unified Field Journal with the chapter objective and a selectable list of collected notes. Click a document to reread it; **E** returns to the journal. Works outside Quest Lab, after F7 or in the main game.
- Note IDs, headings, text and source are persisted in `user://chernozerye_field_documents_v1.json` (browser profile storage in Web); duplicates do not overwrite a saved collectible. If notes were collected, their permanent in-world paper props disappear on subsequent loads, while entries remain readable.
- The old StoryPrologue table note now also enters this journal. The map-authored F7 house still resolves to its Geo Lab ID; the nearby note has authored content. F7 advances the collect step **only after closing** the reading screen, and F6 keeps its original mission.
- **Quest Lab 0.3** adds document title and body fields for collect steps; these survive Quest Lab JSON normalization and the Python → Godot mission compiler. Both old Quest Lab v1 and new notes use the existing schema.
- Scene startup, GDScript sources, chapter story regression, new F7 interaction+reading regression, quest data validator and public Web build are CI checked.

### Game pre-alpha 0.5.6 — Quest Lab real Geo Lab object linking

- The Quest Lab Python compiler now optionally accepts `--geo-layout godot/manual_layout.json`. Each non-empty `objectId` must match a stable ID in the **reviewed Geo Lab map**. Resolved `target_world` and `object_type` come from surveyed geometry, **not** stale editor coordinates; invalid IDs fail the build rather than silently pointing to an unrelated place.
- Polygons (buildings, sheds, plots) are anchored at a nearby **exterior edge** with a 1.8m clearance from the footprint instead of the unreachable interior centre. Lines use the midpoint along their length; points retain their original exact location. Import is deterministic, preserves user map/project files, and rejects incompatible Geo Lab map origins.
- In the F7 Godot test, the first step references the **actual Geo Lab house ID** `4499fe7a-c031-469c-aac4-96636c23eea8` and displays a discreet locator outside its footprint. The second step is a separately placed collectable paper note. Interact with **E** near the indicated location to advance, then read the message.
- F6 still plays the unmodified user-authored two-step mission. F7 remains an opt-in, reversible test; items do **not** yet persist in the real game inventory, and background/OSM tiles without stable editable IDs are not linkable.
- The release log shows Game **pre-alpha 0.5.6** (Studio stays at 0.5.0), and CI adds compiler geometry/linking tests, verifies conversion from the **same** 710-item geo layout used by the game and tests F7 gameplay conditions.

### Godot pre-alpha 0.5.5 — Quest Lab F7 interaction + collectible vignette

- **F6** still runs the original, unmodified user-authored “ВОЗВРАЩЕНИЕ НА ЧЕРНЫЙ КОРДОН” quest (two reach steps). **F7** launches a separate, opt-in, generated Quest Lab test nearby: approach a turquoise marker and press **E** to inspect, approach a glowing paper note and press **E** to pick it up, then read a story message.
- The F7 data lives in `data/questlab_interactions_demo.json` and is converted via the same WGS84 → UTM → Godot transformation as normal Quest Lab exports. The source user's quest JSON and main storyline are not modified.
- Interaction distance is capped at 3m, with HUD guidance, a small temporary 3D marker for each current step, and a playtest-only list of collected item IDs. F7's test item **is not** a permanent inventory item or a real mapped house; this stage is a playable proof of quest events.
- Leaving F6 or F7 restores player transform, previous story HUD and map visibility. Two headless Godot regression scripts now verify the existing F6 route, F7 interaction range, single-item collection, story message and state restoration.
- Studio release log records game **pre-alpha 0.5.5**, while the Studio UI stays at 0.5.0. Live Geo Lab prop interactions remain planned work.

### CHERNOZERYE STUDIO 0.5 / QUEST LAB 0.2 — links to manually mapped objects

- Quest Lab now has **«Выбрать объект»** on the map and **«Указать на карте»** in the step inspector. Select a task, enter picking mode, and click a user-authored house, forest, water polygon, road, plot or prop from the Geo Lab manual map.
- Selecting a feature persists its **stable Geo Lab feature ID** in the existing Quest Lab v1 `objectId` field and fills the geographic `target` with a deterministic polygon centroid, line midpoint or point position. Existing Quest JSON and the Godot Quest Lab converter stay compatible.
- The inspector supports a substring search by category/name/ID, quick navigation to a linked object, visible focus ring and warnings if an ID no longer exists.
- Switching from Geo Lab back into Quest Lab refreshes the manual feature index. If an object moves, matching quest targets update to its current geometry and are saved; if the ID disappears, the last target and ID are retained with a warning, never silently dropped.
- Basemap/Osm/Overture overlays remain background-only. **Only user-authored Geo Lab features with stable IDs are linkable**. No Godot gameplay trigger system or automated game publishing was added in this slice.
- Studio release manifest is now **0.5.0**, Quest Lab **0.2**, and the completed object-link roadmap item is removed from the future-only backlog. CI has pure geometry/binding tests and checks HTML/JS wiring.

### CHERNOZERYE STUDIO 0.4 — release desk, changelog, backlog and roadmap

- The **Центр управления** screen now starts with a large Release Desk showing the active Studio version, the current game release, the **actual Git SHA** of the published Web build, versioned changes and an interactive roadmap/backlog.
- Release history can be filtered (all / Studio / game / Labs + Forge); entries expand into their change lists and links to real, verified GitHub commits. All release content is kept in the reviewed, versioned source file `site/studio/releases.json`. No invented completion statuses or release dates.
- The roadmap is grouped by `NEXT`, `PLANNED`, `IDEAS` and includes module, priority and a concrete expected outcome; these are future tasks, not implemented features. The user can still open the four editors from cards below the Release Desk.
- `site/studio/release-core.js` validates the data format, dates, SHA references, unique release IDs, roadmap items and priorities. Regression tests cover schema correctness, filtering and roadmap grouping.
- CI generates `build/web/studio/build-meta.json` from the **current** `GITHUB_SHA` and current Studio release number on every deployment, avoiding a stale hardcoded "last build" label. GitHub Pages publication verification checks both the changelog JSON and real build SHA.
- **Release notes are curated manually in Git** when functionality changes; only the build SHA is generated automatically. No prior browser-saved drafts are modified.

### Forge pistol — пользовательский ассет и FP-поза (2026-11-20)

- Обновлены бинарный GLB и отдельный FPS-профиль именно из предоставленных файлов `новый-игровой-предмет (1).glb` и `новый-игровой-предмет.viewmodel.json`.
- GLB 28,844 байта, SHA-256 `0eea0b0e3e61f41033df60b8e1b50933b743e87a07ce798e7c963bad1f256a6e`, 11 meshes и три именованных игровых маркера.
- Viewmodel: позиция `[0.285,-0.225,-0.47]`, поворот `[0,9,0]` градусов, масштаб `0.32`; кисть `[-0.01,0.06,-0.01]`.
- Данные GLB хранятся в репозитории как сжатый `data/forge_pistol.glb.xz.b64` и разворачиваются в `godot/assets/forge_pistol.glb` в CI с проверкой SHA-256; JSON напрямую загружается игрой. Механика 7 виртуальных патронов и отдельная двухкликовая механика револьвера не меняются.

### Hellish Forge 0.2 — FP-предпросмотр и руки

- Рука теперь отдельная стилизованная low-poly геометрия в `godot/weapon_hand_viewmodel.gd`, используется **и револьвером, и пистолетом из Forge**. Без выбранного оружия руки не появляются; старая игровая механика оружия не затронута.
- Модель пистолета из пользовательского GLB увеличена с 0.165 до **0.26** в viewmodel и приближена к камере. Настройки лежат в `godot/assets/forge_pistol.viewmodel.json`, а не захардкожены только в GDScript.
- В редакторе Forge появилась кнопка «Вид от первого лица». Она показывает игровой FOV 75°, цифровую low-poly руку и предмет, размещённый по `HF_GRIP_PRIMARY`. В панели справа можно менять положение и поворот модели, масштаб, положение и поворот кисти; preview обновляется на лету.
- Поля `viewmodel` сохраняются в `.forge.json` и метаданных `.glb`; отдельная кнопка «Скачать FP-профиль для Godot» экспортирует `.viewmodel.json`, соответствующий формату, который загружает игра.
- Старые Forge JSON совместимы: при отсутствии `viewmodel` используется общий стандартный пресет. Локальные изменения в браузере автоматически **не публикуются в игру**: экспортированный профиль надо включить в репозиторий и пересобрать Web-версию.
- В CI добавлены тесты схемы и общего стартового FP-профиля, проверки рук обоих оружий и импортированного ассета.

### Forge pistol: user-authored weapon skin, seven-shot arcade controls

- The GLB supplied by the user in Hellish Forge is restored during CI at `godot/assets/forge_pistol.glb` (SHA-256 checked).
- Inventory: 1 cigarette pack, 2 existing two-click revolver (6 rounds), **3 Forge pistol (7 rounds)**, 4 empty.
- The Forge pistol shoots once for each valid left click (no separate cocking), `R` reloads seven virtual rounds; the original revolver controls, ammunition and visual mesh are preserved.
- Godot imports the original GLB meshes and `HF_GRIP_PRIMARY`, `HF_FORWARD`, `HF_MAGAZINE` markers. The viewmodel scales/positions the mesh without editing the source asset.
- Includes a headless regression for the uploaded GLB, three anchors, seven-shot ammo cycle, independent reload, and preserved revolver.

### Hellish Forge 0.1 — цифровая кузница игровых предметов

- Самостоятельный браузерный модуль: https://blacklambcult.github.io/chernozerye/forge/ и вкладка `/studio/#forge`. Не заменяет Model Lab и использует отдельный ключ локального хранилища.
- Пять игровых категорий: холодное, дробящее, одноручное (револьвер, пистолет, пистолет-пулемёт), двуручное (дробовик, винтовка, автомат, пулемёт, гранатомёт), уникальное (арбалет, лук, метательное копьё, артефакт), плюс дополнительные условные типы.
- Собирает **визуальные игровые ассеты** из стилизованных low-poly примитивов; маркирует роль каждой детали и редактирует шесть локальных опорных точек: основной хват, второй хват, направление (-Z), слот магазина, отметка барабана, опорная точка предмета. Не представляет конструкцию действующих реальных механизмов.
- Показывает габариты модели в игровых метрах (X/Y/Z), 1 метр на шаг сетки. Маркеры визуализированы 3D стрелками и регулируются отдельными координатами или gizmo.
- `*.forge.json`: отдельная версия данных с категорией, подтипом, ролями деталей и опорными точками. `*.glb`: низкополигональная модель и именованные узлы `HF_GRIP_PRIMARY`, `HF_FORWARD` и т. п.; локальная ось направления маркера — -Z. Это **метаданные для будущей интеграции**: в Godot ещё нет загрузчика Forge ассетов и автоматической настройки логики предметов.
- CI проверяет схему и импорт, наличие Forge модуля в сборке, публичный HTML и JS. Для полного визуального теста нужны браузер с WebGL и Three.js с CDN.

### CHERNOZERYE STUDIO 0.2 — компоновка и единые геослои

- Левая навигация сворачивается кнопкой «« / »» в узкую полосу с иконками; состояние сохраняется локально. Ctrl+B переключает её с клавиатуры.
- Верхняя шапка и строка заголовка редактора стали компактнее: больше площади для карт и 3D.
- Quest Lab автоматически загружает **те же** GeoJSON слои, что создаёт Geo Lab: дома Overture, дороги OSM, лес/растительность OSM, озёра/водные объекты OSM, а также всю ручную разметку Geo Lab (`chernozerye_manual_geojson_v2`).
- Вид спутника теперь открыт по умолчанию. Кнопка «Геообъекты» включает/выключает слои, не затрагивая маркеры заданий. При возвращении в Quest Lab из Geo Lab ручная разметка обновляется без пересоздания квеста.
- Данные Quest Lab и Geo Lab остаются независимыми и сохраняются прежним способом. Это пока **видимые слои для планирования**, а не новые игровые сущности или обработчик взаимодействия в Godot.

### CHERNOZERYE STUDIO 0.1 — единая оболочка трёх инструментов

- Центр управления: https://blacklambcult.github.io/chernozerye/studio/
- В одном окне доступны Geo Lab, Quest Lab и Model Lab. Редакторы подгружаются по мере обращения; после переключения открытые iframe сохраняются, без сброса текущей сцены и состояния камеры.
- Существующие локальные данные **не переносятся и не удаляются**: Studio читает прежние ключи `chernozerye_manual_geojson_v2`, `chernozerye.questlab.v1`, `chernozerye.modellab.v1`, показывает счётчики и оставляет оригинальные редакторы доступными по прежним ссылкам.
- Deep links: `/studio/#geo`, `/studio/#quest`, `/studio/#model`, `/studio/#home`; переключение: Alt+1 / Alt+2 / Alt+3 (Alt+0 — старт).
- Первый этап — оболочка и переключение. **Общей библиотеки объектов, автоматического обмена моделями/квестами и синхронизации файлов между редакторами пока нет** — это следующий этап.

### Model Lab 0.1 — самостоятельный браузерный конструктор 3D-пропсов

- Онлайн-редактор: https://blacklambcult.github.io/chernozerye/model/
- Базовая сцена из 5 примитивов (куб, цилиндр, сфера, конус и плоскость), с выбором деталей мышью/в списке, gizmo перемещения, вращения и масштаба, PBR-материалами (цвет, металличность, шероховатость).
- Три тестовых шаблона: деревянный ящик, уличный фонарь и дорожный указатель. Настройка отдельных частей, дублирование, удаление, рамка всей модели, сетка, клавиатурные горячие клавиши.
- Локальное сохранение, импорт и экспорт JSON-проекта в формате `chernozerye.modellab` v1; экспорт настоящего `.glb` (glTF 2.0 binary) с мешами, трансформациями и материалами для Godot.
- Работает в браузере на Three.js (подгружается из CDN). Пока без анимаций, костей, коллизий и автоматического размещения в Geo Lab; эти интеграции запланированы на следующую фазу — единую студию Geo / Quest / Model.
- Горячие клавиши: W — движение, E — вращение, R — масштаб, F — объект в кадр, Del — удалить, Ctrl+D — дублировать, Ctrl+Z — отменить.

### Quest Lab → Godot / playtest v0.1

- Загрузили первый пользовательский квест `data/questlab_return_cordon.json` («ВОЗВРАЩЕНИЕ НА ЧЕРНЫЙ КОРДОН»): две последовательные задачи «Добраться до Черного Кордона» и «Найти дом старосты» с исходными текстами из Quest Lab.
- Сборка переводит координаты WGS84 из Quest Lab в те же метры UTM EPSG:32640, что и Geo Lab. Исходный JSON не меняется, Godot получает `questlab_runtime.json`.
- В игре **F6** включает тест пользовательского квеста: игрок переносится к заданному спавну и видит текущую цель/дистанцию. При приближении на 8 м к цели включается следующий шаг; после второй цели квест завершается. **F6** повторно возвращает прежний пролог и позицию персонажа.
- Старый сюжет «Найти родной дом» по умолчанию сохранён. Режим теста отключает его HUD и обработку событий только пока включён F6; в остальном игровая логика не меняется.
- В этом первом срезе Godot исполняет условия `reach` и самостоятельные `message` (задержка 3.5 с). Для шагов `interact` и `collect` ещё нужны реальные связи с предметами/триггерами: они не помечаются выполненными автоматически.

### Quest Lab 0.1 — браузерный редактор квестов

- Онлайн-редактор: https://blacklambcult.github.io/chernozerye/quest/ (Geo Lab: https://blacklambcult.github.io/chernozerye/map/).
- Создание главных и побочных квестов, стартовая точка игрока (WGS84 + курс), упорядоченные задачи четырёх типов: точка, взаимодействие, предмет, сообщение. Положение точек задаётся на интерактивной карте.
- Автосохранение в браузере, импорт/экспорт одного JSON-проекта для всех квестов, валидация формата и ID, перестановка шагов и дублирование квестов.
- Это инструмент **создания данных**, а не игровой runtime. В версии 0.1 Godot пока не исполняет квесты из экспортированного JSON. Следующая фаза — универсальный загрузчик и обработчик заданий в Godot.

**Текущая версия игры: Pre-Alpha 0.6.9.** Место действия — Чернозёрье.

### Pre-Alpha 0.6.9 — карта Geo Lab от 19 ноября и FPS без квадратных плеч

- Новые 710 объектов из оригинального Geo Lab: 232 дома, 209 участков, 104 бани, 61 сарай, 52 машины, 25 лесных контуров, 20 дорог, 4 водоёма и 3 тропы. Источник сохранён с исходными координатами и идентификаторами в `data/manual_survey_2026-11-19.geojson`. Файл 18 ноября сохранён для отката.
- CI конвертирует новую карту WGS84 → EPSG:32640 для игрового мира; идентификатор родного дома сохранён, чтобы не пересоздавать сюжетный ориентир.
- Удалены `ShoulderYoke` и `CoatPatch` из FP-камеры. Рукава сужены, их начало отодвинуто от камеры, а смещение вниз ослаблено. В первом лице по-прежнему нет полного тела.
- Тесты проверяют актуальные числа объектов, устойчивость родного дома и отсутствие наплечников.


### Pre-Alpha 0.6.8 — компактные плечи FPS

- Убраны большие обрубленные плечевые блоки: плечевой сегмент уменьшен по толщине примерно вдвое, смещён глубже от камеры и соединён с верхней частью рукава.
- Верх рукава больше не начинается внутри ближней плоскости игровой камеры. Это защищает от огромных плоских полигонов в углах экрана при наклоне головы.
- Плечи расположены симметричнее, без заметных различий высоты и ширины левой/правой стороны. Поза при взгляде вниз остаётся плавной, видны обе руки и кисти.
- Полная модель героя остаётся только в F4. В игровом FPS корпус и ноги по-прежнему отключены.
- Новый Godot-тест проверяет соединение плеча с рукавом, визуальный размер плечевого сегмента и отсутствие пересечения рукавов с near plane.



### Pre-Alpha 0.6.7 — вид от первого лица без тела

- По результатам визуальной проверки убрано всё FPS-тело: таз, ноги, ботинки и остальная геометрия больше не создаются в игровой камере. Глаза игрока видят мир и только отдельные FPS-руки с рукавами и предметами.
- Полная 3D-модель продолжает загружаться **только для F4**. При выходе из осмотра она скрывается; при обычной игре не может появиться из-за наклона головы.
- Старый `FirstPersonFullBody` остаётся как скрытый совместимый узел для уже созданных сценарных анимаций, но больше не обрабатывается каждый кадр и никогда не рисуется.
- Внесён регрессионный тест: на четырёх углах камеры тело остаётся отсутствующим, руки видны, F4 включает единственную полную модель и возвращает FPS-режим без наложений.
- Движение, физика, интерьер, окружающая среда, журнал и анимация курения не менялись. Генератор старого FPS-GLB оставлен в репозитории на случай будущего отдельного переосмысления, но в игровой сцене он не импортируется.



### Pre-Alpha 0.6.6 — устойчивый FPS-вид

- В первом лице теперь только отдельная нижняя GLB-модель с тазом, ногами и ботинками. Верхний бушлат, горловина, грудь и шея полностью исключены из FPS-модели, поскольку их полигоны перекрывали экран при взгляде вниз.
- Два плеча, рукава, предплечья и кисти созданы в FPS-viewmodel камеры; они больше не отключаются при сильном наклоне. При взгляде вниз плечевые части плавно появляются у краёв кадра, не вытесняя ноги.
- F4 сохраняет полную модель героя. Не менялись физика, камера, взаимодействия, мир и шаги.
- Проверки сборки контролируют, что у нижнего тела нет высокой геометрии, обе руки видны при максимальном наклоне камеры, а ботинки находятся дальше таза в перспективе.


### Pre-Alpha 0.6.5 — исправление FPS-проекции воротника и корпуса

- По скриншоту 0.6.4 причина «восьмиугольника» определена точно: камера находилась непосредственно над осью открытой горловины 3D-бушлата и при взгляде вниз видела её целиком, как широкую рамку с подкладкой.
- Сдвинут **только импортированный FPS-ассет** на 24 см назад относительно глаз, что воспроизводит естественное положение камеры перед лицом. Камера, интерактивные лучи, коллизии, перемещение и полная F4-модель не изменялись.
- Новый Godot-тест рассчитывает проекцию верхнего края бушлата на конкретном угле `-1.45`: край должен располагаться ниже центра экрана, а носок берца — выше края куртки. Такая проверка обнаружит повторение прежнего артефакта даже при полностью непрозрачных материалах.
- Оба самостоятельных GLB (полный и для первого лица) сохранены. Результат сборки дополнительно проверяется визуально в браузере.



### Pre-Alpha 0.6.4 — независимое объёмное тело в FPS

- Вместо плоских cutaway-панелей теперь два самостоятельных GLB: `dembel_full.glb` (полный герой с вещмешком и лицом, F4) и `dembel_fp.glb` (отдельный объёмный корпус, закрытые подкладка и таз, связанные ноги/берцы для первого лица).
- Godot импортирует оба меша и переключает целые сцены. Первая-person сцена не содержит головы или рюкзака. Старый процедурный корпус скрыт.
- Материалы обеих сцен непрозрачные. Положения суставов не зависят от угла камеры; движением управляются только суставные вращения.
- В CI собираются и проверяются оба независимых GLB: PBR-цвета, объёмность груди, закрытость таза, отсутствие вырезанных плоскостей и неизменность суставов.
- Это архитектурное исправление. Окончательную композицию тела при взгляде вниз проверяем по браузерным скриншотам.



### Pre-Alpha 0.6.3 — фикс цветных GLB-материалов и гигантских панелей бушлата

- Исправлены две ошибки, обнаруженные по трём скриншотам 0.6.2: белая бесфактурная фигура при F4 и огромные треугольники передней части бушлата при взгляде вниз.
- Генератор GLB теперь сохраняет настоящие базовые glTF PBR-материалы (baseColorFactor), а Godot назначает определённые цветные материалы всем частям модели **и в F4**, вместо сброса материала в ноль. Так модель видна с цветом даже в Web GL Compatibility.
- Фронтальные панели бушлата стали компактнее и ниже глаз игрока (верх y ≤ 1.055), без обратных дублирующих треугольников; у штанин убраны плоские верхние «восьмиугольные» заглушки.
- В CI добавлена независимая Python-проверка GLB на PBR-цвета и размеры first-person геометрии, а Godot-тест проверяет цвет материалов при осмотре F4.
- Игра, движение, окружение и сюжетные механики не менялись. Результат рендера необходимо дополнительно проверить в браузере.



### Pre-Alpha 0.6.2 — видимая GLB-модель вместо старого тела, F4 осмотр

- Проверено по исходникам: в 0.6.1 под видом новой модели всё ещё отображался старый процедурный бушлат `first_person_body.gd`. Теперь он полностью скрыт при успешной загрузке GLB.
- Исходный генератор модели `scripts/build_dembel_character.py` включает отдельные незамкнутые передние панели нового бушлата `FPSCoat*`, созданные из палитры того же 3D-ассета. В первом лице видны именно эти панели и импортированные настоящие ноги/ботинки. Полная геометрия спины/вещмешка/головы не попадает в камеру.
- **F4 — осмотр героя**: отдельная камера перед персонажем, подсветка и вся оригинальная модель (включая лицо, ремень, подсумок и вещмешок). F4 повторно возвращает вид от первого лица. Осмотр не изменяет игровые координаты и выключает движение.
- Добавлен новый тест, который запрещает показ старого корпуса при успешном импорте и проверяет переключение F4, работу отдельной камеры и неизменность координат ног при наклоне взгляда.
- Игровая анимация рук FPS сохранена, чтобы пока не менять взаимодействие и уже проверенное движение; полная модель рук доступна в режиме осмотра.



### Pre-Alpha 0.6.1 — устранение серой поверхности, перекрывающей экран

- В 0.6.0 полная импортированная GLB-модель отображалась перед камерой первого лица. Закрытые поверхности бушлата и вещмешка оказались слишком близко к ней и перекрыли изображение серыми полигонами.
- У импортированной модели теперь включены **только меши брюк, голеней и берцев**. Все остальные меши скрываются через явный список разрешённых частей; палитра обуви/брюк задаётся напрямую материалами Godot.
- Восстановлен проверенный в 0.5.9 first-person бушлат; его старые процедурные ноги скрыты, чтобы две пары ног не дублировались.
- Взгляд вниз больше не изменяет положение тазобедренных суставов импортированной модели. Для внешнего вида всей модели и дальнейшего Blender-редактирования GLB остаётся самостоятельным ресурсом.
- Усилены headless-тесты: теперь проверяется реальная видимость мешей, а не только координаты узлов. Проверяется, что белая «стена» из верхней части импортированного персонажа не может появиться.
- Тесты не заменяют визуальную проверку браузера. Для внешнего просмотра персонажа потребуется отдельная камера/сцена, а не внедрение полной модели внутрь игрока.



### Pre-Alpha 0.6.0 — отдельная импортированная GLB-модель главного героя

- Первая самостоятельная PS1/PS2 low-poly модель дембеля по пользовательскому концепту: выцветший зимний бушлат, ремень, подсумок, вещмешок, брюки и берцы.
- Подключение через `res://assets/dembel_2005.glb`; вершины и отдельные узлы ног, коленей и рук импортируются из реальной 3D-модели, а не рисуются GDScript.
- **Исправление вытягивания ног:** при взгляде вниз поворачивается только камера. Позиции тазобедренных и коленных узлов никогда не зависят от угла взгляда; движение ног — ограниченное вращение суставов во время ходьбы.
- В первом лице спрятана модель головы, чтобы камера не смотрела изнутри полигонов лица. Старый процедурный body rig выключен в визуализации, но сохранён как резервный вариант и для предыдущих тестов.
- Исходник генератора модели: `scripts/build_dembel_character.py`. CI генерирует GLB перед импортом в Godot (`pip install numpy trimesh`; `python scripts/build_dembel_character.py godot/assets/dembel_2005.glb`). Полученный GLB можно открыть и дальше редактировать в Blender.
- Новая регрессионная проверка подтверждает загрузку GLB, симметрию ног и неподвижность их точек крепления при вращении камеры. Полноценный внешний вид по игровым скриншотам требует визуальной проверки.



### Pre-Alpha 0.5.9 — расслабленные руки и чистый переход к виду на тело

- По игровым скриншотам исправлена поза: руки больше не держатся перед лицом симметрично, словно постоянно удерживают предмет. Левая рука расположена ниже правой; предплечья тоньше, угол локтя естественнее.
- Геометрия кистей получила сужающуюся форму ладони и направленные вниз пальцы вместо прямоугольных кулаков; сохранён грубый low-poly стиль одежды демобилизованного героя.
- При умеренном наклоне камеры вниз FPS-руки заранее опускаются за край кадра, а при дальнейшем наклоне исчезают, оставляя куртку и ноги читаемыми. На максимальном наклоне доступны руки full-body, как в предыдущей версии.
- Добавлен регрессионный тест промежуточного угла камеры, где раньше FPS-кисти накладывались на куртку. Мир, сюжет, коллизии и движение остаются прежними.



### Pre-Alpha 0.5.8 — отдельные low-poly FPS-руки

- Новый `godot/fps_viewmodel.gd` — две камеры-привязанные руки с пятигранным/шестигранным силуэтом рукавов выцветшего бушлата, манжетами, ладонями, большим пальцем и фалангами. Пока без оружия или предмета.
- Руки в обычной игре крупнее, но расположены по нижним сторонам экрана; реагируют на поворот мыши, дыхание и шаги. Существует только одна визуальная пара рук: на экстремальном взгляде вниз управление видимостью возвращается к полноценному телу.
- Промежуточные жесты персонажа временно скрывают FPS-руки, чтобы не возникало наложения с уже существующей кинематографической анимацией.
- Физика, камера и достигнутая в 0.5.7 видимость ног не изменены. Добавлен независимый headless-тест viewmodel, его кадрирования, handoff и восстановления после сюжетной анимации.


### Pre-Alpha 0.5.7 — ноги целиком при взгляде вниз

- Скриншоты из браузера выявили недостаток предыдущей проверки: ботинки проходили тест по точкам, но голени и бёдра почти не показывались в кадре.
- Увеличена плавная визуальная компенсация перспективы при взгляде вниз: бёдра, колени и ботинки должны теперь занимать различимые участки кадра. При обычном взгляде сохранена прежняя вертикальная поза.
- Брюки и обувь немного светлее для читаемости в тёмной сцене.
- Тест обновлён: отдельно проверяет экранные проекции бёдер, голеней и ботинок. Физика движения и камера не изменены.


### Pre-Alpha 0.5.6 — ноги и ботинки при взгляде вниз

- Исправлены подошвы и носки ботинок, ранее частично скрывавшиеся под уровнем земли.
- Появилась отдельная коррекция визуальной позы при сильном наклоне взгляда вниз: колени и голеностопы слегка выдвигаются в кадр, а голени сохраняют соединение с бёдрами. При обычном взгляде ноги возвращаются в исходное вертикальное положение.
- Добавлен регрессионный тест проекции двух ботинок и коленей относительно настоящего края куртки, а также тест высоты подошвы относительно поверхности. Игровая капсула, камера и физика передвижения не менялись.


### Pre-Alpha 0.5.5 — анатомия ног и цикл шага

- Ноги больше не вынесены вперёд: таз, колени и голеностопы находятся почти на одной вертикали. Ботинки слегка направлены носками вперёд и видны при взгляде вниз.
- Вместо вращения жёсткой ноги целиком — отдельное движение бедра, сгибание колена и компенсация голеностопа. При остановке походка плавно переходит в стоячую позу.
- Анимация управляется скоростью по земле и не меняет физику капсулы, столкновения с объектами, высоту камеры или движение игрока. Добавлен отдельный headless-тест походки.


### Pre-Alpha 0.5.4 — меню паузы и настройка обзора

- **Esc** открывает паузу: движение и симуляция мира останавливаются, курсор становится свободным. **Esc** повторно или кнопка «Продолжить игру» возвращают к тому же моменту и состоянию мира.
- В паузе доступна настройка чувствительности мыши (0,5–1,8×), действующая сразу и сохраняющаяся до перезагрузки страницы. Подсказки по клавишам находятся в том же меню.
- Положение ног и геометрия куртки из 0.5.3 оставлены без изменений до визуальной проверки в браузере. GitHub Actions проверяет остановку/возобновление дерева и передачу настройки игроку.

### Pre-Alpha 0.4.3 — физика объектов и анимация персонажа

Стены домов, видимые секции заборов (с проходами), теплицы, колодцы, крупные дворовые объекты, машины и стволы деревьев теперь имеют физические коллизии. Движение игрока проверяется через Godot Physics. Клавиша **V** запускает короткую необязательную анимацию курения у взрослого главного героя: это исключительно визуальная характеристика персонажа, без бонусов, игровых ресурсов или трактовки как лечения ПТСР. В первой реализации движение и сюжет не зависят от анимации.

### Глава 1 — «Возвращение» (первый игровой эпизод)

Действие: **ноябрь 2005 года**, герой возвращается после демобилизации в заброшенную родную деревню. Прототип главы начинается непосредственно в Чернозёрье: найдите родной дом, подойдите к отмеченному месту у дороги, нажмите **E** (на русской раскладке **У**) и осмотрите оставленные вещи и деревянную маску в отдельном 3D-интерьере. **J / О** открывает журнал задач. Завершение двух улик и выход возвращают игрока в открытый мир. Эта сцена ещё не содержит транспорта, полноценных интерьеров других домов и вражеского ИИ.

### Запуск игры (текущая версия)

- Откройте https://blacklambcult.github.io/chernozerye/
- Веб-версия **сразу открывает игровую 3D-деревню** по ручной разметке из 314 объектов; больше не нужно нажимать «Ручная разметка».
- В игровом HUD и встроенной карте отображаются **Fearless Knights of the Cordon / Pre-Alpha 0.4.3**. Старые кнопки перехода в географический прототип и возврата к нему не показываются.
- Временная отдельная ссылка на файлы сборки: https://blacklambcult.github.io/chernozerye/ — только после успешной публикации GitHub Actions.
- **WASD** — движение, мышь — обзор после щелчка, **M/Ь** — карта, **Esc** — пауза и свободный курсор (ещё раз Esc — продолжить).
- В GitHub Actions автоматическая проверка требует `FEARLESS_KNIGHTS_STARTUP_READY`, `manual_mode=true`, загрузку 314 объектов и прежние проверки геометрии. При неудачной сборке последняя опубликованная игра не изменяется.

---

## История проекта «Чернозёрье»

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


## Чернозёрье 3.9 — исправления геометрии (Web /v39)

- Ручная география (314 объектов) не меняется: все изменения касаются только визуальной процедурной геометрии.
- **Подходы к домам:** фасад выбирается с учётом направления к ближайшей дороге и проверкой свободного пространства. Перед каждой дверью резервируется коридор; секции забора, теплицы, другие крупные дворовые объекты и цветы в этом коридоре не создаются. Пропуск забора служит калиткой.
- **Дороги:** поверхность, обочины и пара колей строятся как непрерывные ленты с общей вершиной на повороте; острые миты ограничены. Это исправляет треугольные разрывы, возникавшие при сборке отдельных дорожных прямоугольников.
- **Крыши:** мелкие высококонтрастные пиксельные детали ослаблены, повторение текстуры уменьшено; кровельные накладки отделены дальше от основного ската. В режиме ручной деревни камера использует near=0.60, far=390 вместо 0.36/680 для лучшей точности depth buffer, добавлено MSAA 2x (насколько это допускает WebGL-рендерер).
- **Проверки CI:** headless GDScript regression test `godot/geometry_regression.gd` проверяет стыки дороги, резервирование дверного прохода, отсутствие забора и теплицы в проходе. Помимо него продолжаются проверки 314 объектов и дымовой тест запуска сцены.
- После успешного GitHub Actions экспорта: https://blacklambcult.github.io/chernozerye/v39/

Если CI красный — смотрите `Regression-test curved roads and entrance clearance` и `Validate GDScript sources` в `.github/workflows/web.yml`. Эти изменения не гарантируют отсутствие артефактов WebGL: оценка мерцания крыши требует проверки при движении в браузере.

### Pre-Alpha 0.4.3 — правка столкновений и камеры

Замкнутые коллизии для стен домов вместо плоских оболочек; капсула игрока расширена до 0.46 м, камера не должна входить в декоративные бревна и углы. Добавлен тест, проверяющий движение капсулы к реальной стене и через предусмотренный проём забора. Необязательная короткая анимация персонажа уменьшена, чтобы предмет и частицы не закрывали обзор. Возможны оставшиеся визуальные недостатки, проверяемые в браузере.

### Pre-Alpha 0.4.3 — корректная камера у фасадов

Исправлена причина обрезания стен в Godot Compatibility Web: при входе в ручную деревню ближняя плоскость камеры ошибочно ставилась на 0,60 м при радиусе коллизии персонажа 0,46 м. Теперь ближняя плоскость — 0,16 м, дальняя — 250 м (дальние объекты скрываются туманом). В автоматической проверке соотносятся ближняя плоскость и капсула персонажа. Жест по V теперь плавно поднимает и опускает руку; подсказка к родному дому содержит стрелку относительно направления взгляда, а не только расстояние.

### Pre-Alpha 0.4.4 — путь домой и атмосфера пролога

Указатель направления в HUD теперь показывает слова «ПРЯМО», «НАЗАД», «СПРАВА» или «СЛЕВА» вместо неподдерживаемых шрифтом символов стрелок. При приближении к родному дому появляются две короткие, неповторяющиеся сюжетные реплики о заброшенной деревне. Декоративная модель руки уменьшена в кадре: жест расположен ниже и ближе к краю экрана. Проверки CI дополнены тестом направлений и однократных событий пролога.

### Pre-Alpha 0.4.6 — персонаж и игровой HUD

Добавлена процедурная заглушка полнотелой модели от первого лица: торс, одежда, две руки и две ноги, видимые при взгляде вниз, с простым циклом ходьбы. HUD: слева сверху имя задания, по центру сверху компас N/E/S/W с меткой задания, слева снизу здоровье 100/100 (пока без системы урона), справа снизу четыре ячейки, первая содержит вымышленную пачку сигарет. Клавиши 1–4 выбирают ячейку, V воспроизводит необязательную декоративную анимацию правой руки. Анимация не даёт бонусов и не лечит ПТСР. Модель и эффекты предварительные, не финальная анимация.

### Pre-Alpha 0.4.6 — корректировка обзора и интерфейса

При взгляде вниз камера больше не должна проходить сквозь модель: убран верхний воротник, геометрия туловища смещена назад относительно глаз и опущена ниже, уменьшены плечи. Временная модель по-прежнему видима при взгляде вниз, ноги и ботинки остаются на месте. Декоративный жест по V переписан как отдельная анимируемая конструкция плечо—локоть—кисть с подъёмом руки ближе к лицу вместо перемещения прямой руки. Текст расстояния до родного дома и управление журналом находятся под названием задания слева сверху; направления в тексте больше нет, за ориентацию отвечает компас. Субтитры остаются по центру снизу.

### Pre-Alpha 0.4.7 — гражданская куртка, естественный шаг, модель кисти

Исправлена временная модель от первого лица по отзывам: вместо широкой прямоугольной груди и «бронежилета» создан узкий восьмигранный силуэт обычной тёмной куртки, плечи и центр корпуса не перекрывают взгляд вниз, остаются ноги и обувь. Персонаж идёт медленнее: стандартный шаг 3,35 м/с, ускоренный 5,15 м/с, переход к скорости и остановка сглажены. Отдельная декоративная анимация по V использует более компактную кисть и рукава, сгиб локтя сохраняется, кисть поднимается к уровню лица. Поведение анимации не даёт баффов, эффекта здоровья или лечения травматического стресса. В CI проверяются новая форма торса, размеры кисти, траектория и скорость.

### Pre-Alpha 0.4.8 — один тазовый узел и обновлённая анимация руки

Торс, подол куртки и обе ноги теперь строятся относительно общего узла PelvisRoot. Удалены отдельные шарообразные сочленения бёдер, которые выглядели как выступающие круги при взгляде вниз. Камера остаётся отдельной и вращается по вертикали без поворота таза. Исправлена ориентация кисти в декоративной анимации: ладонь обращена к лицу, два отдельных пальца разделены моделью сигареты, цветной конец модели смотрит наружу. Автоматические тесты проверяют взаимное положение тела, ладони и модели, а также отсутствие регрессий в физике и сюжете.

### Pre-Alpha 0.4.9 — обзор вниз и форма руки

Для уменьшения перекрытия камеры крупной геометрией при почти вертикальном взгляде вниз верх куртки и обычные рукава временно скрываются, но пояс, нижняя часть куртки, ноги и ботинки продолжают отображаться. Верхняя часть возвращается после подъёма взгляда. Убрана узкая выступающая деталь спереди куртки. Косметический жест по V получил округлую ладонь вместо плоской коробки, манжету для скрытия разрыва с рукавом и более компактное расположение пальцев; модель сигареты немного уменьшена. Это пока процедурная геометрия и временная анимация, не готовый скелет персонажа. Скорость и остальные механики не менялись.

### Pre-Alpha 0.5.0 — непрерывная модель тела и сюжетный предмет

Торс возвращён и остаётся видимым при взгляде вниз: две компактные секции обычной куртки размещены над общим тазом, без полного скрытия верхней части при наклоне камеры. Сохранены брюки, ботинки и сглаженная скорость передвижения.

Прежний краткий жест V удалён и заменён отдельной визуальной последовательностью взрослого персонажа: при выбранной первой ячейке (пачка) клавиша V запускает сценическую анимацию с пачкой, реквизитом зажигалки и перемещением сигареты к лицу; затем небольшой реквизит остаётся у края кадра около 120 секунд без постоянной руки, постепенно уменьшается, после чего последовательность автоматически заканчивается и на земле появляется краткая декоративная деталь. Другие ячейки не запускают событие; повторный запуск до конца цикла запрещён. Система исключительно визуальная, без усилений, лечебных эффектов или изменения игровых характеристик.

### Pre-Alpha 0.5.1 — устранение многоугольника перед ногами

Обе секции процедурной куртки стали открытыми оболочками без плоских верхних и нижних заглушек цилиндров. При взгляде вниз крупный тёмный восьмиугольник больше не должен закрывать землю и брюки; торс и обе ноги сохраняются. Маленький реквизит у лица перенесён непосредственно к краю ближней плоскости камеры, уменьшен и направлен вперёд от лица: при взгляде прямо вниз он не должен зависать над торсом. Основная последовательность V, выбранный предмет, автоматическое течение 120 секунд и завершение без влияния на характеристики сохранены.

### Pre-Alpha 0.5.2 — исправленный вид тела по референсам

Вид от первого лица перестроен в `godot/first_person_body.gd`: вместо полых цилиндров куртки используется связанная оболочка из вертикальных передних и боковых панелей (без больших заглушек). Плечи и руки расположены по бокам, корпус плавно переходит в таз, а ноги имеют более читаемые бедра, колени, голени и ботинки, выдвинутые немного вперед. Вертикальное вращение камеры не поворачивает модель тела; туловище не скрывается при взгляде вниз. В регрессионных тестах дополнительно проверяется перспективное расположение ботинка выше живота. Отдельная двухминутная косметическая сценическая последовательность не изменена.

### Pre-Alpha 0.5.3 — исправление геометрии ног

Исправлено положение ног под общим тазом: бедра почти вертикальные, колени и голени меньше выступают вперёд, ботинки компактнее и ближе к проекции тела. Снижена амплитуда поворота ног при ходьбе с 0,19 до 0,12 радиана, чтобы исчезло ощущение постоянного полуприседа и выноса ног под углом. Камера, туловище, руки, движение по миру и сюжетные механики не менялись. Регрессионный тест теперь дополнительно проверяет положение бёдер, коленей и передней части ботинок.
