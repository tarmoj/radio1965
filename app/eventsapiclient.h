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

    // Fetches one Joomla article's rendered HTML via the server's
    // GET /articles/{id} proxy (server/main.py) - the app never talks to
    // Joomla directly, so it never needs the Joomla API token.
    Q_INVOKABLE void fetchArticle(const QString &baseUrl, int articleId);

    // Posts to POST /events/{eventId}/report (server/main.py) - the app's
    // "Report"/"Block author" actions (App Store 1.2 UGC compliance).
    // reason is e.g. "objectionable"/"abusive"/"blocked"/"other"; details
    // is optional free text. Blocking's own "remove from feed" effect
    // happens entirely client-side (NotificationManager::blockAuthor) -
    // this call is purely the developer-notification side of it.
    Q_INVOKABLE void reportEvent(const QString &baseUrl, const QString &eventId, const QString &reason,
                                  const QString &details);

signals:
    // One element per event, each shaped like server/db.py's Event.to_dict().
    void eventsReceived(const QJsonArray &events);
    void fetchFailed(const QString &errorString);

    // html is a full, ready-to-render document (server-wrapped); baseUrl is
    // the site root to resolve relative asset paths in that html against -
    // pass both straight to WebView.loadHtml(html, baseUrl).
    void articleReceived(int articleId, const QString &title, const QString &html, const QString &baseUrl);
    void articleFetchFailed(int articleId, const QString &errorString);

    void reportSubmitted(const QString &eventId);
    void reportFailed(const QString &eventId, const QString &errorString);

private:
    QNetworkAccessManager m_networkManager;
};
