# Steam screenshot candidates

These eight 1920×1080 PNGs were captured from the exported Windows Release build of 山河问道 0.17.0. They show the real game UI and deterministic gameplay states; no concept art or generated promotional scene is substituted for gameplay.

Regenerate them from the repository root after exporting the full build:

```powershell
& ".\build\windows\ShanheWendao.exe" -- --capture-store-screenshots
```

Godot writes the captures to `user://store_screenshots`. Copy the reviewed output here only after checking every image for overlays, debug UI, cropping, readability, and accurate representation of the current build. A later gameplay or UI change should trigger a fresh capture and visual review before Steam upload.
