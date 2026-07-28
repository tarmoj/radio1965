#pragma once

#include <QAbstractListModel>
#include <QVector>

struct PushMessage
{
    QString title;
    QString summary;
    QString payload;
};

// Holds push notifications received while the app is running (in-memory only,
// nothing is persisted). Exposed to QML as a context property "notificationManager".
class NotificationManager : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        TitleRole = Qt::UserRole + 1,
        SummaryRole,
        PayloadRole
    };

    explicit NotificationManager(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Called from QML/C++ and from the Android JNI bridge when a push message arrives.
    Q_INVOKABLE void addMessage(const QString &title, const QString &summary, const QString &payload);

    // Singleton-style accessor so the Android JNI callback (which runs outside
    // of any QML context) can reach the instance created in main.cpp.
    static NotificationManager *instance();

private:
    QVector<PushMessage> m_messages;
    static NotificationManager *s_instance;
};
