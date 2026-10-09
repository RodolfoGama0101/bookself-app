'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const net = require('node:net');
const {options, checkPorts} = require('./dev-web.cjs');

test('configuração não aceita destino remoto, comandos livres, serviços extras ou colisões', () => {
  for (const args of [['--project=production'], ['--host=0.0.0.0'], ['--deploy'], ['--web-port=1'], ['--web-port=65536'], ['--auth-port=8080'], ['--web-port=17360;whoami'], ['--web-port=17361', '--web-port=17362']]) {
    assert.throws(() => options(args));
  }
  assert.equal(options(['--check', '--web-port=17361']).web, 17361);
});

test('porta ocupada interrompe preflight sem encerrar o servidor existente', async () => {
  const existing = net.createServer();
  await new Promise(resolve => existing.listen(0, '127.0.0.1', resolve));
  try {
    await assert.rejects(checkPorts({...options([]), auth: existing.address().port}), /indisponível/);
    assert.equal(existing.listening, true);
  } finally {await new Promise(resolve => existing.close(resolve));}
});
