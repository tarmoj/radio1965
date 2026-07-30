#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#ifdef RADIO65_ENABLE_NOTIFICATIONS
#include "notificationmanager.h"
#endif

#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

#ifdef RADIO65_ENABLE_NOTIFICATIONS
    NotificationManager notificationManager;
#endif

#ifdef Q_OS_ANDROID
    QJniObject::callStaticMethod<void>(
        "org/eccm/radio65/PushMessagingService", "subscribeToTopic",
        "(Ljava/lang/String;)V",
        QJniObject::fromString("radio65_event").object<jstring>());
#endif

    QQmlApplicationEngine engine;
#ifdef RADIO65_ENABLE_NOTIFICATIONS
    engine.rootContext()->setContextProperty("notificationManager", &notificationManager);
#endif
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("radio65", "Main");

    return app.exec();
}
