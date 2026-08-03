#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSortFilterProxyModel>

#include "eventsapiclient.h"

#ifdef RADIO65_ENABLE_NOTIFICATIONS
#include "notificationmanager.h"
#endif

#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

#ifdef Q_OS_IOS
#include "iospush.h"
#endif

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    EventsApiClient eventsApiClient;

#ifdef RADIO65_ENABLE_NOTIFICATIONS
    NotificationManager notificationManager;

    QObject::connect(&eventsApiClient, &EventsApiClient::eventsReceived,
                      &notificationManager, [&notificationManager](const QJsonArray &events) {
                          for (const QJsonValue &event : events)
                              notificationManager.upsertEvent(event.toObject());
                      });

    // "New Arrivals" (status=new) and "Collection" (status=shelved) -
    // project-description.md #2.1. Shelving happens silently via
    // server/cron_publish.py (no push), so these only pick it up once
    // EventsApiClient::fetchEvents() re-hydrates the source model.
    QSortFilterProxyModel newEventsModel;
    newEventsModel.setSourceModel(&notificationManager);
    newEventsModel.setFilterRole(NotificationManager::StatusRole);
    newEventsModel.setFilterFixedString("new");

    QSortFilterProxyModel shelfEventsModel;
    shelfEventsModel.setSourceModel(&notificationManager);
    shelfEventsModel.setFilterRole(NotificationManager::StatusRole);
    shelfEventsModel.setFilterFixedString("shelved");
#endif

#ifdef Q_OS_ANDROID
    QJniObject::callStaticMethod<void>(
        "org/eccm/radio65/PushMessagingService", "subscribeToTopic",
        "(Ljava/lang/String;)V",
        QJniObject::fromString("radio65_event").object<jstring>());
#endif

#ifdef Q_OS_IOS
    iosPushInit();
    iosPushSubscribeToTopic("radio65_event");
#endif

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("eventsApiClient", &eventsApiClient);
#ifdef RADIO65_ENABLE_NOTIFICATIONS
    engine.rootContext()->setContextProperty("notificationManager", &notificationManager);
    engine.rootContext()->setContextProperty("newEventsModel", &newEventsModel);
    engine.rootContext()->setContextProperty("shelfEventsModel", &shelfEventsModel);
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
