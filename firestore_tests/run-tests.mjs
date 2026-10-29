// Spustí testy pravidel (rules.test.js) ve Firebase Emulatoru.
//
// Na Windows firebase-tools po skončení `emulators:exec` neukončí Java
// proces emulátoru – zůstane viset na portu 8080 a další spuštění selže
// na „port taken“. Proto tento skript takový proces před testy i po nich
// ukončí. Hledá jen emulátor testovacího projektu demo-trenapp, takže
// nesáhne na jiné běžící emulátory.

import { spawnSync } from 'node:child_process';

const PROJECT = 'demo-trenapp';

function stopLeftoverEmulator() {
  if (process.platform !== 'win32') return;
  const script =
    'Get-CimInstance Win32_Process | Where-Object { ' +
    "$_.Name -eq 'java.exe' -and " +
    "$_.CommandLine -like '*cloud-firestore-emulator*' -and " +
    `$_.CommandLine -like '*${PROJECT}*' } | ` +
    'ForEach-Object { Stop-Process -Id $_.ProcessId -Force }';
  spawnSync('powershell', ['-NoProfile', '-Command', script], { stdio: 'inherit' });
}

stopLeftoverEmulator();
const result = spawnSync(
  `firebase emulators:exec --only firestore --project ${PROJECT} "node --test rules.test.js"`,
  { stdio: 'inherit', shell: true },
);
stopLeftoverEmulator();
process.exit(result.status ?? 1);
