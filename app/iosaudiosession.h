#pragma once

// Forces AVAudioSession to .playback (speaker-safe route) - used at startup
// and whenever the mic is released after broadcasting.
void iosAudioSessionActivatePlayback();

// Forces AVAudioSession to .playAndRecord with defaultToSpeaker - used right
// before the mic is opened for broadcasting, since .playAndRecord otherwise
// defaults to the quiet earpiece receiver instead of the loudspeaker.
void iosAudioSessionActivateRecording();
