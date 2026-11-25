#pragma once

#include <QObject>

// Android's "screen pinning" (Activity.startLockTask()/stopLockTask()) -
// the only way a regular (non-device-owner) app can actually disable the
// system navigation bar's Home/Recent-apps buttons, which otherwise stay
// live even while Main.qml's lockOverlay ("pocket lock") is covering the
// screen - a stray tap in a pocket could background the app or open the
// app switcher despite the QML overlay. No-op on other platforms (no
// equivalent app-triggerable API - iOS's Guided Access is user-enabled
// only). Exposed as a context property ("screenPinner"), same wiring as
// screenKeeper - see androidscreenpinner.cpp/screenpinner_noop.cpp for the
// per-platform implementations, exactly one compiled in (app/CMakeLists.txt).
class ScreenPinner : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE void setEnabled(bool enabled);
};
