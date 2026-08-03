#pragma once

#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QObject>

// Fetches the event feed from the notification server's GET /events
// (server/main.py) so the app can hydrate "New Arrivals"/"Collection" on
// launch and notice shelving transitions, which FCM push never announces.
// Exposed to QML as context property "eventsApiClient".
class EventsApiClient : public QObject
{
    Q_OBJECT

public:
    explicit EventsApiClient(QObject *parent = nullptr);

    // baseUrl example: "https://live.uuu.ee/radio1965/api" (no trailing slash).
    Q_INVOKABLE void fetchEvents(const QString &baseUrl);

signals:
    // One element per event, each shaped like server/db.py's Event.to_dict().
    void eventsReceived(const QJsonArray &events);
    void fetchFailed(const QString &errorString);

private:
    QNetworkAccessManager m_networkManager;
};
