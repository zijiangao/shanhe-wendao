# Steam release preparation

The project includes both a persistent local simulation and a dynamic GodotSteam adapter. At startup it attempts the live adapter only when the `Steam` engine singleton exists and its required API is compatible; initialization failure safely falls back to the local simulation. The repository still does not ship GodotSteam, a Steamworks redistributable, or an App ID, so current exported builds must not claim a live Steam connection.

The live adapter waits for `current_stats_received` before writing account data. Achievement and integer-stat changes requested during startup are queued, merged, and flushed once after Steam reports a successful stats load. `SteamService` pumps `run_callbacks` every frame, reports the account-stat synchronization state on the achievements screen, and calls `steamShutdown` during clean exit. When selecting a GodotSteam build, pin a version compatible with the shipping Godot version, add its license and Steamworks redistributable notices, and rerun the adapter contract tests against the actual extension.

## Achievements

The authoritative 15 definitions are in `data/steam_achievements.json`. Create matching achievements in Steamworks using the exact `api_name` values before enabling the live adapter. The four training/crafting milestones use saved world-state flags so they can be restored after loading, while account-level unlock state remains in `ISteamUserStats` and is never embedded in a game save. Configure both integer stats, `STAT_HIGHEST_MASTERY` and `STAT_HIGHEST_SPECIALTY`, before testing the live adapter.

The local simulation stores `user://steam_local.cfg` only for development. Do not include that file in Steam Auto-Cloud.

## Steam Auto-Cloud

Godot stores this project's Windows user data under `%APPDATA%/Godot/app_userdata/山河问道`.

Configure these two Auto-Cloud root entries in Steamworks:

| Root | Subdirectory | Pattern | OS | Recursive |
| --- | --- | --- | --- | --- |
| `WinAppDataRoaming` | `Godot/app_userdata/山河问道` | `*.json` | Windows | No |
| `WinAppDataRoaming` | `Godot/app_userdata/山河问道` | `*.json.bak` | Windows | No |

This includes automatic and manual saves plus their recovery backups. Exclude `settings.cfg`, `steam_local.cfg`, and temporary `*.tmp` files. Display, audio, and local mock-account settings are machine-specific.

Before release, publish the Cloud configuration and verify upload/download on two separate Windows machines using Steam's `testappcloudpaths <AppId>` console command.

## SteamPipe

Release export produces:

- `ShanheWendao.exe`
- `ShanheWendao.pck`

Keep both files in the same depot directory. Example VDF files and `prepare_steampipe.ps1` live in `steamworks/scripts`. The preparation script validates four distinct numeric App/Depot IDs, semantic version text, private beta branch names, and the required Full/Demo EXE+PCK pairs. It then writes resolved VDF files to the ignored `steamworks/generated` directory using the actual absolute build paths. Steam credentials are never accepted or stored by the script.

```powershell
& .\steamworks\scripts\prepare_steampipe.ps1 `
  -FullAppId <APP_ID> -FullDepotId <WINDOWS_DEPOT_ID> `
  -DemoAppId <DEMO_APP_ID> -DemoDepotId <DEMO_WINDOWS_DEPOT_ID> `
  -Version 0.23.0 -BetaBranch internal-qa -DemoBetaBranch demo-qa
```

Run `test_prepare_steampipe.ps1` after changing any VDF template or preparation rule. It verifies successful generation and rejection of duplicate IDs, public/default release-candidate branches, and incomplete build artifact pairs.

Upload new builds to a password-protected beta branch first. The preparation script intentionally rejects `public` and `default` as candidate targets. Test install, launch, save migration, Cloud synchronization, controller navigation, overlay behavior, achievements, offline launch, uninstall/reinstall, and rollback before promoting a build to the default branch through Steamworks.

## Live-integration gate

Do not report Steam integration as complete until all of the following are proven with the assigned App ID:

- Steam API initializes from a Steam client launch and safely falls back offline.
- Every configured achievement unlocks once and persists after restart.
- Every achievement has approved unlocked and locked artwork uploaded in the dimensions required by Steamworks.
- Steam Overlay works in windowed and fullscreen modes.
- Auto-Cloud round-trips current and legacy saves on two machines.
- Depot install contains the EXE, PCK, required Steam redistributables, and licenses.
- A clean Steam install passes the full first-run and battle flow.
- The build has been tested on a private Steam branch before default-branch promotion.

The exported executable also supports `--verify-steam-data`. Run it from both full and demo depot candidates to prove that the packaged achievement metadata is present before upload. This verifier does not substitute for a live account test.
