import QtQuick

// A Nerd Font icon.
Text {
    property int size: 16

    color: Colors.surfaceText
    font.family: Style.iconFont
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
