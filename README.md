# AutoReady

Server-side mutator for Unreal Tournament 99 (OldUnreal 469f) that enables
tournament-style ready-up without requiring a full server.

## How it works
When the present players press Fire (or the ready timeout expires once a
majority is ready), `MaxPlayers` is temporarily lowered to the number of
present players so that `DeathMatchPlus` starts the countdown. Once the match
starts, the original `MaxPlayers` is restored so late joiners can still enter.

- Server-side only: do **not** add it to `ServerPackages`.
- Enable it in the VoteSys presets with `bTournament=True`, e.g.
  `Mutators=AutoReady.AutoReady`.
- Admin commands: `mutate ar status | start | hold`.
- Configuration lives in `System/AutoReady.ini`.

## Repository layout
```
AutoReady/Classes/      UnrealScript sources (*.uc)
docs/DEVELOPMENT.md     full guide and development log
tools/nodots.c          LD_PRELOAD shim for the ucc make loop on Linux
AutoReady.ini.example   default configuration
scripts/build.sh        copy sources to the server and compile
```

## Build
On the server (`/opt/ut99-server`):
1. Copy `AutoReady/` to `/opt/ut99-server/AutoReady/`.
2. Add `EditPackages=AutoReady` under `[Editor.EditorEngine]` in
   `System/UnrealTournament.ini` (only needed while compiling).
3. `cd /opt/ut99-server/System && ./ucc-bin-amd64 make -nohomedir`
4. Expect `Success - 0 error(s)`; `AutoReady.u` is created in `System/`.

If `ucc make` hangs on "Analyzing...", preload `tools/nodots.c` (see
`docs/DEVELOPMENT.md`, "How to rebuild").

Delete any old `AutoReady.u` before recompiling: `ucc make` skips packages
that already exist.

## CI/CD (GitHub Actions)

- **Build** (`.github/workflows/build.yml`) runs on every push and pull request.
  It installs UT99 GOTY + the OldUnreal patch selected in `ut-patch.conf`
  using the official OldUnreal installer, compiles `AutoReady.u` and uploads it
  as an artifact. Pushing a tag `vX.Y` also publishes a GitHub Release with
  `AutoReady.u` and its md5.
- The UT99 installation is **cached per patch tag**: the game is downloaded
  and installed only on the first build and whenever a new patch is released
  (`UT_PATCH=newest` follows release candidates too).
- **Deploy** (`.github/workflows/deploy.yml`) is manual only (Actions → Deploy →
  Run workflow, with a release tag). It joins the tailnet, copies `AutoReady.u`
  to the server, verifies the md5 and restarts `ut99-server`.
  Required secrets: `TS_AUTHKEY`, `SSH_KEY`, `SERVER_HOST`.

Local build against any UT99 installation:
`scripts/compile.sh <ut99-dir>` (output in `build/`).
