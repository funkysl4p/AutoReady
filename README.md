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

## Installation

1. Download `AutoReady.u` and `AutoReady.u.md5` from the latest
   [release](../../releases) and check them with `md5sum -c AutoReady.u.md5`.
2. With the server stopped, copy `AutoReady.u` to `System/`.
   Do **not** add it to `ServerPackages`.
3. Copy `AutoReady.ini.example` to `System/AutoReady.ini` and adjust it
   (see Configuration).
4. Enable it in the presets that use tournament mode:
   `Mutators=AutoReady.AutoReady` and `GameSettings=bTournament=True`.

Details (upgrade, enabling it, log checks):
"Installation" in [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

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
