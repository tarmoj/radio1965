#include "eventsapiclient.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

EventsApiClient::EventsApiClient(QObject *parent)
    : QObject(parent)
{
}

void EventsApiClient::fetchEvents(const QString &baseUrl)
{
    QNetworkRequest request(QUrl(baseUrl + "/events"));
    QNetworkReply *reply = m_networkManager.get(request);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            emit fetchFailed(reply->errorString());
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonArray events = doc.object().value("events").toArray();
        emit eventsReceived(events);
    });
}
