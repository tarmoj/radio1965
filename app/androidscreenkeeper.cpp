#include "screenkeeper.h"

#ifdef Q_OS_ANDROID

#include <QCoreApplication>
#include <QJniObject>
#include <QtCore/qcoreapplication_platform.h>

namespace {
// android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON - doesn't
// need any manifest permission.
constexpr int FLAG_KEEP_SCREEN_ON = 0x00000080;
}

void ScreenKeeper::setEnabled(bool enabled)
{
    // PlaybackController.qml calls this straight from the MediaPlayer's
    // onPlaybackStateChanged, which fires on Qt's own thread - not
    // Android's UI thread (Qt for Android runs its event loop on a
    // separate native thread from the one that created the Activity's
    // view hierarchy). Calling Window.addFlags/clearFlags directly from
    // here therefore threw a caught-and-logged
    // android.view.ViewRootImpl$CalledFromWrongThreadException on every
    // playback state change, which left the Activity's window in a
    // half-updated layout state - observed as content pushed onto
    // Main.qml's StackView afterwards (e.g. WebViewPage) failing to
    // render even though the QML-level StackView.currentItem was
    // correct. runOnAndroidMainThread() marshals the JNI calls onto the
    // actual Android UI thread, same as the Activity itself expects.
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([enabled]() {
        // QNativeInterface::QAndroidApplication::context() would be the
        // "proper" Qt 6 way to get the Activity, but its header isn't
        // reliably found across Qt 6.9's packaging - QtNative.activity()
        // is the same Activity instance, reached directly via the Java
        // side Qt itself installs on every Android build
        // (org.qtproject.qt.android.QtNative), same approach as
        // main.cpp's existing QJniObject::callStaticMethod use for
        // PushMessagingService.
        QJniObject activity = QJniObject::callStaticObjectMethod(
            "org/qtproject/qt/android/QtNative", "activity", "()Landroid/app/Activity;");
        if (!activity.isValid())
            return;
        QJniObject window = activity.callObjectMethod("getWindow", "()Landroid/view/Window;");
        if (!window.isValid())
            return;
        if (enabled)
            window.callMethod<void>("addFlags", "(I)V", FLAG_KEEP_SCREEN_ON);
        else
            window.callMethod<void>("clearFlags", "(I)V", FLAG_KEEP_SCREEN_ON);
    });
}

#endif // Q_OS_ANDROID
