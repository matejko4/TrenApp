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
- spravovat soupisku týmu,
- měnit role členů (trenér / hráč),
- odebírat členy z týmu,
- zrušit celý tým,
- zadávat společné tréninky pro celý tým (den, čas, místo, popis),
- zadávat individuální tréninky pro konkrétní hráče,
- upravovat a rušit zadané tréninky,
- vidět, kdo na společný trénink přijde a kdo ne,
- sledovat plnění individuálních tréninků,
- komunikovat s hráči v chatu týmu.

## 3. Týmy a role

Uživatel může být členem libovolného počtu týmů a v každém z nich může mít jinou roli. Role se proto neukládá k uživateli globálně, ale vždy ve vazbě na konkrétní tým.

- **Trenér** – správce týmu. Zakladatel týmu je vždy trenérem.
- **Hráč** – běžný člen týmu. Každý, kdo se připojí pomocí kódu, je nejprve hráčem.

Pravidla týmů:

- název týmu musí být unikátní (bez ohledu na velikost písmen a mezery),
- každý tým má unikátní šestimístný pozvánkový kód (bez snadno zaměnitelných znaků jako 0/O nebo 1/I),
- zakladatele týmu nelze změnit na hráče ani odebrat – tým tak nikdy nezůstane bez trenéra,
- zakladatele se lze „zbavit“ pouze zrušením celého týmu.

## 4. Tréninky

Tréninky zadává trenér. Každý trénink je naplánovaný na konkrétní den a čas a je jednoho ze dvou druhů:

- **Společný trénink** – platí pro celý tým (např. týmový trénink na hřišti).
- **Individuální trénink** – zadaný konkrétnímu hráči (např. běh, posilování).

Každý trénink obsahuje:

- druh (společný / individuální),
- název,
- typ tréninku,
- datum,
- čas začátku (a případně konce),
- místo (u společného tréninku),
- popis / zadání od trenéra,
- hráče, kterému je určen (u individuálního tréninku).

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

Hráč může individuální trénink (např. běh) zaznamenat pomocí GPS, případně jej označit jako splněný ručně. Trenér tak má přehled o tom, jak jednotliví hráči plní zadané tréninky.

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
│   │   └── account_settings_screen.dart – nastavení účtu (jméno, heslo)
│   │
│   ├── services/
│   │   ├── auth_service.dart        – přihlášení, registrace, správa účtu
│   │   └── team_service.dart        – práce s týmy a členy
│   │
│   └── widgets/
│       └── account_actions.dart     – tlačítka nastavení účtu a odhlášení v horní liště
│
├── test/
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
- e-mail
- datum registrace

### users/{uid}/teams/{teamId}

Přehled týmů daného uživatele (pro rychlé načtení na hlavní obrazovce).

Obsahuje:

- ID týmu
- název týmu
- roli uživatele v týmu
- pozvánkový kód (pouze u trenéra)
- datum připojení

### teams/{teamId}

Tým.

Obsahuje:

- název
- pozvánkový kód
- zakladatele
- datum vytvoření

### teams/{teamId}/members/{uid}

Soupiska týmu.

Obsahuje:

- ID uživatele
- jméno (kopie z users/{uid}, při změně jména se aktualizuje ve všech týmech)
- e-mail
- roli (trenér / hráč)
- datum připojení

### team_codes/{code}

Mapování pozvánkového kódu na tým. ID dokumentu je přímo kód, díky čemuž se k týmu může připojit i uživatel, který zatím není jeho členem.

Obsahuje:

- ID týmu
- název týmu

### team_names/{normalizedName}

Hlídání unikátnosti názvu týmu. ID dokumentu je normalizovaný název.

Obsahuje:

- ID týmu
- autora

### Plánované kolekce

#### teams/{teamId}/trainings/{trainingId}

Trénink zadaný trenérem.

Obsahuje:

- druh (společný / individuální)
- název
- typ tréninku
- datum a čas začátku / konce
- místo
- popis
- hráče (pouze u individuálního tréninku)
- stav – naplánovaný / splněný / nesplněný (pouze u individuálního tréninku)
- autora (trenéra)
- datum vytvoření

#### teams/{teamId}/trainings/{trainingId}/attendance/{uid}

Odpověď hráče na společný trénink.

Obsahuje:

- ID hráče
- odpověď (BUDU / NEBUDU)
- datum odpovědi

#### Další

- **activities** – záznamy tréninků z GPS (délka, vzdálenost, tempo, trasa),
- **chats / messages** – zprávy v chatu týmu.

## 9. Uživatelské role

Aplikace využívá systém oprávnění vázaný na konkrétní tým.

```
                       TRENAPP
                          │
                  Přihlášený uživatel
                          │
          ┌───────────────┴───────────────┐
          │                               │
   založí tým                     připojí se kódem
          │                               │
       Trenér  ───── může povýšit ─────▶  Hráč
          │                               │
   správa týmu,                  kalendář, BUDU/NEBUDU,
   zadávání tréninků,            plnění individuálních
   přehled účasti                tréninků, chat
```

Hráč nemá přístup ke správě týmu, nemůže zadávat tréninky a nevidí individuální tréninky ostatních hráčů.

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
    "email": "hrac@example.com",
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
- zákaz hromadného vypsání pozvánkových kódů,
- ochrana zakladatele týmu před odebráním nebo degradací,
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

### Nasazení bezpečnostních pravidel

```
firebase deploy --only firestore:rules
```

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
- založení týmu a kontrola unikátního názvu,
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

Testy lze spustit příkazem:

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
