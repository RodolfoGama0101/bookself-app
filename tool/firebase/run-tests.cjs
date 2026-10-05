const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');
const {spawn, spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const cli = require.resolve('firebase-tools/lib/bin/firebase.js');
const emulatorEnvironment = {...process.env};
if (process.platform === 'win32') {
  // O launcher Oracle javapath pode criar outro filho e sair antes da limpeza.
  // Consulte o runtime selecionado, sem imprimir propriedades pessoais, e use
  // seu executável real somente neste processo de teste e em seus filhos.
  const javaInfo = spawnSync('java', ['-XshowSettings:properties', '-version'],
    {encoding: 'utf8', windowsHide: true});
  const javaHome = /(?:^|\n)\s*java\.home\s*=\s*([^\r\n]+)/
    .exec(`${javaInfo.stdout || ''}\n${javaInfo.stderr || ''}`)?.[1].trim();
  if (javaInfo.status !== 0 || !javaHome ||
      !fs.existsSync(path.join(javaHome, 'bin', 'java.exe'))) {
    throw new Error('Não foi possível localizar o runtime Java para os testes.');
  }
  const pathKey = Object.keys(emulatorEnvironment)
    .find(key => key.toLowerCase() === 'path') || 'PATH';
  emulatorEnvironment[pathKey] = `${path.join(javaHome, 'bin')}${path.delimiter}` +
    (emulatorEnvironment[pathKey] || '');
}
let configPath = path.join(root, 'firebase.emulators.json');
let temporaryDirectory;
function cleanupConfig() {
  if (!temporaryDirectory) return;
  fs.unlinkSync(configPath);
  fs.rmdirSync(temporaryDirectory); // Diretório próprio e vazio; sem remoção recursiva.
  temporaryDirectory = undefined;
}
const overrides = {
  auth: process.env.BOOKSELF_TEST_AUTH_PORT,
  firestore: process.env.BOOKSELF_TEST_FIRESTORE_PORT,
};
if (Object.values(overrides).some(value => value !== undefined)) {
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  for (const [service, value] of Object.entries(overrides)) {
    if (value === undefined) continue;
    if (!/^\d+$/.test(value) || Number(value) < 1 || Number(value) > 65535) {
      throw new Error(`Porta de teste inválida para ${service}.`);
    }
    config.emulators[service].port = Number(value);
  }
  if (config.emulators.auth.port === config.emulators.firestore.port) {
    throw new Error('As portas de Auth e Firestore devem ser distintas.');
  }
  // Hosts/projeto continuam fixos; não aceitar configurações externas.
  config.emulators.auth.host = '127.0.0.1';
  config.emulators.firestore.host = '127.0.0.1';
  config.firestore.rules = path.join(root, 'firestore.rules');
  config.firestore.indexes = path.join(root, 'firestore.indexes.json');
  temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'bookself-firebase-'));
  configPath = path.join(temporaryDirectory, 'config.json');
  fs.writeFileSync(configPath, JSON.stringify(config));
}
// Projeto/serviços fixos: este comando não pode executar deploy.
const child = spawn(process.execPath, [cli, 'emulators:exec',
  '--non-interactive', '--config', configPath,
  '--project', 'demo-bookself', '--only', 'auth,firestore',
  'node --test --test-concurrency=1 test/*.test.cjs',
], {cwd: __dirname, stdio: 'inherit', env: emulatorEnvironment});
child.once('spawn', () => {
  console.info(`CLI do teste demo iniciado (PID ${child.pid}).`);
});
child.on('error', () => { process.exitCode = 1; });
child.on('close', code => {
  // Algumas versões do Java no Windows não encerram com SIGINT do CLI.
  // Limpeza limitada aos filhos Java deste CLI, deste projeto e destas regras.
  if (process.platform === 'win32' && child.pid) {
    const cleanup = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive',
      '-File', path.join(__dirname, 'stop-test-emulator.ps1'),
      '-CliProcessId', String(child.pid), '-RulesPath', path.join(root, 'firestore.rules'),
    ], {stdio: 'inherit', windowsHide:true});
    if (cleanup.status !== 0) process.exitCode = 1;
  }
  cleanupConfig();
  process.exitCode = process.exitCode || (code ?? 1);
});
