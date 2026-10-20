import QtQuick
import QtQuick.Layouts

// A Sparkline that draws itself in from the left as `reveal` goes 0 → 1.
Item {
    id: gr

    property real reveal: 1
    property alias values: spark.values
    property alias values2: spark.values2
    property alias max: spark.max
    property alias accent: spark.accent
    property alias accent2: spark.accent2

    Layout.fillWidth: true

    Item {
        width: gr.width * gr.reveal
        height: gr.height
        clip: true
        Sparkline {
            id: spark
            width: gr.width
            height: gr.height
        }
    }
}
