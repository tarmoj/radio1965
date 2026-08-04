#include "notificationmanager.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>

NotificationManager *NotificationManager::s_instance = nullptr;

namespace {

EventItem eventItemFromJson(const QJsonObject &event)
{
    EventItem item;
    item.id = event.value("id").toString();
    item.type = event.value("type").toString();
    item.title = event.value("title").toString();
    item.summary = event.value("summary").toString();
    item.url = event.value("url").toString();
    item.publishAt = event.value("publish_at").toString();
    item.shelfAt = event.value("shelf_at").toString();
    item.status = event.value("status").toString();
    item.commentsEnabled = event.value("comments_enabled").toBool();

    for (const QJsonValue &tag : event.value("tags").toArray())
        item.tags.append(tag.toString());

    item.payload = event.value("payload").toObject().toVariantMap();

    return item;
}

} // namespace

NotificationManager::NotificationManager(QObject *parent)
    : QAbstractListModel(parent)
{
    s_instance = this;
}

NotificationManager *NotificationManager::instance()
{
    return s_instance;
}

int NotificationManager::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_events.size();
}

QVariant NotificationManager::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_events.size())
        return {};

    const EventItem &event = m_events.at(index.row());
    switch (role) {
    case IdRole:
        return event.id;
    case TypeRole:
        return event.type;
    case TitleRole:
        return event.title;
    case SummaryRole:
        return event.summary;
    case UrlRole:
        return event.url;
    case PublishAtRole:
        return event.publishAt;
    case ShelfAtRole:
        return event.shelfAt;
    case StatusRole:
        return event.status;
    case TagsRole:
        return event.tags;
    case PayloadRole:
        return event.payload;
    case CommentsEnabledRole:
        return event.commentsEnabled;
    default:
        return {};
    }
}

QHash<int, QByteArray> NotificationManager::roleNames() const
{
    // Role names match EventDelegate's required property names exactly
    // (eventId/eventType, not id/type - "id" is a reserved QML property
    // name) so QQmlDelegateModel auto-populates the delegate's required
    // properties directly from role data at construction time, instead of
    // going through an explicit `model.xxx` binding. That binding style is
    // what caused ListView delegates to intermittently see `model` as
    // undefined when several rows were inserted in one batch.
    return {
        { IdRole, "eventId" },
        { TypeRole, "eventType" },
        { TitleRole, "title" },
        { SummaryRole, "summary" },
        { UrlRole, "url" },
        { PublishAtRole, "publishAt" },
        { ShelfAtRole, "shelfAt" },
        { StatusRole, "status" },
        { TagsRole, "tags" },
        { PayloadRole, "payload" },
        { CommentsEnabledRole, "commentsEnabled" }
    };
}

int NotificationManager::indexOfId(const QString &id) const
{
    for (int i = 0; i < m_events.size(); ++i) {
        if (m_events.at(i).id == id)
            return i;
    }
    return -1;
}

void NotificationManager::upsertEvent(const QJsonObject &event)
{
    const EventItem item = eventItemFromJson(event);
    if (item.id.isEmpty())
        return;

    const int existingRow = indexOfId(item.id);
    if (existingRow >= 0) {
        m_events[existingRow] = item;
        const QModelIndex changed = index(existingRow);
        emit dataChanged(changed, changed);
        return;
    }

    beginInsertRows(QModelIndex(), 0, 0);
    m_events.prepend(item);
    endInsertRows();
}

void NotificationManager::upsertEvents(const QJsonArray &events)
{
    QVector<EventItem> newItems;

    for (const QJsonValue &value : events) {
        const EventItem item = eventItemFromJson(value.toObject());
        if (item.id.isEmpty())
            continue;

        const int existingRow = indexOfId(item.id);
        if (existingRow >= 0) {
            m_events[existingRow] = item;
            const QModelIndex changed = index(existingRow);
            emit dataChanged(changed, changed);
        } else {
            newItems.append(item);
        }
    }

    if (newItems.isEmpty())
        return;

    beginInsertRows(QModelIndex(), 0, newItems.size() - 1);
    for (const EventItem &item : newItems)
        m_events.prepend(item);
    endInsertRows();
}

void NotificationManager::addMessage(const QString &title, const QString &summary, const QString &data)
{
    const QJsonObject fcmData = QJsonDocument::fromJson(data.toUtf8()).object();
    const QString eventJson = fcmData.value("event").toString();

    if (!eventJson.isEmpty()) {
        const QJsonObject event = QJsonDocument::fromJson(eventJson.toUtf8()).object();
        if (!event.isEmpty()) {
            upsertEvent(event);
            return;
        }
    }

    // Fallback: malformed/unexpected push payload - still surface something
    // rather than silently dropping the notification.
    QJsonObject fallback;
    fallback["id"] = fcmData.value("event_id").toString(
        QStringLiteral("push_%1").arg(QDateTime::currentMSecsSinceEpoch()));
    fallback["type"] = fcmData.value("type").toString("text");
    fallback["title"] = title;
    fallback["summary"] = summary;
    fallback["status"] = "new";
    upsertEvent(fallback);
}
