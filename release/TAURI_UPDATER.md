---
description: "TAURI_UPDATER"
---

# Tauri updater — suggested config snippet

The project's `tauri.conf.json` must enable the updater. The exact place to add this depends on your Tauri version; some schemas expect `tauri.updater` and others accept a top-level `updater` key.

If your `tauri.conf.json` schema accepts a top-level `updater` key, add the following snippet (replace owner/repo):

```json
"updater": {
  "active": true,
  "dialog": true,
  "endpoints": [
    "https://api.github.com/repos/<OWNER>/<REPO>/releases"
  ]
}
```

If your schema nests options under `tauri` (some versions), add under `tauri`:

```json
"tauri": {
  "updater": {
    "active": true,
    "dialog": true,
    "endpoints": [
      "https://api.github.com/repos/<OWNER>/<REPO>/releases"
    ]
  }
}
```

Notes
- Replace `<OWNER>/<REPO>` with `fuaadabdullah/ForgeMonorepo` or the repository you publish releases to.
- The Tauri GitHub updater will look for release assets that match platform and channel naming conventions. Ensure your release artifacts follow a predictable name (e.g., `MyApp-macos.zip`).
- Test update flow locally by publishing a GitHub release with the artifact and running the app built with the updater enabled.
