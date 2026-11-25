// Inserted before the Godot Engine constructor in the Web export.
if (new URLSearchParams(location.search).get("startup_profile") === "1") {
    if (!GODOT_CONFIG.args.includes("--")) GODOT_CONFIG.args.push("--");
    GODOT_CONFIG.args.push("--startup-profile");

    const page = new URL(".", location.href);
    const resources = ["index.wasm", "index.pck"];
    window.chernozeryeStartupProfile = {
        worldStart: null,
        worldReady: null,
        mapStart: null,
        finish() {
            const ready = performance.now();
            const files = resources.map(file => {
                const entry = performance.getEntriesByName(new URL(file, page).href, "resource").at(-1);
                return {
                    file,
                    durationMs: entry ? Math.round(entry.duration) : null,
                    responseEndMs: entry?.responseEnd || null,
                    transferBytes: entry?.transferSize ?? null,
                    decodedBytes: entry?.decodedBodySize ?? null,
                };
            });
            const responses = files.map(file => file.responseEndMs);
            const filesEnd = responses.every(value => value !== null) ? Math.max(...responses) : null;
            const elapsed = (start, end) =>
                start === null || end === null ? null : Math.round(end - start);
            console.table(files);
            console.table({
                navigationToMapReadyMs: Math.round(ready),
                navigationToFilesReadyMs: filesEnd === null ? null : Math.round(filesEnd),
                filesReadyToWorldStartMs: elapsed(filesEnd, this.worldStart),
                worldStartToMapReadyMs: elapsed(this.worldStart, ready),
                worldInitMs: elapsed(this.worldStart, this.worldReady),
                worldReadyToMapStartMs: elapsed(this.worldReady, this.mapStart),
                manualMapBuildMs: elapsed(this.mapStart, ready),
            });
        },
    };
}
