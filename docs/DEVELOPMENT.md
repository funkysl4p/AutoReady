# AutoReady – status, backlog and development log

Rules, constraints and conventions are in `CLAUDE.md`; user documentation in
`README.md`; the build in `docs/BUILD.md`.

## Current status

Latest build: **AutoReady v1.2**, `AutoReady.u` 21,593 bytes (md5 `68c7c4800c8f15763ae6a8d9ce86dbd0`), compiled before the move to CI. Installed on the server and tested with a single player.

**Tested and working (28/09, single player with `MinReadyPlayers=1`):** start on Fire, countdown with players back in the waiting state, `MaxPlayers` restored once the match starts, `mutate ar hold` / `mutate ar start`, logging and debug.

## Backlog

Open items. Tick them off (or remove them) when done and record the outcome in "Development log".

**Testing v1.2**

- [ ] Two clients, `MinReadyPlayers=2`: no timeout in a duel, status message in chat, disconnect during the countdown (start cancelled), `mutate ar status`.
- [ ] Three or more clients: majority timeout, on-screen countdown, player forced ready by the timeout.
- [ ] Teams (TDM) with `bRequireBalancedTeams=True`.
- [ ] After testing: `AutoReady.ini` with `MinReadyPlayers=2` and `bDebug=False`, edited with the server stopped.

**Build and release**

- [ ] Publish the first release (`v1.2`) from CI and install it on the server; the CI build is compiled against 469f-rc5, so its size and md5 differ from the build above.
- [ ] Update "Current status" with the size and md5 of the released `AutoReady.u`.
- [ ] At every new OldUnreal patch, check whether `ucc make` still needs the `nodots` shim (build once without `LD_PRELOAD`); if the bug is gone, simplify `scripts/compile.sh` and `docs/BUILD.md`. Consider reporting the bug to OldUnreal.

## How it works, step by step

Every second AutoReady checks the situation and does exactly one of the following.

1. **Tournament mode off** (`bTournament=False`): logs that there is nothing to do and disables itself for the rest of the map.
2. **Match already started**: restores the original `MaxPlayers`, logs a summary and disables itself.
3. **Counts players.** Anyone who is not a real spectator (class `Spectator`) counts as a player. Players waiting for the match count, even if UT temporarily flags them as spectators. Bots do not count.
4. **Too few players** (fewer than `MinReadyPlayers`): waits, no timeout.
5. **Admin hold active** (`mutate ar hold`): starts nothing and repeats "Start on hold by admin" at screen centre.
6. **More than half ready, but not everyone**: starts the `ReadyTimeout` timer. In the last 10 seconds it shows "Forced start in N s - press Fire!" at screen centre. When it expires, latecomers are marked ready.
7. **Everyone ready** (and teams balanced, if required): saves the current `MaxPlayers`, lowers it to the player count and the game starts the 10…1 countdown.
8. **During the countdown**: if someone joins or leaves, `MaxPlayers` is realigned with the player count. If players drop below `MinReadyPlayers`, the start is cancelled and the original `MaxPlayers` is restored.
9. **Status messages**: every `MessageInterval` seconds, the number of ready players is posted in chat.

## Development log

AutoReady was created because stock UT99 offers no way to start a tournament-mode match without a full server. Builds are listed newest first. From now on, changes are tracked in git history; add a row here for each new build.

| Date | Build | What changed | Why |
|---|---|---|---|
| 16/10 | – | Project moved to git; documentation translated to English. | Version control and consistency with the English standard. |
| 28/09 | v1.2 · 21,593 bytes · md5 `68c7c480…` | Timeout only if someone is still missing. Centre countdown in the last 10 s. "On hold" repeated every 3 s. | Testing showed a useless "timeout started" with everyone ready. Centre messages disappeared too soon. |
| 28/09 | v1.2 · 21,157 bytes | Spectators identified only by the `Spectator` class. | **Bug:** a player in `PlayerWaiting` has `bIsSpectator=True`, was discarded and the start cancelled after 2 s (endless wait). Tested: match started. |
| 28/09 | v1.2 · 21,218 bytes | First fix attempt using `bWaitingPlayer`. | Superseded by the next, more robust build. |
| 28/09 | v1.2 · 20,836 bytes | `bDebug` flag with `[debug]` lines on each state change. | Needed to find where the start got stuck. |
| 28/09 | v1.2 | Configuration moved to `AutoReady.ini` (`config(AutoReady)`). | Giulio's choice: separate file. |
| 28/09 | v1.2 | Removed `MajorityPercent` and the "timeout only with 3+ players" rule: fixed "more than half" threshold. | One parameter fewer. With 51% rounded up a duel already required both players. |
| 28/09 | v1.2 | Same status message for everyone. | Giulio's choice: details via `mutate ar status`. |
| 28/09 | v1.2 | `mutate ar status/start/hold` commands. Log summary once the match starts. Removed `bCenterMessages`. | Handling real LAN situations (absentees, waiting). |
| 28/09 | v1.1 | `SaveConfig()` at startup. | The config section was never written. |
| 27/09 | v1.1 | Messages and log in English. | Standard for all mutators. |
| 27/09 | v1.1 | `LogAR`/`Announce` helpers, startup banner, messages for every event, `bCenterMessages`. | Visibility for players and admins. |
| 27/09 | v1 | First version: lowers `MaxPlayers` to the player count when everyone is ready, majority timeout, realignment during the countdown, restore on start. | Start tournament mode without a full server. |

**Findings that shaped the project**

- In `DeathMatchPlus.Timer` the tournament countdown only decreases if `NumPlayers == MaxPlayers` and everyone has `bReadyToPlay`.
- In stock UT, `DeathMatchPlus` puts new players in `PlayerPawn` state `PlayerWaiting` when ready-up is required, and that state sets `PlayerReplicationInfo.bIsSpectator=True` (and `bWaitingPlayer=True`); `EndState` clears them.
