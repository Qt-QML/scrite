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

import Scrite 1.0
import QtQuick 2.13
import QtQuick.Window 2.13
import Qt.labs.settings 1.0
import QtQuick.Controls 2.13

Rectangle {
    // This editor has to specialize in rendering scenes within a ScreenplayAdapter
    // The adapter may contain a single scene or an entire screenplay, that doesnt matter.
    // This way we can avoid having a SceneEditor and ScreenplayEditor as two distinct
    // QML components.

    id: screenplayEditor
    property ScreenplayFormat screenplayFormat: scriteDocument.displayFormat
    property ScreenplayPageLayout pageLayout: screenplayFormat.pageLayout
    property alias source: screenplayAdapter.source
    property bool toolBarVisible: toolbar.visible

    property alias zoomLevel: zoomSlider.zoomLevel
    property int zoomLevelModifier: 0
    color: primaryColors.windowColor
    border.width: 1
    border.color: primaryColors.borderColor
    clip: true

    ScreenplayAdapter {
        id: screenplayAdapter
        source: scriteDocument.loading ? null : scriteDocument.screenplay
        onCurrentIndexChanged: {
            if(currentIndex < 0) {
                contentView.scrollToFirstScene()
                return
            }
            if(mainUndoStack.screenplayEditorActive || mainUndoStack.sceneEditorActive)
                app.execLater(contentView, 100, function() {
                    contentView.scrollIntoView(currentIndex)
                })
            else
                contentView.positionViewAtIndex(currentIndex, ListView.Beginning)
        }
        onSourceChanged: {
            globalScreenplayEditorToolbar.showScreenplayPreview = false
            contentView.synopsisExpandCounter = 0
            contentView.synopsisExpanded = false
        }
    }

    ScreenplayTextDocument {
        id: screenplayTextDocument
        screenplay: screenplayAdapter.screenplay
        formatting: scriteDocument.printFormat
        syncEnabled: true
    }

    // Ctrl+Shift+N should result in the newly added scene to get keyboard focus
    Connections {
        target: screenplayAdapter.isSourceScreenplay ? scriteDocument : null
        ignoreUnknownSignals: true
        onNewSceneCreated: {
            app.execLater(screenplayAdapter.screenplay, 100, function() {
                contentView.positionViewAtIndex(screenplayIndex, ListView.Visible)
                var delegate = contentView.itemAtIndex(screenplayIndex)
                delegate.item.assumeFocus()
            })
        }
    }

    Rectangle {
        id: toolbar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 1
        color: primaryColors.c100.background
        width: ruler.width
        height: screenplaySearchBar.height * opacity
        enabled: screenplayAdapter.screenplay
        border.width: 1
        border.color: primaryColors.borderColor
        visible: opacity > 0
        opacity: globalScreenplayEditorToolbar.showFindAndReplace ? 1 : 0
        Behavior on opacity {
            enabled: screenplayEditorSettings.enableAnimations
            NumberAnimation { duration: 100 }
        }

        SearchBar {
            id: screenplaySearchBar
            searchEngine.objectName: "Screenplay Search Engine"
            anchors.horizontalCenter: parent.horizontalCenter
            allowReplace: !scriteDocument.readOnly
            width: toolbar.width * 0.6
            enabled: !screenplayPreview.active

            Repeater {
                id: searchAgents
                model: screenplayAdapter.screenplay ? 1 : 0

                Item {
                    property string searchString
                    property var searchResults: []
                    property int previousSceneIndex: -1

                    signal replaceCurrentRequest(string replacementText)

                    SearchAgent.onReplaceAll: {
                        screenplayTextDocument.syncEnabled = false
                        screenplayAdapter.screenplay.replace(searchString, replacementText, 0)
                        screenplayTextDocument.syncEnabled = true
                    }
                    SearchAgent.onReplaceCurrent: replaceCurrentRequest(replacementText)

                    SearchAgent.engine: screenplaySearchBar.searchEngine

                    SearchAgent.onSearchRequest: {
                        searchString = string
                        searchResults = screenplayAdapter.screenplay.search(string, 0)
                        SearchAgent.searchResultCount = searchResults.length
                    }

                    SearchAgent.onCurrentSearchResultIndexChanged: {
                        if(SearchAgent.currentSearchResultIndex >= 0) {
                            var searchResult = searchResults[SearchAgent.currentSearchResultIndex]
                            var sceneIndex = searchResult["sceneIndex"]
                            if(sceneIndex !== previousSceneIndex)
                                clearPreviousElementUserData()
                            var sceneResultIndex = searchResult["sceneResultIndex"]
                            var screenplayElement = screenplayAdapter.screenplay.elementAt(sceneIndex)
                            var data = {
                                "searchString": searchString,
                                "sceneResultIndex": sceneResultIndex,
                                "currentSearchResultIndex": SearchAgent.currentSearchResultIndex,
                                "searchResultCount": SearchAgent.searchResultCount
                            }
                            contentView.positionViewAtIndex(sceneIndex, ListView.Visible)
                            screenplayElement.userData = data
                            previousSceneIndex = sceneIndex
                        }
                    }

                    SearchAgent.onClearSearchRequest: {
                        screenplayAdapter.screenplay.currentElementIndex = previousSceneIndex
                        searchString = ""
                        searchResults = []
                        clearPreviousElementUserData()
                    }

                    function clearPreviousElementUserData() {
                        if(previousSceneIndex >= 0) {
                            var screenplayElement = screenplayAdapter.screenplay.elementAt(previousSceneIndex)
                            if(screenplayElement)
                                screenplayElement.userData = undefined
                        }
                        previousSceneIndex = -1
                    }
                }
            }
        }
    }

    Item {
        id: screenplayEditorWorkspace
        anchors.top: toolbar.visible ? toolbar.bottom : parent.top
        anchors.left: sidePanels.right
        anchors.right: parent.right
        anchors.bottom: statusBar.top
        clip: true

        EventFilter.events: [31]
        EventFilter.onFilter: {
            EventFilter.forwardEventTo(contentView)
            result.filter = true
            result.accepted = true
        }

        Item {
            id: pageRulerArea
            width: pageLayout.paperWidth * screenplayEditor.zoomLevel * Screen.devicePixelRatio
            height: parent.height
            anchors.left: parent.left
            anchors.leftMargin: leftMargin
            property real leftMargin: contentView.synopsisExpanded && sidePanels.expanded ? 80 : (parent.width-width)/2
            Behavior on leftMargin {
                enabled: screenplayEditorSettings.enableAnimations && contentView.synopsisExpandCounter > 0
                NumberAnimation { duration: 50 }
            }

            Rectangle {
                id: contentArea
                anchors.top: ruler.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 5
                color: "white"

                ResetOnChange {
                    id: contentViewModel
                    trackChangesOn: screenplayEditorSettings.displaySceneCharacters || scriteDocument.loading
                    from: null
                    to: screenplayAdapter
                    onJustReset: {
                        app.execLater(contentView, 100, function() {
                            contentView.positionViewAtIndex(screenplayAdapter.currentIndex, ListView.Beginning)
                        })
                    }
                }

                ListView {
                    id: contentView
                    anchors.fill: parent
                    model: contentViewModel.value
                    property int synopsisExpandCounter: 0
                    property bool synopsisExpanded: false
                    property real spaceForSynopsis: screenplayEditorSettings.displaySceneNotes ? ((sidePanels.expanded ? (screenplayEditorWorkspace.width - pageRulerArea.width - 80) : (screenplayEditorWorkspace.width - pageRulerArea.width)/2) - 20) : 0
                    onSynopsisExpandedChanged: synopsisExpandCounter = synopsisExpandCounter+1
                    delegate: Loader {
                        width: contentView.width
                        property var componentData: modelData
                        sourceComponent: modelData.scene ? contentComponent : breakComponent
                    }
                    snapMode: ListView.NoSnap
                    boundsBehavior: Flickable.StopAtBounds
                    boundsMovement: Flickable.StopAtBounds
                    cacheBuffer: 10
                    ScrollBar.vertical: verticalScrollBar
                    property int numberOfWordsAddedToDict : 0
                    header: Item {
                        width: contentView.width
                        height: (screenplayAdapter.isSourceScreenplay ? (titleCardLoader.active ? titleCardLoader.height : ruler.topMarginPx) : 0)
                        property real padding: width * 0.1

                        function editTitlePage(source) {
                            modalDialog.arguments = {"activeTabIndex": 2}
                            modalDialog.popupSource = source
                            modalDialog.sourceComponent = optionsDialogComponent
                            modalDialog.active = true
                        }

                        Loader {
                            id: titleCardLoader
                            active: screenplayAdapter.isSourceScreenplay && scriteDocument.screenplay.hasTitlePageAttributes
                            sourceComponent: titleCardComponent
                            anchors.left: parent.left
                            anchors.right: parent.right

                            ToolButton3 {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.rightMargin: ruler.rightMarginPx
                                iconSource: "../icons/action/edit.png"
                                onClicked: editTitlePage(this)
                                visible: parent.active && enabled
                                enabled: !scriteDocument.readOnly
                            }
                        }

                        Button2 {
                            id: editTitlePageButton
                            text: "Edit Title Page"
                            visible: screenplayAdapter.isSourceScreenplay && titleCardLoader.active === false && enabled
                            opacity: hovered ? 1 : 0.75
                            anchors.centerIn: parent
                            onClicked: editTitlePage(this)
                            enabled: !scriteDocument.readOnly
                        }
                    }
                    footer: Item {
                        width: contentView.width
                        height: ruler.bottomMarginPx

                        Column {
                            anchors.centerIn: parent
                            visible: screenplayAdapter.screenplay === scriteDocument.screenplay && enabled
                            spacing: 5
                            enabled: !scriteDocument.readOnly

                            Image {
                                id: addSceneButton
                                source: "../icons/content/add_circle_outline.png"
                                height: ruler.bottomMarginPx * 0.6
                                width: height
                                smooth: true
                                anchors.horizontalCenter: parent.horizontalCenter
                                opacity: defaultOpacity
                                Behavior on opacity {
                                    enabled: screenplayEditorSettings.enableAnimations
                                    NumberAnimation { duration: 250 }
                                }
                                property real defaultOpacity: screenplayAdapter.elementCount === 0 ? 0.5 : 0.05
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onContainsMouseChanged: parent.opacity = containsMouse ? 1 : parent.defaultOpacity
                                    onClicked: {
                                        scriteDocument.screenplay.currentElementIndex = scriteDocument.screenplay.elementCount-1
                                        if(!scriteDocument.readOnly)
                                            scriteDocument.createNewScene()
                                    }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: (screenplayAdapter.elementCount === 0 ? "Create your first scene" : "Add a new scene") + "\n(" + app.polishShortcutTextForDisplay("Ctrl+Shift+N") + ")"
                                opacity: addSceneButton.opacity
                            }
                        }
                    }

                    FocusTracker.window: qmlWindow
                    FocusTracker.indicator.target: mainUndoStack
                    FocusTracker.indicator.property: screenplayAdapter.isSourceScreenplay ? "screenplayEditorActive" : "sceneEditorActive"

                    Component.onCompleted: positionViewAtIndex(screenplayAdapter.currentIndex, ListView.Beginning)

                    property int firstItemIndex: screenplayAdapter.elementCount > 0 ? Math.max(indexAt(width/2, contentY+1), 0) : 0
                    property int lastItemIndex: screenplayAdapter.elementCount > 0 ? validOrLastIndex(indexAt(width/2, contentY+height-2)) : 0

                    function validOrLastIndex(val) { return val < 0 ? screenplayAdapter.elementCount-1 : val }

                    function isVisible(index) {
                        return index >= firstItemIndex && index <= lastItemIndex
                    }

                    function scrollToFirstScene() {
                        positionViewAtBeginning()
                    }

                    function scrollIntoView(index) {
                        if(index < 0) {
                            positionViewAtBeginning()
                            return
                        }

                        var topIndex = firstItemIndex
                        var bottomIndex = lastItemIndex

                        if(index >= topIndex && index <= bottomIndex)
                            return // item is already visible

                        if(index < topIndex && topIndex-index <= 2) {
                            contentView.contentY -= height*0.2
                        } else if(index > bottomIndex && index-bottomIndex <= 2) {
                            contentView.contentY += height*0.2
                        } else {
                            positionViewAtIndex(index, ListView.Beginning)
                        }
                    }

                    function ensureVisible(item, rect) {
                        if(item === null)
                            return

                        var pt = item.mapToItem(contentView.contentItem, rect.x, rect.y)
                        var startY = contentView.contentY
                        var endY = contentView.contentY + contentView.height - rect.height
                        if( pt.y >= startY && pt.y <= endY )
                            return

                        var newContentY = 0
                        if( pt.y < startY )
                            contentView.contentY = pt.y
                        else
                            contentView.contentY = (pt.y + 2*rect.height) - contentView.height
                    }
                }
            }

            RulerItem {
                id: ruler
                width: parent.width
                height: 20
                font.pixelSize: 10
                leftMargin: pageLayout.leftMargin * Screen.devicePixelRatio
                rightMargin: pageLayout.rightMargin * Screen.devicePixelRatio
                zoomLevel: screenplayEditor.zoomLevel

                property real leftMarginPx: leftMargin * zoomLevel
                property real rightMarginPx: rightMargin * zoomLevel
                property real topMarginPx: pageLayout.topMargin * Screen.devicePixelRatio * zoomLevel
                property real bottomMarginPx: pageLayout.bottomMargin * Screen.devicePixelRatio * zoomLevel
            }
        }
    }

    ScrollBar {
        id: verticalScrollBar
        anchors.top: screenplayEditorWorkspace.top
        anchors.right: parent.right
        anchors.bottom: statusBar.top
        orientation: Qt.Vertical
        minimumSize: 0.1
        policy: screenplayAdapter.elementCount > 0 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }

    Rectangle {
        id: statusBar
        height: 30
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: primaryColors.windowColor
        border.width: 1
        border.color: primaryColors.borderColor
        clip: true

        ToolButton3 {
            id: toggleLockButton
            width: parent.height - 10
            height: width
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            enabled: !scriteDocument.readOnly
            iconSource: scriteDocument.readOnly ? "../icons/action/lock_outline.png" : (scriteDocument.locked ? "../icons/action/lock_outline.png" : "../icons/action/lock_open.png")
            ToolTip.text: "Lock to allow editing of this document only on this computer."
            onClicked: {
                var question = ""
                if(scriteDocument.locked)
                    question = "By unlocking this document, you will be able to edit it on this and any other computer. Do you want to unlock?"
                else
                    question = "By locking this document, you will be able to edit it only on this computer. Do you want to lock?"

                askQuestion({
                    "question": question,
                    "okButtonText": "Yes",
                    "cancelButtonText": "No",
                    "callback": function(val) {
                        if(val) {
                            scriteDocument.locked = !scriteDocument.locked
                        }
                    }
                }, this)
            }
        }

        Text {
            id: pageNumberDisplay
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: toggleLockButton.right
            anchors.leftMargin: 20
            text: "Page " + screenplayTextDocument.currentPage + " of " + screenplayTextDocument.pageCount
        }

        Item {
            width: pageRulerArea.width
            height: parent.height
            anchors.centerIn: parent
            visible: parent.width - pageNumberDisplay.width - zoomSlider.width > width

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: ruler.leftMarginPx
                anchors.rightMargin: ruler.rightMarginPx
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: height*0.1
                font.family: headingFontMetrics.font.family
                font.pixelSize: parent.height * 0.6
                elide: Text.ElideRight
                text: {
                    if(screenplayAdapter.isSourceScene || screenplayAdapter.elementCount === 0)
                        return ""

                    var scene = null
                    var element = null
                    if(contentView.isVisible(screenplayAdapter.currentIndex)) {
                        scene = screenplayAdapter.currentScene
                        element = screenplayAdapter.currentElement
                    } else {
                        var data = screenplayAdapter.at(contentView.firstItemIndex)
                        scene = data ? data.scene : null
                        element = data ? data.screenplayElement : null
                    }
                    return scene && scene.heading.enabled ? "[" + element.sceneNumber + "] " + scene.heading.text : ''
                }
            }
        }

        ZoomSlider {
            id: zoomSlider
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            property var zoomLevels: screenplayFormat.fontZoomLevels
            zoomLevel: zoomLevels[value]
            from: 0; to: zoomLevels.length-1
            stepSize: 1
            onValueChanged: {
                if(mainTabBar.currentIndex === 0)
                    screenplayEditorSettings.mainEditorZoomValue = value
                else
                    screenplayEditorSettings.embeddedEditorZoomValue = value
                screenplayFormat.fontZoomLevelIndex = value
            }
            Component.onCompleted: {
                var _value = -1
                if(mainTabBar.currentIndex === 0)
                    _value = screenplayEditorSettings.mainEditorZoomValue
                else
                    _value = screenplayEditorSettings.embeddedEditorZoomValue
                if(_value >= from && _value <= to)
                    value = _value
                else
                    value = screenplayFormat.fontZoomLevelIndex + zoomLevelModifier
                screenplayFormat.fontZoomLevelIndex = value
            }
        }
    }

    Component {
        id: breakComponent

        Item {
            property int theIndex: componentData.rowNumber
            property Scene theScene: componentData.scene
            property ScreenplayElement theElement: componentData.screenplayElement
            height: breakText.contentHeight+16

            Rectangle {
                anchors.fill: breakText
                anchors.margins: -4
                color: primaryColors.windowColor
                border.width: 1
                border.color: primaryColors.borderColor
            }

            Text {
                id: breakText
                anchors.centerIn: parent
                width: parent.width-16
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 30
                font.bold: true
                text: parent.theElement.sceneID
            }
        }
    }

    Component {
        id: contentComponent

        Rectangle {
            id: contentItem
            property int theIndex: componentData.rowNumber
            property Scene theScene: componentData.scene
            property ScreenplayElement theElement: componentData.screenplayElement

            width: contentArea.width
            height: contentItemLayout.height
            color: "white"
            readonly property var binder: sceneDocumentBinder
            readonly property var editor: sceneTextEditor

            SceneDocumentBinder {
                id: sceneDocumentBinder
                scene: contentItem.theScene
                textDocument: sceneTextEditor.textDocument
                cursorPosition: sceneTextEditor.cursorPosition
                characterNames: scriteDocument.structure.characterNames
                screenplayFormat: screenplayEditor.screenplayFormat
                forceSyncDocument: !sceneTextEditor.activeFocus
                spellCheckEnabled: !scriteDocument.readOnly && spellCheckEnabledFlag.value
                liveSpellCheckEnabled: sceneTextEditor.activeFocus
                onDocumentInitialized: sceneTextEditor.cursorPosition = 0
                onRequestCursorPosition: app.execLater(contentItem, 100, function() { contentItem.assumeFocusAt(position) })
                property var currentParagraphType: currentElement ? currentElement.type : SceneHeading.Action
                onCurrentParagraphTypeChanged: {
                    if(currentParagraphType === SceneElement.Action) {
                        ruler.paragraphLeftMargin = 0
                        ruler.paragraphRightMargin = 0
                    } else {
                        var elementFormat = screenplayEditor.screenplayFormat.elementFormat(currentParagraphType)
                        ruler.paragraphLeftMargin = ruler.leftMargin + pageLayout.contentWidth * elementFormat.leftMargin * Screen.devicePixelRatio
                        ruler.paragraphRightMargin = ruler.rightMargin + pageLayout.contentWidth * elementFormat.rightMargin * Screen.devicePixelRatio
                    }
                }
            }

            ResetOnChange {
                id: spellCheckEnabledFlag
                trackChangesOn: contentView.numberOfWordsAddedToDict
                from: false
                to: screenplayEditorSettings.enableSpellCheck
                delay: 100
            }

            SidePanel {
                id: synopsisSidePanel
                z: 1
                buttonText: ""
                buttonColor: expanded ? Qt.tint(contentItem.theScene.color, "#C0FFFFFF") : Qt.tint(contentItem.theScene.color, "#D7EEEEEE")
                backgroundColor: buttonColor
                borderColor: expanded ? primaryColors.borderColor : Qt.rgba(0,0,0,0)
                anchors.top: parent.top
                anchors.left: parent.right
                // anchors.leftMargin: expanded ? 0 : -minPanelWidth
                height: expanded ? Math.min(300, parent.height) : sceneHeadingAreaLoader.height
                property bool synopsisExpanded: contentView.synopsisExpanded
                expanded: synopsisExpanded
                onSynopsisExpandedChanged: expanded = synopsisExpanded
                onExpandedChanged: contentView.synopsisExpanded = expanded
                maxPanelWidth: contentView.spaceForSynopsis
                width: maxPanelWidth
                clip: true
                visible: width >= 100 && screenplayEditorSettings.displaySceneNotes
                content: TextArea {
                    id: synopsisEdit
                    background: Rectangle {
                        color: Qt.tint(contentItem.theScene.color, "#E7FFFFFF")
                    }
                    font.pointSize: app.idealFontPointSize + 1
                    onTextChanged: contentItem.theScene.title = text
                    wrapMode: Text.WordWrap
                    text: contentItem.theScene.title
                    selectByMouse: true
                    selectByKeyboard: true
                    leftPadding: 10
                    rightPadding: 10
                    topPadding: 10
                    bottomPadding: 10

                    Transliterator.textDocument: textDocument
                    Transliterator.cursorPosition: cursorPosition
                    Transliterator.hasActiveFocus: activeFocus

                    SpecialSymbolsSupport {
                        anchors.top: parent.bottom
                        anchors.left: parent.left
                        textEditor: synopsisEdit
                        textEditorHasCursorInterface: true
                    }
                }
            }

            Column {
                id: contentItemLayout
                width: parent.width

                Loader {
                    id: sceneHeadingAreaLoader
                    width: parent.width
                    active: contentItem.theScene !== null
                    sourceComponent: sceneHeadingArea
                    onItemChanged: {
                        if(item) {
                            item.theScene = contentItem.theScene
                            item.theElement = contentItem.theElement
                            item.sceneTextEditor = sceneTextEditor
                        }
                    }
                    function edit() {
                        if(item)
                            item.edit()
                    }
                }

                TextArea {
                    // Basic editing functionality
                    id: sceneTextEditor
                    width: parent.width
                    height: Math.ceil(contentHeight + topPadding + bottomPadding)
                    topPadding: sceneEditorFontMetrics.lineSpacing
                    bottomPadding: sceneEditorFontMetrics.lineSpacing
                    leftPadding: ruler.leftMarginPx
                    rightPadding: ruler.rightMarginPx
                    palette: app.palette
                    selectByMouse: true
                    selectByKeyboard: true
                    property bool hasSelection: selectionStart >= 0 && selectionEnd >= 0 && selectionEnd > selectionStart
                    property Scene scene: contentItem.theScene
                    readOnly: scriteDocument.readOnly
                    background: Item {
                        id: sceneTextEditorBackground

                        ResetOnChange {
                            id: document
                            trackChangesOn: sceneDocumentBinder.documentLoadCount + zoomSlider.value
                            from: null
                            to: screenplayTextDocument
                            delay: 100
                        }

                        ScreenplayElementPageBreaks {
                            id: pageBreaksEvaluator
                            screenplayElement: contentItem.theElement
                            screenplayDocument: scriteDocument.loading ? null : document.value
                        }

                        Repeater {
                            model: pageBreaksEvaluator.pageBreaks

                            Item {
                                id: pageBreakLine
                                property rect cursorRect: modelData.position >= 0 ? sceneTextEditor.positionToRectangle(modelData.position) : Qt.rect(0,0,0,0)
                                x: 0
                                y: (modelData.position >= 0 ? cursorRect.y : -sceneHeadingAreaLoader.height) - height/2
                                width: sceneTextEditorBackground.width
                                height: 1
                                // color: primaryColors.c400.background

                                PageNumberBubble {
                                    x: -width - 20
                                    pageNumber: modelData.pageNumber
                                }
                            }
                        }
                    }
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    font: screenplayFormat.defaultFont2
                    placeholderText: activeFocus ? "" : "Click here to type your scene content..."
                    onActiveFocusChanged: {
                        if(activeFocus) {
                            contentView.ensureVisible(sceneTextEditor, cursorRectangle)
                            screenplayAdapter.currentIndex = contentItem.theIndex
                            globalScreenplayEditorToolbar.sceneEditor = contentItem
                        } else if(globalScreenplayEditorToolbar.sceneEditor === contentItem)
                            globalScreenplayEditorToolbar.sceneEditor = null
                        sceneHeadingAreaLoader.item.sceneHasFocus = activeFocus
                        contentItem.theScene.undoRedoEnabled = activeFocus
                    }

                    onCursorRectangleChanged: {
                        if(activeFocus /*&& contentView.isVisible(contentItem.theIndex)*/)
                            contentView.ensureVisible(sceneTextEditor, cursorRectangle)
                    }

                    // Support for transliteration.
                    property bool userIsTyping: false
                    EventFilter.events: [51,6] // Wheel, ShortcutOverride
                    EventFilter.onFilter: {
                        if(event.type === 51) {
                            // We want to avoid TextArea from processing Ctrl+Z
                            // and other such shortcuts.
                            result.acceptEvent = false
                            result.filter = true
                        } else if(event.type === 6) {
                            // Enter, Tab and other keys must not trigger
                            // Transliteration. Only space should.
                            sceneTextEditor.userIsTyping = event.hasText
                        }
                    }
                    Transliterator.enabled: contentItem.theScene && !contentItem.theScene.isBeingReset && userIsTyping
                    Transliterator.textDocument: textDocument
                    Transliterator.cursorPosition: cursorPosition
                    Transliterator.hasActiveFocus: activeFocus
                    Transliterator.onAboutToTransliterate: {
                        contentItem.theScene.beginUndoCapture(false)
                        contentItem.theScene.undoRedoEnabled = false
                    }
                    Transliterator.onFinishedTransliterating: {
                        app.execLater(Transliterator, 0, function() {
                            contentItem.theScene.endUndoCapture()
                            contentItem.theScene.undoRedoEnabled = true
                        })
                    }

                    // Support for auto completion
                    Item {
                        id: cursorOverlay
                        x: parent.cursorRectangle.x
                        y: parent.cursorRectangle.y
                        width: parent.cursorRectangle.width
                        height: parent.cursorRectangle.height
                        visible: parent.cursorVisible
                        ToolTip.text: '<font name="' + sceneDocumentBinder.currentFont.family + '"><font color="lightgray">' + sceneDocumentBinder.completionPrefix.toUpperCase() + '</font>' + completer.suggestion.toUpperCase() + '</font>';
                        ToolTip.visible: completer.hasSuggestion

                        SpecialSymbolsSupport {
                            anchors.top: parent.bottom
                            anchors.left: parent.left
                            textEditor: sceneTextEditor
                            // Because of a bug in Qt we will be unable to include Emoji's in
                            // the generated PDFs.
                            // More information about the bug can be found here:
                            // https://bugreports.qt.io/browse/QTBUG-78833
                            // When we update Qt to say 5.15 in the next cycle, we can allow
                            // Emoji's to be used within the screenplay editor. Until then, it
                            // just won't work.
                            includeEmojis: app.isWindowsPlatform
                            textEditorHasCursorInterface: true
                        }

                        Completer {
                            id: completer
                            strings: sceneDocumentBinder.autoCompleteHints
                            completionPrefix: sceneDocumentBinder.completionPrefix
                        }

                        // Context menus must ideally show up directly below the cursor
                        // So, we keep the menu loaders inside the cursorOverlay
                        MenuLoader {
                            id: spellingSuggestionsMenu
                            anchors.bottom: parent.bottom
                            enabled: !scriteDocument.readOnly
                            menu: Menu2 {
                                onAboutToShow: sceneTextEditor.persistentSelection = true
                                onAboutToHide: sceneTextEditor.persistentSelection = false

                                Repeater {
                                    model: sceneDocumentBinder.spellingSuggestions

                                    MenuItem2 {
                                        text: modelData
                                        focusPolicy: Qt.NoFocus
                                        onClicked: {
                                            spellingSuggestionsMenu.close()
                                            sceneDocumentBinder.replaceWordUnderCursor(modelData)
                                        }
                                    }
                                }

                                MenuSeparator { }

                                MenuItem2 {
                                    text: "Add to dictionary"
                                    focusPolicy: Qt.NoFocus
                                    onClicked: {
                                        spellingSuggestionsMenu.close()
                                        sceneDocumentBinder.addWordUnderCursorToDictionary()
                                        ++contentView.numberOfWordsAddedToDict
                                    }
                                }

                                MenuItem2 {
                                    text: "Ignore"
                                    focusPolicy: Qt.NoFocus
                                    onClicked: {
                                        spellingSuggestionsMenu.close()
                                        sceneDocumentBinder.addWordUnderCursorToIgnoreList()
                                        ++contentView.numberOfWordsAddedToDict
                                    }
                                }
                            }
                        }

                        MenuLoader {
                            id: editorContextMenu
                            anchors.bottom: parent.bottom
                            enabled: !scriteDocument.readOnly
                            menu: Menu2 {
                                onAboutToShow: sceneTextEditor.persistentSelection = true
                                onAboutToHide: sceneTextEditor.persistentSelection = false

                                MenuItem2 {
                                    focusPolicy: Qt.NoFocus
                                    text: "Cut\t" + app.polishShortcutTextForDisplay("Ctrl+X")
                                    enabled: sceneTextEditor.selectionEnd > sceneTextEditor.selectionStart
                                    onClicked: { sceneTextEditor.cut(); editorContextMenu.close() }
                                }

                                MenuItem2 {
                                    focusPolicy: Qt.NoFocus
                                    text: "Copy\t" + app.polishShortcutTextForDisplay("Ctrl+C")
                                    enabled: sceneTextEditor.selectionEnd > sceneTextEditor.selectionStart
                                    onClicked: { sceneTextEditor.copy(); editorContextMenu.close() }
                                }

                                MenuItem2 {
                                    focusPolicy: Qt.NoFocus
                                    text: "Paste\t" + app.polishShortcutTextForDisplay("Ctrl+V")
                                    enabled: sceneTextEditor.canPaste
                                    onClicked: { sceneTextEditor.paste(); editorContextMenu.close() }
                                }

                                MenuSeparator {  }

                                MenuItem2 {
                                    focusPolicy: Qt.NoFocus
                                    text: "Split Scene"
                                    enabled: sceneDocumentBinder && sceneDocumentBinder.currentElement && sceneDocumentBinder.currentElementCursorPosition >= 0 && screenplayAdapter.isSourceScreenplay
                                    onClicked: {
                                        contentItem.splitScene()
                                        editorContextMenu.close()
                                    }
                                }

                                MenuSeparator {  }

                                Menu2 {
                                    title: "Format"
                                    width: 250

                                    Repeater {
                                        model: [
                                            { "value": SceneElement.Action, "display": "Action" },
                                            { "value": SceneElement.Character, "display": "Character" },
                                            { "value": SceneElement.Dialogue, "display": "Dialogue" },
                                            { "value": SceneElement.Parenthetical, "display": "Parenthetical" },
                                            { "value": SceneElement.Shot, "display": "Shot" },
                                            { "value": SceneElement.Transition, "display": "Transition" }
                                        ]

                                        MenuItem2 {
                                            focusPolicy: Qt.NoFocus
                                            text: modelData.display + "\t" + app.polishShortcutTextForDisplay("Ctrl+" + (index+1))
                                            enabled: sceneDocumentBinder.currentElement !== null
                                            onClicked: {
                                                sceneDocumentBinder.currentElement.type = modelData.value
                                                editorContextMenu.close()
                                            }
                                        }
                                    }
                                }

                                Menu2 {
                                    title: "Translate"
                                    enabled: sceneTextEditor.hasSelection

                                    Repeater {
                                        model: app.enumerationModel(app.transliterationEngine, "Language")

                                        MenuItem2 {
                                            focusPolicy: Qt.NoFocus
                                            visible: index >= 0
                                            enabled: modelData.value !== TransliterationEngine.English
                                            text: modelData.key
                                            onClicked: {
                                                editorContextMenu.close()
                                                sceneTextEditor.forceActiveFocus()
                                                sceneTextEditor.scene.beginUndoCapture()
                                                sceneTextEditor.Transliterator.transliterateToLanguage(sceneTextEditor.selectionStart, sceneTextEditor.selectionEnd, modelData.value)
                                                sceneTextEditor.scene.endUndoCapture()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MenuLoader {
                            id: doubleEnterMenu
                            enabled: !scriteDocument.readOnly
                            anchors.bottom: parent.bottom
                            property Scene currentScene: contentItem.theScene
                            menu: Menu2 {
                                width: 200
                                onAboutToShow: sceneTextEditor.persistentSelection = true
                                onAboutToHide: sceneTextEditor.persistentSelection = false
                                EventFilter.target: app
                                EventFilter.events: [6]
                                EventFilter.onFilter: {
                                    result.filter = true
                                    result.acceptEvent = true

                                    if(screenplayAdapter.isSourceScreenplay && event.key === Qt.Key_N) {
                                        newSceneMenuItem.handle()
                                        return
                                    }

                                    if(event.key === Qt.Key_H) {
                                        editHeadingMenuItem.handle()
                                        return
                                    }

                                    if(sceneDocumentBinder.currentElement === null) {
                                        result.filter = false
                                        result.acceptEvent = false
                                        sceneTextEditor.forceActiveFocus()
                                        doubleEnterMenu.close()
                                        return
                                    }

                                    switch(event.key) {
                                    case Qt.Key_A:
                                        sceneDocumentBinder.currentElement.type = SceneElement.Action
                                        break;
                                    case Qt.Key_C:
                                        sceneDocumentBinder.currentElement.type = SceneElement.Character
                                        break;
                                    case Qt.Key_D:
                                        sceneDocumentBinder.currentElement.type = SceneElement.Dialogue
                                        break;
                                    case Qt.Key_P:
                                        sceneDocumentBinder.currentElement.type = SceneElement.Parenthetical
                                        break;
                                    case Qt.Key_S:
                                        sceneDocumentBinder.currentElement.type = SceneElement.Shot
                                        break;
                                    case Qt.Key_T:
                                        sceneDocumentBinder.currentElement.type = SceneElement.Transition
                                        break;
                                    default:
                                        result.filter = false
                                        result.acceptEvent = false
                                    }

                                    sceneTextEditor.forceActiveFocus()
                                    doubleEnterMenu.close()
                                }

                                MenuItem2 {
                                    id: editHeadingMenuItem
                                    text: "&Heading (H)"
                                    onClicked: handle()

                                    function handle() {
                                        if(currentScene.heading.enabled === false)
                                            currentScene.heading.enabled = true
                                        sceneHeadingAreaLoader.edit()
                                        doubleEnterMenu.close()
                                    }
                                }

                                Repeater {
                                    model: [
                                        { "value": SceneElement.Action, "display": "Action" },
                                        { "value": SceneElement.Character, "display": "Character" },
                                        { "value": SceneElement.Dialogue, "display": "Dialogue" },
                                        { "value": SceneElement.Parenthetical, "display": "Parenthetical" },
                                        { "value": SceneElement.Shot, "display": "Shot" },
                                        { "value": SceneElement.Transition, "display": "Transition" }
                                    ]

                                    MenuItem2 {
                                        text: modelData.display + " (" + modelData.display[0] + ")"
                                        onClicked: {
                                            if(sceneDocumentBinder.currentElement)
                                                sceneDocumentBinder.currentElement.type = modelData.value
                                            sceneTextEditor.forceActiveFocus()
                                            doubleEnterMenu.close()
                                        }
                                    }
                                }

                                MenuSeparator { }

                                MenuItem2 {
                                    id: newSceneMenuItem
                                    text: "&New Scene (N)"
                                    onClicked: handle()
                                    enabled: screenplayAdapter.isSourceScreenplay

                                    function handle() {
                                        currentScene.removeLastElementIfEmpty()
                                        scriteDocument.createNewScene()
                                        doubleEnterMenu.close()
                                    }
                                }
                            }
                        }
                    }

                    QtObject {
                        ShortcutsModelItem.priority: 1
                        ShortcutsModelItem.enabled: sceneTextEditor.activeFocus
                        ShortcutsModelItem.visible: sceneTextEditor.activeFocus
                        ShortcutsModelItem.group: "Formatting"
                        ShortcutsModelItem.title: sceneDocumentBinder.nextTabFormatAsString
                        ShortcutsModelItem.shortcut: "Tab"
                    }

                    QtObject {
                        ShortcutsModelItem.priority: 1
                        ShortcutsModelItem.enabled: sceneTextEditor.activeFocus
                        ShortcutsModelItem.visible: sceneTextEditor.activeFocus
                        ShortcutsModelItem.group: "Formatting"
                        ShortcutsModelItem.title: {
                            if( (binder.currentElement === null || binder.currentElement.text === "") && completer.suggestion !== "")
                                return "Show Format Menu"
                            if( completer.suggestion !== "" )
                                return "Auto Complete"
                            return "Create New Paragraph"
                        }
                        ShortcutsModelItem.shortcut: "Enter"
                    }

                    QtObject {
                        ShortcutsModelItem.priority: 1
                        ShortcutsModelItem.enabled: sceneTextEditor.activeFocus
                        ShortcutsModelItem.visible: sceneTextEditor.activeFocus
                        ShortcutsModelItem.group: "Formatting"
                        ShortcutsModelItem.title: "Split Scene"
                        ShortcutsModelItem.shortcut: "Ctrl+Enter"
                    }

                    Keys.onTabPressed: sceneDocumentBinder.tab()
                    Keys.onBacktabPressed: sceneDocumentBinder.backtab()

                    // Double enter menu and split-scene handling.
                    Keys.onReturnPressed: {
                        if(event.modifiers & Qt.ControlModifier) {
                            contentItem.splitScene()
                            event.accepted = true
                            return
                        }

                        if( (binder.currentElement === null || binder.currentElement.text === "") && completer.suggestion === "" ) {
                            doubleEnterMenu.show()
                            event.accepted = true
                        } else if(completer.suggestion !== "") {
                            userIsTyping = false
                            insert(cursorPosition, completer.suggestion)
                            userIsTyping = true
                            Transliterator.enableFromNextWord()
                            event.accepted = true
                        } else
                            event.accepted = false
                    }

                    // Context menu
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        enabled: !scriteDocument.readOnly && contextMenuEnableBinder.get
                        cursorShape: Qt.IBeamCursor
                        onClicked: {
                            mouse.accept = true
                            sceneTextEditor.persistentSelection = true
                            if(!sceneTextEditor.hasSelection && sceneDocumentBinder.spellCheckEnabled) {
                                sceneTextEditor.cursorPosition = sceneTextEditor.positionAt(mouse.x, mouse.y)
                                if(sceneDocumentBinder.wordUnderCursorIsMisspelled) {
                                    spellingSuggestionsMenu.popup()
                                    return
                                }
                            }
                            editorContextMenu.popup()
                        }

                        DelayedPropertyBinder {
                            id: contextMenuEnableBinder
                            initial: false
                            set: !editorContextMenu.active && !spellingSuggestionsMenu.active && sceneTextEditor.activeFocus
                            delay: 100
                        }
                    }

                    // Scrolling up and down
                    Keys.onUpPressed: {
                        if(sceneDocumentBinder.canGoUp())
                            event.accepted = false
                        else {
                            event.accepted = true
                            contentItem.scrollToPreviousScene()
                        }
                    }
                    Keys.onDownPressed: {
                        if(sceneDocumentBinder.canGoDown())
                            event.accepted = false
                        else {
                            event.accepted = true
                            contentItem.scrollToNextScene()
                        }
                    }
                    Keys.onPressed: {
                        if(event.key === Qt.Key_PageUp) {
                            event.accepted = true
                            contentItem.scrollToPreviousScene()
                        } else if(event.key === Qt.Key_PageDown) {
                            event.accepted = true
                            contentItem.scrollToNextScene()
                        } else
                            event.accepted = false
                    }

                    // Search & Replace
                    TextDocumentSearch {
                        id: textDocumentSearch
                        textDocument: sceneTextEditor.textDocument
                        searchString: sceneDocumentBinder.documentLoadCount > 0 ? (contentItem.theElement.userData ? contentItem.theElement.userData.searchString : "") : ""
                        currentResultIndex: searchResultCount > 0 ? (contentItem.theElement.userData ? contentItem.theElement.userData.sceneResultIndex : -1) : -1
                        onHighlightText: selection = {"start": start, "end": end}
                        onClearHighlight: selection = { "start": -1, "end": -1 }

                        property var selection: { "start": -1, "end": -1 }
                        property int loadCount: sceneDocumentBinder.documentLoadCount

                        onLoadCountChanged: highlightSearchResultTextSnippet()
                        onSelectionChanged: highlightSearchResultTextSnippet()

                        function highlightSearchResultTextSnippet() {
                            if(selection.start >= 0 && selection.end >= 0) {
                                var rect = app.uniteRectangles( sceneTextEditor.positionToRectangle(selection.start),
                                                               sceneTextEditor.positionToRectangle(selection.end) )
                                rect = app.adjustRectangle(rect, -20, -50, 20, 50)
                                contentView.ensureVisible(contentItem, rect)

                                sceneTextEditor.select(selection.start, selection.end)
                                sceneTextEditor.update()
                            } else {
                                sceneTextEditor.deselect()
                            }
                        }
                    }

                    Connections {
                        target: searchAgents.count > 0 ? searchAgents.itemAt(0).SearchAgent : null
                        ignoreUnknownSignals: true
                        onReplaceCurrentRequest: {
                            if(textDocumentSearch.currentResultIndex >= 0) {
                                contentItem.theScene.beginUndoCapture()
                                textDocumentSearch.replace(replacementText)
                                contentItem.theScene.endUndoCapture()
                            }
                        }
                    }
                }
            }

            function assumeFocus() {
                if(!sceneTextEditor.activeFocus)
                    sceneTextEditor.forceActiveFocus()
            }

            function splitScene() {
                var newElement = screenplayAdapter.splitElement(contentItem.theElement, sceneDocumentBinder.currentElement, sceneDocumentBinder.currentElementCursorPosition)
                if(newElement !== null) {
                    app.execLater(contentItem, 100, function() {
                        var delegate = contentView.itemAtIndex(contentItem.theIndex+1)
                        delegate.item.assumeFocus()
                    })
                }
            }

            function assumeFocusAt(pos) {
                if(!sceneTextEditor.activeFocus)
                    sceneTextEditor.forceActiveFocus()
                if(pos < 0)
                    sceneTextEditor.cursorPosition = sceneDocumentBinder.lastCursorPosition()
                else
                    sceneTextEditor.cursorPosition = pos
            }

            function scrollToPreviousScene() {
                var idx = screenplayAdapter.previousSceneElementIndex()
                if(idx === 0 && idx === theIndex) {
                    contentView.scrollToFirstScene()
                    assumeFocusAt(0)
                    return
                }

                contentView.scrollIntoView(idx)
                var item = contentView.itemAtIndex(idx).item
                item.assumeFocusAt(-1)
            }

            function scrollToNextScene() {
                var idx = screenplayAdapter.nextSceneElementIndex()
                if(idx === screenplayAdapter.elementCount-1 && idx === theIndex) {
                    contentView.positionViewAtEnd()
                    assumeFocusAt(-1)
                    return
                }

                contentView.scrollIntoView(idx)
                var item = contentView.itemAtIndex(idx).item
                item.assumeFocusAt(0)
            }
        }
    }

    Component {
        id: sceneHeadingArea

        Rectangle {
            id: headingItem
            property Scene theScene
            property bool sceneHasFocus: false
            property ScreenplayElement theElement
            property TextArea sceneTextEditor

            function edit() {
                if(theScene.heading.enabled)
                    sceneHeadingLoader.viewOnly = false
            }

            height: sceneHeadingLayout.height + 16
            color: Qt.tint(theScene.color, "#E7FFFFFF")

            Item {
                width: ruler.leftMarginPx
                height: sceneHeadingLoader.height + 16

                Text {
                    font: headingFontMetrics.font
                    text: "[" + theElement.sceneNumber + "]"
                    height: sceneHeadingLoader.height
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: parent.width * 0.075
                    visible: theElement.sceneNumber > 0 && screenplayAdapter.isSourceScreenplay
                }

                SceneTypeImage {
                    width: sceneHeadingLoader.height
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: parent.width * 0.2
                    sceneType: headingItem.theScene.type
                }
            }

            Column {
                id: sceneHeadingLayout
                spacing: sceneCharactersListLoader.active ? 5 : 0
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: ruler.leftMarginPx
                anchors.rightMargin: ruler.rightMarginPx
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    spacing: 5
                    width: parent.width

                    Loader {
                        id: sceneHeadingLoader
                        width: parent.width - sceneMenuButton.width - parent.spacing
                        height: item ? item.contentHeight : headingFontMetrics.lineSpacing
                        property bool viewOnly: true
                        property SceneHeading sceneHeading: headingItem.theScene.heading
                        property TextArea sceneTextEditor: headingItem.sceneTextEditor
                        sourceComponent: {
                            if(scriteDocument.readOnly)
                                return sceneHeading.enabled ? sceneHeadingViewer : sceneHeadingDisabled
                            if(sceneHeading.enabled)
                                return viewOnly ? sceneHeadingViewer : sceneHeadingEditor
                            return sceneHeadingDisabled
                        }

                        Connections {
                            target: sceneHeadingLoader.item
                            ignoreUnknownSignals: true
                            onEditRequest: sceneHeadingLoader.viewOnly = false
                            onEditingFinished: sceneHeadingLoader.viewOnly = true
                        }
                    }

                    ToolButton3 {
                        id: sceneMenuButton
                        iconSource: "../icons/navigation/menu.png"
                        ToolTip.text: "Click here to view scene options menu."
                        ToolTip.delay: 1000
                        onClicked: sceneMenu.visible = true
                        down: sceneMenu.visible
                        anchors.verticalCenter: parent.verticalCenter
                        width: headingFontMetrics.lineSpacing
                        height: headingFontMetrics.lineSpacing
                        visible: enabled
                        enabled: !scriteDocument.readOnly

                        Item {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right

                            Menu2 {
                                id: sceneMenu
                                MenuItem2 {
                                    action: Action {
                                        text: "Scene Heading"
                                        checkable: true
                                        checked: headingItem.theScene.heading.enabled
                                    }
                                    onTriggered: {
                                        headingItem.theScene.heading.enabled = action.checked
                                        sceneMenu.close()
                                    }
                                }

                                ColorMenu {
                                    title: "Color"
                                    onMenuItemClicked: {
                                        headingItem.theScene.color = color
                                        sceneMenu.close()
                                    }
                                }

                                Menu2 {
                                    title: "Mark Scene As"

                                    Repeater {
                                        model: app.enumerationModel(headingItem.theScene, "Type")

                                        MenuItem2 {
                                            text: modelData.key
                                            font.bold: headingItem.theScene.type === modelData.value
                                            onTriggered: headingItem.theScene.type = modelData.value
                                        }
                                    }
                                }

                                MenuItem2 {
                                    text: "Remove"
                                    enabled: screenplayAdapter.screenplay === scriteDocument.screenplay
                                    onClicked: {
                                        sceneMenu.close()
                                        scriteDocument.screenplay.removeSceneElements(headingItem.theScene)
                                    }
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: sceneCharactersListLoader
                    width: parent.width
                    readonly property bool editorHasActiveFocus: headingItem.sceneHasFocus
                    property Scene scene: headingItem.theScene
                    active: screenplayEditorSettings.displaySceneCharacters
                    sourceComponent: sceneCharactersList
                }
            }
        }
    }

    FontMetrics {
        id: defaultFontMetrics
        readonly property SceneElementFormat format: scriteDocument.formatting.elementFormat(SceneElement.Action)
        font: format ? format.font2 : scriteDocument.formatting.defaultFont2
    }

    FontMetrics {
        id: headingFontMetrics
        readonly property SceneElementFormat format: scriteDocument.formatting.elementFormat(SceneElement.Heading)
        font: format.font2
    }

    Component {
        id: sceneHeadingDisabled

        Item {
            property real contentHeight: headingFontMetrics.lineSpacing

            Text {
                text: "no scene heading"
                anchors.verticalCenter: parent.verticalCenter
                color: primaryColors.c10.text
                font: headingFontMetrics.font
                opacity: 0.25
            }
        }
    }

    Component {
        id: sceneHeadingEditor

        Item {
            property real contentHeight: height
            height: layout.height + 4
            Component.onCompleted: {
                locTypeEdit.forceActiveFocus()
            }

            signal editingFinished()

            property bool hasFocus: locTypeEdit.activeFocus || locTypeEdit.showingSymbols ||
                                    locEdit.activeFocus || locEdit.showingSymbols ||
                                    momentEdit.activeFocus || momentEdit.showingSymbols
            onHasFocusChanged: {
                if(!hasFocus)
                    editingFinished()
            }

            Row {
                id: layout
                anchors.left: parent.left
                anchors.right: parent.right

                TextField2 {
                    id: locTypeEdit
                    font: headingFontMetrics.font
                    width: Math.max(contentWidth, 80)
                    anchors.verticalCenter: parent.verticalCenter
                    text: sceneHeading.locationType
                    completionStrings: scriteDocument.structure.standardLocationTypes()
                    enableTransliteration: true
                    onEditingComplete: sceneHeading.locationType = text
                    tabItem: locEdit
                    includeEmojiSymbols: false
                }

                Text {
                    id: sep1Text
                    font: headingFontMetrics.font
                    text: ". "
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextField2 {
                    id: locEdit
                    font: headingFontMetrics.font
                    width: parent.width - locTypeEdit.width - sep1Text.width - momentEdit.width - sep2Text.width
                    anchors.verticalCenter: parent.verticalCenter
                    text: sceneHeading.location
                    enableTransliteration: true
                    completionStrings: scriteDocument.structure.allLocations()
                    onEditingComplete: sceneHeading.location = text
                    tabItem: momentEdit
                    includeEmojiSymbols: false
                }

                Text {
                    id: sep2Text
                    font: headingFontMetrics.font
                    text: "- "
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextField2 {
                    id: momentEdit
                    font: headingFontMetrics.font
                    width: Math.max(contentWidth, 150);
                    anchors.verticalCenter: parent.verticalCenter
                    text: sceneHeading.moment
                    enableTransliteration: true
                    completionStrings: scriteDocument.structure.standardMoments()
                    onEditingComplete: sceneHeading.moment = text
                    tabItem: sceneTextEditor
                    includeEmojiSymbols: false
                }
            }
        }
    }

    Component {
        id: sceneHeadingViewer

        Item {
            property real contentHeight: sceneHeadingText.contentHeight
            signal editRequest()

            Text {
                id: sceneHeadingText
                width: parent.width
                font: headingFontMetrics.font
                text: sceneHeading.text
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.WordWrap
                color: headingFontMetrics.format.textColor
            }

            MouseArea {
                anchors.fill: parent
                onClicked: parent.editRequest()
            }
        }
    }

    Component {
        id: sceneCharactersList

        Flow {
            spacing: 5
            flow: Flow.LeftToRight

            Text {
                id: sceneCharactersListHeading
                text: "Characters: "
                font.bold: true
                topPadding: 5
                bottomPadding: 5
                font.pointSize: 12
            }

            Repeater {
                model: scene ? scene.characterNames : 0

                TagText {
                    id: characterNameLabel
                    property var colors: {
                        if(containsMouse)
                            return accentColors.c900
                        return editorHasActiveFocus ? accentColors.c600 : accentColors.c10
                    }
                    border.width: editorHasActiveFocus ? 0 : 1
                    border.color: colors.text
                    color: colors.background
                    textColor: colors.text
                    text: modelData
                    leftPadding: 10
                    rightPadding: 10
                    topPadding: 2
                    bottomPadding: 2
                    font.pointSize: 12
                    closable: scene.isCharacterMute(modelData)
                    onClicked: requestCharacterMenu(modelData)
                    onCloseRequest: {
                        if(!scriteDocument.readOnly)
                            scene.removeMuteCharacter(modelData)
                    }
                }
            }

            Loader {
                id: newCharacterInput
                width: active && item ? Math.max(item.contentWidth, 100) : 0
                active: false
                sourceComponent: Item {
                    property alias contentWidth: textViewEdit.contentWidth
                    height: textViewEdit.height

                    TextViewEdit {
                        id: textViewEdit
                        width: parent.width
                        y: fontDescent
                        readOnly: false
                        font.capitalization: Font.AllUppercase
                        font.pointSize: 12
                        horizontalAlignment: Text.AlignLeft
                        wrapMode: Text.NoWrap
                        completionStrings: scriteDocument.structure.characterNames
                        onEditingFinished: {
                            scene.addMuteCharacter(text)
                            newCharacterInput.active = false
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.fontHeight - parent.fontAscent - parent.fontHeight*0.25
                            height: 1
                            color: accentColors.borderColor
                        }
                    }
                }
            }

            Image {
                source: "../icons/content/add_box.png"
                width: sceneCharactersListHeading.height
                height: sceneCharactersListHeading.height
                opacity: 0.5
                visible: enabled
                enabled: !scriteDocument.readOnly

                MouseArea {
                    ToolTip.text: "Click here to capture characters who don't have any dialogues in this scene, but are still required for the scene."
                    ToolTip.delay: 1000
                    ToolTip.visible: containsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onContainsMouseChanged: parent.opacity = containsMouse ? 1 : 0.5
                    onClicked: newCharacterInput.active = true
                }
            }
        }
    }

    Item {
        id: sidePanels
        anchors.top: screenplayEditorWorkspace.top
        anchors.left: parent.left
        anchors.bottom: statusBar.top
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        width: sceneListSidePanel.width // Math.max(sceneListSidePanel.width, notesSidePanel.width)
        property bool expanded: sceneListSidePanel.expanded
        onExpandedChanged: contentView.synopsisExpandCounter = 0

        SidePanel {
            id: sceneListSidePanel
            height: parent.height
            buttonY: 20
            buttonText: ""
            z: expanded ? 1 : 0

            content: Item {
                Text {
                    width: parent.width * 0.9
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 16
                    text: "Scene headings will be listed here as you add them into your screenplay."
                    anchors.horizontalCenter: sceneListView.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 50
                    visible: screenplayAdapter.elementCount === 0
                }

                ListView {
                    id: sceneListView
                    anchors.fill: parent
                    clip: true
                    model: screenplayAdapter
                    currentIndex: screenplayAdapter.currentIndex
                    ScrollBar.vertical: ScrollBar {
                        policy: sceneListView.contentHeight > sceneListView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        minimumSize: 0.1
                        palette {
                            mid: Qt.rgba(0,0,0,0.25)
                            dark: Qt.rgba(0,0,0,0.75)
                        }
                        opacity: active ? 1 : 0.2
                        Behavior on opacity {
                            enabled: screenplayEditorSettings.enableAnimations
                            NumberAnimation { duration: 250 }
                        }
                    }
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 0
                    highlightResizeDuration: 0

                    header: Rectangle {
                        width: sceneListView.width-1
                        height: 40
                        color: screenplayAdapter.currentIndex < 0 ? accentColors.windowColor : Qt.rgba(0,0,0,0)

                        Text {
                            readonly property real iconWidth: 18
                            property real t: screenplayAdapter.hasNonStandardScenes ? 1 : 0
                            property real leftMargin: 6 + (iconWidth+12)*t
                            Behavior on t {
                                enabled: screenplayEditorSettings.enableAnimations
                                NumberAnimation { duration: 250 }
                            }

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: leftMargin
                            font.family: "Courier Prime"
                            font.pixelSize: 14
                            font.bold: screenplayAdapter.currentIndex < 0
                            text: "[#] TITLE PAGE"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                screenplayAdapter.currentIndex = -1
                                contentView.positionViewAtBeginning()
                            }
                        }
                    }

                    delegate: Rectangle {
                        width: sceneListView.width-1
                        height: 40
                        color: scene ? Qt.tint(scene.color, (screenplayAdapter.currentIndex === index ? "#9CFFFFFF" : "#E7FFFFFF")) : Qt.rgba(0,0,0,0)

                        SceneTypeImage {
                            id: sceneTypeImage
                            width: 18
                            height: 18
                            showTooltip: false
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            sceneType: scene ? scene.type : Scene.Standard
                            opacity: (screenplayAdapter.currentIndex === index ? 1 : 0.5) * t
                            visible: t > 0
                            property real t: screenplayAdapter.hasNonStandardScenes ? 1 : 0
                            Behavior on t {
                                enabled: screenplayEditorSettings.enableAnimations
                                NumberAnimation { duration: 250 }
                            }
                        }

                        Text {
                            property real leftMargin: 6 + (sceneTypeImage.width+12)*sceneTypeImage.t
                            anchors.left: parent.left
                            anchors.leftMargin: leftMargin
                            anchors.right: parent.right
                            anchors.rightMargin: (sceneListView.contentHeight > sceneListView.height ? sceneListView.ScrollBar.vertical.width : 0) + 5
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: "Courier Prime"
                            font.bold: screenplayAdapter.currentIndex === index || screenplayElementType === ScreenplayElement.BreakElementType
                            font.pixelSize: screenplayElementType === ScreenplayElement.BreakElementType ? 16 : 14
                            font.letterSpacing: screenplayElementType === ScreenplayElement.BreakElementType ? 3 : 0
                            horizontalAlignment: screenplayElementType === ScreenplayElement.BreakElementType ? Qt.AlignHCenter : (scene && scene.heading.enabled ? Qt.AlignLeft : Qt.AlignRight)
                            color: screenplayElementType === ScreenplayElement.BreakElementType ? "gray" : "black"
                            text: {
                                if(scene && scene.heading.enabled)
                                    return "[" + screenplayElement.sceneNumber + "] " + (scene && scene.heading.enabled ? scene.heading.text : "")
                                if(screenplayElementType === ScreenplayElement.BreakElementType)
                                    return screenplayElement.sceneID
                                return "NO SCENE HEADING"
                            }
                            elide: Text.ElideMiddle
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: screenplayElementType === ScreenplayElement.SceneElementType
                            onClicked: navigateToScene()
                            onDoubleClicked: {
                                navigateToScene()
                                sceneListSidePanel.expanded = false
                            }

                            function navigateToScene() {
                                contentView.positionViewAtIndex(index, ListView.Beginning)
                                screenplayAdapter.currentIndex = index
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: screenplayPreview
        visible: globalScreenplayEditorToolbar.showScreenplayPreview
        active: globalScreenplayEditorToolbar.showScreenplayPreview
        anchors.fill: parent
        sourceComponent: Rectangle {
            color: primaryColors.windowColor

            Component.onCompleted: {
                app.execLater(screenplayTextDocument, 250, function() {
                    screenplayTextDocument2.print(screenplayImagePrinter)
                })
            }

            ScreenplayTextDocument {
                id: screenplayTextDocument2
                screenplay: screenplayTextDocument.screenplay
                formatting: screenplayTextDocument.formatting
                sceneNumbers: true
                titlePage: screenplayEditorSettings.includeTitlePageInPreview
                purpose: ScreenplayTextDocument.ForPrinting
                syncEnabled: false
            }

            ImagePrinter {
                id: screenplayImagePrinter
                scale: 2
            }

            Text {
                id: noticeText
                font.pixelSize: 30
                anchors.centerIn: parent
                text: "Generating preview ..."
                visible: screenplayImagePrinter.printing || (screenplayImagePrinter.pageCount === 0 && screenplayTextDocument.pageCount > 0)
            }

            Flickable {
                id: pageView
                anchors.fill: parent
                anchors.bottomMargin: statusBar.height
                contentWidth: pageViewContent.width
                contentHeight: pageViewContent.height
                clip: true

                ScrollBar.horizontal: ScrollBar {
                    policy: pageLayout.width > pageView.width ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    minimumSize: 0.1
                    palette {
                        mid: Qt.rgba(0,0,0,0.25)
                        dark: Qt.rgba(0,0,0,0.75)
                    }
                    opacity: active ? 1 : 0.2
                    Behavior on opacity {
                        enabled: screenplayEditorSettings.enableAnimations
                        NumberAnimation { duration: 250 }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: pageLayout.height > pageView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    minimumSize: 0.1
                    palette {
                        mid: Qt.rgba(0,0,0,0.25)
                        dark: Qt.rgba(0,0,0,0.75)
                    }
                    opacity: active ? 1 : 0.2
                    Behavior on opacity {
                        enabled: screenplayEditorSettings.enableAnimations
                        NumberAnimation { duration: 250 }
                    }
                }

                property real cellWidth: screenplayImagePrinter.pageWidth*previewZoomSlider.value + 40
                property real cellHeight: screenplayImagePrinter.pageHeight*previewZoomSlider.value + 40
                property int nrColumns: Math.max(Math.floor(width/cellWidth), 1)
                property int nrRows: Math.ceil(screenplayImagePrinter.pageCount / nrColumns)
                property int currentIndex: 0

                Item {
                    id: pageViewContent
                    width: Math.max(pageLayout.width, pageView.width)
                    height: pageLayout.height

                    Flow {
                        id: pageLayout
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: pageView.cellWidth * pageView.nrColumns
                        height: pageView.cellHeight * pageView.nrRows

                        Repeater {
                            id: pageRepeater

                            model: screenplayImagePrinter.printing ? null : screenplayImagePrinter
                            delegate: Item {
                                readonly property int pageIndex: index
                                width: pageView.cellWidth
                                height: pageView.cellHeight

                                property bool itemIsVisible: {
                                    var firstRow = Math.max(Math.floor(pageView.contentY / pageView.cellHeight), 0)
                                    var lastRow = Math.min(Math.ceil( (pageView.contentY+pageView.height)/pageView.cellHeight ), pageRepeater.count-1)
                                    var myRow = Math.floor(pageIndex/pageView.nrColumns)
                                    return firstRow <= myRow && myRow <= lastRow;
                                }

                                BoxShadow {
                                    anchors.fill: pageImage
                                    opacity: pageView.currentIndex === index ? 1 : 0.15
                                }

                                Rectangle {
                                    anchors.fill: pageImage
                                    color: "white"
                                }

                                Image {
                                    id: pageImage
                                    width: pageWidth*previewZoomSlider.value
                                    height: pageHeight*previewZoomSlider.value
                                    source: parent.itemIsVisible ? pageUrl : ""
                                    anchors.centerIn: parent
                                    smooth: true
                                    mipmap: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: pageView.currentIndex = index
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: statusBar.height
                color: statusBar.color
                border.width: statusBar.border.width
                border.color: statusBar.border.color

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    text: noticeText.visible ? "Generating preview ..." : ("Page " + (Math.max(pageView.currentIndex,0)+1) + " of " + pageRepeater.count)
                }

                ZoomSlider {
                    id: previewZoomSlider
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    from: 0.5; to: 2.5; value: 1
                }
            }
        }
    }

    function requestCharacterMenu(characterName) {
        if(characterMenu.characterReports.length === 0) {
            var reports = scriteDocument.supportedReports
            var chReports = []
            reports.forEach( function(item) {
                if(item.name.indexOf('Character') >= 0)
                    chReports.push(item)
            })
            characterMenu.characterReports = chReports
        }

        characterMenu.characterName = characterName
        characterMenu.popup()
    }

    Menu2 {
        id: characterMenu
        width: 300
        property string characterName
        property var characterReports: []

        Repeater {
            model: characterMenu.characterReports

            MenuItem2 {
                leftPadding: 15
                rightPadding: 15
                topPadding: 5
                bottomPadding: 5
                width: reportsMenu.width
                height: 65
                contentItem: Column {
                    id: menuContent
                    width: characterMenu.width - 30
                    spacing: 5

                    Text {
                        font.bold: true
                        font.pixelSize: 16
                        text: modelData.name
                    }

                    Text {
                        text: modelData.description
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                        font.italic: true
                    }
                }

                onClicked: {
                    reportGeneratorTimer.requestSource = this
                    reportGeneratorTimer.reportArgs = {"reportName": modelData.name, "configuration": {"characterNames": [characterMenu.characterName]}}
                    characterMenu.close()
                    characterMenu.characterName = ""
                }
            }
        }
    }

    Component {
        id: titleCardComponent

        Column {
            property int defaultFontSize: screenplayFormat.defaultFont2.pointSize
            spacing: 10 * zoomLevel

            Image { width: parent.width; height: 35 * zoomLevel }

            Image {
                property real maxWidth: parent.width - 2*ruler.leftMarginPx
                width: {
                    switch(scriteDocument.screenplay.coverPagePhotoSize) {
                    case Screenplay.SmallCoverPhoto:
                        return maxWidth / 4
                    case Screenplay.MediumCoverPhoto:
                        return maxWidth / 2
                    }
                    return maxWidth
                }

                source: visible ? "file:///" + scriteDocument.screenplay.coverPagePhoto : ""
                visible: scriteDocument.screenplay.coverPagePhoto !== ""
                smooth: true; mipmap: true
                fillMode: Image.PreserveAspectFit
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Image { width: parent.width; height: scriteDocument.screenplay.coverPagePhoto !== "" ? 20 * zoomLevel : 0 }

            Column {
                width: parent.width
                spacing: parent.spacing/1

                Text {
                    font.family: scriteDocument.formatting.defaultFont.family
                    font.pointSize: defaultFontSize + 2
                    font.bold: true
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    text: scriteDocument.screenplay.title === "" ? "<untitled>" : scriteDocument.screenplay.title
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    font.family: scriteDocument.formatting.defaultFont.family
                    font.pointSize: defaultFontSize
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    text: scriteDocument.screenplay.subtitle
                    visible: scriteDocument.screenplay.subtitle !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                font.family: scriteDocument.formatting.defaultFont.family
                font.pointSize: defaultFontSize
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: "Written By\n" + (scriteDocument.screenplay.author === "" ? "<unknown author>" : scriteDocument.screenplay.author)
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                font.family: scriteDocument.formatting.defaultFont.family
                font.pointSize: defaultFontSize
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: scriteDocument.screenplay.version === "" ? "Initial Version" : scriteDocument.screenplay.version
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                font.family: scriteDocument.formatting.defaultFont.family
                font.pointSize: defaultFontSize
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: scriteDocument.screenplay.basedOn
                visible: scriteDocument.screenplay.basedOn !== ""
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Column {
                spacing: parent.spacing/2
                width: parent.width * 0.5
                anchors.left: parent.left
                anchors.leftMargin: ruler.leftMarginPx

                Item {
                    width: parent.width
                    height: 20 * zoomLevel
                }

                Text {
                    font.family: scriteDocument.formatting.defaultFont.family
                    font.pointSize: defaultFontSize - 2
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: scriteDocument.screenplay.contact
                    visible: text !== ""
                }

                Text {
                    font.family: scriteDocument.formatting.defaultFont.family
                    font.pointSize: defaultFontSize - 2
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: scriteDocument.screenplay.address
                    visible: text !== ""
                }

                Text {
                    font.family: scriteDocument.formatting.defaultFont.family
                    font.pointSize: defaultFontSize - 2
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: scriteDocument.screenplay.phoneNumber
                    visible: text !== ""
                }

                Text {
                    font.family: scriteDocument.formatting.defaultFont.family
                    font.pointSize: defaultFontSize - 2
                    font.underline: true
                    color: "blue"
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: scriteDocument.screenplay.email
                    visible: text !== ""

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Qt.openUrlExternally("mailto:" + parent.text)
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Text {
                    font.family: scriteDocument.formatting.defaultFont.family
                    font.pointSize: defaultFontSize - 2
                    font.underline: true
                    color: "blue"
                    width: parent.width
                    elide: Text.ElideRight
                    text: scriteDocument.screenplay.website
                    visible: text !== ""

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Qt.openUrlExternally(parent.text)
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            Image { width: parent.width; height: 35 * zoomLevel }
        }
    }
}
