class WayfolioAudioDirector {
  constructor() {
    this.context = null;
    this.master = null;
    this.gains = new Map();
    this.loops = new Map();
    this.catalog = new Map();
    this.profiles = null;
    this.ready = false;
    this.busLevels = {voice:1, sfx:0.9, ambience:0.55, music:0.5, ui:0.75};
  }

  async load() {
    const [catalog, profiles] = await Promise.all([
      fetch('/audio-catalog.json').then(response => response.json()),
      fetch('/creature-audio-profiles.json').then(response => response.json()),
    ]);
    this.catalog = new Map(catalog.cues.map(cue => [cue.id, cue]));
    this.profiles = profiles;
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

  mediaFor(cue, loop = false) {
    const media = new Audio(`/${cue.file}`);
    media.loop = loop;
    media.preload = 'auto';
    media.volume = Math.max(0, Math.min(1, cue.default_volume ?? 1));
    const source = this.context.createMediaElementSource(media);
    source.connect(this.gains.get(cue.bus));
    return media;
  }

  async oneShot(cueID, requestedVolume) {
    if (!this.ready) return this.setStatus(`Enable audio to play ${cueID}`);
    const cue = this.catalog.get(cueID);
    if (!cue) return this.setStatus(`Unknown cue: ${cueID}`);
    const media = this.mediaFor(cue);
    if (requestedVolume != null) media.volume = Math.max(0, Math.min(1, requestedVolume));
    media.addEventListener('ended', () => media.remove());
    await media.play().catch(() => this.setStatus(`Could not play ${cueID}`));
    this.setStatus(`Playing ${cueID}`);
  }

  async setLoop(bus, action, cueID, requestedVolume, fadeDuration = 0.4) {
    const existing = this.loops.get(bus);
    if (existing) {
      existing.pause();
      this.loops.delete(bus);
    }
    if (action === 'stop') return this.setStatus(`${bus} stopped`);
    if (!this.ready) return this.setStatus(`Enable audio to start ${cueID}`);
    const cue = this.catalog.get(cueID);
    if (!cue || cue.bus !== bus) return this.setStatus(`Invalid ${bus} cue: ${cueID}`);
    const media = this.mediaFor(cue, true);
    if (requestedVolume != null) media.volume = Math.max(0, Math.min(1, requestedVolume));
    this.loops.set(bus, media);
    await media.play().catch(() => this.setStatus(`Could not start ${cueID}`));
    this.setStatus(`${bus}: ${cueID}${fadeDuration ? ` · ${fadeDuration}s transition` : ''}`);
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

  speak(event) {
    const caption = document.getElementById('dialogue-caption');
    if (caption) {
      caption.hidden = false;
      caption.textContent = event.text;
    }
    if (!this.ready || !('speechSynthesis' in window)) return;
    speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(event.text);
    utterance.rate = event.performance?.includes('measured') ? 0.88 : 0.96;
    utterance.volume = this.busLevels.voice;
    this.duck(true);
    utterance.onend = () => {
      this.duck(false);
      if (caption) caption.hidden = true;
    };
    utterance.onerror = () => this.duck(false);
    speechSynthesis.speak(utterance);
    this.setStatus(`Dialogue: ${event.speaker_id}`);
  }

  duck(active) {
    if (!this.context) return;
    const now = this.context.currentTime;
    const time = active ? 0.18 : 0.45;
    this.gains.get('music').gain.setTargetAtTime(this.busLevels.music * (active ? 0.45 : 1), now, time / 3);
    this.gains.get('ambience').gain.setTargetAtTime(this.busLevels.ambience * (active ? 0.65 : 1), now, time / 3);
  }

  stopAll() {
    for (const media of this.loops.values()) media.pause();
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
      case 'ambience': return this.setLoop('ambience', event.action, event.cue, event.volume, event.fade_duration);
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
