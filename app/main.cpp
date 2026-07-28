#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "notificationmanager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    NotificationManager notificationManager;

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
