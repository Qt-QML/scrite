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

import QtQuick 2.13
import QtMultimedia 5.13
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.13
import Qt.labs.settings 1.0
import QtQuick.Controls 2.13
import QtQuick.Controls.Material 2.12

import Scrite 1.0

Item {
    id: scritedView

    property int skipDuration: 10*1000

    Settings {
        id: scritedViewSettings
        fileName: app.settingsFilePath
        category: "Scrited"
        property string lastOpenScritedFolderUrl: "file:///" + StandardPaths.writableLocation(StandardPaths.MoviesLocation)
    }

    FileDialog {
        id: fileDialog
        folder: scritedViewSettings.lastOpenScritedFolderUrl
        onFolderChanged: scritedViewSettings.lastOpenScritedFolderUrl = folder
        selectFolder: false
        selectMultiple: false
        selectExisting: true
        onAccepted: {
            mediaPlayer.source = fileUrl
            mediaPlayer.play()
        }
    }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal
        Material.background: Qt.darker(primaryColors.button.background, 1.1)

        Item {
            SplitView.preferredWidth: scritedView.width * 0.50

            SplitView {
                anchors.fill: parent
                orientation: Qt.Vertical

                Rectangle {
                    SplitView.preferredHeight: scritedView.height * 0.4
                    color: "black"

                    MediaPlayer {
                        id: mediaPlayer
                        notifyInterval: 250
                        function togglePlayback() {
                            if(status == MediaPlayer.NoMedia)
                                return

                            if(playbackState === MediaPlayer.PlayingState)
                                pause()
                            else
                                play()
                        }
                    }

                    VideoOutput {
                        id: videoOutput
                        source: mediaPlayer
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectFit
                    }

                    Rectangle {
                        id: mediaPlayerControls
                        width: parent.width * 0.9
                        radius: 6
                        height: mediaPlayerControlsLayout.height+2*radius
                        anchors.bottomMargin: 10
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Qt.rgba(0,0,0,0.25)
                        visible: mediaPlayerMouseArea.containsMouse

                        MouseArea {
                            anchors.fill: mediaPlayerControlsLayout
                            onClicked: {
                                var pos = Math.abs((mouse.x/width) * mediaPlayer.duration)
                                mediaPlayer.seek(pos)
                            }
                        }

                        Column {
                            id: mediaPlayerControlsLayout
                            width: parent.width-2*parent.radius
                            spacing: 5
                            anchors.centerIn: parent

                            Item {
                                width: parent.width
                                height: 20
                                enabled: mediaPlayer.status !== MediaPlayer.NoMedia

                                Rectangle {
                                    height: 2
                                    width: parent.width
                                    color: enabled ? "white" : "gray"
                                    anchors.centerIn: parent
                                }

                                Rectangle {
                                    width: 5
                                    height: parent.height
                                    color: enabled ? "white" : "gray"
                                    x: ((mediaPlayer.position / mediaPlayer.duration) * parent.width) - width/2
                                    onXChanged: {
                                        if(positionHandleMouseArea.drag.active) {
                                            var pos = Math.abs(((x + width/2)/parent.width) * mediaPlayer.duration)
                                            mediaPlayer.seek(pos)
                                        }
                                    }

                                    MouseArea {
                                        id: positionHandleMouseArea
                                        anchors.fill: parent
                                        drag.target: parent
                                        drag.axis: Drag.XAxis
                                    }
                                }
                            }

                            RowLayout {
                                width: parent.width

                                ToolButton2 {
                                    icon.source: "../icons/file/folder_open_inverted.png"
                                    onClicked: fileDialog.open()
                                    suggestedHeight: 36
                                    ToolTip.text: "Load a video file for this screenplay."
                                    focusPolicy: Qt.NoFocus
                                }

                                ToolButton2 {
                                    icon.source: {
                                        if(mediaPlayer.playbackState === MediaPlayer.PlayingState)
                                            return "../icons/mediaplayer/pause_inverted.png"
                                        return "../icons/mediaplayer/play_arrow_inverted.png"
                                    }
                                    onClicked: mediaPlayer.togglePlayback()
                                    enabled: mediaPlayer.status !== MediaPlayer.NoMedia
                                    suggestedHeight: 36
                                    ToolTip.text: "Play / Pause"
                                    focusPolicy: Qt.NoFocus
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    width: parent.width
                                    opacity: mediaPlayer.status !== MediaPlayer.NoMedia ? 1 : 0
                                    enabled: mediaPlayer.status !== MediaPlayer.NoMedia
                                    horizontalAlignment: Text.AlignHCenter
                                    color: "white"
                                    font.pointSize: 16
                                    font.family: "Courier Prime"
                                    text: {
                                        var msToTime = function(ms) {
                                            var secs = Math.round(ms/1000)
                                            var second = secs%60
                                            var minute = ((secs-second)/60)%60
                                            var hour = (secs - minute*60 - second)/3600
                                            if(hour > 0)
                                                return hour + ":" + minute + ":" + second
                                            return minute + ":" + second
                                        }
                                        return msToTime(mediaPlayer.position) + " / " + msToTime(mediaPlayer.duration)
                                    }
                                }

                                ToolButton2 {
                                    icon.source: "../icons/mediaplayer/rewind_10_inverted.png"
                                    enabled: mediaPlayer.status !== MediaPlayer.NoMedia && mediaPlayer.position > 0
                                    suggestedHeight: 36
                                    onClicked: mediaPlayer.seek( Math.max(mediaPlayer.position-skipDuration, 0 ) )
                                    ToolTip.text: "Rewind by " + (skipDuration/1000) + " seconds"
                                    focusPolicy: Qt.NoFocus
                                }

                                ToolButton2 {
                                    icon.source: "../icons/mediaplayer/forward_10_inverted.png"
                                    enabled: mediaPlayer.status !== MediaPlayer.NoMedia && mediaPlayer.position < mediaPlayer.duration
                                    suggestedHeight: 36
                                    onClicked: mediaPlayer.seek( Math.min(mediaPlayer.position+skipDuration, mediaPlayer.duration) )
                                    ToolTip.text: "Forward by " + (skipDuration/1000) + " seconds"
                                    focusPolicy: Qt.NoFocus
                                }
                            }
                        }
                    }

                    EventFilter.active: true
                    EventFilter.acceptHoverEvents: true
                    EventFilter.events: [127,128,129] // [HoverEnter, HoverLeave, HoverMove]
                    EventFilter.onFilter: mediaPlayerControls.visible = event.type === 127 || event.type === 129
                }

                ScreenplayPreview {
                    id: screenplayPreview
                    SplitView.fillHeight: true
                    fitPageToWidth: true
                    purpose: ScreenplayTextDocument.ForDisplay
                    onCurrentOffsetChanged: screenplaySplitsView.currentIndex = row
                }
            }
        }

        Rectangle {
            SplitView.fillWidth: true
            color: primaryColors.c100.background

            Row {
                id: screenplaySplitsHeading
                width: screenplaySplitsView.width-(screenplaySplitsView.scrollBarVisible ? 20 : 1)
                visible: screenplaySplitsView.count > 0

                Text {
                    padding: 5
                    width: parent.width * 0.1
                    text: "Scene #"
                    font.bold: true
                    font.family: "Courier Prime"
                    font.pointSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                }

                Text {
                    padding: 5
                    width: parent.width * 0.6
                    font.bold: true
                    text: "Scene Heading"
                    font.family: "Courier Prime"
                    font.pointSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                }

                Text {
                    padding: 5
                    width: parent.width * 0.1
                    font.bold: true
                    text: "Page #"
                    font.family: "Courier Prime"
                    font.pointSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                }

                Text {
                    padding: 5
                    width: parent.width * 0.2
                    font.bold: true
                    text: "Time"
                    font.family: "Courier Prime"
                    font.pointSize: 16
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                anchors.bottom: screenplaySplitsHeading.bottom
                color: primaryColors.borderColor
                visible: screenplaySplitsHeading.visible
            }

            ListView {
                id: screenplaySplitsView
                anchors.top: screenplaySplitsHeading.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                model: screenplayPreview.textDocumentOffsets
                clip: true
                property bool scrollBarVisible: contentHeight > height
                ScrollBar.vertical: ScrollBar {
                    policy: screenplaySplitsView.scrollBarVisible ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
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
                highlight: Rectangle {
                    color: primaryColors.highlight.background
                }
                delegate: Item {
                    // Columns: SceneNr, Heading, PageNumber, Time
                    width: screenplaySplitsView.width-(screenplaySplitsView.scrollBarVisible ? 20 : 1)
                    height: 40

                    Row {
                        anchors.fill: parent

                        Text {
                            padding: 5
                            width: parent.width * 0.1
                            text: offsetInfo.sceneNumber
                            horizontalAlignment: Text.AlignHCenter
                            font.family: "Courier Prime"
                            font.pointSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            padding: 5
                            width: parent.width * 0.6
                            text: offsetInfo.sceneHeading
                            font.family: "Courier Prime"
                            font.pointSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideMiddle
                        }

                        Text {
                            padding: 5
                            width: parent.width * 0.1
                            text: offsetInfo.pageNumber
                            font.family: "Courier Prime"
                            font.pointSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            padding: 5
                            width: parent.width * 0.2
                            text: offsetInfo.sceneTime.text
                            font.family: "Courier Prime"
                            font.pointSize: 14
                            horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            screenplaySplitsView.currentIndex = index
                            scriteDocument.screenplay.currentElementIndex = offsetInfo.sceneIndex
                            if(mediaPlayer.status !== MediaPlayer.NoMedia)
                                mediaPlayer.seek(offsetInfo.sceneTime.position)
                        }
                    }
                }

                property int offsetCount: screenplayPreview.textDocumentOffsets.count
                onOffsetCountChanged: Qt.callLater(initialize)
                function initialize() {
                    if(count === 0) {
                        screenplaySplitsView.currentIndex = -1
                        return
                    }
                    scrollToRow(0)
                }

                function scrollToRow(row, seekMedia) {
                    if(currentIndex === row)
                        return
                    var offsetInfo = screenplayPreview.textDocumentOffsets.offsetInfoAt(row)
                    currentIndex = offsetInfo.row
                    scriteDocument.screenplay.currentElementIndex = offsetInfo.sceneIndex
                    if(seekMedia !== false && mediaPlayer.status !== MediaPlayer.NoMedia)
                        mediaPlayer.seek(offsetInfo.sceneTime.position)
                }
            }
        }
    }

    EventFilter.target: qmlWindow
    EventFilter.events: [6] // KeyPress
    EventFilter.onFilter: {
        switch(event.key) {
        case Qt.Key_Space:
            mediaPlayer.togglePlayback()
            break
        case Qt.Key_Up:
            if(event.controlModifier)
                screenplaySplitsView.scrollToRow(Math.max(screenplaySplitsView.currentIndex-1,0))
            else
                screenplayPreview.contentY = Math.max(screenplayPreview.contentY - (event.altModifier ? screenplayPreview.pageHeight : screenplayPreview.lineHeight), 0)
            break
        case Qt.Key_Down:
            if(event.controlModifier)
                screenplaySplitsView.scrollToRow(Math.min(screenplaySplitsView.currentIndex+1,screenplaySplitsView.count-1))
            else
                screenplayPreview.contentY = Math.min(screenplayPreview.contentY + (event.altModifier ? screenplayPreview.pageHeight : screenplayPreview.lineHeight), screenplayPreview.contentHeight-screenplayPreview.height)
            break
        case Qt.Key_Left:
            if(event.controlModifier)
                mediaPlayer.seek( Math.max(mediaPlayer.position-skipDuration, 0 ) )
            else
                mediaPlayer.seek( Math.max(mediaPlayer.position-500, 0) )
            break
        case Qt.Key_Right:
            if(event.controlModifier)
                mediaPlayer.seek( Math.min(mediaPlayer.position+skipDuration, mediaPlayer.duration) )
            else
                mediaPlayer.seek( Math.min(mediaPlayer.position+500, mediaPlayer.duration) )
            break
        case Qt.Key_Greater:
        case Qt.Key_Period:
            // TODO: apply time offset from the media player and update
            // the Offsets model. Have the model class store the offsets into a file.
        }
    }
}
