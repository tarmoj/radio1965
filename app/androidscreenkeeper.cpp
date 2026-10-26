#include "screenkeeper.h"

#ifdef Q_OS_ANDROID

#include <QJniObject>
#include <QNativeInterface/QAndroidApplication>

namespace {
// android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON - doesn't
// need any manifest permission.
constexpr int FLAG_KEEP_SCREEN_ON = 0x00000080;
}

void ScreenKeeper::setEnabled(bool enabled)
{
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
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
