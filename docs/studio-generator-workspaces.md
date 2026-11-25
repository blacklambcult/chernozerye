# Generator workspaces — side panels

Base: main 9eb9f031. User screenshot showed the settings drawer covering most of the preview inside World Editor. This package only changes presentation and canvas sizing; generator recipes, geometry, asset storage, game runtime, IDs and actions are unchanged.

- Buildings, Nature, Arms and Weapon Generator use one shared generator-workbench.css. Desktop: selectors on left, settings on right, actual dedicated central viewport. Arms retains its existing left-side library and places generic controls on the right.
- At viewport widths <=820px, reserve the upper half for the model and the lower region for independently scrolling controls instead of covering the canvas. Existing hide/restore UI actions retain fullscreen preview.
- Resize the renderer using actual canvas client dimensions, preserving aspect ratio and pixelated preview mode. No new WebGL contexts.
- World Editor dialog stays within visible iframe bounds, occupies more of the screen and removes duplicate headings/library inputs in object-specific mode.
- Model Lab and Hellish Forge already have dedicated workbench panels; not changed. NPC Lab is a character preview, not one of the four affected overlay generators.
- Cache revisions updated for direct generator routes and embedded preview.

Acceptance: at desktop and small window sizes, open each standalone generator and World Editor's building/nature dialog; expand settings, switch tabs, rotate preview, hide and restore UI; verify no panel covers the viewport, no clipping of dialog buttons, no loss of previously saved configuration. Regression tests assert shared CSS and canvas sizing and run real HTML layout checks in Chromium when available (scripts removed; not a WebGL functional test). Full runtime visual acceptance still required.
