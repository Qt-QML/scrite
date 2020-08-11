/****************************************************************************
**
** Copyright (C) TERIFLIX Entertainment Spaces Pvt. Ltd. Bengaluru
** Author: Prashanth N Udupa (prashanth.udupa@teriflix.com)
**
** This code is distributed under GPL v3. Complete text of the license
** can be found here: https://www.gnu.org/licenses/gpl-3.0.txt
**
** This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
** WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
**
****************************************************************************/

#include "execlatertimer.h"
#include "application.h"

#include <QList>
#include <QThread>

#ifndef QT_NO_DEBUG
Q_GLOBAL_STATIC(QList<ExecLaterTimer*>, ExecLaterTimerList)
#endif

ExecLaterTimer *ExecLaterTimer::get(int timerId)
{
#ifndef QT_NO_DEBUG
    Q_FOREACH(ExecLaterTimer *timer, *ExecLaterTimerList)
    {
        if(timer->timerId() == timerId)
            return timer;
    }
#else
    Q_UNUSED(timerId)
#endif

    return nullptr;
}

ExecLaterTimer::ExecLaterTimer(const QString &name, QObject *parent)
    : QObject(parent), m_name(name)
{
#ifndef QT_NO_DEBUG
    ExecLaterTimerList->append(this);
#endif

    m_timer.setObjectName("SimpleTimer");
    m_timer.setSingleShot(!m_repeat);
    connect(&m_timer, &QTimer::timeout, this, &ExecLaterTimer::onTimeout);
}

ExecLaterTimer::~ExecLaterTimer()
{
    m_destroyed = true;
    this->stop();

#ifndef QT_NO_DEBUG
    ExecLaterTimerList->removeOne(this);
#endif
}

void ExecLaterTimer::setName(const QString &val)
{
    if(m_name == val)
        return;

    m_name = val;
    emit nameChanged();
}

void ExecLaterTimer::setRepeat(bool val)
{
    if(m_repeat == val)
        return;

    m_repeat = val;
    m_timer.setSingleShot(!m_repeat);
    emit repeatChanged();
}

void ExecLaterTimer::start(int msec, QObject *object)
{
    if(m_timer.isActive())
        this->stop();

    if(object == nullptr || m_destroyed)
        return;

    if(object != m_object)
    {
        if(object)
            disconnect(object, &QObject::destroyed, this, &ExecLaterTimer::onObjectDestroyed);

        m_object = object;

        if(m_object)
            connect(object, &QObject::destroyed, this, &ExecLaterTimer::onObjectDestroyed);
    }

    if(this->thread() != nullptr && this->thread()->eventDispatcher() != nullptr)
    {
        m_timer.start(msec);
        m_timerId = m_timer.timerId();
    }
    else
        m_timerId = -1;
}

void ExecLaterTimer::stop()
{
    m_timer.stop();
    m_timerId = -1;
}

void ExecLaterTimer::onTimeout()
{
    if(m_object != nullptr && m_timerId >= 0)
    {
#ifndef QT_NO_DEBUG
        qDebug() << "Posting Timer " << m_timerId << " to " << m_object;
#endif
        qApp->postEvent(m_object, new QTimerEvent(m_timerId));
    }
}

void ExecLaterTimer::onObjectDestroyed(QObject *ptr)
{
    if(m_object == ptr)
    {
        m_object = nullptr;
        this->stop();
    }
}
