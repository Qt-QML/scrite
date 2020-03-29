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

import QtQuick 2.13
import QtQuick.Controls 2.13
import Scrite 1.0

Item {
    property var tabColors: ["#6600cc", "#ff3300", "#0000cc", "#993300", "#006600", "#660066", "#003300", "#6600ff", "#999966"]

    Image {
        anchors.fill: parent
        source: "../images/notebookpage.jpg"
        fillMode: Image.Stretch
        smooth: true
        opacity: 0.5
    }

    ListView {
        id: notebookTabsView
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 3
        width: 50
        model: scriteDocument.structure.characterCount + 1
        spacing: 3
        currentIndex: 0
        footer: Item {
            width: notebookTabsView.width
            height: width

            RoundButton {
                anchors.centerIn: parent
                hoverEnabled: true
                icon.source: "../icons/navigation/refresh.png"
                onClicked: {
                    modalDialog.popupSource = this
                    modalDialog.sourceComponent = newCharactersDialogUi
                    modalDialog.active = true
                }
                ToolTip.text: "Click this button to detect characters in your screenplay and create sections for a subset of them in this notebook."
                ToolTip.visible: hovered
            }
        }

        delegate: Rectangle {
            width: notebookTabsView.width
            height: textItem.width + 20
            color: selected ? tabColor : Qt.tint(tabColor, "#C0FFFFFF")
            border { width: 1; color: "lightgray" }
            radius: 8

            property color tabColor: tabColors[ index%tabColors.length ]
            property bool selected: notebookTabsView.currentIndex === index
            property Character character: index === 0 ? null : scriteDocument.structure.characterAt(index-1)
            property string label: index === 0 ? "Story" : character.name

            Text {
                id: textItem
                rotation: 90
                text: parent.label
                anchors.centerIn: parent
                font.pixelSize: parent.selected ? 20 : 18
                font.bold: parent.selected
                color: parent.selected ? "white" : "black"
                Behavior on font.pixelSize { NumberAnimation { duration: 250 } }
                Behavior on color { ColorAnimation { duration: 125 } }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: index === 0 ? Qt.LeftButton : (Qt.LeftButton|Qt.RightButton)
                onClicked: {
                    notebookTabsView.currentIndex = index
                    if(mouse.button === Qt.RightButton) {
                        characterItemMenu.character = character
                        characterItemMenu.popup(this)
                    }
                }
            }
        }
    }

    Menu {
        id: characterItemMenu
        property Character character

        MenuItem {
            text: "Remove Section"
            onClicked: {
                scriteDocument.structure.removeCharacter(characterItemMenu.character)
                characterItemMenu.close()
            }
        }
    }

    property var notesPack: notebookTabsView.currentIndex <= 0 ? scriteDocument.structure : scriteDocument.structure.characterAt(notebookTabsView.currentIndex-1)

    ScrollView {
        id: notesScrollView
        anchors.left: parent.left
        anchors.right: notebookTabsView.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 5
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AlwaysOn

        GridView {
            id: notesGrid
            width: notesScrollView.width

            property real minimumCellWidth: 340
            property int nrCells: Math.floor(width/minimumCellWidth)

            cellWidth: width/nrCells
            cellHeight: 400

            model: notesPack.noteCount+1

            delegate: Loader {
                width: notesGrid.cellWidth
                height: notesGrid.cellHeight
                property int noteIndex: index < notesPack.noteCount ? index : -1
                sourceComponent: noteIndex >= 0 ? noteDelegate : newNoteDelegate
                active: true
            }
        }
    }

    Loader {
        anchors.left: notesScrollView.left
        anchors.right: notesScrollView.right
        anchors.bottom: notesScrollView.bottom
        anchors.top: notesScrollView.verticalCenter
        active: notesPack.noteCount === 0
        sourceComponent: Item {
            Text {
                anchors.fill: parent
                anchors.margins: 30
                font.pixelSize: 30
                font.letterSpacing: 1
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                lineHeight: 2
                text: {
                    if(notebookTabsView.currentIndex > 0)
                        return "You can capture your thoughts, ideas and research related to '<b>" + notesPack.name + "</b>' here.";
                    return "You can capture your thoughts, ideas and research about your screenplay here.";
                }
            }
        }
    }

    Component {
        id: noteDelegate

        Item {
            id: noteItem
            property Note note: notesPack.noteAt(noteIndex)

            Loader {
                anchors.fill: parent
                anchors.margins: 10
                active: parent.note !== null
                sourceComponent: Item {
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.tint(note.color, "#C0FFFFFF")
                        border.width: 2
                        border.color: (note.color === Qt.rgba(1,1,1,1)) ? "black" : note.color
                        radius: 5
                        Behavior on color {  ColorAnimation { duration: 500 } }
                    }

                    ScrollView {
                        id: noteScrollView
                        anchors.fill: parent
                        anchors.margins: 5
                        clip: true

                        Column {
                            width: noteScrollView.width
                            spacing: 10

                            Rectangle {
                                id: noteTitleBar
                                width: parent.width
                                height: noteTitleBarLayout.height+8
                                color: notesGrid.currentIndex === noteIndex ? Qt.rgba(0,0,0,0.25) : Qt.rgba(0,0,0,0)
                                radius: 5

                                Row {
                                    id: noteTitleBarLayout
                                    spacing: 5
                                    width: parent.width-4
                                    anchors.centerIn: parent

                                    TextEdit {
                                        id: headingEdit
                                        width: parent.width-menuButton.width-deleteButton.width-2*parent.spacing
                                        wrapMode: Text.WordWrap
                                        text: note.heading
                                        font.bold: true
                                        font.pixelSize: 18
                                        onTextChanged: {
                                            if(activeFocus)
                                                note.heading = text
                                        }
                                        anchors.verticalCenter: parent.verticalCenter
                                        KeyNavigation.tab: contentEdit
                                    }

                                    ToolButton {
                                        id: menuButton
                                        icon.source: "../icons/navigation/menu.png"
                                        anchors.verticalCenter: parent.verticalCenter
                                        down: noteMenuLoader.item.visible
                                        onClicked: {
                                            if(noteMenuLoader.item.visible)
                                                noteMenuLoader.item.close()
                                            else
                                                noteMenuLoader.item.open()
                                        }
                                        flat: true

                                        Loader {
                                            id: noteMenuLoader
                                            width: parent.width; height: 1
                                            anchors.top: parent.bottom
                                            sourceComponent: ColorMenu { }
                                            active: true

                                            Connections {
                                                target: noteMenuLoader.item
                                                onMenuItemClicked: note.color = color
                                            }
                                        }
                                    }

                                    ToolButton {
                                        id: deleteButton
                                        icon.source: "../icons/action/delete.png"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: notesPack.removeNote(note)
                                        flat: true
                                    }
                                }
                            }

                            TextArea {
                                id: contentEdit
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: note.content
                                textFormat: TextArea.PlainText
                                font.pixelSize: 16
                                onTextChanged: {
                                    if(activeFocus)
                                        note.content = text
                                }
                                placeholderText: "type the contents of your note here.."
                                KeyNavigation.tab: headingEdit
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: notesGrid.currentIndex !== noteIndex
                onClicked: notesGrid.currentIndex = noteIndex
            }
        }
    }

    Component {
        id: newNoteDelegate

        Item {
            Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                radius: 5
                color: "lightgray"
                opacity: 0.25
            }

            RoundButton {
                width: 80; height: 80
                anchors.centerIn: parent
                icon.width: 48
                icon.height: 48
                icon.source: "../icons/action/note_add.png"
                down: noteMenuLoader.item.visible
                onClicked: {
                    if(noteMenuLoader.item.visible)
                        noteMenuLoader.item.close()
                    else
                        noteMenuLoader.item.open()
                }

                Loader {
                    id: noteMenuLoader
                    width: parent.width; height: 1
                    anchors.top: parent.bottom
                    sourceComponent: ColorMenu { }
                    active: true

                    Connections {
                        target: noteMenuLoader.item
                        onMenuItemClicked: {
                            var props = {"color": color}
                            var note = noteComponent.createObject(scriteDocument.structure, props)
                            notesPack.addNote(note)
                            notesGrid.currentIndex = notesPack.noteCount-1
                        }
                    }
                }
            }
        }
    }

    Component {
        id: noteComponent

        Note {
            heading: "Note Heading"
        }
    }

    Component {
        id: newCharactersDialogUi

        Rectangle {
            width: 400
            height: 600
            color: "white"

            Item {
                anchors.fill: parent
                anchors.margins: 10

                Text {
                    id: title
                    width: parent.width
                    anchors.top: parent.top
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: "Create sections in your notebook for characters in your screenplay"
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    anchors.fill: charactersScrollView
                    anchors.margins: -2
                    border { width: 1; color: "black" }
                }

                ScrollView {
                    id: charactersScrollView
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: title.bottom
                    anchors.bottom: createSectionsButton.top
                    anchors.topMargin: 20
                    anchors.bottomMargin: 10
                    clip: true

                    ListView {
                        id: charactersListView
                        property var detectedCharacters: scriteDocument.structure.detectCharacters()
                        property var newCharacters: []

                        model: detectedCharacters
                        spacing: 10
                        delegate: Row {
                            width: charactersListView.width
                            spacing: 10

                            CheckBox {
                                checkable: true
                                checked: modelData.added
                                anchors.verticalCenter: parent.verticalCenter
                                enabled: modelData.added === false
                                onToggled: {
                                    var chs = charactersListView.newCharacters
                                    if(checked)
                                        chs.push(modelData.name)
                                    else
                                        chs.splice( chs.indexOf(modelData.name), 1 )
                                    charactersListView.newCharacters = chs
                                }
                            }

                            Text {
                                font.pixelSize: 15
                                text: modelData.name
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Button {
                    id: createSectionsButton
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    text: "Create Sections"
                    onClicked: {
                        scriteDocument.structure.addCharacters(charactersListView.newCharacters)
                        modalDialog.closeRequest()
                    }
                }
            }
        }
    }
}
