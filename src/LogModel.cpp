/*
 * Copyright (C) 2014 Red Hat
 *
 * This file is part of Ocelot.
 *
 * Ocelot is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "LogModel.h"

#include <QDateTime>

// Keep in sync with the limit used by the Logger itself.
#define MAX_MESSAGES 20000

static QString component_name(const Logger::ComponentType& type)
{
    switch (type) {
    case Logger::ComponentType::OCONNECT:
        return QStringLiteral("openconnect");
    case Logger::ComponentType::GNUTLS:
        return QStringLiteral("gnutls");
    case Logger::ComponentType::VPNC:
        return QStringLiteral("vpnc-script");
    case Logger::ComponentType::GUI:
        return QStringLiteral("gui");
    default:
        return QString();
    }
}

LogModel::LogModel(QObject* parent)
    : QAbstractListModel(parent)
    , m_messages(Logger::instance().getMessages())
{
    connect(&Logger::instance(), &Logger::newLogMessage,
        this, &LogModel::append, Qt::QueuedConnection);
}

int LogModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid()) {
        return 0;
    }
    return m_messages.size();
}

QVariant LogModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= m_messages.size()) {
        return QVariant();
    }

    const Logger::Message& message = m_messages.at(index.row());

    switch (role) {
    case TimeRole:
        return QDateTime::fromMSecsSinceEpoch(message.timeStamp).toString(QStringLiteral("hh:mm:ss"));
    case TextRole:
    case Qt::DisplayRole:
        return message.text;
    case ComponentRole:
        return component_name(message.componentType);
    }

    return QVariant();
}

QHash<int, QByteArray> LogModel::roleNames() const
{
    return {
        { TimeRole, "time" },
        { TextRole, "text" },
        { ComponentRole, "component" }
    };
}

void LogModel::clear()
{
    beginResetModel();
    m_messages.clear();
    Logger::instance().clear();
    endResetModel();
}

QString LogModel::text() const
{
    QString text;
    for (const auto& message : m_messages) {
        text += QDateTime::fromMSecsSinceEpoch(message.timeStamp).toString(QStringLiteral("yyyy-MM-dd hh:mm:ss"))
            + QLatin1String(" | ") + message.text + QLatin1Char('\n');
    }
    return text;
}

void LogModel::append(const Logger::Message& message)
{
    if (m_messages.size() >= MAX_MESSAGES) {
        beginRemoveRows(QModelIndex(), 0, 0);
        m_messages.pop_front();
        endRemoveRows();
    }

    beginInsertRows(QModelIndex(), m_messages.size(), m_messages.size());
    m_messages.push_back(message);
    endInsertRows();
}
