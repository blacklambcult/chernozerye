// Inserted before the Godot Engine constructor in the Web export.
if (new URLSearchParams(location.search).get("startup_profile") === "1") {
    if (!GODOT_CONFIG.args.includes("--")) GODOT_CONFIG.args.push("--");
    GODOT_CONFIG.args.push("--startup-profile");

    const page = new URL(".", location.href);
    const resources = ["index.wasm", "index.pck"];
    window.chernozeryeStartupProfile = {
        worldStart: null,
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
            console.table(files);
            console.table({
                navigationToMapReadyMs: Math.round(ready),
                navigationToFilesReadyMs: filesEnd === null ? null : Math.round(filesEnd),
                filesReadyToWorldStartMs: filesEnd === null || this.worldStart === null
                    ? null : Math.round(this.worldStart - filesEnd),
                worldStartToMapReadyMs: this.worldStart === null
                    ? null : Math.round(ready - this.worldStart),
            });
        },
    };
}
