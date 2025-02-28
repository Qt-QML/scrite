/****************************************************************************
**
** Copyright (C) VCreate Logic Pvt. Ltd. Bengaluru
** Author: Prashanth N Udupa (prashanth@scrite.io)
**
** This code is distributed under GPL v3. Complete text of the license
** can be found here: https://www.gnu.org/licenses/gpl-3.0.txt
**
** This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
** WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
**
****************************************************************************/

#ifndef FILEINFO_H
#define FILEINFO_H

#include <QObject>
#include <QFileInfo>
#include <QQuickImageProvider>
#include <QAbstractListModel>

class FileInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit FileInfo(QObject *parent = nullptr);
    ~FileInfo();

    Q_PROPERTY(QString absoluteFilePath READ absoluteFilePath WRITE setAbsoluteFilePath NOTIFY fileInfoChanged)
    void setAbsoluteFilePath(const QString &val);
    QString absoluteFilePath() const { return m_fileInfo.absoluteFilePath(); }

    Q_PROPERTY(QString absolutePath READ absolutePath WRITE setAbsolutePath NOTIFY fileInfoChanged)
    void setAbsolutePath(const QString &val);
    QString absolutePath() const { return m_fileInfo.absolutePath(); }

    Q_PROPERTY(QString fileName READ fileName WRITE setFileName NOTIFY fileInfoChanged)
    void setFileName(const QString &val);
    QString fileName() const { return m_fileInfo.fileName(); }

    Q_PROPERTY(QString suffix READ suffix WRITE setSuffix NOTIFY fileInfoChanged)
    void setSuffix(const QString &val);
    QString suffix() const { return m_fileInfo.suffix(); }

    Q_PROPERTY(QString baseName READ baseName WRITE setBaseName NOTIFY fileInfoChanged)
    void setBaseName(const QString &val);
    QString baseName() const { return m_fileInfo.completeBaseName(); }

    QFileInfo fileInfo() const { return m_fileInfo; }
    Q_SIGNAL void fileInfoChanged();

private:
    void setFileInfo(const QFileInfo &val);

private:
    QFileInfo m_fileInfo;
};

class FileIconProvider : public QQuickImageProvider
{
public:
    explicit FileIconProvider();
    ~FileIconProvider();

    // QQuickImageProvider interface
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize);

private:
    QImage requestImage(const QFileInfo &fi);

private:
    QMap<QString, QImage> m_suffixImageMap;
};

class RecentFileListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

public:
    RecentFileListModel(QObject *parent = nullptr);
    ~RecentFileListModel();

    Q_PROPERTY(int count READ count NOTIFY filesChanged)
    int count() const { return m_files.size(); }

    Q_PROPERTY(int maxCount READ maxCount WRITE setMaxCount NOTIFY maxCountChanged)
    void setMaxCount(int val);
    int maxCount() const { return m_maxCount; }
    Q_SIGNAL void maxCountChanged();

    Q_PROPERTY(QStringList files READ files WRITE setFiles NOTIFY filesChanged)
    void setFiles(const QStringList &val);
    QStringList files() const;
    Q_SIGNAL void filesChanged();

    Q_INVOKABLE void add(const QString &filePath);

    // QAbstractItemModel interface
    enum Roles { FileNameRole = Qt::DisplayRole, FilePathRole, FileBaseNameRole };
    int rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : m_files.size(); }
    QVariant data(const QModelIndex &index, int role) const;
    QHash<int, QByteArray> roleNames() const;

private:
    int m_maxCount = 10;
    QFileInfoList m_files;
};

#endif // FILEINFO_H
