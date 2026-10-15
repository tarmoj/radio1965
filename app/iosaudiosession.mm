#include "qglobal.h"
#include "iosaudiosession.h"

#ifdef Q_OS_IOS

#import <AVFoundation/AVFoundation.h>
#include <QDebug>

void iosAudioSessionActivatePlayback()
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    // Mode is reset explicitly: setCategory: alone leaves whatever mode
    // iosAudioSessionActivateRecording() set (.measurement) in place, which
    // left playback silent after a broadcast ended.
    [session setCategory:AVAudioSessionCategoryPlayback
                    mode:AVAudioSessionModeDefault
                 options:0
                   error:&error];
    if (error) {
        qWarning() << "[iosaudiosession] setCategory(.playback) failed:"
                    << error.localizedDescription.UTF8String;
        return;
    }
    [session setActive:YES error:&error];
    if (error) {
        qWarning() << "[iosaudiosession] setActive (.playback) failed:"
                    << error.localizedDescription.UTF8String;
    }
}

double iosAudioSessionActivateRecording()
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    // No defaultToSpeaker: nothing plays audio back while broadcasting
    // (see BroadcastPage.qml), so forcing the loudspeaker on at the same
    // time as the mic serves no purpose here - it's a textbook acoustic-
    // feedback setup, and the most likely cause of gate/limiter-like
    // crackling reported on iPhone broadcasts.
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
              withOptions:AVAudioSessionCategoryOptionAllowBluetooth |
                          AVAudioSessionCategoryOptionAllowBluetoothA2DP
                    error:&error];
    if (error) {
        qWarning() << "[iosaudiosession] setCategory(.playAndRecord) failed:"
                    << error.localizedDescription.UTF8String;
        return 0;
    }
    // .measurement minimizes iOS's own AGC/noise-suppression/echo-
    // cancellation on the input signal - broadcasting wants the raw mic
    // signal, not voice-call-optimized processing.
    [session setMode:AVAudioSessionModeMeasurement error:&error];
    if (error) {
        qWarning() << "[iosaudiosession] setMode(.measurement) failed:"
                    << error.localizedDescription.UTF8String;
        error = nil;
    }
    [session setActive:YES error:&error];
    if (error) {
        qWarning() << "[iosaudiosession] setActive (.playAndRecord) failed:"
                    << error.localizedDescription.UTF8String;
    }
    qInfo() << "[iosaudiosession] recording session sample rate:" << session.sampleRate;
    return session.sampleRate;
}

#endif // Q_OS_IOS
