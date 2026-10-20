import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

// Right-click menu for tray icons, drawn by us instead of the default Qt menu.
// Submenus slide in place (with a back row) instead of opening side windows.
PopupWindow {
    id: win

    required property Item target
    property var rootMenu: null          // QsMenuHandle of the tray item

    property var stack: []               // submenu handles, deepest last
    readonly property var current: stack.length ? stack[stack.length - 1] : rootMenu
    property bool shown: false
    property int slideDir: 1

    anchor.item: target
    anchor.rect.x: (target.width - implicitWidth) / 2
    anchor.rect.y: target.height + 8
    implicitWidth: Math.max(210, Math.min(340, list.implicitWidth + 12))
    implicitHeight: list.implicitHeight + 12
    color: "transparent"
    visible: false

    function open() {
        stack = [];
        visible = true;
        shown = true;
    }
    function close() { shown = false; }
    function enter(entry) {
        slideDir = 1;
        swap.restart();
        stack = stack.concat([entry]);
    }
    function back() {
        slideDir = -1;
        swap.restart();
        stack = stack.slice(0, -1);
    }

    QsMenuOpener { id: opener; menu: win.current }

    HyprlandFocusGrab {
        windows: [win]
        active: win.visible
        onCleared: win.close()
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 14
        color: Colors.surfaceContainer
        border.width: 1
        border.color: Qt.alpha(Colors.primary, 0.25)
        clip: true
        focus: true
        Keys.onEscapePressed: win.stack.length ? win.back() : win.close()

        // grow from the icon + fade
        transformOrigin: Item.Top
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        onOpacityChanged: if (opacity === 0 && !win.shown) win.visible = false

        // faint accent wash at the top
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Colors.primary, 0.10) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        ColumnLayout {
            id: list
            x: 6 + win.slideDir * 18 * (1 - win.swapT)
            y: 6
            width: win.width - 12
            spacing: 1
            opacity: win.swapT

            // Back row inside submenus
            MenuRow {
                visible: win.stack.length > 0
                label: win.stack.length ? (win.stack[win.stack.length - 1].text || "Back") : ""
                leading: Style.glyph(0xf0141)   // chevron-left
                bold: true
                onActivated: win.back()
            }
            Rectangle {
                visible: win.stack.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 3
                Layout.bottomMargin: 3
                color: Qt.alpha(Colors.outlineVariant, 0.6)
            }

            Repeater {
                model: opener.children
                delegate: Loader {
                    id: slot
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    sourceComponent: modelData.isSeparator ? sepComp : rowComp

                    Component {
                        id: sepComp
                        Item {
                            implicitHeight: 9
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 16
                                height: 1
                                color: Qt.alpha(Colors.outlineVariant, 0.6)
                            }
                        }
                    }
                    Component {
                        id: rowComp
                        MenuRow {
                            entry: slot.modelData
                            label: slot.modelData.text
                            iconSource: slot.modelData.icon
                            appearIndex: slot.index
                            onActivated: {
                                if (slot.modelData.hasChildren) {
                                    win.enter(slot.modelData);
                                } else {
                                    slot.modelData.triggered();
                                    win.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // crossfade/slide when entering or leaving a submenu
    property real swapT: 1
    SequentialAnimation {
        id: swap
        NumberAnimation { target: win; property: "swapT"; to: 0; duration: 0 }
        NumberAnimation { target: win; property: "swapT"; to: 1; duration: 240; easing.type: Easing.OutCubic }
    }

    component MenuRow: Item {
        id: row
        property var entry: null
        property string label: ""
        property string iconSource: ""
        property string leading: ""
        property bool bold: false
        property int appearIndex: 0
        readonly property bool hovered: ma.containsMouse
        signal activated()

        Layout.fillWidth: true
        implicitHeight: 32
        implicitWidth: content.implicitWidth + 24
        opacity: (entry && !entry.enabled) ? 0.4 : 1

        // stagger in on open
        property real appear: win.shown ? 1 : 0
        Behavior on appear { NumberAnimation { duration: 220 + row.appearIndex * 25; easing.type: Easing.OutCubic } }
        transform: Translate { y: 6 * (1 - row.appear) }

        Rectangle {
            anchors.fill: parent
            radius: 9
            color: ma.pressed ? Qt.alpha(Colors.primary, 0.28)
                 : row.hovered ? Qt.alpha(Colors.primary, 0.16)
                 : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
            scale: ma.pressed ? 0.98 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }

            // accent bar slides in on hover
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: 3
                width: 3
                radius: 2
                height: row.hovered ? parent.height - 14 : 0
                color: Colors.primary
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
        }

        RowLayout {
            id: content
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 10

            // check / radio indicator, app icon, or leading glyph
            Item {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                readonly property int kind: row.entry ? row.entry.buttonType : 0
                readonly property bool checked: row.entry ? row.entry.checkState === Qt.Checked : false
                visible: kind !== 0 || row.iconSource !== "" || row.leading !== ""

                Rectangle {
                    visible: parent.kind !== 0
                    anchors.centerIn: parent
                    width: 15; height: 15
                    radius: parent.kind === 2 ? width / 2 : 4
                    color: parent.checked ? Colors.primary : "transparent"
                    border.width: parent.checked ? 0 : 1.5
                    border.color: Colors.outline
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Glyph {
                        anchors.centerIn: parent
                        visible: parent.parent.checked && parent.parent.kind !== 2
                        text: Style.glyph(0xf012c)   // check
                        size: 11
                        color: Colors.primaryText
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: parent.parent.checked && parent.parent.kind === 2
                        width: 6; height: 6; radius: 3
                        color: Colors.primaryText
                    }
                }
                IconImage {
                    visible: parent.kind === 0 && row.iconSource !== ""
                    anchors.centerIn: parent
                    implicitSize: 16
                    source: row.iconSource
                }
                Glyph {
                    visible: parent.kind === 0 && row.iconSource === "" && row.leading !== ""
                    anchors.centerIn: parent
                    text: row.leading
                    size: 14
                    color: row.hovered ? Colors.primary : Colors.surfaceVariantText
                }
            }

            Text {
                Layout.fillWidth: true
                text: row.label.replace(/_(?!_)/g, "")   // drop GTK mnemonic underscores
                elide: Text.ElideRight
                color: row.hovered ? Colors.primary : Colors.surfaceText
                Behavior on color { ColorAnimation { duration: 140 } }
                font.family: Style.font
                font.pixelSize: Style.fontSize
                font.weight: row.bold ? Font.Bold : Font.Medium
            }

            Glyph {
                visible: row.entry !== null && row.entry.hasChildren
                text: Style.glyph(0xf0142)   // chevron-right
                size: 14
                color: row.hovered ? Colors.primary : Colors.outline
                Layout.rightMargin: row.hovered ? -2 : 0
                Behavior on Layout.rightMargin { NumberAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            enabled: !row.entry || row.entry.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }
}
