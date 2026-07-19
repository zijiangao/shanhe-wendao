# Steam release preparation

The project currently uses a local Steam-service simulation. It does not claim a live Steam connection and does not ship a Steamworks redistributable. A real adapter can replace the local backend after the game has an App ID and an approved Godot Steamworks integration.

## Achievements

The authoritative initial definitions are in `data/steam_achievements.json`. Create matching achievements in Steamworks using the exact `api_name` values before enabling the live adapter. Achievement progress is account-level and should be sent through `ISteamUserStats`; it must not be embedded in a game save.

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

Keep both files in the same depot directory. Example VDF files live in `steamworks/scripts`; copy them outside the repository, replace every placeholder, and keep Steam credentials out of source control.

Upload new builds to a password-protected beta branch first. Test install, launch, save migration, Cloud synchronization, controller navigation, overlay behavior, achievements, offline launch, uninstall/reinstall, and rollback before promoting a build to the default branch.

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
