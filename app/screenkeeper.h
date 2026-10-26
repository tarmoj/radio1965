#pragma once

#include <QObject>

// Toggles the OS-level "keep display on" flag while media is actively
// playing (Android's FLAG_KEEP_SCREEN_ON / iOS's idleTimerDisabled) - a
// no-op on other platforms. Exposed as a context property ("screenKeeper")
// so PlaybackController.qml can call it directly from its MediaPlayer's
// onPlaybackStateChanged, same as notificationManager/icecastBroadcaster are
// already referenced there. See androidscreenkeeper.cpp/iosscreenkeeper.mm/
// screenkeeper_noop.cpp for the per-platform implementations - exactly one
// is compiled in, selected in app/CMakeLists.txt.
class ScreenKeeper : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE void setEnabled(bool enabled);
};
