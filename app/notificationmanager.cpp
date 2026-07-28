#include "notificationmanager.h"

NotificationManager *NotificationManager::s_instance = nullptr;

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
    return m_messages.size();
}

QVariant NotificationManager::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_messages.size())
        return {};

    const PushMessage &msg = m_messages.at(index.row());
    switch (role) {
    case TitleRole:
        return msg.title;
    case SummaryRole:
        return msg.summary;
    case PayloadRole:
        return msg.payload;
    default:
        return {};
    }
}

QHash<int, QByteArray> NotificationManager::roleNames() const
{
    return {
        { TitleRole, "title" },
        { SummaryRole, "summary" },
        { PayloadRole, "payload" }
    };
}

void NotificationManager::addMessage(const QString &title, const QString &summary, const QString &payload)
{
    beginInsertRows(QModelIndex(), 0, 0);
    m_messages.prepend({ title, summary, payload });
    endInsertRows();
}
