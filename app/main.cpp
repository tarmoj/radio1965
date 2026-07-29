#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "notificationmanager.h"

#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    NotificationManager notificationManager;

#ifdef Q_OS_ANDROID
    QJniObject::callStaticMethod<void>(
        "org/eccm/radio65/PushMessagingService", "subscribeToTopic",
        "(Ljava/lang/String;)V",
        QJniObject::fromString("radio65_event").object<jstring>());
#endif

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("notificationManager", &notificationManager);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("radio65", "Main");

    return app.exec();
}
