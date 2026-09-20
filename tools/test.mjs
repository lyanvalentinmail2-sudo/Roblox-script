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
  const hubModules = modules
    + `local Favorites = (function()\n${await read('src/ReplicatedStorage/FEEmotes/Favorites.lua')}\nend)()\n`
    + `local HubState = (function()\n${await read('src/ReplicatedStorage/FEEmotes/HubState.lua')}\nend)()\n`
    + `local HubLayout = (function()\n${await read('src/ReplicatedStorage/FEEmotes/HubLayout.lua')}\nend)()\n`;
  await state.loadstring(hubModules + await read('tests/hub.spec.luau'), 'Hub modules', true)();
  await state.loadstring(hubModules + await read('tests/layout.spec.luau'), 'Compact layout', true)();
  const detailsModule = `\nlocal EmoteDetails = (function()\n${await read('src/ReplicatedStorage/FEEmotes/EmoteDetails.lua')}\nend)()\n`;
  const detailsTest = modules + await read('tests/server.fixture.luau') + detailsModule
    + await read('tests/details.fixture.luau') + '\n' + await read('tests/details.spec.luau');
  await state.loadstring(detailsTest, 'Details and purchases', true)();
  const uiTest = hubModules + await read('tests/server.fixture.luau') + detailsModule
    + '\n' + await read('tests/ui.fixture.luau')
    + '\nlocal function mountHub()\n' + await read('src/StarterPlayer/StarterPlayerScripts/FEEmotes.client.lua') + '\nend\nmountHub()\n'
    + await read('tests/ui.spec.luau')
    + '\nmountHub()\n'
    + `advance(1)
local restoredGui = assert(playerGui:FindFirstChild("FEEmotesGui"))
check(not find(restoredGui, "Panel").Visible, "UI: reejecutar no abre el panel solo")
click(find(restoredGui, "Reopen"), 0.4)
check(find(find(restoredGui, "Emote_123"), "Favorite").Text == "★", "UI: favoritos sobreviven al recrear la GUI")
restoredGui:Destroy()
advance(1)
check(liveTweens == 0, "UI: segunda destrucción limpia todos los tweens")
print("Restauración GUI: 3 comprobaciones adicionales correctas")
`;
  await state.loadstring(uiTest, 'UI structure tests', true)();
} finally {
  state.destroy();
}
