function wayfolioWav(arrayBuffer) {
  const view = new DataView(arrayBuffer);
  const string = (offset, count) => String.fromCharCode(...new Uint8Array(arrayBuffer, offset, count));
  if (arrayBuffer.byteLength < 44 || string(0, 4) !== 'RIFF' || string(8, 4) !== 'WAVE') throw new Error('Expected WAV audio');
  let offset = 12, format, data;
  while (offset + 8 <= arrayBuffer.byteLength) {
    const id = string(offset, 4), size = view.getUint32(offset + 4, true), payload = offset + 8;
    if (id === 'fmt ') format = {kind:view.getUint16(payload, true), channels:view.getUint16(payload + 2, true), sampleRate:view.getUint32(payload + 4, true), bits:view.getUint16(payload + 14, true)};
    if (id === 'data') data = {offset:payload, size:Math.min(size, arrayBuffer.byteLength - payload)};
    offset = payload + size + (size & 1);
  }
  if (!format || !data) throw new Error('Invalid WAV audio');
  return {arrayBuffer, view, format, data};
}

function wayfolioSample(wav, index) {
  const bytes = wav.format.bits / 8, offset = wav.data.offset + index * bytes;
  if (wav.format.kind === 3 && wav.format.bits === 32) return wav.view.getFloat32(offset, true);
  if (wav.format.bits === 16) return wav.view.getInt16(offset, true) / 32768;
  if (wav.format.bits === 24) { let value = wav.view.getUint8(offset) | (wav.view.getUint8(offset + 1) << 8) | (wav.view.getUint8(offset + 2) << 16); if (value & 0x800000) value |= 0xff000000; return value / 8388608; }
  if (wav.format.bits === 32) return wav.view.getInt32(offset, true) / 2147483648;
  throw new Error('Unsupported WAV sample format');
}

function wayfolioFrameCount(wav) { return Math.floor(wav.data.size / (wav.format.bits / 8)); }
function wayfolioPut(wav, index, value, rules) { value = Math.max(-rules.sampleClamp, Math.min(rules.sampleClamp, value)); wav.view.setInt16(wav.data.offset + index * 2, Math.round(value * 32767), true); }
function wayfolioHeader(output, frames, rate) { const view = new DataView(output), write = (offset, value) => { for (let index = 0; index < value.length; index++) view.setUint8(offset + index, value.charCodeAt(index)); }; const bytes = frames * 2; write(0, 'RIFF'); view.setUint32(4, 36 + bytes, true); write(8, 'WAVE'); write(12, 'fmt '); view.setUint32(16, 16, true); view.setUint16(20, 1, true); view.setUint16(22, 1, true); view.setUint32(24, rate, true); view.setUint32(28, rate * 2, true); view.setUint16(32, 2, true); view.setUint16(34, 16, true); write(36, 'data'); view.setUint32(40, bytes, true); }

function wayfolioCanonical(input, rules) {
  const source = wayfolioWav(input), channels = source.format.channels, frames = Math.floor(wayfolioFrameCount(source) / channels), sourceRate = source.format.sampleRate;
  const count = Math.max(1, Math.round(frames * rules.sampleRate / sourceRate)), output = new ArrayBuffer(44 + count * 2); wayfolioHeader(output, count, rules.sampleRate); const target = wayfolioWav(output);
  const mono = frame => { frame = Math.max(0, Math.min(frames - 1, frame)); let value = 0; for (let channel = 0; channel < channels; channel++) value += wayfolioSample(source, frame * channels + channel); return value / channels; };
  for (let index = 0; index < count; index++) { const position = index * sourceRate / rules.sampleRate, first = Math.floor(position), second = Math.min(frames - 1, first + 1), fraction = position - first; wayfolioPut(target, index, mono(first) + (mono(second) - mono(first)) * fraction, rules); }
  return output;
}

function wayfolioAnalyze(input) { const wav = wayfolioWav(input), count = wayfolioFrameCount(wav); let peak = 0; for (let index = 0; index < count; index++) peak = Math.max(peak, Math.abs(wayfolioSample(wav, index))); const threshold = Math.max(.0022, peak * .04); let first = -1, last = -1, sum = 0, samples = 0; for (let index = 0; index < count; index++) { const value = wayfolioSample(wav, index); if (Math.abs(value) >= threshold) { if (first < 0) first = index; last = index; sum += value * value; samples++; } } if (first < 0) { first = 0; last = count - 1; } return {wav, peak, rms:samples ? Math.sqrt(sum / samples) : 0, first, last}; }
function wayfolioScale(input, gain, rules) { const output = input.slice(0), wav = wayfolioWav(output); for (let index = 0; index < wayfolioFrameCount(wav); index++) wayfolioPut(wav, index, wayfolioSample(wav, index) * gain, rules); return output; }
function wayfolioCalibrate(input, rules) { const analysis = wayfolioAnalyze(input); if (!analysis.rms || !analysis.peak) return input.slice(0); let gain = rules.targetRms / analysis.rms; gain = Math.min(gain, rules.maxPeak / analysis.peak); return wayfolioScale(input, Math.max(.25, Math.min(4, gain)), rules); }
function wayfolioCrop(input, rules) { const analysis = wayfolioAnalyze(input), rate = analysis.wav.format.sampleRate, start = Math.max(0, analysis.first - Math.round(rate * rules.trimPreMs / 1000)), end = Math.min(wayfolioFrameCount(analysis.wav) - 1, analysis.last + Math.round(rate * rules.trimPostMs / 1000)), frames = end - start + 1, output = new ArrayBuffer(44 + frames * 2); wayfolioHeader(output, frames, rate); new Uint8Array(output, 44).set(new Uint8Array(input, analysis.wav.data.offset + start * 2, frames * 2)); return output; }
function wayfolioInsertSilence(input, frame, milliseconds) { const wav = wayfolioWav(input), count = wayfolioFrameCount(wav), rate = wav.format.sampleRate, extra = Math.max(1, Math.round(rate * milliseconds / 1000)), cut = Math.max(0, Math.min(count, frame)), output = new ArrayBuffer(44 + (count + extra) * 2); wayfolioHeader(output, count + extra, rate); const destination = new Uint8Array(output), source = new Uint8Array(input, wav.data.offset, count * 2); destination.set(source.subarray(0, cut * 2), 44); destination.set(source.subarray(cut * 2), 44 + (cut + extra) * 2); return output; }
function wayfolioLocate(input, text, characterIndex, rules, radius = rules.punctuationSearchRadiusMs) { const analysis = wayfolioAnalyze(input), wav = analysis.wav, rate = wav.format.sampleRate, ratio = characterIndex / Math.max(1, text.length - 1), approximate = Math.round(analysis.first + ratio * (analysis.last - analysis.first)), range = Math.round(rate * radius / 1000), half = Math.max(2, Math.round(rate * .006)), step = Math.max(1, Math.round(rate * .0025)); let best = approximate, score = Infinity; for (let center = Math.max(analysis.first + half, approximate - range); center <= Math.min(analysis.last - half, approximate + range); center += step) { let sum = 0; for (let offset = -half; offset <= half; offset++) { const value = wayfolioSample(wav, center + offset); sum += value * value; } const rms = Math.sqrt(sum / (half * 2 + 1)), distance = Math.abs(center - approximate) / Math.max(1, range), candidate = rms * (1 + distance * .75); if (candidate < score) { score = candidate; best = center; } } return best; }
function wayfolioEnvelope(input, points, rules) { const output = input.slice(0), analysis = wayfolioAnalyze(output), wav = analysis.wav, span = Math.max(1, analysis.last - analysis.first); const gain = time => { if (time <= points[0][0]) return points[0][1]; for (let index = 1; index < points.length; index++) if (time <= points[index][0]) { const [x0, y0] = points[index - 1], [x1, y1] = points[index], fraction = (time - x0) / (x1 - x0), smooth = fraction * fraction * (3 - 2 * fraction); return y0 + (y1 - y0) * smooth; } return points[points.length - 1][1]; }; for (let index = analysis.first; index <= analysis.last; index++) wayfolioPut(wav, index, wayfolioSample(wav, index) * gain((index - analysis.first) / span), rules); return output; }
function wayfolioWordRange(input, text, punctuationIndex, rules) { let end = punctuationIndex; while (end > 0 && /\s/.test(text[end - 1])) end--; let start = end; while (start > 0 && /[A-Za-z0-9'’\-]/.test(text[start - 1])) start--; if (start === end) return null; const analysis = wayfolioAnalyze(input), span = Math.max(1, analysis.last - analysis.first), rate = analysis.wav.format.sampleRate, approximateStart = Math.round(analysis.first + start / Math.max(1, text.length - 1) * span), approximateEnd = Math.round(analysis.first + end / Math.max(1, text.length - 1) * span); let first = wayfolioLocate(input, text, start, rules, rules.wordSearchRadiusMs), last = wayfolioLocate(input, text, end, rules, rules.wordSearchRadiusMs); const minimum = Math.round(rate * .055); if (last - first < minimum) { first = Math.max(analysis.first, approximateStart); last = Math.min(analysis.last, Math.max(approximateStart + minimum, approximateEnd)); } return {start:first, end:last}; }
function wayfolioExclamationRamp(input, start, end, rule, rules) { const output = input.slice(0), wav = wayfolioWav(output), count = wayfolioFrameCount(wav), first = Math.max(0, Math.min(count - 2, start)), last = Math.max(first + 2, Math.min(count, end)), rampStart = Math.round(first + (last - first) * rule.startFraction), span = Math.max(1, last - rampStart); for (let index = rampStart; index < last; index++) { const fraction = Math.max(0, Math.min(1, (index - rampStart) / span)), smooth = fraction * fraction * (3 - 2 * fraction), gain = rule.fromGain + (rule.toGain - rule.fromGain) * smooth; wayfolioPut(wav, index, wayfolioSample(wav, index) * gain, rules); } return output; }
function wayfolioPitchRegion(input, start, end, semitones, rules) { const wav = wayfolioWav(input), count = wayfolioFrameCount(wav), rate = wav.format.sampleRate, first = Math.max(0, Math.min(count - 2, start)), last = Math.max(first + 2, Math.min(count, end)), length = last - first, speed = Math.pow(2, semitones / 12), newLength = Math.max(2, Math.round(length / speed)), output = new ArrayBuffer(44 + (count - length + newLength) * 2); wayfolioHeader(output, count - length + newLength, rate); const target = wayfolioWav(output); for (let index = 0; index < first; index++) wayfolioPut(target, index, wayfolioSample(wav, index), rules); for (let index = 0; index < newLength; index++) { const position = first + index * speed, lower = Math.min(last - 1, Math.floor(position)), upper = Math.min(last - 1, lower + 1), fraction = position - lower; wayfolioPut(target, first + index, wayfolioSample(wav, lower) + (wayfolioSample(wav, upper) - wayfolioSample(wav, lower)) * fraction, rules); } for (let index = last; index < count; index++) wayfolioPut(target, first + newLength + index - last, wayfolioSample(wav, index), rules); return output; }
function wayfolioWordPerformance(input, packet, rules) { let output = input; const punctuation = packet.render.punctuation; for (let index = 0; index < packet.text.length; index++) if (packet.text[index] === '!') { const range = wayfolioWordRange(output, packet.text, index, rules); if (range) output = wayfolioExclamationRamp(output, range.start, range.end, punctuation.exclamation.finalWordRamp, rules); } const questions = []; for (let index = 0; index < packet.text.length; index++) if (packet.text[index] === '?') questions.push(index); questions.sort((first, second) => second - first); for (const index of questions) { const range = wayfolioWordRange(output, packet.text, index, rules); if (range) output = wayfolioPitchRegion(output, range.start, range.end, punctuation.question.finalWordPitchSemitones, rules); } return output; }
function wayfolioPunctuationTiming(input, packet, rules) { const marks = [], punctuation = packet.render.punctuation; for (let index = 0; index < packet.text.length; index++) { const character = packet.text[index]; if (character === '—') marks.push({index, milliseconds:punctuation.emDash.pauseMs}); else if (character === '?') marks.push({index, milliseconds:punctuation.question.pauseMs}); else if (character === '!') marks.push({index, milliseconds:punctuation.exclamation.pauseMs}); else if (character === '…') marks.push({index, milliseconds:punctuation.ellipsis.pauseMs}); } const located = marks.map(mark => ({...mark, frame:wayfolioLocate(input, packet.text, mark.index, rules)})).sort((first, second) => second.frame - first.frame); let output = input; for (const mark of located) output = wayfolioInsertSilence(output, mark.frame, mark.milliseconds); return output; }
function renderWayfolioVoice(input, packet) { const rules = packet.render.audio; let output = wayfolioCanonical(input, rules); output = wayfolioCrop(output, rules); output = wayfolioCalibrate(output, rules); output = wayfolioScale(output, packet.render.baseGain || 1, rules); output = wayfolioScale(output, packet.performance.gain || 1, rules); output = wayfolioEnvelope(output, packet.performance.envelope || [[0, 1], [1, 1]], rules); output = wayfolioWordPerformance(output, packet, rules); return wayfolioPunctuationTiming(output, packet, rules); }

class WayfolioAudioDirector {
  constructor() {
    this.context = null;
    this.master = null;
    this.gains = new Map();
    this.loops = new Map();
    this.lastCueAt = new Map();
    this.buffers = new Map();
    this.catalog = new Map();
    this.profiles = null;
    this.voiceRegistry = null;
    this.visualProfiles = null;
    this.voiceDirectorBase = 'https://wayfolio-voice-proxy-wxlq.vercel.app';
    this.voiceBuffers = new Map();
    this.activeVoice = null;
    this.dialogueQueue = Promise.resolve();
    this.dialoguePending = [];
    this.dialogueBatchTimer = null;
    this.dialogueGeneration = 0;
    this.pendingRestoredDialogue = null;
    this.restoredDialogueTimer = null;
    this.dialogueSlotAssignments = new Map([['renn','left'], ['soren','right'], ['lupin','center']]);
    this.locationProfiles = null;
    this.ambienceDetailTimer = null;
    this.ambienceGeneration = 0;
    this.ready = false;
    this.busLevels = {voice:1, sfx:0.9, ambience:0.55, music:0.5, ui:0.75};
    this.busMuted = {voice:false, sfx:false, ambience:false, music:false, ui:false};
    try {
      const saved = JSON.parse(localStorage.getItem('wayfolio.audio.mix.v1') || '{}');
      for (const bus of Object.keys(this.busLevels)) {
        if (Number.isFinite(saved.levels?.[bus])) this.busLevels[bus] = Math.max(0, Math.min(1, saved.levels[bus]));
        if (typeof saved.muted?.[bus] === 'boolean') this.busMuted[bus] = saved.muted[bus];
      }
    } catch {}
    try {
      const savedSlots = JSON.parse(localStorage.getItem('wayfolio.dialogue.slots.v1') || '{}');
      for (const [speaker, slot] of Object.entries(savedSlots)) {
        if (['left','right','center'].includes(slot)) this.dialogueSlotAssignments.set(speaker, slot);
      }
    } catch {}
  }

  async load() {
    const [catalog, profiles, voiceRegistry, locationProfiles, visualProfiles, loginContext] = await Promise.all([
      fetch('/audio-catalog.json').then(response => response.json()),
      fetch('/creature-audio-profiles.json').then(response => response.json()),
      fetch('/character-voice-profiles.json').then(response => response.json()),
      fetch('/location-ambience-profiles.json').then(response => response.json()),
      fetch('/assets/approved/characters/visual-profiles.json').then(response => response.json()),
      fetch('/api/shared-login-context?code=HEMLOCK', {cache:'no-store'}).then(response => response.ok ? response.json() : null).catch(() => null),
    ]);
    this.catalog = new Map(catalog.cues.map(cue => [cue.id, cue]));
    this.profiles = profiles;
    this.voiceRegistry = voiceRegistry;
    this.locationProfiles = locationProfiles;
    this.visualProfiles = visualProfiles;
    for (const member of loginContext?.party || []) {
      if (!member?.sprite?.url) continue;
      this.visualProfiles.profiles[member.id] = {
        ...(this.visualProfiles.profiles[member.id] || {}),
        display_name:member.name,
        portrait:member.sprite.url,
        portrait_position:'50% 28%',
        status:'approved_manifest',
      };
    }
    if (this.pendingRestoredDialogue) {
      const event = this.pendingRestoredDialogue;
      this.pendingRestoredDialogue = null;
      this.restoreDialogue(event);
    }
  }

  async enable() {
    if (!this.context) {
      this.context = new AudioContext();
      this.master = this.context.createGain();
      this.master.connect(this.context.destination);
      for (const [bus, level] of Object.entries(this.busLevels)) {
        const gain = this.context.createGain();
        gain.gain.value = this.busMuted[bus] ? 0 : level;
        gain.connect(this.master);
        this.gains.set(bus, gain);
      }
    }
    await this.context.resume();
    this.ready = true;
    this.setStatus('Shared audio enabled');
  }

  setStatus(text) {
    const target = document.getElementById('audio-status');
    if (target) target.textContent = text;
  }

  setBusVolume(bus, volume) {
    if (!(bus in this.busLevels)) return;
    const normalized = Math.max(0, Math.min(1, Number(volume)));
    this.busLevels[bus] = normalized;
    this.applyBusLevel(bus);
    this.saveMixPreferences();
  }

  setBusMuted(bus, muted) {
    if (!(bus in this.busMuted)) return;
    this.busMuted[bus] = Boolean(muted);
    this.applyBusLevel(bus);
    if (bus === 'voice' && muted && this.activeVoice) {
      try { this.activeVoice.stop(); } catch {}
      this.activeVoice = null;
    }
    this.saveMixPreferences();
    this.setStatus(`${bus} ${muted ? 'off' : 'on'}`);
  }

  applyBusLevel(bus) {
    const gain = this.gains.get(bus);
    if (!gain || !this.context) return;
    gain.gain.setTargetAtTime(this.busMuted[bus] ? 0 : this.busLevels[bus], this.context.currentTime, 0.03);
  }

  saveMixPreferences() {
    try {
      localStorage.setItem('wayfolio.audio.mix.v1', JSON.stringify({levels:this.busLevels, muted:this.busMuted}));
    } catch {}
  }

  async bufferFor(cue) {
    if (!this.buffers.has(cue.id)) {
      const pending = fetch(`/${cue.file}`)
        .then(response => {
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
          return response.arrayBuffer();
        })
        .then(data => this.context.decodeAudioData(data));
      this.buffers.set(cue.id, pending);
    }
    return this.buffers.get(cue.id);
  }

  async sourceFor(cue, loop = false, requestedVolume) {
    const source = this.context.createBufferSource();
    source.buffer = await this.bufferFor(cue);
    source.loop = loop;
    const cueGain = this.context.createGain();
    cueGain.gain.value = Math.max(0, Math.min(1, requestedVolume ?? cue.default_volume ?? 1));
    source.connect(cueGain);
    cueGain.connect(this.gains.get(cue.bus));
    source.wayfolioGain = cueGain;
    source.wayfolioVolume = cueGain.gain.value;
    return source;
  }

  async oneShot(cueID, requestedVolume) {
    if (!this.ready) return this.setStatus(`Enable audio to play ${cueID}`);
    const cue = this.catalog.get(cueID);
    if (!cue) return this.setStatus(`Unknown cue: ${cueID}`);
    const now = performance.now();
    const cooldown = cueID.startsWith('creature_') ? 4000 : 2000;
    const lastPlayed = this.lastCueAt.get(cueID);
    if (lastPlayed && now - lastPlayed < cooldown) return;
    this.lastCueAt.set(cueID, now);
    try {
      const source = await this.sourceFor(cue, false, requestedVolume);
      source.start();
      this.setStatus(`Playing ${cueID}`);
    } catch (error) {
      this.setStatus(`Could not play ${cueID}: ${error.message}`);
    }
  }

  async setLoop(bus, action, cueID, requestedVolume, fadeDuration = 0.4) {
    const existing = this.loops.get(bus);
    const fade = Math.max(0, Number(fadeDuration) || 0);
    const fadeOut = source => {
      if (!source) return;
      const now = this.context.currentTime;
      source.wayfolioGain.gain.cancelScheduledValues(now);
      source.wayfolioGain.gain.setValueAtTime(source.wayfolioGain.gain.value, now);
      source.wayfolioGain.gain.linearRampToValueAtTime(0, now + fade);
      setTimeout(() => { try { source.stop(); } catch {} }, fade * 1000 + 50);
    };
    if (action === 'stop') {
      fadeOut(existing);
      this.loops.delete(bus);
      return this.setStatus(`${bus} stopped`);
    }
    if (!this.ready) return this.setStatus(`Enable audio to start ${cueID}`);
    const cue = this.catalog.get(cueID);
    if (!cue || cue.bus !== bus) return this.setStatus(`Invalid ${bus} cue: ${cueID}`);
    try {
      const source = await this.sourceFor(cue, true, requestedVolume);
      const target = source.wayfolioVolume;
      const now = this.context.currentTime;
      source.wayfolioGain.gain.setValueAtTime(fade ? 0 : target, now);
      if (fade) source.wayfolioGain.gain.linearRampToValueAtTime(target, now + fade);
      this.loops.set(bus, source);
      source.start();
      fadeOut(existing);
      this.setStatus(`${bus}: ${cueID}${fadeDuration ? ` · ${fadeDuration}s transition` : ''}`);
    } catch (error) {
      this.setStatus(`Could not start ${cueID}: ${error.message}`);
    }
  }

  stopAmbienceDetails() {
    this.ambienceGeneration += 1;
    if (this.ambienceDetailTimer) clearTimeout(this.ambienceDetailTimer);
    this.ambienceDetailTimer = null;
  }

  scheduleAmbienceDetail(profile, generation) {
    if (!profile.details?.length || generation !== this.ambienceGeneration) return;
    const detail = profile.details[Math.floor(Math.random() * profile.details.length)];
    const delay = detail.min_delay + Math.random() * (detail.max_delay - detail.min_delay);
    this.ambienceDetailTimer = setTimeout(async () => {
      if (generation !== this.ambienceGeneration) return;
      await this.oneShot(detail.cue);
      this.scheduleAmbienceDetail(profile, generation);
    }, delay * 1000);
  }

  async setLocationAmbience(event) {
    this.stopAmbienceDetails();
    if (event.action === 'stop') {
      await this.setLoop('ambience', 'stop');
      return this.setLoop('music', 'stop');
    }
    const profile = this.locationProfiles?.profiles?.[event.profile];
    if (!profile) return this.setStatus(`Unknown ambience profile: ${event.profile}`);
    await this.setLoop('ambience', 'play', profile.base_cue, event.volume ?? profile.default_volume, event.fade_duration);
    if (profile.music?.cue) {
      await this.setLoop('music', 'play', profile.music.cue, profile.music.volume, event.fade_duration ?? 2);
    } else {
      await this.setLoop('music', 'stop');
    }
    const generation = this.ambienceGeneration;
    this.scheduleAmbienceDetail(profile, generation);
    this.setStatus(`Ambience: ${profile.label}`);
  }

  resolveCreature(event) {
    const behavior = event.behavior;
    const override = this.profiles.creature_overrides[event.creature_id];
    if (override?.cue) return override.cue;
    if (override?.profile) {
      const cue = this.profiles.profiles[override.profile]?.[behavior];
      if (cue) return cue;
    }
    for (const composite of this.profiles.composite_profiles) {
      const selectors = Object.entries(composite).filter(([key]) => key !== 'cue');
      if (selectors.every(([key, value]) => event[key] === value)) return composite.cue;
    }
    return this.profiles.body_form_profiles[event.body_form]?.[behavior]
      || this.profiles.profiles[event.creature_type]?.[behavior]
      || this.profiles.profiles[this.profiles.fallback_profile]?.[behavior]
      || null;
  }

  resolveVoice(speakerID) {
    const registry = this.voiceRegistry;
    if (!registry) return {id:'narrator', profile:null};
    const normalized = String(speakerID || '').trim().toLowerCase();
    if (registry.profiles[normalized]) return {id:normalized, profile:registry.profiles[normalized]};
    const match = Object.entries(registry.profiles)
      .find(([, profile]) => profile.aliases?.some(alias => alias.toLowerCase() === normalized));
    const id = match?.[0] || registry.default_profile;
    return {id, profile:registry.profiles[id]};
  }

  browserVoiceFor(settings) {
    const voices = speechSynthesis.getVoices();
    const language = settings.language.toLowerCase();
    const matching = voices.filter(voice => voice.lang.toLowerCase().startsWith(language));
    const candidates = matching.length ? matching : voices;
    if (!candidates.length) return null;
    return candidates[settings.voice_index % candidates.length];
  }

  performanceFor(event, profile) {
    const settings = profile?.browser_voice || {language:'en-US', voice_index:0, rate:0.9, pitch:1};
    const text = `${event.performance || ''} ${event.emotion || ''}`.toLowerCase();
    let rate = settings.rate;
    let pitch = settings.pitch;
    for (const [name, modifier] of Object.entries(this.voiceRegistry?.performance_modifiers || {})) {
      if (!text.includes(name)) continue;
      rate *= modifier.rate_multiplier;
      pitch += modifier.pitch_delta;
    }
    const form = profile?.forms?.[event.form];
    if (form) {
      rate *= form.rate_multiplier;
      pitch += form.pitch_delta;
    }
    return {
      ...settings,
      rate:Math.max(0.5, Math.min(2, rate)),
      pitch:Math.max(0, Math.min(2, pitch)),
    };
  }

  voiceDirectorSpeaker(speakerID) {
    const supported = new Set(['narrator', 'soren', 'lupin', 'wayfolio']);
    const normalized = String(speakerID || '').trim().toLowerCase();
    return supported.has(normalized) ? normalized : 'narrator';
  }

  async directorPacketFor(event, speaker) {
    const response = await fetch(`${this.voiceDirectorBase}/api/voice-director`, {
      method:'POST', headers:{'Content-Type':'application/json'},
      body:JSON.stringify({speaker, text:event.text, performance:event.performance || event.emotion || 'neutral'}),
    });
    if (!response.ok) throw new Error(`Voice Director ${response.status}`);
    const body = await response.json();
    return body.packet;
  }

  async directorVoiceFor(event, speaker, packet) {
    const key = `${speaker}|${packet.performance.intent}|${packet.performance.pace}|${event.text}`;
    if (!this.voiceBuffers.has(key)) {
      const pending = fetch(`${this.voiceDirectorBase}/api/speech`, {
        method:'POST', headers:{'Content-Type':'application/json'},
        body:JSON.stringify({speaker, text:event.text, pace:packet.performance.pace}),
      }).then(response => {
        if (!response.ok) throw new Error(`Kokoro speech ${response.status}`);
        return response.arrayBuffer();
      }).then(data => renderWayfolioVoice(data, packet))
        .then(data => this.context.decodeAudioData(data));
      this.voiceBuffers.set(key, pending);
    }
    return this.voiceBuffers.get(key);
  }

  speak(event) {
    const generation = this.dialogueGeneration;
    const prepared = this.prepareDialogue(event).catch(error => ({error,
      resolved:this.resolveVoice(event.voice_profile_id || event.speaker_id)}));
    return new Promise(resolve => {
      this.dialoguePending.push({event, prepared, generation, resolve});
      if (this.dialogueBatchTimer) clearTimeout(this.dialogueBatchTimer);
      this.dialogueBatchTimer = setTimeout(() => this.flushDialogueBatch(), 120);
    });
  }

  flushDialogueBatch() {
    this.dialogueBatchTimer = null;
    const batch = this.dialoguePending.splice(0);
    this.dialogueQueue = this.dialogueQueue.catch(() => {}).then(async () => {
      await Promise.all(batch.map(item => item.prepared));
      for (const item of batch) {
        if (item.generation === this.dialogueGeneration) await this.playDialogue(item.event, item.prepared);
        item.resolve();
      }
    });
  }

  async prepareDialogue(event) {
    const resolved = this.resolveVoice(event.voice_profile_id || event.speaker_id);
    if (!this.ready || this.busMuted.voice) return {resolved, packet:null, buffer:null};
    const speaker = this.voiceDirectorSpeaker(resolved.id);
    const packet = await this.directorPacketFor(event, speaker);
    const buffer = await this.directorVoiceFor(event, speaker, packet);
    return {resolved, packet, buffer};
  }

  dialogueStatus(event, status) {
    window.dispatchEvent(new CustomEvent('wayfolio-dialogue-status', {detail:{
      line_id:event.line_id, speaker_id:event.speaker_id, status,
    }}));
  }

  stageDialogueCharacter(speakerID, visual) {
    const stage = document.getElementById('dialogue-character-stage');
    if (!stage) return;
    for (const slot of stage.querySelectorAll('[data-dialogue-slot]')) slot.classList.remove('active');
    if (!visual?.portrait || speakerID === 'narrator') {
      stage.hidden = true;
      return;
    }
    const reserved = new Set(this.dialogueSlotAssignments.values());
    if (!this.dialogueSlotAssignments.has(speakerID)) {
      this.dialogueSlotAssignments.set(speakerID, ['left','right','center'].find(slot => !reserved.has(slot)) || 'center');
      try { localStorage.setItem('wayfolio.dialogue.slots.v1', JSON.stringify(Object.fromEntries(this.dialogueSlotAssignments))); } catch {}
    }
    const name = this.dialogueSlotAssignments.get(speakerID);
    const slot = stage.querySelector(`[data-dialogue-slot="${name}"]`);
    if (!slot) return;
    let portrait = slot.querySelector('img');
    if (!portrait || portrait.dataset.speaker !== speakerID) {
      portrait = document.createElement('img');
      portrait.dataset.speaker = speakerID;
      portrait.src = visual.portrait;
      portrait.alt = '';
      portrait.style.setProperty('--portrait-position', visual.portrait_position || '50% 30%');
      slot.replaceChildren(portrait);
    }
    slot.classList.add('active');
    stage.hidden = false;
  }

  renderDialogueSurface(event, resolved, visual) {
    const caption = document.getElementById('dialogue-caption');
    const namePlate = document.getElementById('speaker-name-plate');
    if (!caption) return;

    const isNarration = resolved.id === 'narrator' || event.is_narration === true;
    const line = document.createElement('p');
    line.textContent = event.text;
    caption.replaceChildren(line);
    caption.classList.toggle('no-portrait', !visual?.portrait || isNarration);
    caption.hidden = false;

    if (namePlate) {
      if (isNarration) {
        namePlate.hidden = true;
        namePlate.replaceChildren();
        namePlate.setAttribute('aria-hidden', 'true');
      } else {
        namePlate.textContent = event.speaker_name || visual?.display_name || resolved.profile?.display_name || resolved.id;
        namePlate.hidden = false;
        namePlate.setAttribute('aria-hidden', 'false');
        requestAnimationFrame(() => {
          namePlate.style.bottom = `${caption.offsetHeight + (window.innerHeight * 0.04) - 3}px`;
        });
      }
    }
  }

  restoreDialogue(event) {
    if (!event?.text) return;
    const presentedAt = Date.parse(event.presented_at || '');
    const remaining = (2 * 60 * 1000) - (Date.now() - presentedAt);
    if (!Number.isFinite(presentedAt) || remaining <= 0) {
      this.dismissDialogue();
      if (event.line_id) this.dialogueStatus(event, 'completed');
      return;
    }
    if (!this.voiceRegistry || !this.visualProfiles) {
      this.pendingRestoredDialogue = event;
      return;
    }
    const resolved = this.resolveVoice(event.voice_profile_id || event.speaker_id);
    const visual = this.visualProfiles?.profiles?.[resolved.id];
    this.stageDialogueCharacter(resolved.id, visual);
    this.renderDialogueSurface(event, resolved, visual);
    if (this.restoredDialogueTimer) clearTimeout(this.restoredDialogueTimer);
    this.restoredDialogueTimer = setTimeout(() => {
      this.restoredDialogueTimer = null;
      this.dismissDialogue();
      this.dialogueStatus(event, 'completed');
    }, Math.min(10 * 1000, remaining));
  }

  dismissDialogue() {
    this.dialogueGeneration += 1;
    if (this.restoredDialogueTimer) clearTimeout(this.restoredDialogueTimer);
    this.restoredDialogueTimer = null;
    if (this.dialogueBatchTimer) clearTimeout(this.dialogueBatchTimer);
    this.dialogueBatchTimer = null;
    for (const item of this.dialoguePending.splice(0)) item.resolve();
    this.dialogueQueue = Promise.resolve();
    this.pendingRestoredDialogue = null;
    if (this.activeVoice) try { this.activeVoice.stop(); } catch {}
    this.activeVoice = null;
    this.duck(false);
    const caption = document.getElementById('dialogue-caption');
    if (caption) {
      caption.hidden = true;
      caption.replaceChildren();
    }
    const namePlate = document.getElementById('speaker-name-plate');
    if (namePlate) {
      namePlate.hidden = true;
      namePlate.replaceChildren();
      namePlate.setAttribute('aria-hidden', 'true');
    }
    const stage = document.getElementById('dialogue-character-stage');
    if (stage) {
      stage.hidden = true;
      for (const slot of stage.querySelectorAll('[data-dialogue-slot]')) slot.classList.remove('active');
    }
    if (document.body?.dataset.role === 'screen' || document.body?.classList.contains('shared-table')) {
      document.body.dataset.stageState = 'exploration';
    }
  }

  async playDialogue(event, prepared) {
    if (this.restoredDialogueTimer) clearTimeout(this.restoredDialogueTimer);
    this.restoredDialogueTimer = null;
    const ready = await prepared;
    const resolved = ready.resolved;
    const caption = document.getElementById('dialogue-caption');
    if (caption) {
      const visual = this.visualProfiles?.profiles?.[resolved.id];
      this.stageDialogueCharacter(resolved.id, visual);
      this.renderDialogueSurface(event, resolved, visual);
    }
    this.dialogueStatus(event, 'received');
    if (!this.ready || this.busMuted.voice) {
      this.dialogueStatus(event, 'completed');
      return;
    }
    try {
      if (ready.error) throw ready.error;
      const packet = ready.packet;
      const source = this.context.createBufferSource();
      source.buffer = ready.buffer;
      const performanceGain = this.context.createGain();
      performanceGain.gain.value = 1;
      source.connect(performanceGain);
      performanceGain.connect(this.gains.get('voice'));
      this.activeVoice = source;
      this.duck(true);
      await new Promise(resolve => {
        source.onended = () => {
          if (this.activeVoice === source) this.activeVoice = null;
          this.duck(false);
          if (caption) caption.hidden = true;
          const namePlate = document.getElementById('speaker-name-plate');
          if (namePlate) namePlate.hidden = true;
          const stage = document.getElementById('dialogue-character-stage');
          if (stage) stage.hidden = true;
          this.dialogueStatus(event, 'completed');
          resolve();
        };
        source.start();
        this.dialogueStatus(event, 'started');
        this.setStatus(`Voice Director: ${packet.baseline} · ${resolved.profile?.display_name || resolved.id}`);
      });
    } catch (error) {
      this.duck(false);
      this.setStatus(`Voice Director unavailable: ${error.message}`);
      this.dialogueStatus(event, 'failed');
    }
  }

  duck(active) {
    if (!this.context) return;
    const now = this.context.currentTime;
    const time = active ? 0.18 : 0.45;
    const music = this.busMuted.music ? 0 : this.busLevels.music;
    const ambience = this.busMuted.ambience ? 0 : this.busLevels.ambience;
    this.gains.get('music').gain.setTargetAtTime(music * (active ? 0.45 : 1), now, time / 3);
    this.gains.get('ambience').gain.setTargetAtTime(ambience * (active ? 0.65 : 1), now, time / 3);
  }

  stopAll() {
    this.dismissDialogue();
    this.stopAmbienceDetails();
    for (const source of this.loops.values()) {
      try { source.stop(); } catch {}
    }
    this.loops.clear();
    this.setStatus('All presentation audio stopped');
  }

  async handle(event) {
    if (!event) return;
    switch (event.type) {
      case 'ui_sound':
      case 'sound_effect': return this.oneShot(event.cue, event.volume);
      case 'creature_sound': {
        const cue = this.resolveCreature(event);
        return cue ? this.oneShot(cue, event.volume) : this.setStatus('No matching creature sound');
      }
      case 'ambience':
        this.stopAmbienceDetails();
        return this.setLoop('ambience', event.action, event.cue, event.volume, event.fade_duration);
      case 'ambience_scene': return this.setLocationAmbience(event);
      case 'music': return this.setLoop('music', event.action, event.cue, event.volume, event.fade_duration);
      case 'dialogue': return this.speak(event);
      case 'audio_control': if (event.action === 'stop_all') this.stopAll();
    }
  }

  async restore(state) {
    if (!state || !this.ready) return;
    if (state.ambience) await this.handle(state.ambience);
    if (state.music) await this.handle(state.music);
  }
}

window.wayfolioAudio = new WayfolioAudioDirector();
window.wayfolioAudio.load().catch(() => window.wayfolioAudio.setStatus('Audio catalog unavailable'));
