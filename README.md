# TrenApp

Mobilní aplikace pro komunikaci a sledování tréninků ve sportovním oddíle. Projekt je vytvořen jako závěrečná maturitní práce pro obor Informační technologie.

## 1. Popis projektu

TrenApp propojuje trenéry a hráče sportovního oddílu v jedné aplikaci. Trenér si v aplikaci založí tým, pozve do něj hráče pomocí krátkého kódu a následně zadává tréninky na konkrétní den a čas – buď společné pro celý tým, nebo individuální pro jednotlivé hráče.

Hráčům se zadané tréninky zobrazí v kalendáři. U společného tréninku hráč odpoví, jestli přijde (**BUDU / NEBUDU**), u individuálního tréninku se sleduje, jestli ho splnil. Hráči si navíc mohou zaznamenávat tréninky pomocí GPS a komunikovat v chatu týmu.

Cílem projektu je nahradit roztříštěnou komunikaci přes různé chaty a tabulky jedním přehledným nástrojem, který může využít libovolný menší sportovní klub nebo oddíl.

Aplikace je postavena na frameworku Flutter a jako backend využívá služby Firebase (autentizace a databáze Cloud Firestore).

## 2. Hlavní funkce

### Uživatel (bez týmu)

Uživatel bude moci:

- vytvořit účet pomocí jména, e-mailu a hesla,
- přihlásit se e-mailem nebo účtem Google (jméno se převezme z Google účtu),
- změnit své jméno, které se ostatním zobrazuje místo e-mailu,
- založit nový tým (stane se jeho trenérem),
- připojit se k existujícímu týmu pomocí kódu (stane se hráčem),
- odhlásit se.

### Hráč

Hráč bude moci:

- zobrazit seznam svých týmů,
- zobrazit soupisku týmu,
- zobrazit své tréninky v kalendáři,
- u společného tréninku odpovědět **BUDU / NEBUDU**,
- označit individuální trénink jako splněný,
- zaznamenat běžecký trénink pomocí GPS,
- zobrazit historii svých tréninků,
- komunikovat v chatu týmu.

### Trenér

Trenér bude mít rozšířená oprávnění v rámci svého týmu:

- zobrazit a sdílet pozvánkový kód týmu,
- odebírat hráče z týmu,
- zadávat společné tréninky pro celý tým (den, čas, místo, popis),
- zadávat individuální tréninky pro vybrané hráče (nebo všechny najednou),
- upravovat a rušit zadané tréninky,
- vidět, kdo na společný trénink přijde a kdo ne,
- sledovat plnění individuálních tréninků,
- komunikovat s hráči v chatu týmu.

### Správce týmu

Kdo tým založí, stane se jeho správcem. Správce má všechna oprávnění trenéra a navíc může:

- povyšovat hráče na trenéry a trenéry měnit na hráče nebo odebírat z týmu,
- předat vedení týmu jinému členovi (hráč se tím zároveň stane trenérem),
- zrušit celý tým.

## 3. Týmy a role

Uživatel může být členem libovolného počtu týmů a v každém z nich může mít jinou roli. Role se proto neukládá k uživateli globálně, ale vždy ve vazbě na konkrétní tým.

- **Správce** – kdo tým založil, nebo komu bylo vedení předáno. Každý tým má právě jednoho správce a ten je vždy zároveň trenérem.
- **Trenér** – zadává tréninky a spravuje hráče. Trenéra jmenuje správce.
- **Hráč** – běžný člen týmu. Každý, kdo se připojí pomocí kódu, je nejprve hráčem.

Pravidla týmů:

- název týmu musí být unikátní – nerozlišují se mezery navíc ani velká a malá písmena A–Z (písmena s diakritikou se rozlišují, „ČEZ“ a „čez“ jsou dva týmy); hlídá to přímo databáze, protože upravený název je zároveň ID dokumentu týmu,
- k týmu se jde připojit jen se správným pozvánkovým kódem – kód ověřují bezpečnostní pravidla, samotná znalost ID týmu nestačí,
- každý tým má unikátní osmimístný pozvánkový kód (bez snadno zaměnitelných znaků jako 0/O nebo 1/I),
- správce týmu nelze změnit na hráče ani odebrat – tým tak nikdy nezůstane bez někoho, kdo ho spravuje,
- správce může vedení předat jinému členovi týmu (původní správce zůstane trenérem),
- zrušit tým může jen správce.

## 4. Tréninky

Tréninky zadává trenér. Každý trénink je naplánovaný na konkrétní den a čas a je jednoho ze dvou druhů:

- **Společný trénink** – platí pro celý tým (např. týmový trénink na hřišti).
- **Individuální trénink** – zadaný vybraným hráčům (např. běh, posilování). Trenér při zadávání zaškrtne buď všechny hráče, nebo jen ty, pro které má trénink platit. Kalendář se tak může pro každého hráče lišit.

Každý trénink obsahuje:

- druh (společný / individuální),
- název,
- typ tréninku,
- datum,
- čas začátku (a případně konce),
- místo (u společného tréninku),
- popis / zadání od trenéra,
- hráče, kterým je určen (u individuálního tréninku).

Typy tréninků:

- Běh
- Silový trénink
- Technický trénink
- Regenerace
- Ostatní

Typy tréninků bude možné v budoucnu rozšířit podle potřeby.

## 5. Kalendář a účast

Všechny tréninky se hráčům zobrazí v kalendáři – společné tréninky celého týmu i individuální tréninky zadané přímo jim. Hráč tak má na jednom místě přehled, co ho v jaký den čeká.

### Společný trénink – docházka

U společného tréninku hráč odpovídá, jestli přijde:

- **BUDU** – hráč na trénink přijde.
- **NEBUDU** – hráč na trénink nepřijde.

Dokud hráč neodpoví, je u něj trénink označený jako **bez odpovědi**. Trenér u každého společného tréninku vidí, kolik hráčů a kteří konkrétně přijdou, nepřijdou nebo ještě neodpověděli.

### Individuální trénink – plnění

Individuální trénink má jeden ze stavů:

- **Naplánovaný** – trénink čeká na splnění.
- **Splněný** – hráč trénink odcvičil.
- **Nesplněný** – termín tréninku uplynul a trénink nebyl splněn.

Individuální trénink jde splnit do konce dne, na který je zadaný. Hráč ho označí jako splněný ručně, u tréninku typu **Běh** je navíc tlačítko **Začít běh**, které otevře obrazovku pro záznam běhu pomocí GPS (podobně jako aplikace Adidas Running). Trenér tak má přehled o tom, jak jednotliví hráči plní zadané tréninky.

## 6. Technologie

Projekt je vytvořen pomocí těchto technologií:

### Aplikace

- Dart
- Flutter
- Material Design 3

### Backend

- Firebase Authentication (e-mail/heslo, Google Sign-In)
- Cloud Firestore
- Firestore Security Rules

### Plánované

- GPS / geolokace zařízení
- mapové podklady pro zobrazení trasy

### Další technologie

- Firebase CLI
- FlutterFire CLI

## 7. Struktura projektu

```
TrenApp/
│
├── pubspec.yaml
├── README.md
├── .gitignore
├── analysis_options.yaml
│
├── firebase.json
├── .firebaserc
├── firestore.rules
├── firestore.indexes.json
│
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart        (generuje FlutterFire CLI, není v gitu)
│   │
│   ├── screens/
│   │   ├── root_gate.dart           – rozcestník podle stavu přihlášení
│   │   ├── login_screen.dart        – přihlášení a registrace
│   │   ├── name_setup_screen.dart   – zadání jména po prvním přihlášení
│   │   ├── team_setup_screen.dart   – založení týmu / připojení kódem
│   │   ├── home_screen.dart         – přehled týmů uživatele
│   │   ├── team_detail_screen.dart  – detail týmu a správa členů
│   │   ├── team_calendar_screen.dart – kalendář tréninků týmu
│   │   ├── training_detail_screen.dart – detail tréninku a přehled odpovědí
│   │   ├── training_form_screen.dart – zadání / úprava tréninku (trenér)
│   │   ├── run_screen.dart          – záznam běhu (připravuje se)
│   │   ├── notifications_screen.dart – oznámení (připravuje se)
│   │   └── account_settings_screen.dart – nastavení účtu (jméno, heslo)
│   │
│   ├── services/
│   │   ├── auth_service.dart        – přihlášení, registrace, správa účtu
│   │   ├── team_service.dart        – práce s týmy a členy
│   │   └── training_service.dart    – tréninky a odpovědi hráčů
│   │
│   ├── utils/
│   │   └── date_format.dart         – české formátování data a času
│   │
│   └── widgets/
│       ├── account_actions.dart     – tlačítko odhlášení v horní liště
│       ├── app_bottom_bar.dart      – spodní navigační lišta (Domů, Oznámení, Účet)
│       ├── training_widgets.dart    – karta tréninku, BUDU / NEBUDU, stavy
│       └── coming_soon.dart         – zástupný obsah „Připravujeme“
│
├── test/                        – testy aplikace (flutter test)
│
├── firestore_tests/             – testy bezpečnostních pravidel (Firebase Emulator)
│
├── android/
├── ios/
├── web/
├── windows/
├── linux/
└── macos/
```

Struktura se může během vývoje změnit podle konkrétní implementace.

## 8. Databázový model

Aplikace využívá dokumentovou databázi Cloud Firestore. Data jsou uložena v kolekcích a podkolekcích.

### users/{uid}

Uživatel systému.

Obsahuje:

- jméno (zobrazuje se v aplikaci místo e-mailu)
- datum registrace

E-mail se sem neukládá – přihlášení i obnova hesla používají e-mail z účtu ve Firebase Authentication a profil `users/{uid}` si může přečíst kterýkoli přihlášený uživatel.

### users/{uid}/teams/{teamId}

Přehled týmů daného uživatele (pro rychlé načtení na hlavní obrazovce).

Obsahuje:

- ID týmu
- název týmu
- roli uživatele v týmu
- pozvánkový kód (pouze u trenéra)
- datum připojení

### teams/{teamId}

Tým. ID dokumentu je upravený název týmu (bez mezer navíc, písmena A–Z malá), např. „SFC Praha“ → `sfc praha` – díky tomu databáze sama hlídá, že dva týmy nemají stejný název.

Obsahuje:

- název
- pozvánkový kód
- správce (`ownerUid`) – kdo tým aktuálně vede (po založení ten, kdo tým založil)
- datum vytvoření

### teams/{teamId}/members/{uid}

Soupiska týmu.

Obsahuje:

- ID uživatele
- jméno (kopie z users/{uid}, při změně jména se aktualizuje ve všech týmech)
- roli (trenér / hráč)
- u hráče kód, kterým se připojil (`joinCode`) – pravidla ho při připojení porovnají s kódem týmu

E-mail se do soupisky neukládá – soupisku čtou všichni členové týmu a pravidla nejdou omezit na jednotlivá pole dokumentu.
- datum připojení

### team_codes/{code}

Mapování pozvánkového kódu na tým. ID dokumentu je přímo kód, díky čemuž se k týmu může připojit i uživatel, který zatím není jeho členem.

Obsahuje:

- ID týmu
- název týmu

### teams/{teamId}/trainings/{trainingId}

Trénink zadaný trenérem.

Obsahuje:

- druh (`team` – společný / `individual` – individuální)
- název
- typ tréninku (`run`, `strength`, `technique`, `recovery`, `other`)
- datum a čas začátku / konce
- místo (pouze u společného tréninku)
- popis
- seznam hráčů, kterým je trénink zadaný (pouze u individuálního tréninku)
- odpovědi hráčů – mapa `uid -> odpověď`: `yes` / `no` (BUDU / NEBUDU u společného tréninku) nebo `done` (splněno u individuálního tréninku)
- autora (trenéra)
- datum vytvoření

Odpovědi jsou přímo v dokumentu tréninku, aby trenér viděl přehled účasti celého kalendáře bez dalšího čtení pro každý trénink. Bezpečnostní pravidla hráči dovolí změnit jen jeho vlastní odpověď. Stav individuálního tréninku se neukládá zvlášť – „splněný“ je odpověď `done`, „nesplněný“ znamená, že den tréninku uplynul bez splnění.

Hráč smí číst jen společné tréninky a individuální tréninky zadané jemu. Aplikace proto pro hráče posílá dva dotazy (podle druhu tréninku a podle seznamu hráčů), které potřebují složené indexy definované v `firestore.indexes.json`.

### Plánované kolekce

- **activities** – záznamy tréninků z GPS (délka, vzdálenost, tempo, trasa),
- **chats / messages** – zprávy v chatu týmu.

## 9. Uživatelské role

Aplikace využívá systém oprávnění vázaný na konkrétní tým.

```
  založí tým ───────────────▶ Správce   (v týmu právě jeden, vždy i trenér)
  připojí se kódem ─────────▶ Hráč
  správce povýší hráče ─────▶ Trenér
  správce předá vedení ─────▶ nový Správce (původní zůstane trenérem)
```

| Oprávnění | Správce | Trenér | Hráč |
|---|:---:|:---:|:---:|
| vidět soupisku a kalendář | ✓ | ✓ | ✓ |
| odpovídat BUDU / NEBUDU, plnit individuální tréninky | – | – | ✓ |
| zadávat, upravovat a rušit tréninky, vidět účast | ✓ | ✓ | – |
| sdílet pozvánkový kód, odebírat hráče | ✓ | ✓ | – |
| jmenovat trenéry, měnit je na hráče a odebírat | ✓ | – | – |
| předat vedení týmu, zrušit tým | ✓ | – | – |

Hráč nemá přístup ke správě týmu, nemůže zadávat tréninky a nevidí individuální tréninky ostatních hráčů. Všechna oprávnění vynucují Firestore Security Rules a ověřují je automatické testy (kapitola 16).

## 10. Hlavní obrazovka

Po přihlášení je uživatel přesměrován podle svého stavu:

- nepřihlášený uživatel → přihlašovací obrazovka,
- přihlášený uživatel bez jména → zadání jména,
- přihlášený uživatel bez týmu → založení týmu / připojení k týmu,
- přihlášený uživatel s alespoň jedním týmem → přehled týmů.

Hlavní obrazovka může dále zobrazovat například:

- seznam týmů uživatele a jeho roli v nich,
- kalendář tréninků,
- nejbližší trénink,
- společné tréninky, na které hráč ještě neodpověděl BUDU / NEBUDU,
- nepřečtené zprávy.

Trenér navíc uvidí počty odpovědí na nejbližší společný trénink a plnění individuálních tréninků svých hráčů.

## 11. Statistiky

Aplikace bude obsahovat statistickou část.

Možné statistiky:

- docházka hráčů na společné tréninky,
- procento splněných individuálních tréninků,
- počet tréninků za týden / měsíc,
- celková uběhnutá vzdálenost a průměrné tempo (z GPS záznamů),
- porovnání aktivity hráčů v týmu (pro trenéra).

Statistiky mohou být zobrazeny pomocí grafů.

## 12. Komunikace

Součástí aplikace bude chat mezi trenérem a hráči.

- soukromá konverzace trenér ↔ hráč,
- zprávy se zobrazují v reálném čase (Firestore streamy),
- přehled konverzací s označením nepřečtených zpráv.

## 13. Firebase

Aplikace nemá vlastní server – veškerou logiku na straně backendu zajišťují služby Firebase.

- **Firebase Authentication** – registrace a přihlášení uživatelů,
- **Cloud Firestore** – ukládání dat a jejich synchronizace v reálném čase,
- **Firestore Security Rules** – kontrola oprávnění přímo na straně databáze.

Příklad dokumentu člena týmu:

```json
{
    "uid": "a1B2c3D4",
    "name": "Jan Novák",
    "role": "player",
    "joinedAt": "2026-09-15T18:30:00Z"
}
```

## 14. Bezpečnost

Aplikace obsahuje základní bezpečnostní prvky:

- přihlašování uživatelů přes Firebase Authentication,
- bezpečné ukládání hesel (zajišťuje Firebase),
- oprávnění vynucená Firestore Security Rules, nikoli jen v aplikaci,
- přístup k datům týmu pouze pro jeho členy,
- úpravy týmu a soupisky pouze pro trenéry,
- zákaz hromadného vypsání pozvánkových kódů; připojení k týmu jen se správným kódem ověřeným pravidly,
- ochrana správce týmu před odebráním nebo degradací; předat vedení a zrušit tým smí jen správce,
- název a kód týmu nejde po založení měnit,
- validace vstupních údajů.

## 15. Instalace

### Požadavky

Pro spuštění projektu je potřeba:

- Flutter SDK (Dart 3.12 nebo novější)
- Git
- Android Studio nebo Xcode (podle cílové platformy)
- Firebase projekt
- Firebase CLI a FlutterFire CLI

### Klonování projektu

```
git clone https://github.com/matejko4/TrenApp.git
cd TrenApp
```

### Instalace závislostí

```
flutter pub get
```

### Napojení na Firebase

Soubory `lib/firebase_options.dart` a `android/app/google-services.json` nejsou součástí repozitáře, je potřeba je vygenerovat:

```
dart pub global activate flutterfire_cli
flutterfire configure
```

### Podpisový klíč (Google přihlášení)

Přihlášení přes Google funguje jen pro aplikaci podepsanou klíčem, jehož otisk SHA-1 je zaregistrovaný ve Firebase (Nastavení projektu → Android aplikace → otisky). Aby byl otisk na každém počítači stejný, podepisuje se aplikace společným klíčem `android/app/trenapp.keystore`, jehož cestu a hesla obsahuje `android/key.properties`:

```
storePassword=<heslo ke klíči>
keyPassword=<heslo k aliasu>
keyAlias=<alias>
storeFile=trenapp.keystore
```

Klíč ani `key.properties` nejsou v repozitáři (viz `android/.gitignore`) a nesmí se nikdy nahrát na GitHub. Na nový počítač se po naklonování projektu nakopírují ze zálohy (např. flashdisku) spolu se soubory Firebase:

| Soubor | Umístění v projektu |
|---|---|
| `trenapp.keystore` | `android/app/` |
| `key.properties` | `android/` |
| `google-services.json` | `android/app/` |
| `firebase_options.dart` | `lib/` |

Když `key.properties` chybí, aplikace se podepíše výchozím debug klíčem daného počítače – sestaví se, ale Google přihlášení na ní fungovat nebude.

### Nasazení bezpečnostních pravidel a indexů

```
firebase deploy --only firestore
```

Nasadí bezpečnostní pravidla (`firestore.rules`) i složené indexy (`firestore.indexes.json`), které potřebuje kalendář tréninků. Vytvoření indexů může po nasazení trvat několik minut.

### Spuštění aplikace

```
flutter run
```

Aplikace se spustí na připojeném zařízení nebo emulátoru.

## 16. Testování

Projekt bude během vývoje testován.

Testovat se budou například:

- registrace uživatele (včetně jména),
- změna jména a jeho zobrazení na soupisce týmu,
- přihlášení e-mailem a účtem Google,
- odhlášení,
- založení týmu,
- připojení k týmu pomocí kódu,
- změna role člena,
- odebrání člena a zrušení týmu,
- oprávnění jednotlivých rolí (Firestore Security Rules),
- zadání společného a individuálního tréninku,
- zobrazení tréninků v kalendáři,
- odpověď BUDU / NEBUDU a přehled účasti u trenéra,
- změna stavu individuálního tréninku (naplánovaný / splněný / nesplněný),
- záznam GPS tréninku,
- chat.

### Automatické testy

Projekt má dvě sady automatických testů.

**Testy bezpečnostních pravidel** (`firestore_tests/rules.test.js`, 64 testů) ověřují `firestore.rules` proti lokálnímu Firebase Emulatoru – skutečná databáze se nepoužívá. Každý test provede jednu operaci jako konkrétní uživatel (správce, trenér, hráč, nečlen týmu, nepřihlášený) a ověří, že ji pravidla povolí, nebo zamítnou. Pokrývají například:

- hráč si nemůže sám změnit roli na trenéra ani se připojit rovnou jako trenér,
- bez správného kódu se do týmu nikdo nepřipojí – ani odebraný hráč, který ID týmu zná,
- druhý tým se stejným názvem nejde založit a ID týmu musí odpovídat jeho názvu,
- trenéry jmenuje, mění na hráče a odebírá jen správce; trenér smí odebrat jen hráče,
- správce týmu nejde změnit na hráče ani odebrat; vedení předá a tým zruší jen on,
- vedení jde předat jen členovi týmu, který je (nebo se stejnou dávkou stane) trenérem,
- název ani kód týmu nejde po založení přepsat,
- nečlen nevidí tým, soupisku ani tréninky; pozvánkové kódy nejde hromadně vypsat,
- tým se zakládá v jedné dávce (tým, kód, členství správce) a kód nejde vytvořit pro cizí tým,
- hráč vidí jen společné tréninky a individuální tréninky zadané jemu,
- hráč smí změnit jen svou odpověď (BUDU / NEBUDU u společného, splněno u individuálního tréninku),
- založení týmu, připojení kódem, změna role, odebrání člena i zrušení týmu projdou ve stejné podobě, v jaké je zapisuje aplikace.

Spuštění (potřebuje Node.js, Javu 21+ a Firebase CLI; první spuštění stáhne emulátor):

```
cd firestore_tests
npm install
npm test
```

**Testy aplikace** (`test/`) ověřují logiku bez připojení k Firebase: formátování data a času, stavy tréninku (naplánovaný / splněný / nesplněný, do kdy jde odpovídat) a souhrn odpovědí, který vidí trenér v kalendáři.

```
flutter test
```

## 17. Cíl projektu

Hlavním cílem projektu je vytvořit funkční mobilní aplikaci, která usnadní komunikaci a plánování tréninků ve sportovním oddíle.

Projekt má zároveň demonstrovat znalosti získané během studia oboru Informační technologie, především:

- programování,
- objektově orientovaného programování,
- vývoje mobilních aplikací,
- databází (NoSQL),
- cloudových služeb,
- práce s geolokací,
- verzovacích systémů,
- základů kybernetické bezpečnosti.

## 18. Možná rozšíření

Pokud bude dostatek času, je možné projekt rozšířit o:

- push notifikace (nový trénink, připomenutí odpovědi BUDU / NEBUDU, nová zpráva),
- opakované tréninky (např. každé úterý a čtvrtek),
- zápasy a další týmové akce v kalendáři,
- důvod omluvy u odpovědi NEBUDU,
- profilové fotky,
- export tréninků do GPX / CSV,
- propojení s chytrými hodinkami,
- tmavý režim,
- více jazyků.

Rozšíření budou implementována pouze v případě, že budou dokončeny všechny základní funkce.

## 19. Harmonogram

### Září

- analýza požadavků
- návrh aplikace
- návrh databáze
- vytvoření Flutter projektu a napojení na Firebase
- registrace a přihlášení (e-mail, Google)
- systém týmů a rolí
- správa členů týmu

### Říjen

- zadávání společných a individuálních tréninků
- kalendář tréninků
- odpovědi BUDU / NEBUDU a přehled účasti
- stavy individuálních tréninků

### Listopad

- GPS záznam běžeckého tréninku
- zobrazení trasy na mapě
- chat týmu
- hlavní obrazovka
- statistiky
- testování

### Prosinec

- opravy chyb
- optimalizace
- dokončení vzhledu
- dokumentace
- uživatelská příručka
- příprava prezentace a obhajoby

## 20. Výsledek

Výsledkem projektu bude kompletní mobilní aplikace, která sportovnímu oddílu umožní spravovat týmy, plánovat společné i individuální tréninky v kalendáři, sledovat docházku a plnění tréninků a komunikovat mezi trenéry a hráči.

Projekt bude navržen tak, aby byl použitelný například pro školní sportovní kroužek nebo menší sportovní klub.

## 21. Zdroje a dokumentace

Při vývoji aplikace jsem vycházel z oficiálních dokumentací a návodů.

### Flutter a Dart

- [Flutter – dokumentace](https://docs.flutter.dev) – základ celé aplikace
- [Flutter – nastavení vývoje pro Android](https://docs.flutter.dev/platform-integration/android/setup)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook) – hotové ukázky běžných úloh (formuláře, navigace, seznamy)
- [Flutter – navigace mezi obrazovkami](https://docs.flutter.dev/ui/navigation) – `Navigator.push`, `pushAndRemoveUntil`
- [Flutter – Material widgety](https://docs.flutter.dev/ui/widgets/material) – `Scaffold`, `AppBar`, `ListTile`, `AlertDialog`
- [Flutter – internacionalizace](https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization) – české texty systémových widgetů (výběr data a času)
- [StreamBuilder (API)](https://api.flutter.dev/flutter/widgets/StreamBuilder-class.html) – živé zobrazení dat z Firestore
- [Dart – dokumentace jazyka](https://dart.dev/guides)
- [Material Design 3](https://m3.material.io) – vzhled a zásady návrhu UI

### Firebase

- [Přidání Firebase do Flutter aplikace (FlutterFire CLI)](https://firebase.google.com/docs/flutter/setup)
- [FlutterFire – přehled pluginů](https://firebase.flutter.dev)
- [Firebase Authentication – začínáme](https://firebase.google.com/docs/auth/flutter/start) – registrace a přihlášení e-mailem
- [Firebase Authentication – správa uživatelů](https://firebase.google.com/docs/auth/flutter/manage-users) – změna jména, změna hesla, opětovné ověření, reset hesla
- [Firebase Authentication – přihlášení přes Google](https://firebase.google.com/docs/auth/flutter/federated-auth)
- [Cloud Firestore – dokumentace](https://firebase.google.com/docs/firestore)
- [Cloud Firestore – datový model](https://firebase.google.com/docs/firestore/data-model) – kolekce, dokumenty, podkolekce
- [Cloud Firestore – realtime aktualizace](https://firebase.google.com/docs/firestore/query-data/listen)
- [Cloud Firestore – transakce a dávkové zápisy](https://firebase.google.com/docs/firestore/manage-data/transactions) – např. propsání jména do všech týmů najednou
- [Firestore Security Rules – začínáme](https://firebase.google.com/docs/firestore/security/get-started)
- [Firestore Security Rules – podmínky a přístup k dalším dokumentům](https://firebase.google.com/docs/firestore/security/rules-conditions) – `get()`, `exists()`, kontrola rolí
- [Firestore Security Rules – bezpečné dotazy](https://firebase.google.com/docs/firestore/security/rules-query) – pravidla nejsou filtr, dotaz musí sám omezit výsledky
- [Cloud Firestore – indexy](https://firebase.google.com/docs/firestore/query-data/indexing) – složené indexy pro dotazy kalendáře
- [Firebase API klíče](https://firebase.google.com/docs/projects/api-keys) – proč klíče nejsou tajné a jak je omezit
- [Firebase CLI](https://firebase.google.com/docs/cli) – nasazení bezpečnostních pravidel

### Použité balíčky (pub.dev)

- [firebase_core](https://pub.dev/packages/firebase_core)
- [firebase_auth](https://pub.dev/packages/firebase_auth)
- [cloud_firestore](https://pub.dev/packages/cloud_firestore)
- [google_sign_in](https://pub.dev/packages/google_sign_in)

### Nástroje

- [Android Studio](https://developer.android.com/studio) – Android SDK a emulátor
- [Visual Studio Code](https://code.visualstudio.com/docs) – vývojové prostředí
- [Git – dokumentace](https://git-scm.com/doc)
- [gitignore – dokumentace](https://git-scm.com/docs/gitignore)

### Umělá inteligence

- [Claude Code](https://claude.com/claude-code) (Anthropic) – AI asistent, který jsem při vývoji používal k návrhu a úpravám části kódu (např. nastavení účtu, sdílená tlačítka v horní liště), k hledání chyb a ke kontrole bezpečnosti repozitáře. Vygenerovaný kód jsem procházel a upravoval.
