import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const [html, css, app, audio] = await Promise.all([
  readFile(new URL('./public/index.html', import.meta.url), 'utf8'),
  readFile(new URL('./public/style.css', import.meta.url), 'utf8'),
  readFile(new URL('./public/app.js', import.meta.url), 'utf8'),
  readFile(new URL('./public/audio.js', import.meta.url), 'utf8'),
]);

for (const slot of ['left','center','right']) {
  assert.match(html, new RegExp(`data-dialogue-slot="${slot}"`));
}
assert.match(html, /id="speaker-name-plate"/);
for (const state of ['exploration','dialogue','manifestation','result','reconnecting','fallback']) {
  assert.match(app + css, new RegExp(state));
}
assert.match(css, /#dialogue-caption\{position:absolute[^}]*bottom:4%/);
assert.match(css, /\.shared-table \.shared-header\{display:none!important\}/);
assert.match(css, /\.shared-table #action-panel\{display:none!important\}/);
assert.match(css, /#dialogue-caption\{left:4%;right:4%;bottom:4%[^}]*border:0[^}]*rgba\(95,229,255,\.14\)/);
assert.match(audio, /wayfolio\.dialogue\.slots\.v1/);
assert.match(audio, /speakerID === 'narrator'/);
assert.match(audio, /renderDialogueSurface/);
assert.match(audio, /namePlate\.textContent = event\.speaker_name/);
assert.match(audio, /caption\.replaceChildren\(line\)/);

console.log('Shared iPad stage states, independent speaker plate and dialogue pane, narration privacy, and stable slots passed.');
