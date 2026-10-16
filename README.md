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
docs/DEVELOPMENT.md     full guide and development log (Italian)
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
`docs/DEVELOPMENT.md`, "Come ricompilare").

Delete any old `AutoReady.u` before recompiling: `ucc make` skips packages
that already exist.
