# AutoReady – mutator UT99: guida e diario di sviluppo

2026-09-28 · Giulio Celidoni

## Stato attuale (punto di ripartenza)

L'ultima build è **AutoReady v1.2, `AutoReady.u` da 21 593 byte (md5 `68c7c4800c8f15763ae6a8d9ce86dbd0`)**, installata sul server e testata con un solo giocatore.

| Elemento | Dove si trova |
|---|---|
| Pacchetto compilato | `/opt/ut99-server/System64/AutoReady.u` (server) · `~/Scrivania/backup/AutoReady/AutoReady.u` (copia) |
| Sorgente | `~/Scrivania/backup/AutoReady/Classes/AutoReady.uc` (anche in Appendice) |
| Backup sorgenti precedenti | `AutoReady.uc.v1.bak`, `AutoReady.uc.v11-it.bak`, `AutoReady.uc.v11.bak` nella stessa cartella |
| Configurazione | `/opt/ut99-server/System64/AutoReady.ini` |
| README | `~/Scrivania/backup/AutoReady/README.txt` |
| Preset di test | `[VS_PresetConfig9]` "TEST - DM AutoReady" in `VoteSysPresets.ini` sul server |

**Testato e funzionante (28/09, da solo con `MinReadyPlayers=1`):** avvio col Fire, countdown dopo il reset del warm-up FNN, `MaxPlayers` ripristinato a partita avviata, `mutate ar hold` / `mutate ar start`, log e debug.

**Ancora da testare:**

- [ ] Due client, `MinReadyPlayers=2`: nel duello nessun timeout, messaggio di stato in chat, uscita durante il countdown (avvio annullato), `mutate ar status`.
- [ ] Tre o più client: timeout dalla maggioranza, conto alla rovescia a centro schermo, giocatore dichiarato pronto d'ufficio nel warm-up FNN.
- [ ] Squadre (TDM) con `bRequireBalancedTeams=True`.
- [ ] Dopo i test: `AutoReady.ini` con `MinReadyPlayers=2` e `bDebug=False`, a server fermo.

## Cos'è AutoReady e perché serve

AutoReady permette di usare il **tournament mode** (tutti premono Fire per dire "sono pronto") senza dover riempire il server.

In UT99 il tournament mode fa partire la partita solo quando il numero di giocatori collegati è **uguale** a `MaxPlayers`. Con `MaxPlayers=10` e 6 amici in LAN, la partita non parte mai: tutti restano nel warm-up di FNN, anche se hanno premuto Fire.

AutoReady risolve così: quando tutti i presenti sono pronti, abbassa per un momento `MaxPlayers` al numero dei presenti. Il gioco vede il server "pieno", fa il countdown 10…1 e avvia la partita. Appena la partita è iniziata, AutoReady rimette `MaxPlayers` al valore originale, così chi arriva dopo può entrare.

In più gestisce i ritardatari: se la maggioranza è pronta e qualcuno non preme Fire, dopo un tempo stabilito lo dichiara pronto d'ufficio.

Gira solo sul server: i client non scaricano nulla.

## Come funziona, passo per passo

Ogni secondo AutoReady controlla la situazione e fa una sola di queste cose.

1. **Tournament mode spento** (`bTournament=False`): scrive nel log che non ha nulla da fare e si disattiva per tutta la mappa.
2. **Partita già iniziata**: rimette `MaxPlayers` al valore originale, scrive il riepilogo nel log e si disattiva.
3. **Conta i giocatori.** Conta come giocatore chiunque non sia uno spettatore vero (classe `Spectator`). Chi è in attesa del match è un giocatore, anche se UT lo marca temporaneamente come spettatore. I bot non contano.
4. **Troppo pochi** (meno di `MinReadyPlayers`): aspetta, senza timeout.
5. **Blocco admin attivo** (`mutate ar hold`): non fa partire nulla e ripete a centro schermo "Start on hold by admin".
6. **Più della metà pronta, ma non tutti**: fa partire il timeout di `ReadyTimeout` secondi. Negli ultimi 10 secondi mostra al centro "Forced start in N s - press Fire!". Allo scadere dichiara pronti i ritardatari.
7. **Tutti pronti** (e squadre bilanciate, se richiesto): salva il `MaxPlayers` attuale, lo abbassa al numero dei presenti e il gioco avvia il countdown 10…1.
8. **Durante il countdown**: se qualcuno entra o esce, riallinea `MaxPlayers` ai presenti. Se i presenti scendono sotto `MinReadyPlayers`, annulla l'avvio e rimette `MaxPlayers` originale.
9. **Messaggi di stato**: ogni `MessageInterval` secondi scrive in chat quanti sono pronti.

Quando il countdown parte, FNN azzera la partita del warm-up (punteggi, armi, proiettili) e tutti ripartono da zero.

## Parametri di AutoReady.ini

La configurazione sta in `System64/AutoReady.ini`, sezione `[AutoReady.AutoReady]`. Se il file non esiste, il mutator lo crea al primo avvio con i valori di default.

| Parametro | Default | Cosa fa | Consigli |
|---|---|---|---|
| `MinReadyPlayers` | 2 | Numero minimo di giocatori presenti perché AutoReady faccia partire la partita. Sotto questa soglia aspetta e basta. | 2 in LAN. 1 solo per test da soli. |
| `ReadyTimeout` | 30 | Secondi concessi ai ritardatari dopo che più della metà è pronta. Allo scadere tutti vengono dichiarati pronti. | 30–60. Sopra 10 compare anche il conto alla rovescia a centro schermo. |
| `MessageInterval` | 5 | Ogni quanti secondi compare in chat il messaggio di stato ("2/6 ready…"). | 5–10. |
| `bRequireBalancedTeams` | False | Solo giochi a squadre: aspetta che la differenza fra le squadre sia al massimo 1 prima di partire. | True per TDM/CTF se si vuole evitare 4 contro 2. |
| `bDebug` | False | Scrive nel log una riga `[debug]` a ogni cambio di stato: presenti, pronti, `MaxPlayers`, `CountDown`, stato di ogni giocatore. | True nei test e nella prima serata, poi False. |

**Regola fissa, non configurabile:** il timeout parte quando è pronta **più della metà** dei presenti (2 su 2, 2 su 3, 3 su 4, 4 su 6). Nel duello quindi servono entrambi i Fire.

**Attenzione:** UT legge l'`.ini` all'avvio e lo riscrive quando si ferma. Va modificato **solo a server fermo**, altrimenti la modifica viene ignorata e poi sovrascritta.

Esempio per la LAN:

```ini
[AutoReady.AutoReady]
MinReadyPlayers=2
ReadyTimeout=30
MessageInterval=5
bRequireBalancedTeams=False
bDebug=False
```

## Installazione, aggiornamento e preset VoteSys

L'installazione richiede solo di copiare `AutoReady.u` sul server e attivarlo nei preset con `bTournament=True`.

**Prima installazione o aggiornamento**

1. Ferma il server: `sudo systemctl stop ut99-server`.
2. Copia `AutoReady.u` in `/opt/ut99-server/System64/` e controlla la dimensione con `ls -la AutoReady.u` (21 593 byte per la v1.2 attuale).
3. **Non** aggiungerlo a `ServerPackages`: gira solo sul server.
4. Crea o aggiorna `System64/AutoReady.ini` (vedi Parametri). Le righe non devono avere spazi all'inizio.
5. Avvia il server: `sudo systemctl start ut99-server`.
6. Verifica nel journal la riga di avvio: `journalctl -u ut99-server.service --since "5 min ago" | grep "v1.2 active"`.

**Attivarlo in un preset** (`VoteSysPresets.ini`, file con fine riga Windows CRLF)

Bastano due righe rispetto a un preset normale: il mutator in `Mutators` e `bTournament=True` in `GameSettings`. `MinPlayers` e `InitialBots` restano a 0 (sono bot, non c'entrano con AutoReady).

```ini
[VS_PresetConfig9]
PresetName=TEST - DM AutoReady
Abbreviation=
Category=TEST
SortPriority=10
Game=Botpack.DeathMatchPlus
MapListName=
Mutators=AutoReady.AutoReady
GameSettings=MaxPlayers=10
GameSettings=TimeLimit=15
GameSettings=FragLimit=30
GameSettings=bTournament=True
GameSettings=NetWait=15
GameSettings=bUseTranslocator=False
GameSettings=bCoopWeaponMode=False
GameSettings=bMultiWeaponStay=True
GameSettings=bForceRespawn=False
GameSettings=RestartWait=35
GameSettings=MinPlayers=0
GameSettings=InitialBots=0
```

Con altri mutator (arene): `Mutators=AutoReady.AutoReady,fnn353.NewNetIG`. Nei preset con `bTournament=False` AutoReady non serve: se presente, si disattiva da solo.

## Comandi admin

I comandi si scrivono nella console del gioco. Quelli admin richiedono prima `adminlogin <password>`.

| Comando | Chi | Effetto |
|---|---|---|
| `mutate ar status` | Tutti | Mostra solo a chi lo chiede quanti sono pronti e l'elenco completo di chi manca. Indica anche se c'è un blocco admin o se la partita è già partita. |
| `mutate ar start` | Admin | Dichiara pronti tutti i presenti e toglie l'eventuale blocco: al secondo successivo parte il countdown. Al centro: "Admin forced start". |
| `mutate ar hold` | Admin | Blocca la partenza automatica finché non si dà `mutate ar start`. Ferma il timeout e, se il countdown era già partito, rimette `MaxPlayers` originale. Al centro, ogni 3 s: "Start on hold by admin". |

A partita avviata i comandi admin rispondono "match already started". Un comando sconosciuto risponde con l'elenco dei comandi validi.

## Comportamento per ogni use-case

Valori di riferimento: `MaxPlayers=10`, `MinReadyPlayers=2`, `ReadyTimeout=30`. "Pronto" = ha premuto Fire (entra nel warm-up FNN con le armi).

| Situazione | Cosa succede | Messaggi |
|---|---|---|
| Un solo giocatore connesso | Nessun avvio: è sotto `MinReadyPlayers`. Resta in warm-up. | Nessuno |
| Duello, 1 pronto su 2 | Nessun timeout (serve più della metà, cioè 2). Si aspetta il secondo Fire. | Chat ogni 5 s: "1/2 ready. Press Fire when you are ready." |
| Duello, 2 pronti su 2 | `MaxPlayers` 10 → 2, countdown, partita. | Chat: "All players ready (2)" |
| 6 presenti, 2 pronti | Si aspetta: non è la maggioranza. | Chat: "2/6 ready. Press Fire…" |
| 6 presenti, 4 pronti | Parte il timeout di 30 s. | Chat: "4/6 ready - forced start in 30s", poi il tempo residuo ogni 5 s |
| Timeout negli ultimi 10 s | Conto alla rovescia continuo. | Centro, ogni secondo: "Forced start in N s - press Fire!" |
| Timeout scaduto | I ritardatari vengono dichiarati pronti, `MaxPlayers` 10 → 6, countdown. | Centro: "Time is up: starting now!" |
| Tutti pronti insieme | Nessun timeout: `MaxPlayers` 10 → presenti, countdown. | Chat: "All players ready (N)" |
| Uno esce durante il countdown, restano ≥ 2 | `MaxPlayers` segue i presenti, il countdown continua. | Solo log |
| Durante il countdown restano < 2 | Avvio annullato, `MaxPlayers` torna 10, si riaspetta. | Centro: "Not enough players, start cancelled" |
| Qualcuno si collega durante il countdown (10 s) | Rifiutato come "server full" o entra da spettatore: il server risulta pieno. | Nessuno |
| Squadre 4 contro 2 con `bRequireBalancedTeams=True` | Non parte finché la differenza non è al massimo 1. | Chat: "Unbalanced teams (4 vs 2)" |
| Admin: `mutate ar hold` | Nessun avvio finché non si dà `start`, anche con tutti pronti. | Centro ogni 3 s: "Start on hold by admin" |
| Admin: `mutate ar start` | Tutti pronti subito, countdown. | Centro: "Admin forced start" |
| Partita avviata | `MaxPlayers` torna 10, chi arriva entra normalmente. AutoReady si ferma fino alla mappa successiva. | Log: riepilogo "match started…" |
| Preset con `bTournament=False` | AutoReady non fa nulla: la partita parte con la regola normale (`NetWait`). | Log: "bTournament=False, nothing to do" |
| Gametype non DeathMatchPlus | AutoReady si disattiva. | Log: "unsupported gametype, disabled" |

## Log, debug e troubleshooting

Il posto giusto dove leggere il log è il **journal di systemd**, non `ucc.log`. `ucc.log` viene scritto a blocchi di 32 KB e le righe recenti restano in memoria.

Nel journal il prefisso `AutoReady:` viene tolto, quindi si cerca il testo dei messaggi:

```bash
journalctl -u ut99-server.service --since "10 min ago" | grep -E "v1\.2 active|\[debug\]|ready|MaxPlayers|countdown|timeout|match started|nothing to do"
```

**Righe normali (sempre)**

| Riga | Significato |
|---|---|
| `v1.2 active - MinReady=2 Timeout=30s Balanced=False Debug=False` | Mutator caricato, con i valori letti dall'`.ini`. |
| `majority ready (4/6), 30s timeout started` | Parte il timeout per i ritardatari. |
| `timeout expired with 5/6 ready, marked ready: Mario` | Timeout scaduto, elenco dei forzati. |
| `all players ready, MaxPlayers 10 -> 6, countdown started` | Avvio: `MaxPlayers` abbassato. |
| `player count changed during countdown, MaxPlayers 6 -> 5` | Riallineamento durante il countdown. |
| `player count dropped to 1, start cancelled, MaxPlayers restored to 10` | Avvio annullato. |
| `match started: 6 players, waited 42s, 1 forced ready (Mario), MaxPlayers restored to 10` | Riepilogo a partita avviata. |
| `admin Giulio forced start` / `put start on hold` | Comandi admin. |

**Righe `[debug]` (con `bDebug=True`)**: una riga a ogni cambio di stato, con presenti, pronti, `NumPlayers`, `MaxPlayers`, `CountDown`, timeout, blocco admin e, per ogni giocatore, nome, classe, `ready`, `spec`, `waiting` e stato FNN (`PlayerWaiting`, `PlayerWarmup`). Durante il countdown ne esce una al secondo perché `CountDown` cambia.

**Problemi già incontrati**

| Sintomo | Causa | Soluzione |
|---|---|---|
| La riga di avvio mostra `MinReady=2` anche se l'`.ini` dice 1 | `.ini` modificato a server acceso, oppure righe con spazi iniziali | Modificare a server fermo, righe senza spazi (`sed -i 's/^[[:space:]]*//' AutoReady.ini`) |
| La partita "parte normalmente" senza countdown | È il warm-up FNN (armi, respawn), non la partita | Controllare nel log se c'è `countdown started` |
| Warm-up infinito anche con tutti pronti | Sotto `MinReadyPlayers`, oppure build vecchia (vedi diario, bug spettatori) | Verificare la riga di avvio e la dimensione di `AutoReady.u` |
| `grep AutoReady` sul journal non trova le righe | Il journal toglie il tag | Cercare il testo dei messaggi (comando sopra) |
| `Unknown Mutator in use: AutoReady.AutoReady` | Messaggio di un altro componente che non riconosce il nome | Innocuo |

## Limiti noti e interazioni con FNN, FSB, VoteSys

- **Ingresso durante il countdown:** per i 10 secondi del countdown `MaxPlayers` è uguale ai presenti, quindi chi si collega viene rifiutato o entra da spettatore. Non evitabile: il gioco controlla `NumPlayers == MaxPlayers` a ogni secondo.
- **FNN (fnn353):** premendo Fire il giocatore entra in `PlayerWarmup` con le armi. Quando il countdown scende sotto 10, FNN azzera tutto e rimette i giocatori in `PlayerWaiting`, stato in cui UT li marca `bIsSpectator=True`. Per questo AutoReady riconosce gli spettatori solo dalla classe `Spectator`. Da verificare con 3+ client: il giocatore dichiarato pronto d'ufficio non passa dal warm-up, ma dovrebbe partire regolarmente dopo il reset.
- **FSB (fsb58):** FSB rileva l'inizio partita con la stessa condizione del gioco (`NumPlayers == MaxPlayers` e tutti pronti), quindi vede l'avvio forzato da AutoReady e azzera le statistiche al momento giusto.
- **VoteSys:** applica i `GameSettings` dopo `InitGame`. AutoReady legge `MaxPlayers` solo al momento dell'avvio, quindi usa il valore del preset e non quello dell'ultima partita salvato nell'`.ini`.
- **Bot:** non vengono contati e non premono Fire. Nei preset AutoReady tenere `MinPlayers=0` e `InitialBots=0`.
- **Messaggi a centro schermo:** usano il tipo standard `CriticalEvent` (azzurro, qualche secondo). Per tenerli a schermo più a lungo vengono reinviati ogni secondo (conto alla rovescia) o ogni 3 s (blocco admin). Una classe di messaggio propria richiederebbe `ServerPackages` e il download sui client: scartata.
- **Gametype:** solo DeathMatchPlus e derivati (DM, TDM, CTF, Domination, Assault).

## Come ricompilare

Su Linux `ucc-bin-amd64` 469e va aiutato con una piccola libreria, altrimenti `ucc make` si blocca su "Analyzing..." ed esaurisce la memoria.

**Il bug.** Quando cerca i sorgenti in `Classes/`, `ucc make` non salta la voce `.` (la cartella stessa) e rientra all'infinito in `Classes/./././…`. Succede con qualunque pacchetto, anche un mutator di 3 righe. La libreria `nodots.so`, caricata con `LD_PRELOAD`, nasconde `.` e `..` dall'elenco dei file.

**Cosa serve:** un'installazione UT99 469e Linux completa (`System`, `SystemLocalized`, `Textures`, `Sounds`). Senza `Sounds`, Botpack non si carica e `ucc` prova a ricompilarlo. Una copia è in `~/Scrivania/backup/ut99/`.

**Procedura**

1. Crea la libreria (una volta sola):

```c
#define _GNU_SOURCE
#include <dirent.h>
#include <string.h>
#include <dlfcn.h>
struct dirent *readdir(DIR *d){static struct dirent*(*r)(DIR*);if(!r)r=dlsym(RTLD_NEXT,"readdir");struct dirent*e;
while((e=r(d))&&(!strcmp(e->d_name,".")||!strcmp(e->d_name,"..")));return e;}
struct dirent64 *readdir64(DIR *d){static struct dirent64*(*r)(DIR*);if(!r)r=dlsym(RTLD_NEXT,"readdir64");struct dirent64*e;
while((e=r(d))&&(!strcmp(e->d_name,".")||!strcmp(e->d_name,"..")));return e;}
```

```bash
gcc -shared -fPIC -o nodots.so nodots.c -ldl
```

2. Metti il sorgente in `<ut99>/AutoReady/Classes/AutoReady.uc`. Nella cartella `Classes` **solo file `.uc`**.
3. Crea `System/Build.ini` copiando `Default.ini` e lasciando solo queste `EditPackages`, nell'ordine: `Core`, `Engine`, `Editor`, `UWindow`, `Fire`, `IpDrv`, `UWeb`, `UBrowser`, `UnrealShare`, `UnrealI`, `UMenu`, `Botpack`, `AutoReady`. I pacchetti successivi (UTMenu ecc.) non servono e senza i loro sorgenti bloccano la build.
4. Cancella il vecchio `System/AutoReady.u`: se esiste, `ucc` non ricompila.
5. Compila:

```bash
cd <ut99>/System
LD_PRELOAD=/percorso/nodots.so ./ucc-bin-amd64 make ini=Build.ini -nohomedir
```

Deve terminare con `Success - 0 error(s), 0 warnings`. I warning `Failed to load AutoReady` prima della compilazione sono normali.

**Note di UnrealScript 469 emerse durante lo sviluppo:** non esiste `Eval()` (usato l'helper `IfStr`); una stringa non può andare a capo; `config(AutoReady)` sulla classe sposta la configurazione in `AutoReady.ini`.

## Diario di sviluppo

AutoReady è nato perché nessun mutator esistente (ClickBoard/PureClickBoard, SmartDM, SmartCTF, IG+) cambia la regola di partenza del tournament mode. Le build sono in ordine dalla più recente.

| Data | Build | Cosa è cambiato | Perché |
|---|---|---|---|
| 28/09 | v1.2 · 21 593 byte · md5 `68c7c480…` | Timeout solo se manca ancora qualcuno. Conto alla rovescia al centro negli ultimi 10 s. "On hold" ripetuto ogni 3 s. | Nel test compariva un inutile "timeout started" con tutti pronti. I messaggi al centro sparivano troppo presto. |
| 28/09 | v1.2 · 21 157 byte | Spettatori riconosciuti solo dalla classe `Spectator`. | **Bug:** dopo il reset FNN il giocatore in `PlayerWaiting` ha `bIsSpectator=True`, veniva scartato e l'avvio annullato dopo 2 s (warm-up infinito). Testato: partita avviata. |
| 28/09 | v1.2 · 21 218 byte | Primo tentativo di correzione con `bWaitingPlayer`. | Sostituito dalla build successiva, più robusta. |
| 28/09 | v1.2 · 20 836 byte | Flag `bDebug` con righe `[debug]` a ogni cambio di stato. | Serviva capire dove si bloccava l'avvio. |
| 28/09 | v1.2 | Configurazione spostata in `AutoReady.ini` (`config(AutoReady)`). | Scelta di Giulio: file separato. |
| 28/09 | v1.2 | Rimossi `MajorityPercent` e la regola "timeout solo con 3+ giocatori": soglia fissa "più della metà". | Un parametro in meno. Col 51% arrotondato per eccesso il duello richiedeva già entrambi. |
| 28/09 | v1.2 | Messaggio di stato uguale per tutti. | Scelta di Giulio: chi vuole i dettagli usa `mutate ar status`. |
| 28/09 | v1.2 | Comandi `mutate ar status/start/hold`. Riepilogo nel log a partita avviata. Rimosso `bCenterMessages`. | Gestione dei casi reali in LAN (assenti, attese). |
| 28/09 | v1.1 | `SaveConfig()` all'avvio. | La sezione di configurazione non veniva mai scritta. |
| 27/09 | v1.1 | Messaggi e log in inglese. | Standard dei mutator. |
| 27/09 | v1.1 | Helper `LogAR`/`Announce`, banner di avvio, messaggi per ogni evento, `bCenterMessages`. | Visibilità per giocatori e admin. |
| 27/09 | v1 | Prima versione: abbassa `MaxPlayers` ai presenti quando tutti sono pronti, timeout dalla maggioranza, riallineamento durante il countdown, ripristino ad avvio. | Far partire il tournament mode senza server pieno. |

**Scoperte che hanno guidato il progetto**

- In `DeathMatchPlus.Timer` il countdown del tournament mode scende solo se `NumPlayers == MaxPlayers` e tutti hanno `bReadyToPlay`.
- FNN mette in warm-up chi preme Fire (`xxServerSetReadyToPlay`) e azzera la partita quando `CountDown` scende sotto 10 (`xxResetGame`). Non è configurabile.
- Il journal di systemd toglie il tag del log; `ucc.log` è scritto a blocchi di 32 KB.
- La copia verso la cartella `backup` a volte scriveva il file vecchio: verificare sempre dimensione e md5 dopo ogni consegna.

## Appendice: sorgente completo

Sorgente della build v1.2 da 21 593 byte (file `AutoReady/Classes/AutoReady.uc`, md5 `c18679e7db738a7836cf9235cc4bb5bd`). Per ripartire basta copiarlo e seguire "Come ricompilare".

```java
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
    // match (state PlayerWaiting, e.g. after the FNN warm-up reset) have it set.
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
        OriginalMax = DMP.MaxPlayers;   // read now: VoteSys GameSettings are already applied
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
```
