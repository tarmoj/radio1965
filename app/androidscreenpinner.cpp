#include "screenpinner.h"

#ifdef Q_OS_ANDROID

#include <QJniObject>
#include <QtCore/qcoreapplication_platform.h>

void ScreenPinner::setEnabled(bool enabled)
{
    // Same threading requirement/reasoning as androidscreenkeeper.cpp's
    // setEnabled() - startLockTask()/stopLockTask() are Activity calls,
    // which must happen on Android's UI thread, not Qt's own thread that
    // this is invoked from (Main.qml's lockOverlay.onOpened/onClosed).
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([enabled]() {
        QJniObject activity = QJniObject::callStaticObjectMethod(
            "org/qtproject/qt/android/QtNative", "activity", "()Landroid/app/Activity;");
        if (!activity.isValid())
            return;
        // startLockTask()/stopLockTask() (API 21+) pin the current task:
        // the system navigation bar's Home/Recent-apps buttons stop
        // responding (and show a brief "press & hold Back + Recents to
        // unpin" hint) for as long as the app is pinned - exactly what's
        // needed while lockOverlay covers the screen, since a stray tap in
        // a pocket could otherwise background the app or open the app
        // switcher despite the QML overlay. No special permission or
        // device-owner/MDM setup needed - any app may pin itself.
        if (enabled)
            activity.callMethod<void>("startLockTask", "()V");
        else
            activity.callMethod<void>("stopLockTask", "()V");
    });
}

#endif // Q_OS_ANDROID
