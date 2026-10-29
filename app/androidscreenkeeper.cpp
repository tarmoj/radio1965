#include "screenkeeper.h"

#ifdef Q_OS_ANDROID

#include <QJniObject>

namespace {
// android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON - doesn't
// need any manifest permission.
constexpr int FLAG_KEEP_SCREEN_ON = 0x00000080;
}

void ScreenKeeper::setEnabled(bool enabled)
{
    // QNativeInterface::QAndroidApplication::context() would be the
    // "proper" Qt 6 way to get the Activity, but its header isn't reliably
    // found across Qt 6.9's packaging - QtNative.activity() is the same
    // Activity instance, reached directly via the Java side Qt itself
    // installs on every Android build (org.qtproject.qt.android.QtNative),
    // same approach as main.cpp's existing QJniObject::callStaticMethod use
    // for PushMessagingService.
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
}

#endif // Q_OS_ANDROID
