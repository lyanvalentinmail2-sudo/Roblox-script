import { readFile, readdir } from 'node:fs/promises';
import { LuauState } from 'luau-web';

async function files(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const nested = await Promise.all(entries.map(entry =>
    entry.isDirectory() ? files(`${dir}/${entry.name}`) : [`${dir}/${entry.name}`]));
  return nested.flat().filter(path => /\.(lua|luau)$/.test(path));
}
const read = path => readFile(path, 'utf8');
const state = await LuauState.createAsync({ print: console.log });
try {
  for (const path of [...await files('src'), 'FEEmotes-Delta.lua']) {
    state.loadstring(await read(path), path, true);
    console.log(`Sintaxis Luau OK: ${path}`);
  }
  const modules = `local Validation = (function()\n${await read('src/ReplicatedStorage/FEEmotes/Validation.lua')}\nend)()\n`
    + `local Config = (function()\n${await read('src/ReplicatedStorage/FEEmotes/Config.lua')}\nend)()\n`;
  await state.loadstring(modules + await read('tests/validation.spec.luau'), 'Validation tests', true)();
  const serverTest = modules + await read('tests/server.fixture.luau')
    + '\ndo\n' + await read('src/ServerScriptService/FEEmotes.server.lua') + '\nend\n'
    + await read('tests/server.spec.luau');
  await state.loadstring(serverTest, 'Server tests', true)();
  const standaloneTest = modules + await read('tests/server.fixture.luau')
    + '\nlocal createController = (function()\n' + await read('src/Standalone/Controller.lua') + '\nend)()\n'
    + await read('tests/standalone.fixture.luau') + '\n' + await read('tests/standalone.spec.luau');
  await state.loadstring(standaloneTest, 'Standalone tests', true)();
} finally {
  state.destroy();
}
