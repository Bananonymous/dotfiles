pragma Singleton
import QtQuick
import Quickshell
import "../.." as Root

// Our weather service (scripts/weather.py emits Serpantinum's forecast format too).
Singleton {
    readonly property var data: Root.Weather.data ?? ({ forecast: [], offline: true })
    readonly property string unit: "metric"
    readonly property string unitSym: "°C"
    function refresh(force) { Root.Weather.refresh(); }
}
