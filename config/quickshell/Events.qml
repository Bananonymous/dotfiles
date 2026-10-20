pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Upcoming Google Calendar events from every calendar listed in calendar.url next to
// shell.qml (one private iCal URL per line), merged by scripts/calendar.py.
// Refreshed every 5 minutes.
Singleton {
    id: root

    property bool configured: false
    property var events: []
    property var calendars: []      // [{ name, ok }] in file order
    property string error: ""
    property string rangeFrom: ""   // yyyy-MM-dd span calendar.py loaded
    property string rangeTo: ""
    function inRange(key) { return !rangeFrom || (key >= rangeFrom && key <= rangeTo); }

    // One color per calendar, by its line in calendar.url
    function colorOf(e) {
        const palette = [Colors.primary, Colors.tertiary, Colors.green, Colors.orange, Colors.magenta, Colors.cyan, Colors.secondary];
        return palette[(e?.calIndex ?? 0) % palette.length];
    }

    // Events of the first day (today onward) that has any, for the clock panel
    readonly property string nextDay: {
        const e = events.find(e => new Date(e.end) > new Date());
        return e ? e.date : "";
    }
    readonly property var nextDayEvents: events.filter(e => e.date === nextDay)

    function refresh() { if (!proc.running) proc.running = true; }

    function dayLabel(iso) {
        if (!iso) return "";
        const d = new Date(iso + "T00:00:00");
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const diff = Math.round((d - today) / 86400000);
        const base = Qt.locale().toString(d, "dddd, d MMM");
        return diff === 0 ? `${base} (Today)` : diff === 1 ? `${base} (Tomorrow)` : diff === -1 ? `${base} (Yesterday)` : base;
    }

    function timeRange(e) {
        if (e.allDay) return "All day";
        const f = s => Qt.locale().toString(new Date(s), "HH:mm");
        return `${f(e.start)}-${f(e.end)}`;
    }

    Process {
        id: proc
        command: ["python3", "-I", Quickshell.shellPath("scripts/calendar.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.configured = d.configured;
                    root.error = d.error ?? "";
                    root.calendars = d.calendars ?? [];
                    root.rangeFrom = d.from ?? "";
                    root.rangeTo = d.to ?? "";
                    // Keep whatever calendars did load, even if one link failed
                    if (d.events.length || !root.error) root.events = d.events;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
