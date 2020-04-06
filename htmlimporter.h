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

#ifndef HTMLIMPORTER_H
#define HTMLIMPORTER_H

#include <QDomDocument>
#include "abstractimporter.h"

class HtmlImporter : public AbstractImporter
{
    Q_OBJECT
    Q_CLASSINFO("Format", "HTML")
    Q_CLASSINFO("NameFilters", "HTML (*.html)")

public:
    Q_INVOKABLE HtmlImporter(QObject *parent=nullptr);
    ~HtmlImporter();

protected:
    bool doImport(QIODevice *device); // AbstractImporter interface
};

#endif // CELTXHTMLIMPORTER_H
