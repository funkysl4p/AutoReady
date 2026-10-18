//=============================================================================
// AutoReady
// Tournament mode without a full server.
//
// In UT99 (DeathMatchPlus.Timer) the tournament countdown only starts when
// NumPlayers == MaxPlayers. When every connected player is ready, this
// mutator lowers MaxPlayers to the number of players present, so the
// countdown can start. Once the match begins, the original value is restored.
//
// - The ready timeout starts once a majority of players is ready
//   (more than half: in a duel both players must press Fire).
// - When it expires, players who are not ready are marked ready.
// - During the countdown MaxPlayers follows the player count, so a
//   disconnect does not freeze the countdown.
// - Optional: wait for balanced teams (max difference of 1).
// - Admin commands: mutate ar status | start | hold
//
// Use only with presets that set GameSettings=bTournament=True.
//=============================================================================
class AutoReady extends Mutator config(AutoReady);

var config int  MinReadyPlayers;      // minimum players required to start
var config int  ReadyTimeout;         // seconds before a forced start
var config int  MessageInterval;      // seconds between status messages
var config bool bRequireBalancedTeams;
var config bool bDebug;               // verbose log of game state changes

const VERSION = "1.2";
const MAX_NAME_LEN = 12;

var int    OriginalMax;
var int    Elapsed;
var int    SinceMessage;
var int    WaitTime;
var bool   bCounting;
var bool   bAdjusted;
var bool   bFinished;
var bool   bHold;
var string ForcedNames;
var int    ForcedCount;
var string LastDebug;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    SaveConfig(); // writes AutoReady.ini with current values if missing
    if (DeathMatchPlus(Level.Game) == None)
    {
        LogAR("v" $ VERSION $ " - unsupported gametype, disabled");
        return;
    }
    LogAR("v" $ VERSION $ " active - MinReady=" $ MinReadyPlayers
        $ " Timeout=" $ ReadyTimeout $ "s Balanced=" $ bRequireBalancedTeams $ " Debug=" $ bDebug);
    DebugAR("gametype=" $ Level.Game.Class $ " bTournament=" $ DeathMatchPlus(Level.Game).bTournament
        $ " MaxPlayers=" $ DeathMatchPlus(Level.Game).MaxPlayers $ " MessageInterval=" $ MessageInterval);
    SetTimer(1.0, true);
}

// Server log (ucc.log), tagged AutoReady.
function LogAR(string Msg)
{
    Log(Msg, 'AutoReady');
}

function DebugAR(string Msg)
{
    if (bDebug)
        Log("[debug] " $ Msg, 'AutoReady');
}

// Debug: log game state only when it changes (no spam every second).
function DebugState(DeathMatchPlus DMP, int Present, int Ready)
{
    local Pawn P;
    local string L, Key;

    if (!bDebug)
        return;
    for (P = Level.PawnList; P != None; P = P.NextPawn)
        if (PlayerPawn(P) != None && PlayerPawn(P).PlayerReplicationInfo != None)
        {
            if (L != "") L = L $ ", ";
            L = L $ PlayerPawn(P).PlayerReplicationInfo.PlayerName $ "(" $ P.Class.Name
                $ " ready=" $ PlayerPawn(P).bReadyToPlay $ " spec=" $ PlayerPawn(P).PlayerReplicationInfo.bIsSpectator
                $ " waiting=" $ PlayerPawn(P).PlayerReplicationInfo.bWaitingPlayer
                $ " state=" $ P.GetStateName() $ ")";
        }
    Key = "present=" $ Present $ " ready=" $ Ready $ " NumPlayers=" $ DMP.NumPlayers
        $ " MaxPlayers=" $ DMP.MaxPlayers $ " CountDown=" $ DMP.CountDown
        $ " bRequireReady=" $ DMP.bRequireReady $ " counting=" $ bCounting
        $ " hold=" $ bHold $ " players: " $ L;
    // logged only when something changes (elapsed is shown but not compared)
    if (Key != LastDebug)
    {
        LastDebug = Key;
        DebugAR(Key $ " elapsed=" $ Elapsed);
    }
}

// Message to all players: screen centre or chat.
function Announce(string Msg, bool bCenter)
{
    if (bCenter)
        BroadcastMessage(Msg, true, 'CriticalEvent');
    else
        BroadcastMessage("AutoReady: " $ Msg);
}

function string IfStr(bool b, string T, string F)
{
    if (b) return T;
    return F;
}

function bool IsPlayer(Pawn P)
{
    local PlayerPawn PP;

    PP = PlayerPawn(P);
    if (PP == None || PP.IsA('Spectator'))
        return false;
    // Real spectators (and server helpers like MessagingSpectator) use a
    // Spectator class. bIsSpectator is not reliable: players waiting for the
    // match (stock PlayerPawn state PlayerWaiting) have it set.
    if (PP.PlayerReplicationInfo == None)
        return false;
    return true;
}

function string ShortName(PlayerPawn PP)
{
    local string S;

    S = PP.PlayerReplicationInfo.PlayerName;
    if (Len(S) > MAX_NAME_LEN)
        S = Left(S, MAX_NAME_LEN - 1) $ ".";
    return S;
}

// Count present players (not spectators) and how many are ready.
function CountPlayers(out int Present, out int Ready, out int TeamA, out int TeamB)
{
    local Pawn P;
    local PlayerPawn PP;

    Present = 0; Ready = 0; TeamA = 0; TeamB = 0;
    for (P = Level.PawnList; P != None; P = P.NextPawn)
    {
        if (!IsPlayer(P))
            continue;
        PP = PlayerPawn(P);
        Present++;
        if (PP.bReadyToPlay)
            Ready++;
        if (PP.PlayerReplicationInfo.Team == 0) TeamA++;
        else if (PP.PlayerReplicationInfo.Team == 1) TeamB++;
    }
}

// Names of players not ready; if more than MaxNames, returns "N players".
function string WaitingList(int MaxNames)
{
    local Pawn P;
    local string S;
    local int N;

    for (P = Level.PawnList; P != None; P = P.NextPawn)
        if (IsPlayer(P) && !PlayerPawn(P).bReadyToPlay)
        {
            N++;
            if (N <= MaxNames)
            {
                if (S != "") S = S $ ", ";
                S = S $ ShortName(PlayerPawn(P));
            }
        }
    if (N > MaxNames)
        return N $ " players";
    return S;
}

function ForceAllReady()
{
    local Pawn P;

    ForcedNames = "";
    ForcedCount = 0;
    for (P = Level.PawnList; P != None; P = P.NextPawn)
        if (IsPlayer(P) && !PlayerPawn(P).bReadyToPlay)
        {
            PlayerPawn(P).bReadyToPlay = true;
            ForcedCount++;
            if (ForcedNames != "") ForcedNames = ForcedNames $ ", ";
            ForcedNames = ForcedNames $ PlayerPawn(P).PlayerReplicationInfo.PlayerName;
        }
}

function RestoreMax(DeathMatchPlus DMP)
{
    if (bAdjusted)
        DMP.MaxPlayers = OriginalMax;
    bAdjusted = false;
}

// Admin commands: mutate ar status | start | hold
function Mutate(string MutateString, PlayerPawn Sender)
{
    local string Cmd;
    local int Present, Ready, TeamA, TeamB;
    local DeathMatchPlus DMP;

    if (Left(Caps(MutateString), 3) == "AR " || Caps(MutateString) == "AR")
    {
        Cmd = Caps(Mid(MutateString, 3));
        if (Sender != None && Sender.PlayerReplicationInfo != None)
            DebugAR("mutate '" $ MutateString $ "' from " $ Sender.PlayerReplicationInfo.PlayerName);
        DMP = DeathMatchPlus(Level.Game);
        if (Sender == None || DMP == None)
            return;

        if (Cmd == "STATUS" || Cmd == "")
        {
            CountPlayers(Present, Ready, TeamA, TeamB);
            Sender.ClientMessage("AutoReady v" $ VERSION $ ": " $ Ready $ "/" $ Present $ " ready"
                $ IfStr(bHold, " (on hold)", "") $ IfStr(bFinished, " (match started)", ""));
            if (Ready < Present)
                Sender.ClientMessage("AutoReady: waiting for " $ WaitingList(32));
        }
        else if (Sender.PlayerReplicationInfo == None || !Sender.PlayerReplicationInfo.bAdmin)
            Sender.ClientMessage("AutoReady: admin login required (adminlogin <password>)");
        else if (bFinished)
            Sender.ClientMessage("AutoReady: match already started");
        else if (Cmd == "START")
        {
            bHold = false;
            ForceAllReady();
            LogAR("admin " $ Sender.PlayerReplicationInfo.PlayerName $ " forced start, " $ ForcedCount $ " marked ready");
            Announce("Admin forced start", true);
        }
        else if (Cmd == "HOLD")
        {
            bHold = true;
            bCounting = false;
            Elapsed = 0;
            RestoreMax(DMP);
            LogAR("admin " $ Sender.PlayerReplicationInfo.PlayerName $ " put start on hold");
            Announce("Start on hold by admin", true);
        }
        else
            Sender.ClientMessage("AutoReady: commands are status, start, hold");
        return;
    }
    Super.Mutate(MutateString, Sender);
}

function Timer()
{
    local DeathMatchPlus DMP;
    local int Present, Ready, TeamA, TeamB, Needed;
    local bool bBalanced;

    DMP = DeathMatchPlus(Level.Game);
    if (DMP == None || bFinished)
        return;

    // Nothing to do without tournament mode.
    if (!DMP.bTournament)
    {
        LogAR("bTournament=False, nothing to do");
        bFinished = true;
        SetTimer(0.0, false);
        return;
    }

    // Match started: restore MaxPlayers, log a summary and stop.
    if (!DMP.bRequireReady || DMP.CountDown <= 0)
    {
        if (bAdjusted)
        {
            LogAR("match started: " $ DMP.MaxPlayers $ " players, waited " $ WaitTime $ "s, "
                $ ForcedCount $ " forced ready" $ IfStr(ForcedCount > 0, " (" $ ForcedNames $ ")", "")
                $ ", MaxPlayers restored to " $ OriginalMax);
        }
        RestoreMax(DMP);
        bFinished = true;
        SetTimer(0.0, false);
        return;
    }

    CountPlayers(Present, Ready, TeamA, TeamB);
    DebugState(DMP, Present, Ready);

    // Countdown running: keep MaxPlayers in line with the player count.
    if (bAdjusted)
    {
        if (Present < MinReadyPlayers)
        {
            LogAR("player count dropped to " $ Present $ ", start cancelled, MaxPlayers restored to " $ OriginalMax);
            RestoreMax(DMP);
            bCounting = false;
            Elapsed = 0;
            Announce("Not enough players, start cancelled", true);
        }
        else if (DMP.MaxPlayers != Present)
        {
            LogAR("player count changed during countdown, MaxPlayers " $ DMP.MaxPlayers $ " -> " $ Present);
            DMP.MaxPlayers = Present;
        }
        return;
    }

    // Not enough players: reset and wait.
    if (Present < MinReadyPlayers)
    {
        bCounting = false;
        Elapsed = 0;
        WaitTime = 0;
        return;
    }
    WaitTime++;

    // Admin hold: do nothing until "mutate ar start".
    if (bHold)
    {
        // repeat at screen centre so it stays visible
        SinceMessage++;
        if (SinceMessage >= 3)
        {
            SinceMessage = 0;
            Announce("Start on hold by admin", true);
        }
        return;
    }

    // The timeout starts once more than half of the players are ready.
    Needed = Present / 2 + 1;
    if (!bCounting && Ready >= Needed && Ready < Present)
    {
        bCounting = true;
        Elapsed = 0;
        LogAR("majority ready (" $ Ready $ "/" $ Present $ "), " $ ReadyTimeout $ "s timeout started");
        Announce(Ready $ "/" $ Present $ " ready - forced start in " $ ReadyTimeout $ "s", false);
        SinceMessage = 0;
    }
    if (bCounting)
        Elapsed++;

    // Live countdown at screen centre in the last 10s before the forced start
    // (re-sent every second, so the message stays on screen).
    if (bCounting && Ready < Present && ReadyTimeout - Elapsed > 0 && ReadyTimeout - Elapsed <= 10)
        Announce("Forced start in " $ (ReadyTimeout - Elapsed) $ "s - press Fire!", true);

    // Timeout expired: mark remaining players as ready.
    if (bCounting && Elapsed >= ReadyTimeout && Ready < Present)
    {
        ForceAllReady();
        LogAR("timeout expired with " $ Ready $ "/" $ Present $ " ready, marked ready: " $ ForcedNames);
        Ready = Present;
        Announce("Time is up: starting now!", true);
    }

    // Balanced teams (team games only, if required).
    bBalanced = true;
    if (bRequireBalancedTeams && DMP.bTeamGame && Abs(TeamA - TeamB) > 1)
        bBalanced = false;

    if (Ready == Present && bBalanced)
    {
        OriginalMax = DMP.MaxPlayers;   // read now: other actors may change it after InitGame
        DMP.MaxPlayers = Present;
        bAdjusted = true;
        LogAR("all players ready, MaxPlayers " $ OriginalMax $ " -> " $ Present $ ", countdown started");
        Announce("All players ready (" $ Present $ ")", false);
        return;
    }

    // Status messages.
    SinceMessage++;
    if (SinceMessage >= MessageInterval)
    {
        SinceMessage = 0;
        if (!bBalanced)
            Announce("Unbalanced teams (" $ TeamA $ " vs " $ TeamB $ ")", false);
        else if (bCounting)
            Announce(Ready $ "/" $ Present $ " ready - forced start in " $ Max(0, ReadyTimeout - Elapsed) $ "s. Press Fire!", false);
        else
            Announce(Ready $ "/" $ Present $ " ready. Press Fire when you are ready.", false);
    }
}

defaultproperties
{
    MinReadyPlayers=2
    ReadyTimeout=30
    MessageInterval=5
    bRequireBalancedTeams=False
    bDebug=False
}
