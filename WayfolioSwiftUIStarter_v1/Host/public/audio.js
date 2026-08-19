class WayfolioAudioDirector {
  constructor() {
    this.context = null;
    this.master = null;
    this.gains = new Map();
    this.loops = new Map();
    this.buffers = new Map();
    this.catalog = new Map();
    this.profiles = null;
    this.voiceRegistry = null;
    this.locationProfiles = null;
    this.ambienceDetailTimer = null;
    this.ambienceGeneration = 0;
    this.ready = false;
    this.busLevels = {voice:1, sfx:0.9, ambience:0.55, music:0.5, ui:0.75};
  }

  async load() {
    const [catalog, profiles, voiceRegistry, locationProfiles] = await Promise.all([
      fetch('/audio-catalog.json').then(response => response.json()),
      fetch('/creature-audio-profiles.json').then(response => response.json()),
      fetch('/character-voice-profiles.json').then(response => response.json()),
      fetch('/location-ambience-profiles.json').then(response => response.json()),
    ]);
    this.catalog = new Map(catalog.cues.map(cue => [cue.id, cue]));
    this.profiles = profiles;
    this.voiceRegistry = voiceRegistry;
    this.locationProfiles = locationProfiles;
  }

  async enable() {
    if (!this.context) {
      this.context = new AudioContext();
      this.master = this.context.createGain();
      this.master.connect(this.context.destination);
      for (const [bus, level] of Object.entries(this.busLevels)) {
        const gain = this.context.createGain();
        gain.gain.value = level;
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
    const normalized = Math.max(0, Math.min(1, Number(volume)));
    this.busLevels[bus] = normalized;
    this.gains.get(bus)?.gain.setTargetAtTime(normalized, this.context.currentTime, 0.03);
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
    return source;
  }

  async oneShot(cueID, requestedVolume) {
    if (!this.ready) return this.setStatus(`Enable audio to play ${cueID}`);
    const cue = this.catalog.get(cueID);
    if (!cue) return this.setStatus(`Unknown cue: ${cueID}`);
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
    if (existing) {
      try { existing.stop(); } catch {}
      this.loops.delete(bus);
    }
    if (action === 'stop') return this.setStatus(`${bus} stopped`);
    if (!this.ready) return this.setStatus(`Enable audio to start ${cueID}`);
    const cue = this.catalog.get(cueID);
    if (!cue || cue.bus !== bus) return this.setStatus(`Invalid ${bus} cue: ${cueID}`);
    try {
      const source = await this.sourceFor(cue, true, requestedVolume);
      this.loops.set(bus, source);
      source.start();
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
    if (event.action === 'stop') return this.setLoop('ambience', 'stop');
    const profile = this.locationProfiles?.profiles?.[event.profile];
    if (!profile) return this.setStatus(`Unknown ambience profile: ${event.profile}`);
    await this.setLoop('ambience', 'play', profile.base_cue, event.volume ?? profile.default_volume, event.fade_duration);
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

  speak(event) {
    const caption = document.getElementById('dialogue-caption');
    if (caption) {
      caption.hidden = false;
      caption.textContent = event.text;
    }
    if (!this.ready || !('speechSynthesis' in window)) return;
    speechSynthesis.cancel();
    const resolved = this.resolveVoice(event.speaker_id);
    const settings = this.performanceFor(event, resolved.profile);
    const utterance = new SpeechSynthesisUtterance(event.text);
    utterance.lang = settings.language;
    utterance.voice = this.browserVoiceFor(settings);
    utterance.rate = settings.rate;
    utterance.pitch = settings.pitch;
    utterance.volume = this.busLevels.voice;
    this.duck(true);
    utterance.onend = () => {
      this.duck(false);
      if (caption) caption.hidden = true;
    };
    utterance.onerror = () => this.duck(false);
    speechSynthesis.speak(utterance);
    this.setStatus(`Dialogue: ${resolved.profile?.display_name || resolved.id}`);
  }

  duck(active) {
    if (!this.context) return;
    const now = this.context.currentTime;
    const time = active ? 0.18 : 0.45;
    this.gains.get('music').gain.setTargetAtTime(this.busLevels.music * (active ? 0.45 : 1), now, time / 3);
    this.gains.get('ambience').gain.setTargetAtTime(this.busLevels.ambience * (active ? 0.65 : 1), now, time / 3);
  }

  stopAll() {
    this.stopAmbienceDetails();
    for (const source of this.loops.values()) {
      try { source.stop(); } catch {}
    }
    this.loops.clear();
    if ('speechSynthesis' in window) speechSynthesis.cancel();
    this.duck(false);
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
