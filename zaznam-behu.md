# Zadání: záznam běhu přes GPS (offline) + zobrazení běhu

Tento soubor je zadání pro Claude Code. Popisuje, co uživatel chce, co už je
hotové a jak to má fungovat. Vznikl po domluvě s uživatelem 16. 10. 2026.

## Kdo je uživatel a jak s ním pracovat

- Píše česky a TrenApp (Flutter + Firebase) je jeho **první aplikace**.
- Když se ptá, jak něco funguje, chce **podrobné vysvětlení na jeho vlastním
  kódu** (diagramy, konkrétní soubory a řádky).
- Před větší změnou mu nejdřív stručně řekni, co budeš dělat. Když řekne
  „nepiš kód, jen vysvětli“, kód opravdu nepiš.
- Po dokončení mu napiš, jak to má ručně vyzkoušet v telefonu.

## Co uživatel chce (shrnutí)

1. Hráč u individuálního tréninku typu **Běh** klikne „Začít běh“, aplikace
   měří přes GPS čas, vzdálenost a tempo. Musí to fungovat **i bez internetu**
   a se **zhasnutým displejem**.
2. Má jít běh **pozastavit** (tlačítko Pauza / Pokračovat).
3. Po ukončení se běh uloží do telefonu a **jakmile bude internet, sám se
   odešle do Firestore**.
4. **Trenér** v detailu tréninku vidí seznam hráčů. Klikne na hráče a otevře
   se obrazovka s **mapkou trasy a informacemi o běhu**.
5. **Hráč** vidí údaje o svém běhu **přímo v detailu tréninku**.

## Rozhodnutí uživatele

| Otázka | Odpověď |
|---|---|
| Tlačítko Pauza | **Ano** |
| Ponechat ruční „Splněno“ u běhu (např. běžel bez telefonu) | **Ano, zatím ponechat** (možná se později smaže) |
| Průběžně ukládat rozběhnutý běh (pro případ pádu aplikace) | **Ne** – do „Uložit“ je běh jen v paměti |
| Zobrazení | Trenér: seznam hráčů → klik → mapa + údaje. Hráč: údaje přímo v detailu tréninku |

## Co už je hotové (necommitnuté změny z počítače, kde zadání vzniklo)

Ověř si `git status` / `git log`. Pokud tyhle věci v repu nejsou, uživatel
je zapomněl commitnout a pushnout – zeptej se ho.

- `pubspec.yaml`: přidaný `geolocator: ^14.1.1` (v locku `geolocator_android 5.1.1+1`).
- `android/app/src/main/AndroidManifest.xml`: oprávnění `ACCESS_FINE_LOCATION`,
  `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`,
  `WAKE_LOCK`. Službu `GeolocatorLocationService` (foregroundServiceType
  location) deklaruje manifest samotného pluginu, do aplikace se nepřidává.
- Dřívější úklid kódu (také necommitnutý), na který navazuj:
  - `lib/widgets/common.dart`: `SectionTitle`, `RoleAvatar`, `confirmDialog(...)`.
  - `lib/utils/error_text.dart`: `AppException('česká hláška')` pro chyby ze
    služeb a `errorText(e)`, která z jakékoli chyby udělá českou hlášku.
  - `lib/widgets/account_actions.dart`: `logOut(context)`.
  - Barvy AppBaru jsou v `appBarTheme` v `main.dart` – v obrazovkách je nenastavuj.
  - Login/logout nenavigují ručně, přepínání dělá `RootGate` přes streamy.

Samotný záznam běhu **zatím není napsaný**. `lib/screens/run_screen.dart` je
pořád zástupná obrazovka (`ComingSoon`).

## Jak to má fungovat

### Offline = Firestore cache, žádná další lokální databáze

Firestore má na Androidu zapnutou offline persistenci (SQLite v telefonu).
Zápis provedený offline se okamžitě uloží lokálně, přežije zavření aplikace
i restart telefonu a odešle se sám, když je internet. Uživatel chtěl
„lokální databázi + synchronizaci“ – **tohle ji plně nahrazuje**, nepřidávej
sqflite/Hive ani vlastní synchronizaci.

**Důležité:** Future ze zápisu (`batch.commit()`, `set`, `update`) skončí až
po potvrzení serverem. Offline by `await` čekal donekonečna. Proto se na
uložení běhu **nečeká**: zápis spustit (`unawaited(...)` s `catchError`, který
chybu jen zaloguje), hned zavřít obrazovku a ukázat SnackBar „Běh uložen“.
UI se aktualizuje samo přes streamy (latency compensation).

### Obrazovka běhu (`RunScreen`)

Stavy: `připraveno → běží ⇄ pauza → dokončeno`.

```
[Start] → BĚŽÍ: čas, vzdálenost, tempo   [Pauza] [Ukončit]
          PAUZA: hodnoty stojí           [Pokračovat] [Ukončit]
          DOKONČENO: souhrn              [Uložit běh] [Zahodit]
```

- Start: ověřit, že je zapnutá poloha a je povolený přístup
  (`Geolocator.isLocationServiceEnabled`, `checkPermission`,
  `requestPermission`). Při odmítnutí / `deniedForever` / vypnuté poloze
  ukázat srozumitelnou českou hlášku, běh nespouštět.
- Poloha: `Geolocator.getPositionStream` s `AndroidSettings(accuracy: best,
  distanceFilter: 5, foregroundNotificationConfig: ForegroundNotificationConfig(
  notificationTitle: 'Záznam běhu', notificationText: 'TrenApp zaznamenává
  tvůj běh', notificationChannelName: 'Záznam běhu', enableWakeLock: true,
  setOngoing: true))`. Na jiných platformách obyčejné `LocationSettings`.
  Služba na popředí zajistí záznam se zhasnutým displejem.
- Filtr: body s `accuracy > 25 m` zahodit (GPS „skáče“).
- Vzdálenost = součet `Geolocator.distanceBetween` mezi po sobě jdoucími
  body **téhož úseku**.
- Čas = **aktivní** čas (bez pauz). Hodiny na displeji překresluje `Timer`
  každou sekundu, protože GPS při stání nic neposílá.
- Tempo = aktivní čas / km, formát „5:27 /km“. Do ~50 m ukazovat „–“.
- Dokud nepřišel první bod: „Hledám signál GPS…“ (offline může první
  zaměření trvat desítky sekund).
- **Pauza:** stream GPS nech běžet (drží zaměření, notifikace zůstane,
  pokračování je okamžité), jen body ignoruj a zastav počítání času.
  Po „Pokračovat“ začíná **nový úsek**: vzdálenost mezi posledním bodem
  před pauzou a prvním po ní se **nepočítá**.
- Zpět / šipka v AppBaru během běhu nebo po dokončení: `PopScope` +
  `confirmDialog` „Zahodit běh?“ (nic se neuloží).
- `dispose`: zrušit subscription GPS i Timer.
- Ruční „Splněno“ v `TrainingPlayerActions` (`lib/widgets/training_widgets.dart`)
  zůstává vedle „Začít běh“. Uprav jen komentář „než bude hotový GPS záznam“.

### Uložení

Jedna dávka (`batch`):
1. `set` dokumentu běhu (viz datový model),
2. `update` tréninku: `responses.{uid} = 'done'` (stejně jako `TrainingService.respond`).

Trénink se tak v kalendáři hned (i offline) přepne na „Splněný“.

### Datový model

```
teams/{teamId}/trainings/{trainingId}/runs/{uid}
  startedAt:        timestamp   (začátek běhu)
  endedAt:          timestamp   (konec běhu)
  durationSeconds:  int         (aktivní čas bez pauz)
  distanceMeters:   int
  points: [ {lat: double, lng: double, t: int, s: int}, ... ]
            t = sekundy od startu, s = číslo úseku (0, 1, 2… po každé pauze)
```

- ID dokumentu = uid hráče → jeden běh na hráče a trénink, nový přepíše starý.
- **Firestore nepodporuje pole polí** (array of arrays), proto úseky jako
  plochý seznam s `s`, ne `[[...], [...]]`.
- Velikost: hodina běhu ≈ 2 000 bodů ≈ 100 KB, limit dokumentu je 1 MB.

### Pravidla Firestore (`firestore.rules`)

Do `match /trainings/{trainingId}` přidat `match /runs/{uid}`:
- `read`: `isMe(uid) || isTeamCoach(teamId)`
- `create, update`: `isMe(uid) && isTeamMember(teamId)` && uid je v
  `assignedTo` tréninku (`get(...trainings/$(trainingId)).data.assignedTo`)
  && validace typů polí (timestampy, int ≥ 0, `points is list`).
- `delete`: `isMe(uid) || isTeamCoach(teamId)`

Po změně je nutné pravidla nasadit: `firebase deploy --only firestore:rules`.
**Nenasazuj sám – řekni uživateli, ať to spustí (nebo se zeptej).** Bez
nasazení server běhy po připojení odmítne a zápis z cache tiše zmizí.

### Úklid

- `TrainingService.deleteTraining`: smazat i podkolekci `runs` (načíst
  `runs` a smazat v jedné dávce s tréninkem). Firestore podkolekce sám nemaže.
- `TeamService.deleteTeam`: u každého tréninku smazat i jeho `runs`.
- **Navrhuji (potvrdit s uživatelem):** „Zrušit splnění“ u běhu smaže i
  hráčův dokument běhu, ať trenér nevidí běh u nesplněného tréninku.

### Zobrazení – trenér

- `TrainingDetailScreen._buildIndividualOverview` už ukazuje seznam
  zadaných hráčů se stavem. U tréninku typu Běh má být každý řádek
  klikací (šipka vpravo) → nová obrazovka `RunDetailScreen(teamId,
  trainingId, uid, playerName)`.
- `RunDetailScreen` streamuje `runs/{uid}`:
  - nahoře **mapa trasy** (~300 px): čára pro každý úsek, značka startu
    a cíle, přiblížení na celou trasu,
  - pod ní údaje: aktivní čas, vzdálenost, průměrné tempo, datum a čas
    startu, počet pauz,
  - když dokument neexistuje: „Hráč zatím nemá záznam běhu“ (např.
    trénink splnil ručně).
- V seznamu hráčů **nenačítat** všechny běhy najednou (každý dokument
  nese celou trasu). Načítá se až po kliknutí.

### Zobrazení – hráč

- V detailu tréninku (u individuálního běhu) hráč vidí kartu se svým
  během: čas, vzdálenost, tempo, kdy běžel. Data ze streamu `runs/{mojeUid}`
  (offline z cache).
- **Otevřená otázka:** má hráč vidět i mapu? Technicky stačí použít stejný
  widget mapy jako trenér. Zeptej se uživatele.

### Mapa

- Doporučeno `flutter_map` + `latlong2` s dlaždicemi OpenStreetMap
  (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`,
  `userAgentPackageName: 'com.example.tren_app'`). Bez API klíče a zdarma.
  Zobrazit povinné uvedení zdroje (© OpenStreetMap contributors). Verze
  a API ověř při instalaci (`flutter pub add`).
- Mapa potřebuje internet na dlaždice. Offline se ukáže jen čára bez
  podkladu – to je v pořádku.

### Pomocné formátování

Nový `lib/utils/run_format.dart`: `formatDuration` („28:29“, „1:05:09“),
`formatDistance` („5,23 km“ s desetinnou čárkou), `formatPace` („5:27 /km“
nebo „–“).

## Konvence projektu

- Vrstvy: `screens/` (UI), `services/` (logika + Firestore), `widgets/`
  (sdílené UI), `utils/` (pomocné funkce). Navrhovaný nový soubor:
  `lib/services/run_service.dart` (oprávnění, GPS stream, uložení).
- Stav obrazovky přes `StatefulWidget` + `setState`. Streamy ukládat do
  `late final` v `State`, ne vytvářet v `build()`.
- Chyby ze služeb přes `throw AppException('česká hláška')`, v UI přes
  `errorText(e)`. Po `await` kontrolovat `mounted`.
- Komentáře česky, vysvětlují *proč*. Texty v UI česky.
- Po změnách spustit `flutter analyze` (musí být bez chyb).
  `test/widget_test.dart` je původní šablona z Flutteru a selhává i bez
  těchto změn – s funkcí nesouvisí.

## Známá omezení (uživatel o nich ví)

- Když aplikace během běhu spadne nebo ji systém ukončí, rozběhnutý běh
  se ztratí (průběžné ukládání uživatel nechce).
- Když server běh po připojení odmítne (např. trenér mezitím trénink
  smazal), běh tiše zmizí.
- Funguje jen na Androidu: na webu je offline cache vypnutá, iOS není
  ve Firebase nastavený.

## Jak to otestovat (napiš uživateli)

1. Trenér vytvoří individuální trénink typu Běh pro hráče.
2. Hráč: zapnout **režim letadlo** (GPS funguje dál), „Začít běh“, projít se,
   Pauza → Pokračovat, zhasnout displej, Ukončit → Uložit.
3. Trénink je hned „Splněný“ a hráč vidí údaje v detailu tréninku.
4. Vypnout režim letadlo → ve Firebase konzoli se objeví
   `teams/.../trainings/.../runs/{uid}`.
5. Trenér: detail tréninku → klik na hráče → mapa + údaje.
