# Building 山河问道

## Requirements

- Godot 4.7.1 stable
- Godot 4.7.1 Windows export templates

## Run automated tests

From the repository root, run each test scene headlessly:

```powershell
$godot = "C:\path\to\Godot_v4.7.1-stable_win64_console.exe"
$project = Join-Path $PWD "godot"
$tests = @(
    "test_game_state.gd",
    "test_save_manager.gd",
    "test_battle_rules.gd",
    "test_battle_engine.gd",
    "test_battle_scene_spec.gd",
    "test_settings_manager.gd",
    "test_difficulty_rules.gd",
    "test_location_art.gd",
    "test_release_credits.gd",
    "test_store_capture_spec.gd",
    "test_navigation_rules.gd",
    "test_tutorial_rules.gd",
    "test_cue_synth.gd",
    "test_steam_service.gd",
    "test_demo_policy.gd"
)

foreach ($test in $tests) {
    & $godot --headless --path $project --script ("res://tests/" + $test)
    if ($LASTEXITCODE -ne 0) { throw "$test failed" }
}
```

The save-manager test deliberately feeds malformed and future-version save files to verify recovery, so warning/error log lines from those fixtures are expected.

The main scene also provides a release presentation verifier. It instantiates the real tactical battle view, plays movement, attack, damage, guard, and boss-technique events, then exits with a non-zero code if the input lock was not released:

```powershell
& $godot --headless --path $project -- --verify-battle-presentation
```

## Export Windows Release

```powershell
New-Item -ItemType Directory -Force -Path (Join-Path $PWD "build/windows") | Out-Null
& $godot --headless --path $project --export-release "Windows Desktop"
New-Item -ItemType Directory -Force -Path (Join-Path $PWD "build/windows-demo") | Out-Null
& $godot --headless --path $project --export-release "Windows Demo"
```

The Windows release is written to `build/windows/ShanheWendao.exe` with `ShanheWendao.pck` beside it. Both files are required. Keeping game content separate improves SteamPipe patch behavior. The `build` directory is intentionally ignored by Git.

The demo is written separately to `build/windows-demo/ShanheWendaoDemo.exe` with `ShanheWendaoDemo.pck`. Its `demo` custom feature enforces the Blackreed victory boundary; the full preset has no such feature.

## Capture Steam store screenshots

After exporting the full Windows release, run the shipping executable with `--capture-store-screenshots`. It creates seven deterministic 1920×1080 gameplay PNGs under the Godot user-data folder in `store_screenshots`. These are candidate captures from the actual release UI; visually review every image before uploading it to Steam.

```powershell
& "..\build\windows\ShanheWendao.exe" -- --capture-store-screenshots
```

Before a public Steam release, review `ASSET_PROVENANCE.md` and `THIRD_PARTY_NOTICES.md`, replace the current provisional application icon only after the final brand and art-rights review, and configure code signing in the Windows export preset.
