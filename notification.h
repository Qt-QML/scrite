/****************************************************************************
**
** Copyright (C) Prashanth Udupa, Bengaluru
** Email: prashanth.udupa@gmail.com
**
** This code is distributed under GPL v3. Complete text of the license
** can be found here: https://www.gnu.org/licenses/gpl-3.0.txt
**
** This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
** WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
**
****************************************************************************/

#ifndef NOTIFICATION_H
#define NOTIFICATION_H

#include <QObject>
#include <QColor>
#include <QQmlEngine>
#include <QBasicTimer>

class Notification : public QObject
{
    Q_OBJECT

public:
    Notification(QObject *parent=nullptr);
    ~Notification();

    static Notification *qmlAttachedProperties(QObject *object);

    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged)
    void setTitle(const QString &val);
    QString title() const { return m_title; }
    Q_SIGNAL void titleChanged();

    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)
    void setText(const QString &val);
    QString text() const { return m_text; }
    Q_SIGNAL void textChanged();

    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    void setColor(const QColor &val);
    QColor color() const { return m_color; }
    Q_SIGNAL void colorChanged();

    Q_PROPERTY(QColor textColor READ textColor WRITE setTextColor NOTIFY textColorChanged)
    void setTextColor(const QColor &val);
    QColor textColor() const { return m_textColor; }
    Q_SIGNAL void textColorChanged();

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    void setActive(bool val);
    bool active() const { return m_active; }
    Q_SIGNAL void activeChanged();

    Q_PROPERTY(bool autoClose READ autoClose WRITE setAutoClose NOTIFY autoCloseChanged)
    void setAutoClose(bool val);
    bool autoClose() const { return m_autoClose; }
    Q_SIGNAL void autoCloseChanged();

    Q_PROPERTY(int autoCloseDelay READ autoCloseDelay WRITE setAutoCloseDelay NOTIFY autoCloseDelayChanged)
    void setAutoCloseDelay(int val);
    int autoCloseDelay() const { return m_autoCloseDelay; }
    Q_SIGNAL void autoCloseDelayChanged();

    Q_PROPERTY(QStringList buttons READ buttons WRITE setButtons NOTIFY buttonsChanged)
    void setButtons(const QStringList &val);
    QStringList buttons() const { return m_buttons; }
    Q_SIGNAL void buttonsChanged();

    Q_INVOKABLE void notifyButtonClick(int index);

signals:
    void dismissed();
    void buttonClicked(int index);

private:
    void doAutoClose();
    void timerEvent(QTimerEvent *te);

private:
    QString m_title;
    QString m_text;
    QColor m_color;
    QColor m_textColor;
    bool m_active;
    bool m_autoClose;
    int m_autoCloseDelay;
    QBasicTimer m_autoCloseTimer;
    QStringList m_buttons;
};
Q_DECLARE_METATYPE(Notification*)
QML_DECLARE_TYPEINFO(Notification, QML_HAS_ATTACHED_PROPERTIES)

#endif // NOTIFICATION_H
