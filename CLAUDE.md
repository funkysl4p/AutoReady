# AutoReady – context for Claude

## Project
UnrealScript mutator `AutoReady` for a UT99 dedicated server used at LAN
parties with friends. Current version: 1.2.

## Server environment
- Ubuntu on Oracle Cloud free tier (1 vCPU, 1 GB RAM), user `ubuntu`.
- Server installed in `/opt/ut99-server`, OldUnreal 469f: on Linux binaries
  and ini files are in `System/` (no longer `System64/`).
- Runs as systemd service `ut99-server` (`ucc-bin-amd64`).
- Other mods on the server: VoteSys (map/preset voting), FragNewNet (fnn353:
  instagib, combogib, rocket arena, grapple), FragStats, IpToCountry.
- Game modes: DM, TDM, CTF, each in standard / instagib / combogib variants.

## Design notes (do not regress)
- Spectators are identified by class (`IsA('Spectator')`), NOT by
  `PlayerReplicationInfo.bIsSpectator`: FNN's warm-up reset puts players in
  `PlayerWaiting` with `bIsSpectator=True`.
- Original `MaxPlayers` is read at adjustment time, not in `PostBeginPlay`:
  VoteSys applies `GameSettings` after initialization.
- Timeout starts when a majority is ready (`Present/2 + 1`, not configurable).
- Live countdown at screen centre in the last 10 seconds.
- Configuration in a separate `AutoReady.ini`; `bDebug` enables per-player
  logging.

## Conventions
- On-screen messages and log lines in **English** (standard for all mutators).
- Code comments in English.
- Server-side only: never add to `ServerPackages`.
- Never commit passwords or real server ini files.
- Commit messages in English, imperative mood.

## Key files
- `AutoReady/Classes/AutoReady.uc` – source of the current build (v1.2, 21 593 bytes).
- `docs/DEVELOPMENT.md` – full guide and development log: parameters,
  installation, use cases, troubleshooting, rebuild procedure. Update its
  "Current status" and "Development log" sections with every new build.
- `tools/nodots.c` – LD_PRELOAD shim for the `ucc make` "Analyzing..." loop on Linux.
- `AutoReady.ini.example` – default configuration.
- Documentation (README, docs/) in English.

## CI/CD
- `ut-patch.conf` selects the OldUnreal patch CI builds against (keep in line with the server).
- `scripts/setup-ut.sh` installs UT99 via the official OldUnreal installer, pinned to that tag.
- `scripts/compile.sh` builds AutoReady.u; used by CI and locally.
- No deploy automation: installation on the server is done by hand.
