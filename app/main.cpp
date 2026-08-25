#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSortFilterProxyModel>

#include "eventsapiclient.h"

#ifdef RADIO65_ENABLE_NOTIFICATIONS
#include "notificationmanager.h"
#endif

#ifdef RADIO65_ENABLE_BROADCAST
#include "icecastbroadcaster.h"
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

    app.setOrganizationName("Tarmo Johannes Events and Software");
    app.setOrganizationDomain("eccm.org");
    app.setApplicationName("VÄIN");

    EventsApiClient eventsApiClient;

#ifdef RADIO65_ENABLE_NOTIFICATIONS
    NotificationManager notificationManager;

    QObject::connect(&eventsApiClient, &EventsApiClient::eventsReceived,
                      &notificationManager, [&notificationManager](const QJsonArray &events) {
                          notificationManager.upsertEvents(events);
                      });

    // "New Arrivals" (status=new) - project-description.md #2.1. Shelving
    // happens silently via server/cron_publish.py (no push), so this only
    // picks it up once EventsApiClient::fetchEvents() re-hydrates the
    // source model. "Collection" (status=shelved) no longer needs its own
    // proxy model here - CollectionPage.qml reads the shelved subset
    // directly via NotificationManager::shelvedEvents() instead, since it
    // groups/sorts the set in QML JS rather than rendering it through a
    // flat ListView.
    QSortFilterProxyModel newEventsModel;
    newEventsModel.setSourceModel(&notificationManager);
    newEventsModel.setFilterRole(NotificationManager::StatusRole);
    newEventsModel.setFilterFixedString("new");
#endif

#ifdef RADIO65_ENABLE_BROADCAST
    IcecastBroadcaster icecastBroadcaster;
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
#endif
#ifdef RADIO65_ENABLE_BROADCAST
    engine.rootContext()->setContextProperty("icecastBroadcaster", &icecastBroadcaster);
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
