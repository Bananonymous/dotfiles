pragma Singleton
import QtQuick
import Quickshell

// Clock strings in the system locale (24 h, with seconds).
Singleton {
    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property date now: clock.date
    readonly property string time: Qt.locale().toString(clock.date, "HH:mm:ss")
    readonly property string timeOnly: Qt.locale().toString(clock.date, "HH:mm")
    readonly property string hour: Qt.locale().toString(clock.date, "HH")
    readonly property string minute: Qt.locale().toString(clock.date, "mm")
    readonly property string second: Qt.locale().toString(clock.date, "ss")
    readonly property string fullDate: {
        const s = Qt.locale().toString(clock.date, "dddd, d MMMM");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
}
