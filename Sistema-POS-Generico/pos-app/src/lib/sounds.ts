const audioCtx = new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)();

export function playBeep(frequency = 800, duration = 80, type: OscillatorType = 'square') {
  try {
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.type = type;
    osc.frequency.setValueAtTime(frequency, audioCtx.currentTime);
    gain.gain.setValueAtTime(0.1, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration / 1000);
    osc.start(audioCtx.currentTime);
    osc.stop(audioCtx.currentTime + duration / 1000);
  } catch {
    // Audio not supported
  }
}

export function playAddSound() {
  playBeep(1200, 60, 'sine');
}

export function playRemoveSound() {
  playBeep(300, 100, 'triangle');
}

export function playCheckoutSound() {
  playBeep(600, 100, 'square');
  setTimeout(() => playBeep(900, 150, 'square'), 100);
}
