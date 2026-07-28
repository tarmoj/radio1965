#ifdef Q_OS_ANDROID

#include <QJniObject>
#include <QMetaObject>
#include <jni.h>

#include "notificationmanager.h"

extern "C" JNIEXPORT void JNICALL
Java_org_eccm_radio65_PushMessagingService_nativeOnMessageReceived(
    JNIEnv *env, jclass /*clazz*/, jstring title, jstring body, jstring data)
{
    Q_UNUSED(env)

    const QString qTitle = QJniObject(title).toString();
    const QString qBody = QJniObject(body).toString();
    const QString qData = QJniObject(data).toString();

    if (NotificationManager *manager = NotificationManager::instance()) {
        QMetaObject::invokeMethod(manager, "addMessage", Qt::QueuedConnection,
                                   Q_ARG(QString, qTitle),
                                   Q_ARG(QString, qBody),
                                   Q_ARG(QString, qData));
    }
}

#endif // Q_OS_ANDROID
