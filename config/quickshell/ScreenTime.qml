pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Screen time per app, counted by the shell itself: every tick, the focused window's
// app gets the time, unless the session has been idle for 5 minutes.
// Stored as { "YYYY-MM-DD": { appId: seconds } } in the shell's state dir, 60 days kept.
Singleton {
    id: root

    readonly property int tick: 10
    property var days: ({})
    property bool dirty: false

    function key(d) { return Qt.formatDate(d, "yyyy-MM-dd"); }
    function totalOf(day) { return Object.values(days[day] ?? {}).reduce((a, b) => a + b, 0); }

    // Pretty "4h 20m" / "37m"
    function fmt(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60);
        return h ? `${h}h ${m}m` : `${m}m`;
    }

    // Day offset from today (0 = today, -1 = yesterday, ...)
    function dayKey(offset) {
        const d = new Date();
        d.setDate(d.getDate() + offset);
        return key(d);
    }

    // Sorted [{ app, seconds }] for one day
    function apps(day) {
        const map = days[day] ?? {};
        return Object.keys(map).map(a => ({ app: a, seconds: map[a] })).sort((a, b) => b.seconds - a.seconds);
    }

    // The Monday-to-Sunday week containing `day`, as totals
    function week(day) {
        const d = new Date(day + "T12:00:00");
        const monday = new Date(d);
        monday.setDate(d.getDate() - (d.getDay() + 6) % 7);
        const out = [];
        for (let i = 0; i < 7; i++) {
            const x = new Date(monday);
            x.setDate(monday.getDate() + i);
            out.push({ day: key(x), seconds: totalOf(key(x)) });
        }
        return out;
    }

    function prune() {
        const cutoff = dayKey(-60);
        for (const k of Object.keys(days)) if (k < cutoff) delete days[k];
    }

    IdleMonitor {
        id: idle
        timeout: 300
    }

    Timer {
        interval: root.tick * 1000
        running: true
        repeat: true
        onTriggered: {
            const top = ToplevelManager.activeToplevel;
            if (idle.isIdle || !top || !top.appId) return;
            const day = root.key(new Date());
            const d = root.days;
            d[day] = d[day] ?? {};
            d[day][top.appId] = (d[day][top.appId] ?? 0) + root.tick;
            root.days = Object.assign({}, d);   // new object so bindings update
            root.dirty = true;
        }
    }

    // Save once a minute, not every tick
    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: if (root.dirty) {
            root.prune();
            store.setText(JSON.stringify(root.days));
            root.dirty = false;
        }
    }

    FileView {
        id: store
        path: Quickshell.statePath("screentime.json")
        printErrors: false
        onLoaded: {
            try { root.days = JSON.parse(text()); } catch (e) {}
        }
    }

    // App id -> display name + icon via .desktop files
    function entry(app) { return DesktopEntries.heuristicLookup(app); }
    function appName(app) { return entry(app)?.name ?? app; }
    function appIcon(app) { return Quickshell.iconPath(entry(app)?.icon ?? app, "application-x-executable"); }
}
