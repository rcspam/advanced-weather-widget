// The base maps of the widget's radar, as MapBackgroundChoices.qml hands
// them to the page: mapProviders.js of the worktree for the tiles, the
// labels of MapBackgroundChoices.qml (English, as the msgids).
// Prints the JSON list. Usage: node bglist.mjs <worktree> <theme> [suffix]
import fs from 'node:fs';
import vm from 'node:vm';

const [wt, theme = 'dark', suffix = ' | <a href="https://librewxr.net/">LibreWXR</a>'] = process.argv.slice(2);
const ctx = {};
vm.runInNewContext(fs.readFileSync(`${wt}/contents/ui/providers/mapProviders.js`, 'utf8'), ctx);

const qml = fs.readFileSync(`${wt}/contents/ui/components/MapBackgroundChoices.qml`, 'utf8');
const labels = {};
for (const m of qml.matchAll(/"([\w-]+)":\s*i18n\("([^"]*)"\)/g)) labels[m[1]] = m[2];

const out = ctx.MAP_BACKGROUND_ORDER.map((id) => {
  const p = ctx.resolveMapBackground(id, theme);
  const label = labels[id] || id;
  return {
    id, label,
    url: p.tileUrlTemplate || '', styleUrl: p.styleUrl || '',
    vector: ctx.isVectorBackground(p), invert: !!p.invert,
    attribution: p.attribution + suffix, maxZoom: p.maxZoom
  };
});
process.stdout.write(JSON.stringify(out));
