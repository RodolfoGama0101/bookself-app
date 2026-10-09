'use strict';

// Ambiente descartável, exclusivo do projeto demo e do loopback.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const net = require('node:net');
const {spawn, spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const defaults = {auth: 9099, firestore: 8080, web: 17360, hub: 4400, logging: 4500, websocket: 9150};

function options(args) {
  const result = {...defaults, check: false};
  const seen = new Set();
  for (const arg of args) {
    if (arg === '--check') { result.check = true; continue; }
    const match = /^--(auth|firestore|web|hub|logging|websocket)-port=(\d+)$/.exec(arg);
    if (!match || seen.has(match[1])) throw new Error('Opção inválida ou repetida. Use --check ou --<serviço>-port=<1024..65535>.');
    seen.add(match[1]);
    const port = Number(match[2]);
    if (port < 1024 || port > 65535) throw new Error('Portas devem ficar entre 1024 e 65535.');
    result[match[1]] = port;
  }
  if (new Set(Object.keys(defaults).map(key => result[key])).size !== Object.keys(defaults).length) throw new Error('Cada serviço exige uma porta distinta.');
  return result;
}

async function checkPorts(config) {
  for (const name of Object.keys(defaults)) {
    await new Promise((resolve, reject) => {
      const probe = net.createServer();
      probe.once('error', () => reject(new Error(`Porta ${name} ${config[name]} indisponível. Escolha outra; nenhum processo foi encerrado.`)));
      probe.listen(config[name], '127.0.0.1', () => probe.close(resolve));
    });
  }
}

function javaEnvironment() {
  const result = spawnSync('java', ['-XshowSettings:properties', '-version'], {encoding: 'utf8', windowsHide: true});
  const output = `${result.stdout || ''}\n${result.stderr || ''}`;
  const version = /(?:java|openjdk) version "(\d+)/.exec(output);
  if (result.status !== 0 || !version || Number(version[1]) < 21) throw new Error('Instale Java 21 ou superior e confira o PATH.');
  const env = {...process.env};
  if (process.platform === 'win32') {
    const home = /(?:^|\n)\s*java\.home\s*=\s*([^\r\n]+)/.exec(output)?.[1].trim();
    if (!home || !fs.existsSync(path.join(home, 'bin', 'java.exe'))) throw new Error('Runtime Java não localizado.');
    const key = Object.keys(env).find(key => key.toLowerCase() === 'path') || 'PATH';
    env[key] = `${path.join(home, 'bin')}${path.delimiter}${env[key] || ''}`;
  }
  // Não imprime propriedades ou variáveis do ambiente.
  return env;
}

function firebaseCli() {
  const manifest = require('./firebase/package.json');
  for (const [name, expected] of Object.entries(manifest.devDependencies)) {
    let installed;
    try { installed = require(`./firebase/node_modules/${name}/package.json`).version; }
    catch { throw new Error('Instale as dependências: npm --prefix tool/firebase ci --no-audit --no-fund'); }
    if (installed !== expected) throw new Error(`Versão divergente de ${name}; reinstale pelo lockfile, sem upgrade.`);
  }
  return require.resolve('./firebase/node_modules/firebase-tools/lib/bin/firebase.js');
}

function command(name, args) {
  // Argumentos internos fixos ou portas numéricas; nenhuma entrada livre no shell.
  return new Promise((resolve, reject) => {
    const child = process.platform === 'win32'
      ? spawn(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', [name, ...args].join(' ')], {cwd: root, stdio: 'inherit', windowsHide: true})
      : spawn(name, args, {cwd: root, stdio: 'inherit'});
    child.once('error', () => reject(new Error(`Não foi possível executar ${name}. Confira o PATH.`)));
    child.once('close', code => code === 0 ? resolve() : reject(new Error(`${name} encerrou com falha; consulte o diagnóstico acima.`)));
  });
}

async function main(args) {
  const config = options(args);
  if (Number(process.versions.node.split('.')[0]) < 20) throw new Error('Use Node.js 20 ou superior.');
  await checkPorts(config);
  const env = javaEnvironment(), cli = firebaseCli();
  await command('dart', ['tool/check_sdk.dart']);
  console.log('Pré-requisitos e portas locais verificados. Projeto fixo: demo-bookself.');
  if (config.check) return;
  await command('flutter', ['pub', 'get', '--enforce-lockfile']);
  await command('flutter', ['build', 'web', '--no-pub', '--dart-define=USE_FIREBASE_EMULATORS=true',
    `--dart-define=FIREBASE_AUTH_EMULATOR_PORT=${config.auth}`, `--dart-define=FIRESTORE_EMULATOR_PORT=${config.firestore}`]);
  // Revalida depois do build; não encerra processos que ocuparam uma porta.
  await checkPorts(config);
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'bookself-web-demo-'));
  const configPath = path.join(directory, 'firebase.json');
  fs.writeFileSync(configPath, JSON.stringify({firestore: {rules: path.join(root, 'firestore.rules'), indexes: path.join(root, 'firestore.indexes.json')}, emulators: {
    auth: {host: '127.0.0.1', port: config.auth}, firestore: {host: '127.0.0.1', port: config.firestore, websocketPort: config.websocket},
    hub: {host: '127.0.0.1', port: config.hub}, logging: {host: '127.0.0.1', port: config.logging}, ui: {enabled: false}, singleProjectMode: true,
  }}));
  let emulator, server, stopped = false;
  let finish;
  const done = new Promise(resolve => {finish = resolve;});
  const stop = () => {
    if (stopped) return;
    stopped = true;
    server?.kill();
    if (process.platform === 'win32' && emulator?.pid) {
      const cleanup = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-File', path.join(__dirname, 'firebase', 'stop-test-emulator.ps1'), '-CliProcessId', String(emulator.pid), '-RulesPath', path.join(root, 'firestore.rules')], {stdio: 'inherit', windowsHide: true});
      if (cleanup.status !== 0) process.exitCode = 1;
    }
    emulator?.kill('SIGINT');
    finish();
  };
  const input = data => {if (data.toString().trim().toLowerCase() === 'q') stop();};
  process.stdin.on('data', input);
  process.stdin.resume();
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);
  try {
    emulator = spawn(process.execPath, [cli, 'emulators:start', '--project', 'demo-bookself', '--only', 'auth,firestore', '--config', configPath], {cwd: root, env, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']});
    await new Promise((resolve, reject) => {
      let output = '';
      const timeout = setTimeout(() => reject(new Error('Emuladores não ficaram prontos em 90 segundos.')), 90000);
      const ready = data => {
        process.stdout.write(data);
        output = (output + data.toString()).slice(-16000);
        if (output.includes('All emulators ready!')) { clearTimeout(timeout); resolve(); }
      };
      emulator.stdout.on('data', ready);
      emulator.stderr.on('data', data => process.stderr.write(data));
      emulator.once('error', () => {clearTimeout(timeout); reject(new Error('Falha ao iniciar o CLI local.'));});
      emulator.once('close', code => {
        clearTimeout(timeout);
        if (!stopped) {process.exitCode = code || 1; stop();}
        reject(new Error('Emuladores encerrados antes da conclusão.'));
      });
    });
    if (stopped) return;
    server = spawn(process.execPath, [path.join(__dirname, 'serve-web.cjs'), String(config.web)], {cwd: root, stdio: 'inherit', windowsHide: true});
    server.once('error', () => {process.exitCode = 1; stop();});
    server.once('close', code => {if (!stopped) {process.exitCode = code || 1; stop();}});
    console.log('Use somente contas fictícias. Digite q + Enter ou Ctrl+C para encerrar; dados emulados são descartáveis.');
    await done;
  } finally {
    stop();
    process.stdin.removeListener('data', input);
    process.stdin.pause();
    process.removeListener('SIGINT', stop);
    process.removeListener('SIGTERM', stop);
    fs.unlinkSync(configPath);
    fs.rmdirSync(directory);
  }
}

module.exports = {options, checkPorts};
if (require.main === module) main(process.argv.slice(2)).catch(error => {console.error(error.message); process.exitCode = 1;});
