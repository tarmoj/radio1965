#pragma once

#include <QAbstractListModel>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariantMap>
#include <QVector>

struct EventItem
{
    QString id;
    QString type;
    QString title;
    QString summary;
    QString url;
    QString publishAt;
    QString shelfAt;
    QString status;
    QStringList tags;
    QVariantMap payload;
    bool commentsEnabled = false;
};

// Holds the event feed (project-description.md #4), fed both by
// GET /events (EventsApiClient, on launch/refresh) and by incoming FCM
// push data (the full event is embedded as JSON under data["event"], see
// server/notifications.py:send_event_notification and
// PushMessagingService.java). Nothing is persisted across app restarts -
// EventsApiClient::fetchEvents() re-hydrates on launch instead.
// Exposed to QML as context property "notificationManager"; "New
// Arrivals"/"Collection" are QSortFilterProxyModels over this, set up in
// main.cpp.
class NotificationManager : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TypeRole,
        TitleRole,
        SummaryRole,
        UrlRole,
        PublishAtRole,
        ShelfAtRole,
        StatusRole,
        TagsRole,
        PayloadRole,
        CommentsEnabledRole
    };

    explicit NotificationManager(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Insert-or-update by id. Used for push-delivered events (one at a time).
    Q_INVOKABLE void upsertEvent(const QJsonObject &event);

    // Same as upsertEvent(), but applies a whole batch under a single
    // beginInsertRows/endInsertRows pair. EventsApiClient::fetchEvents()
    // re-hydration otherwise calls upsertEvent() once per event, and firing
    // several synchronous begin/endInsertRows(parent, 0, 0) in a row (all at
    // row 0) confuses ListView's delegate incubation - the proxy models end
    // up with the right rows/data (confirmed via direct data() calls and via
    // Repeater, which isn't affected) but ListView delegates for those rows
    // get created with no `model` context at all.
    Q_INVOKABLE void upsertEvents(const QJsonArray &events);

    // Called from QML/C++ and from the Android JNI / iOS bridges when a
    // push message arrives. `data` is the raw FCM data payload as a JSON
    // string; the full event is nested under its "event" key.
    Q_INVOKABLE void addMessage(const QString &title, const QString &summary, const QString &data);

    // Singleton-style accessor so the Android JNI callback (which runs outside
    // of any QML context) can reach the instance created in main.cpp.
    static NotificationManager *instance();

private:
    int indexOfId(const QString &id) const;

    QVector<EventItem> m_events;
    static NotificationManager *s_instance;
};
