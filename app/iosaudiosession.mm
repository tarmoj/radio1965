#include "qglobal.h"
#include "iosaudiosession.h"

#ifdef Q_OS_IOS

#import <AVFoundation/AVFoundation.h>
#include <QDebug>

void iosAudioSessionActivatePlayback()
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [session setCategory:AVAudioSessionCategoryPlayback error:&error];
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

void iosAudioSessionActivateRecording()
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
              withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker |
                          AVAudioSessionCategoryOptionAllowBluetooth |
                          AVAudioSessionCategoryOptionAllowBluetoothA2DP
                    error:&error];
    if (error) {
        qWarning() << "[iosaudiosession] setCategory(.playAndRecord) failed:"
                    << error.localizedDescription.UTF8String;
        return;
    }
    [session setActive:YES error:&error];
    if (error) {
        qWarning() << "[iosaudiosession] setActive (.playAndRecord) failed:"
                    << error.localizedDescription.UTF8String;
    }
}

#endif // Q_OS_IOS
