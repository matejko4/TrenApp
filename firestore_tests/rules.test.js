// Testy bezpečnostních pravidel (firestore.rules) proti Firebase Emulatoru.
//
// Každý test spustí na čerstvě naplněné lokální databázi jednu operaci
// jako konkrétní uživatel a ověří, že ji pravidla povolí (assertSucceeds),
// nebo zamítnou (assertFails). Do skutečné databáze se nic nezapisuje –
// projekt "demo-trenapp" existuje jen v emulátoru.
//
// Spuštění: viz README, kapitola 16 (npm test ve složce firestore_tests).

import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { after, before, beforeEach, describe, it } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

// Uživatelé v testech:
//  trener  – zakladatel a správce týmu tym1 (trenér)
//  trener2 – další trenér týmu tym1 (není správce)
//  asistent – další trenér týmu tym1 (není správce)
//  hrac    – hráč týmu tym1, má zadaný individuální trénink „beh“
//  hrac2   – hráč týmu tym1 bez individuálního tréninku
//  cizi    – přihlášený uživatel, který v týmu není
const TEAM = 'tym1';
const CODE = 'ABCD2345';
const MEMBERS = [
  ['trener', 'coach'],
  ['trener2', 'coach'],
  ['asistent', 'coach'],
  ['hrac', 'player'],
  ['hrac2', 'player'],
];

let testEnv;

const db = (uid) => testEnv.authenticatedContext(uid).firestore();
const anonymousDb = () => testEnv.unauthenticatedContext().firestore();

const tomorrow = () => Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000);

function training(overrides = {}) {
  return {
    kind: 'team',
    title: 'Trénink na hřišti',
    type: 'technique',
    startAt: tomorrow(),
    endAt: null,
    place: 'Hřiště',
    description: null,
    assignedTo: [],
    responses: {},
    createdBy: 'trener',
    createdAt: Timestamp.now(),
    ...overrides,
  };
}

async function seed() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    const member = (uid, role) => ({ uid, name: uid, email: `${uid}@test.cz`, role });

    for (const uid of ['trener', 'trener2', 'asistent', 'hrac', 'hrac2', 'cizi']) {
      await setDoc(doc(admin, 'users', uid), { name: uid, email: `${uid}@test.cz` });
    }
    await setDoc(doc(admin, 'teams', TEAM), { name: 'SFC', code: CODE, ownerUid: 'trener' });
    for (const [uid, role] of MEMBERS) {
      await setDoc(doc(admin, 'teams', TEAM, 'members', uid), member(uid, role));
      await setDoc(doc(admin, 'users', uid, 'teams', TEAM), { teamId: TEAM, teamName: 'SFC', role });
    }
    await setDoc(doc(admin, 'team_codes', CODE), { teamId: TEAM, teamName: 'SFC' });
    await setDoc(doc(admin, 'team_names', 'sfc'), { teamId: TEAM, createdBy: 'trener' });
    await setDoc(doc(admin, 'teams', TEAM, 'trainings', 'spolecny'), training());
    await setDoc(
      doc(admin, 'teams', TEAM, 'trainings', 'beh'),
      training({ kind: 'individual', title: 'Běh 5 km', type: 'run', place: null, assignedTo: ['hrac'] }),
    );
  });
}

before(async () => {
  // Zamítnuté zápisy v testech jsou záměrné – nevypisovat je jako chyby.
  setLogLevel('silent');
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-trenapp',
    firestore: { rules: readFileSync(join(import.meta.dirname, '..', 'firestore.rules'), 'utf8') },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed();
});

after(async () => {
  await testEnv.cleanup();
});

describe('Profily uživatelů (users)', () => {
  it('nepřihlášený nepřečte žádný profil', async () => {
    await assertFails(getDoc(doc(anonymousDb(), 'users', 'hrac')));
  });

  it('přihlášený přečte profil jiného uživatele', async () => {
    await assertSucceeds(getDoc(doc(db('hrac'), 'users', 'trener')));
  });

  it('uživatel upraví svůj profil', async () => {
    await assertSucceeds(updateDoc(doc(db('hrac'), 'users', 'hrac'), { name: 'Jan Novák' }));
  });

  it('uživatel neupraví cizí profil', async () => {
    await assertFails(updateDoc(doc(db('hrac'), 'users', 'trener'), { name: 'Hacker' }));
  });

  it('seznam týmů jiného uživatele je soukromý', async () => {
    await assertSucceeds(getDoc(doc(db('hrac'), 'users', 'hrac', 'teams', TEAM)));
    await assertFails(getDoc(doc(db('hrac2'), 'users', 'hrac', 'teams', TEAM)));
  });
});

describe('Tým a soupiska', () => {
  it('člen přečte tým i soupisku', async () => {
    await assertSucceeds(getDoc(doc(db('hrac'), 'teams', TEAM)));
    await assertSucceeds(getDocs(collection(db('hrac'), 'teams', TEAM, 'members')));
  });

  it('nečlen nepřečte tým ani soupisku', async () => {
    await assertFails(getDoc(doc(db('cizi'), 'teams', TEAM)));
    await assertFails(getDocs(collection(db('cizi'), 'teams', TEAM, 'members')));
  });

  it('hráč nezmění údaje týmu', async () => {
    await assertFails(updateDoc(doc(db('hrac'), 'teams', TEAM), { name: 'Můj tým' }));
  });

  it('tým nejde založit s jiným správcem než sám sebou', async () => {
    const team = doc(db('cizi'), 'teams', 'tym2');
    await assertFails(setDoc(team, { name: 'X', code: 'X', ownerUid: 'trener' }));
    await assertFails(setDoc(team, { name: 'X', code: 'X' }));
  });

  it('založení týmu projde stejně jako v TeamService.createTeam', async () => {
    const novy = db('cizi');
    await assertSucceeds(setDoc(doc(novy, 'team_names', 'novy tym'), { teamId: 'tym2', createdBy: 'cizi' }));
    await assertSucceeds(setDoc(doc(novy, 'teams', 'tym2'), {
      name: 'Nový tým', code: 'ZZZZ2222', ownerUid: 'cizi', createdAt: serverTimestamp(),
    }));
    const batch = writeBatch(novy);
    batch.set(doc(novy, 'team_codes', 'ZZZZ2222'), { teamId: 'tym2', teamName: 'Nový tým' });
    batch.set(doc(novy, 'teams', 'tym2', 'members', 'cizi'), { uid: 'cizi', name: 'cizi', role: 'coach' });
    batch.set(doc(novy, 'users', 'cizi', 'teams', 'tym2'), { teamId: 'tym2', teamName: 'Nový tým', role: 'coach' });
    await assertSucceeds(batch.commit());
  });

  it('druhý tým se stejným názvem se nezaloží (team_names jde jen vytvořit)', async () => {
    await assertFails(setDoc(doc(db('cizi'), 'team_names', 'sfc'), { teamId: 'tym2', createdBy: 'cizi' }));
  });
});

describe('Připojení pozvánkovým kódem', () => {
  it('přihlášený najde tým podle kódu', async () => {
    await assertSucceeds(getDoc(doc(db('cizi'), 'team_codes', CODE)));
  });

  it('nepřihlášený kód nepřečte', async () => {
    await assertFails(getDoc(doc(anonymousDb(), 'team_codes', CODE)));
  });

  it('všechny kódy nejde vypsat (ochrana proti hádání)', async () => {
    await assertFails(getDocs(collection(db('cizi'), 'team_codes')));
  });

  it('existující kód nejde přepsat', async () => {
    await assertFails(setDoc(doc(db('trener'), 'team_codes', CODE), { teamId: 'jiny', teamName: 'X' }));
  });

  it('připojení jako hráč projde stejně jako v TeamService.joinTeamByCode', async () => {
    const cizi = db('cizi');
    // Kontrola, jestli už uživatel není členem (čte vlastní, zatím neexistující členství).
    await assertSucceeds(getDoc(doc(cizi, 'teams', TEAM, 'members', 'cizi')));
    const batch = writeBatch(cizi);
    batch.set(doc(cizi, 'teams', TEAM, 'members', 'cizi'), { uid: 'cizi', name: 'cizi', role: 'player' });
    batch.set(doc(cizi, 'users', 'cizi', 'teams', TEAM), { teamId: TEAM, teamName: 'SFC', role: 'player' });
    await assertSucceeds(batch.commit());
  });

  it('nikdo se nepřipojí rovnou jako trenér', async () => {
    await assertFails(setDoc(doc(db('cizi'), 'teams', TEAM, 'members', 'cizi'), { uid: 'cizi', role: 'coach' }));
  });

  it('nikdo nepřidá do týmu jiného uživatele', async () => {
    await assertFails(setDoc(doc(db('cizi'), 'teams', TEAM, 'members', 'novak'), { uid: 'novak', role: 'player' }));
  });
});

describe('Role a správa členů', () => {
  it('hráč si nezmění roli na trenéra', async () => {
    await assertFails(updateDoc(doc(db('hrac'), 'teams', TEAM, 'members', 'hrac'), { role: 'coach' }));
  });

  it('hráč si nezmění roli ani spolu se jménem', async () => {
    await assertFails(updateDoc(doc(db('hrac'), 'teams', TEAM, 'members', 'hrac'), { name: 'Jan', role: 'coach' }));
  });

  it('hráč si změní jméno na soupisce', async () => {
    await assertSucceeds(updateDoc(doc(db('hrac'), 'teams', TEAM, 'members', 'hrac'), { name: 'Jan Novák' }));
  });

  it('správce povýší hráče na trenéra (obě kopie členství v jedné dávce)', async () => {
    const trener = db('trener');
    const batch = writeBatch(trener);
    batch.update(doc(trener, 'teams', TEAM, 'members', 'hrac'), { role: 'coach' });
    batch.update(doc(trener, 'users', 'hrac', 'teams', TEAM), { role: 'coach' });
    await assertSucceeds(batch.commit());
  });

  it('trenér (ne správce) hráče na trenéra nepovýší', async () => {
    await assertFails(updateDoc(doc(db('trener2'), 'teams', TEAM, 'members', 'hrac'), { role: 'coach' }));
    await assertFails(updateDoc(doc(db('trener2'), 'users', 'hrac', 'teams', TEAM), { role: 'coach' }));
  });

  it('správce změní trenéra na hráče a odebere trenéra', async () => {
    await assertSucceeds(updateDoc(doc(db('trener'), 'teams', TEAM, 'members', 'asistent'), { role: 'player' }));
    await assertSucceeds(deleteDoc(doc(db('trener'), 'teams', TEAM, 'members', 'trener2')));
  });

  it('trenér (ne správce) jiného trenéra nedegraduje ani neodebere', async () => {
    await assertFails(updateDoc(doc(db('trener2'), 'teams', TEAM, 'members', 'asistent'), { role: 'player' }));
    await assertFails(deleteDoc(doc(db('trener2'), 'teams', TEAM, 'members', 'asistent')));
  });

  it('správce nejde změnit na hráče – ani jiným trenérem, ani sám sebou', async () => {
    await assertFails(updateDoc(doc(db('trener2'), 'teams', TEAM, 'members', 'trener'), { role: 'player' }));
    await assertFails(updateDoc(doc(db('trener'), 'teams', TEAM, 'members', 'trener'), { role: 'player' }));
  });

  it('hráč nikoho z týmu neodebere', async () => {
    await assertFails(deleteDoc(doc(db('hrac'), 'teams', TEAM, 'members', 'hrac2')));
  });

  it('trenér odebere hráče (obě kopie členství v jedné dávce)', async () => {
    const trener2 = db('trener2');
    const batch = writeBatch(trener2);
    batch.delete(doc(trener2, 'teams', TEAM, 'members', 'hrac'));
    batch.delete(doc(trener2, 'users', 'hrac', 'teams', TEAM));
    await assertSucceeds(batch.commit());
  });

  it('správce nejde z týmu odebrat – ani jiným trenérem, ani sám sebou', async () => {
    await assertFails(deleteDoc(doc(db('trener2'), 'teams', TEAM, 'members', 'trener')));
    await assertFails(deleteDoc(doc(db('trener'), 'teams', TEAM, 'members', 'trener')));
  });

  it('správce zruší celý tým včetně podkolekcí (TeamService.deleteTeam)', async () => {
    const trener = db('trener');
    const batch = writeBatch(trener);
    for (const id of ['spolecny', 'beh']) batch.delete(doc(trener, 'teams', TEAM, 'trainings', id));
    for (const [uid] of MEMBERS) {
      batch.delete(doc(trener, 'teams', TEAM, 'members', uid));
      batch.delete(doc(trener, 'users', uid, 'teams', TEAM));
    }
    batch.delete(doc(trener, 'team_codes', CODE));
    batch.delete(doc(trener, 'team_names', 'sfc'));
    batch.delete(doc(trener, 'teams', TEAM));
    await assertSucceeds(batch.commit());
  });

  it('trenér (ne správce) ani hráč tým nezruší', async () => {
    await assertFails(deleteDoc(doc(db('trener2'), 'teams', TEAM)));
    await assertFails(deleteDoc(doc(db('hrac'), 'teams', TEAM)));
    await assertFails(deleteDoc(doc(db('trener2'), 'team_codes', CODE)));
  });
});

describe('Předání vedení týmu', () => {
  const team = (uid) => doc(db(uid), 'teams', TEAM);

  it('správce předá vedení trenérovi', async () => {
    await assertSucceeds(updateDoc(team('trener'), { ownerUid: 'trener2' }));
  });

  it('správce předá vedení hráči, kterého stejná dávka povýší (TeamService.transferOwnership)', async () => {
    const trener = db('trener');
    const batch = writeBatch(trener);
    batch.update(doc(trener, 'teams', TEAM, 'members', 'hrac'), { role: 'coach' });
    batch.update(doc(trener, 'users', 'hrac', 'teams', TEAM), { role: 'coach' });
    batch.update(doc(trener, 'teams', TEAM), { ownerUid: 'hrac' });
    await assertSucceeds(batch.commit());
  });

  it('předat vedení hráči bez povýšení na trenéra nejde', async () => {
    await assertFails(updateDoc(team('trener'), { ownerUid: 'hrac' }));
  });

  it('předat vedení nečlenovi nejde', async () => {
    await assertFails(updateDoc(team('trener'), { ownerUid: 'cizi' }));
  });

  it('trenér ani hráč si vedení nepřivlastní', async () => {
    await assertFails(updateDoc(team('trener2'), { ownerUid: 'trener2' }));
    await assertFails(updateDoc(team('hrac'), { ownerUid: 'hrac' }));
  });

  it('nikdo nezmění název ani kód týmu – ani správce', async () => {
    await assertFails(updateDoc(team('trener2'), { name: 'Jiný název' }));
    await assertFails(updateDoc(team('trener'), { name: 'Jiný název' }));
    await assertFails(updateDoc(team('trener'), { code: 'ZZZZ2222' }));
  });

  it('po předání chrání pravidla nového správce a ten může spravovat původního', async () => {
    await assertSucceeds(updateDoc(team('trener'), { ownerUid: 'trener2' }));
    await assertFails(updateDoc(doc(db('trener'), 'teams', TEAM, 'members', 'trener2'), { role: 'player' }));
    await assertFails(deleteDoc(doc(db('trener'), 'teams', TEAM)));
    await assertSucceeds(updateDoc(doc(db('trener2'), 'teams', TEAM, 'members', 'trener'), { role: 'player' }));
  });
});

describe('Tréninky – zadávání', () => {
  const newTraining = (uid) => doc(db(uid), 'teams', TEAM, 'trainings', 'novy');

  it('trenér zadá společný trénink', async () => {
    await assertSucceeds(setDoc(newTraining('trener'), training()));
  });

  it('trenér zadá individuální trénink vybraným hráčům', async () => {
    await assertSucceeds(setDoc(newTraining('trener'), training({ kind: 'individual', assignedTo: ['hrac', 'hrac2'] })));
  });

  it('hráč trénink nezadá', async () => {
    await assertFails(setDoc(newTraining('hrac'), training({ createdBy: 'hrac' })));
  });

  it('individuální trénink bez hráčů neprojde', async () => {
    await assertFails(setDoc(newTraining('trener'), training({ kind: 'individual', assignedTo: [] })));
  });

  it('trénink bez názvu nebo s neznámým typem neprojde', async () => {
    await assertFails(setDoc(newTraining('trener'), training({ title: '' })));
    await assertFails(setDoc(newTraining('trener'), training({ type: 'golf' })));
  });

  it('nový trénink nesmí mít předvyplněné odpovědi ani cizího autora', async () => {
    await assertFails(setDoc(newTraining('trener'), training({ responses: { hrac: 'yes' } })));
    await assertFails(setDoc(newTraining('trener'), training({ createdBy: 'trener2' })));
  });

  it('hráč trénink nesmaže ani nepřejmenuje', async () => {
    const spolecny = doc(db('hrac'), 'teams', TEAM, 'trainings', 'spolecny');
    await assertFails(deleteDoc(spolecny));
    await assertFails(updateDoc(spolecny, { title: 'Volno' }));
  });
});

describe('Tréninky – kdo co vidí', () => {
  const trainings = (uid) => collection(db(uid), 'teams', TEAM, 'trainings');

  it('hráč vidí společný trénink a svůj individuální', async () => {
    await assertSucceeds(getDoc(doc(trainings('hrac'), 'spolecny')));
    await assertSucceeds(getDoc(doc(trainings('hrac'), 'beh')));
  });

  it('hráč nevidí individuální trénink jiného hráče', async () => {
    await assertFails(getDoc(doc(trainings('hrac2'), 'beh')));
  });

  it('nečlen nevidí žádný trénink', async () => {
    await assertFails(getDoc(doc(trainings('cizi'), 'spolecny')));
  });

  it('dotazy hráče z kalendáře projdou (TrainingService.streamTrainings)', async () => {
    const today = Timestamp.fromDate(new Date(new Date().setHours(0, 0, 0, 0)));
    await assertSucceeds(getDocs(query(
      trainings('hrac'), where('kind', '==', 'team'), where('startAt', '>=', today), orderBy('startAt'),
    )));
    await assertSucceeds(getDocs(query(
      trainings('hrac'), where('assignedTo', 'array-contains', 'hrac'), where('startAt', '>=', today), orderBy('startAt'),
    )));
  });

  it('hráč nenačte všechny tréninky najednou (pravidla nejsou filtr)', async () => {
    await assertFails(getDocs(trainings('hrac')));
  });

  it('trenér načte všechny tréninky týmu', async () => {
    await assertSucceeds(getDocs(trainings('trener')));
  });
});

describe('Tréninky – odpovědi hráčů', () => {
  const spolecny = (uid) => doc(db(uid), 'teams', TEAM, 'trainings', 'spolecny');
  const beh = (uid) => doc(db(uid), 'teams', TEAM, 'trainings', 'beh');

  it('hráč odpoví BUDU i NEBUDU na společný trénink', async () => {
    await assertSucceeds(updateDoc(spolecny('hrac'), { 'responses.hrac': 'yes' }));
    await assertSucceeds(updateDoc(spolecny('hrac'), { 'responses.hrac': 'no' }));
  });

  it('hráč svou odpověď smaže (zpět na bez odpovědi)', async () => {
    await assertSucceeds(updateDoc(spolecny('hrac'), { 'responses.hrac': 'yes' }));
    await assertSucceeds(updateDoc(spolecny('hrac'), { 'responses.hrac': deleteField() }));
  });

  it('hráč neodpoví za jiného hráče', async () => {
    await assertFails(updateDoc(spolecny('hrac'), { 'responses.hrac2': 'no' }));
  });

  it('u společného tréninku nejde odpovědět „splněno“ ani neznámou hodnotou', async () => {
    await assertFails(updateDoc(spolecny('hrac'), { 'responses.hrac': 'done' }));
    await assertFails(updateDoc(spolecny('hrac'), { 'responses.hrac': 'maybe' }));
  });

  it('hráč nezmění odpověď a zároveň jiné pole tréninku', async () => {
    await assertFails(updateDoc(spolecny('hrac'), { 'responses.hrac': 'yes', place: 'Doma' }));
  });

  it('hráč označí svůj individuální trénink jako splněný', async () => {
    await assertSucceeds(updateDoc(beh('hrac'), { 'responses.hrac': 'done' }));
  });

  it('u individuálního tréninku nejde odpovědět BUDU/NEBUDU', async () => {
    await assertFails(updateDoc(beh('hrac'), { 'responses.hrac': 'yes' }));
  });

  it('hráč nesplní individuální trénink, který mu není zadaný', async () => {
    await assertFails(updateDoc(beh('hrac2'), { 'responses.hrac2': 'done' }));
  });

  it('nečlen na trénink neodpoví', async () => {
    await assertFails(updateDoc(spolecny('cizi'), { 'responses.cizi': 'yes' }));
  });
});
