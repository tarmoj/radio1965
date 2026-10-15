#pragma once

// Forces AVAudioSession to .playback (speaker-safe route) - used at startup
// and whenever the mic is released after broadcasting.
void iosAudioSessionActivatePlayback();

// Switches AVAudioSession to .playAndRecord (.measurement mode) - used right
// before the mic is opened for broadcasting. Returns the session's actual
// hardware sample rate (0 on failure), which the mic should be opened at.
double iosAudioSessionActivateRecording();
