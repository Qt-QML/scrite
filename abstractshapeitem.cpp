#include "abstractshapeitem.h"
#include "polygontesselator.h"

#include <QtQuick/QSGFlatColorMaterial>
#include <QtQuick/QSGGeometryNode>
#include <QtQuick/QSGMaterial>
#include <QtQuick/QQuickWindow>

#include <QPainter>

AbstractShapeItem::AbstractShapeItem(QQuickItem *parent)
    : QQuickPaintedItem(parent),
      m_fillColor(Qt::black),
      m_outlineWidth(1.0),
      m_outlineColor(Qt::black),
      m_renderType(OutlineAndFill),
      m_renderingMechanism(UseOpenGL)
{
    this->setFlag(ItemHasContents);

    connect(this, SIGNAL(opacityChanged()), this, SLOT(update()));
}

AbstractShapeItem::~AbstractShapeItem()
{

}

void AbstractShapeItem::setRenderType(AbstractShapeItem::RenderType val)
{
    if(m_renderType == val)
        return;

    m_renderType = val;
    emit renderTypeChanged();

    this->update();
}

void AbstractShapeItem::setRenderingMechanism(AbstractShapeItem::RenderingMechanism val)
{
    if(m_renderingMechanism == val)
        return;

    m_renderingMechanism = val;
    emit renderingMechanismChanged();

    this->update();
}

void AbstractShapeItem::setOutlineColor(const QColor &val)
{
    if(m_outlineColor == val)
        return;

    m_outlineColor = val;
    emit outlineColorChanged();

    this->update();
}

void AbstractShapeItem::setFillColor(const QColor &val)
{
    if(m_fillColor == val)
        return;

    m_fillColor = val;
    emit fillColorChanged();

    this->update();
}

void AbstractShapeItem::setOutlineWidth(const qreal &val)
{
    if( qFuzzyCompare(m_outlineWidth, val) )
        return;

    if( qIsNaN(val) )
    {
        qDebug("%s was given NaN as parameter", Q_FUNC_INFO);
        return;
    }

    m_outlineWidth = val;
    emit outlineWidthChanged();

    this->update();
}

QRectF AbstractShapeItem::contentRect() const
{
    return m_path.boundingRect();
}

bool AbstractShapeItem::updateShape()
{
    QPainterPath path = this->shape();

#if 0
    QRectF pathRect = path.boundingRect();

    if( pathRect.topLeft() != QPointF(0,0) )
    {
        QTransform tx;
        tx.translate( -pathRect.left(), -pathRect.top() );
        path = tx.map(path).simplified();
    }
    else
        path = path.simplified();
#endif

    if(path == m_path)
        return false;

    m_path = path;
    emit contentRectChanged();
    return true;
}

QSGNode *AbstractShapeItem::updatePaintNode(QSGNode *oldNode, QQuickItem::UpdatePaintNodeData *nodeData)
{
    const bool pathUpdated = this->updateShape();
    static const bool isSoftwareContext = qgetenv("QMLSCENE_DEVICE") == QByteArray("softwarecontext");
    if( isSoftwareContext || m_renderingMechanism == UseQPainter )
        return QQuickPaintedItem::updatePaintNode(oldNode, nodeData);

    QQuickWindow *qmlWindow = this->window();
    if( qmlWindow && qmlWindow->rendererInterface()->graphicsApi() == QSGRendererInterface::Software )
        return QQuickPaintedItem::updatePaintNode(oldNode, nodeData);

    if( pathUpdated )
    {
        if(oldNode)
            delete oldNode;

        oldNode = nullptr;
    }

    QSGNode *node = pathUpdated ? constructSceneGraph() : oldNode;
    return this->polishSceneGraph(node);
}

QSGNode *AbstractShapeItem::constructSceneGraph() const
{
    if( m_path.isEmpty() )
        return nullptr;

    const QList<QPolygonF> subpaths = m_renderType & OutlineAlso ? m_path.toSubpathPolygons() : QList<QPolygonF>();

    // Triangulate all fillable polygons in the path
    const QVector<QPointF> triangles = m_renderType & FillAlso ? PolygonTessellator::tessellate(subpaths) : QVector<QPointF>();
                                // I am not using QPolygonF here on purpose
                                // even though QPolygonF is a QVector<QPointF>.
                                // This is because, QPolygonF implies that all
                                // points in it make a single polygon. Here
                                // we want for the variable to imply a vector
                                // of points such that each set of 3 points make
                                // makes one triangle.

    // Extract all outline polygons
    const QList<QPolygonF> &outlines = subpaths;

    // Construct the scene graph branch for this node.
    QSGNode *rootNode = new QSGNode;

    // Construct one opacity node for outline, one more for filled.
    QSGNode *trianglesNode = new QSGOpacityNode;
    trianglesNode->setFlags(QSGNode::OwnedByParent);
    rootNode->appendChildNode(trianglesNode);

    QSGNode *outlinesNode = new QSGOpacityNode;
    outlinesNode->setFlags(QSGNode::OwnedByParent);
    rootNode->appendChildNode(outlinesNode);

    // Construct one geometry node for each fill-polygon with fill color.
    if(m_renderType & FillAlso)
    {
        QSGGeometryNode *fillNode = new QSGGeometryNode;
        fillNode->setFlags(QSGNode::OwnsGeometry|QSGNode::OwnsMaterial|QSGNode::OwnedByParent);

        QSGGeometry *fillGeometry = new QSGGeometry(QSGGeometry::defaultAttributes_Point2D(), triangles.size());
        fillGeometry->setDrawingMode(QSGGeometry::DrawTriangles);
        fillNode->setGeometry(fillGeometry);

        QSGGeometry::Point2D *fillPoints = fillGeometry->vertexDataAsPoint2D();
        for(int i=0; i<triangles.size(); i++)
        {
            fillPoints[i].x = float(triangles.at(i).x());
            fillPoints[i].y = float(triangles.at(i).y());
        }

        QSGFlatColorMaterial *fillMaterial = new QSGFlatColorMaterial();
        fillNode->setMaterial(fillMaterial);

        QColor fillColor = m_fillColor;
        fillColor.setAlphaF(fillColor.alphaF() * this->opacity());
        fillMaterial->setFlag(QSGMaterial::Blending);
        fillMaterial->setColor(fillColor);

        trianglesNode->appendChildNode(fillNode);
    }

    // Construct one geometry node for each outline will outline color
    Q_FOREACH(QPolygonF polygon, outlines)
    {
        if( polygon.isEmpty() )
            continue;

        QSGGeometryNode *outlineNode = new QSGGeometryNode;
        outlineNode->setFlags(QSGNode::OwnsGeometry|QSGNode::OwnsMaterial|QSGNode::OwnedByParent);

        QSGGeometry *outlineGeometry = new QSGGeometry(QSGGeometry::defaultAttributes_Point2D(), polygon.size());
        outlineGeometry->setDrawingMode(m_renderType == OutlineOnly ? QSGGeometry::DrawLineStrip : QSGGeometry::DrawLineLoop);
        outlineGeometry->setLineWidth( float(m_outlineWidth) );
        outlineNode->setGeometry(outlineGeometry);

        QSGGeometry::Point2D *outlinePoints = outlineGeometry->vertexDataAsPoint2D();
        for(int i=0; i<polygon.size(); i++)
        {
            outlinePoints[i].x = float(polygon.at(i).x());
            outlinePoints[i].y = float(polygon.at(i).y());
        }

        QSGFlatColorMaterial *outlineMaterial = new QSGFlatColorMaterial();
        outlineNode->setMaterial(outlineMaterial);

        QColor outlineColor = m_outlineColor;
        outlineColor.setAlphaF(outlineColor.alphaF() * this->opacity());
        outlineMaterial->setFlag(QSGMaterial::Blending);
        outlineMaterial->setFlag(QSGMaterial::RequiresFullMatrixExceptTranslate);
        outlineMaterial->setColor(outlineColor);

        outlinesNode->appendChildNode(outlineNode);
    }

    return rootNode;
}

QSGNode *AbstractShapeItem::polishSceneGraph(QSGNode *rootNode) const
{
    if(rootNode == nullptr)
        return nullptr;

    QSGOpacityNode *trianglesNode = static_cast<QSGOpacityNode*>(rootNode->childAtIndex(0));
    trianglesNode->setOpacity( m_renderType & FillAlso ? 1 : 0 );

    QSGOpacityNode *outlinesNode = static_cast<QSGOpacityNode*>(rootNode->childAtIndex(1));
    outlinesNode->setOpacity( m_renderType & OutlineAlso ? 1 : 0 );

    return rootNode;
}

void AbstractShapeItem::paint(QPainter *paint)
{
    paint->setBrush(m_fillColor);
    paint->setPen( QPen(m_outlineColor,m_outlineWidth) );
    paint->drawPath(m_path);
}
