import QtQuick

// UI text in the shell's font.
Text {
    property int size: Style.fontSize

    color: Colors.surfaceText
    font.family: Style.font
    font.pixelSize: size
    font.features: { "tnum": 1 }
    elide: Text.ElideRight
}
