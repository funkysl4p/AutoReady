# AutoReady

Server-side mutator for Unreal Tournament 99 (OldUnreal 469f) that enables
tournament-style ready-up without requiring a full server.

## How it works

In tournament mode UT99 only starts the countdown when the server is full
(`NumPlayers == MaxPlayers`). When all present players have pressed Fire,
AutoReady temporarily lowers `MaxPlayers` to the number of present players, so
the countdown starts. Once the match has started, the original `MaxPlayers` is
restored and late joiners can still enter.

- If a majority is ready, latecomers get `ReadyTimeout` seconds and are then
  marked ready automatically.
- Admin commands: `mutate ar status | start | hold`.
- Server-side only: clients download nothing.

Behaviour in every situation: see "Behaviour for each use case" below.

## Installation and upgrade

AutoReady runs on the server only: clients download nothing.

1. Download `AutoReady.u` and `AutoReady.u.md5` from the latest
   [release](../../releases) and check them with `md5sum -c AutoReady.u.md5`.
2. Stop the server.
3. Copy `AutoReady.u` to the server `System/` folder, replacing any older
   version. Do **not** add it to `ServerPackages`.
4. On first install, copy `AutoReady.ini.example` to `System/AutoReady.ini`
   and adjust it (see Configuration). Lines must not have leading spaces.
5. Start the server and check the log for the startup line
   `AutoReady: v<version> active - MinReady=… Timeout=…`.

**Enabling it.** Add `AutoReady.AutoReady` to the mutators of every game
configuration that uses tournament mode (`bTournament=True`), for example on
the server command line (`?Mutator=AutoReady.AutoReady`) or in the mutator
list of the game configuration; combine it with other mutators as a
comma-separated list. Keep `MinPlayers=0` and `InitialBots=0`: bots are not
counted. In configurations with `bTournament=False` AutoReady is not needed;
if present, it disables itself.

## Configuration

Configuration lives in `System/AutoReady.ini`, section `[AutoReady.AutoReady]`. If the file does not exist, the mutator creates it with default values on first run.

| Parameter | Default | What it does | Recommendation |
|---|---|---|---|
| `MinReadyPlayers` | 2 | Minimum number of present players for AutoReady to start the match. Below this threshold it just waits. | 2 for normal use. 1 only for solo testing. |
| `ReadyTimeout` | 30 | Seconds granted to latecomers once more than half is ready. When it expires, everyone is marked ready. | 30–60. The on-screen countdown covers the last 10 seconds. |
| `MessageInterval` | 5 | How often (seconds) the status message appears in chat ("2/6 ready…"). | 5–10. |
| `bRequireBalancedTeams` | False | Team games only: waits until the team size difference is at most 1 before starting. | True for TDM/CTF to avoid 4 vs 2. |
| `bDebug` | False | Logs a `[debug]` line on every state change: present, ready, `MaxPlayers`, `CountDown`, state of each player. | True while testing, then False. |

**Fixed rule, not configurable:** the timeout starts when **more than half** of present players are ready (2 of 2, 2 of 3, 3 of 4, 4 of 6). In a duel both players must press Fire.

**Warning:** UT reads the `.ini` at startup and rewrites it on shutdown. Edit it **only with the server stopped**, otherwise the change is ignored and then overwritten.

Example (same as `AutoReady.ini.example`):

```ini
[AutoReady.AutoReady]
MinReadyPlayers=2
ReadyTimeout=30
MessageInterval=5
bRequireBalancedTeams=False
bDebug=False
```

## Admin commands

Commands are typed in the game console. Admin commands require `adminlogin <password>` first.

| Command | Who | Effect |
|---|---|---|
| `mutate ar status` | Anyone | Shows the requester how many players are ready and the full list of who is missing. Also reports an admin hold or a match already started. |
| `mutate ar start` | Admin | Marks all present players ready and clears any hold: the countdown starts on the next second. Centre: "Admin forced start". |
| `mutate ar hold` | Admin | Blocks the automatic start until `mutate ar start`. Stops the timeout and, if the countdown had started, restores the original `MaxPlayers`. Centre, every 3 s: "Start on hold by admin". |

Once the match has started, admin commands reply "match already started". An unknown command replies with the list of valid commands.

## Behaviour for each use case

Terms used below:

- `Present`: connected players, excluding spectators and bots.
- `Ready`: present players who pressed Fire (`bReadyToPlay=True`).
- `Needed`: `Present/2 + 1` (integer division), i.e. more than half of `Present`.
- `OriginalMax`: the `MaxPlayers` value in use before AutoReady lowers it.
- Messages show the current values in place of `<Ready>`, `<Present>`, `<N>`, etc.

| Situation | What happens | Messages |
|---|---|---|
| `Present < MinReadyPlayers` | No start, no timeout: keeps waiting. | None |
| `Ready < Needed` | Keeps waiting. | Chat every `MessageInterval` s: "`<Ready>`/`<Present>` ready. Press Fire when you are ready." |
| `Needed <= Ready < Present` | The `ReadyTimeout` timer starts. When `Present = 2`, `Needed = 2 = Present`, so in a duel there is never a timeout. | Chat: "`<Ready>`/`<Present>` ready - forced start in `<ReadyTimeout>`s", then the remaining time every `MessageInterval` s |
| Last 10 s of the timeout (the whole timeout if `ReadyTimeout <= 10`) | Continuous countdown. | Centre, every second: "Forced start in `<N>`s - press Fire!" |
| Timeout expired | Players not ready are marked ready; `MaxPlayers` = `Present`; countdown. | Centre: "Time is up: starting now!" |
| `Ready = Present` (everyone ready) | No timeout: `MaxPlayers` = `Present`; countdown. | Chat: "All players ready (`<Present>`)" |
| A player leaves during the countdown, `Present >= MinReadyPlayers` | `MaxPlayers` follows `Present`; the countdown continues. | Log only |
| `Present < MinReadyPlayers` during the countdown | Start cancelled, `MaxPlayers` = `OriginalMax`, waiting again. | Centre: "Not enough players, start cancelled" |
| A player connects during the countdown | Rejected as "server full" or joins as spectator: `NumPlayers = MaxPlayers`. | None |
| Team game, team sizes differ by more than 1, `bRequireBalancedTeams=True` | No start until the difference is at most 1. | Chat: "Unbalanced teams (`<TeamA>` vs `<TeamB>`)" |
| Admin: `mutate ar hold` | No start until `mutate ar start`, even with `Ready = Present`. If the countdown was running, `MaxPlayers` = `OriginalMax`. | Centre every 3 s: "Start on hold by admin" |
| Admin: `mutate ar start` | Every present player is marked ready; countdown. | Centre: "Admin forced start" |
| Match started | `MaxPlayers` = `OriginalMax`, newcomers join normally. AutoReady stops until the next map. | Log: "match started…" summary |
| `bTournament=False` | AutoReady does nothing: the match starts with the stock rule (`NetWait`). | Log: "bTournament=False, nothing to do" |
| Gametype not `DeathMatchPlus` or a subclass | AutoReady disables itself. | Log: "unsupported gametype, disabled" |

## Logging and troubleshooting

AutoReady writes to the server log with the `AutoReady:` prefix. Some log
collectors (e.g. systemd's journal) strip the prefix: search for the message
text instead. `ucc.log` is written in 32 KB blocks, so the most recent lines
may not be there yet; the server's standard output is up to date.

**Normal lines (always logged)**

| Line | Meaning |
|---|---|
| `v<version> active - MinReady=<n> Timeout=<n>s Balanced=<bool> Debug=<bool>` | Mutator loaded, with the values read from `AutoReady.ini`. |
| `majority ready (<Ready>/<Present>), <ReadyTimeout>s timeout started` | Latecomer timeout started. |
| `timeout expired with <Ready>/<Present> ready, marked ready: <names>` | Timeout expired, players forced ready. |
| `all players ready, MaxPlayers <OriginalMax> -> <Present>, countdown started` | Start: `MaxPlayers` lowered. |
| `player count changed during countdown, MaxPlayers <old> -> <new>` | Realignment during the countdown. |
| `player count dropped to <Present>, start cancelled, MaxPlayers restored to <OriginalMax>` | Start cancelled. |
| `match started: <n> players, waited <n>s, <n> forced ready (<names>), MaxPlayers restored to <OriginalMax>` | Summary once the match starts. |
| `admin <name> forced start` / `admin <name> put start on hold` | Admin commands. |
| `bTournament=False, nothing to do` / `unsupported gametype, disabled` | AutoReady inactive for this map. |

**`[debug]` lines** (with `bDebug=True`): one line per state change, with
present, ready, `NumPlayers`, `MaxPlayers`, `CountDown`, timeout, admin hold
and, for each player, name, class, `ready`, `spec`, `waiting` and state name.
During the countdown one line per second is logged because `CountDown`
changes.

**Common problems**

| Symptom | Cause | Fix |
|---|---|---|
| The startup line shows values different from `AutoReady.ini` | The `.ini` was edited while the server was running (UT rewrites it on shutdown), or lines have leading spaces | Edit with the server stopped, without leading spaces |
| The match never starts with everyone ready | `Present < MinReadyPlayers`, admin hold active, `bTournament=False`, or an outdated `AutoReady.u` | Check the startup line, `mutate ar status` and the md5 of `AutoReady.u` |
| `Unknown Mutator in use: AutoReady.AutoReady` | Message from another component that does not recognise the name | Harmless |

## Known limitations

- **Joining during the countdown:** for the 10 seconds of the countdown
  `MaxPlayers` equals the player count, so anyone connecting is rejected or
  joins as a spectator. Unavoidable: the game checks `NumPlayers == MaxPlayers`
  every second.
- **Bots** are not counted and never press Fire.
- **Gametypes:** `DeathMatchPlus` and subclasses only (DM, TDM, CTF,
  Domination, Assault).

## Build

You only need this if you want to compile `AutoReady.u` yourself: every
release already ships the compiled package and its md5. The build runs on
GitHub Actions against UT99 GOTY + the OldUnreal patch, and can also be run
locally with `scripts/compile.sh` on any complete UT99 Linux installation.
CI behaviour, local build and the manual procedure (including the `ucc make`
workaround on Linux) are described in [`docs/BUILD.md`](docs/BUILD.md).
