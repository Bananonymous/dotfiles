pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Quickshell is the notification daemon (replaces swaync).
// Every notification lands in history; new ones also queue as island toasts.
Singleton {
    id: root

    property bool dnd: false
    // Notification id -> arrival time (the protocol has no timestamp). Kept across shell reloads like
    // the notifications themselves (keepOnReload), otherwise every old one read "now" after a reload.
    readonly property var arrived: persist.arrived
    PersistentProperties {
        id: persist
        reloadableId: "notifArrived"
        property var arrived: ({})
    }
    // Ticks so "5 min" labels age while they're on screen (Date.now() alone never re-evaluates a binding)
    property real now: Date.now()
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }
    // Notifications waiting to be shown as a toast, oldest first
    property var queue: []
    readonly property var history: server.trackedNotifications.values
    readonly property int count: history.length

    function dropToast(n) {
        queue = queue.filter(x => x && x !== n);
        // Transient ones are toast-only: gone once shown
        if (n && n.transient) n.expire();
    }

    function clearAll() {
        queue = [];
        for (const n of [...history]) n.dismiss();
    }

    // Default action if the app offers one, then close it
    function activate(n) {
        const def = n.actions.find(a => a.identifier === "default");
        if (def) def.invoke();
        n.dismiss();
    }

    // How long a toast stays up, in ms (0 = critical, waits for the user)
    function toastMs(n) {
        if (n.urgency === NotificationUrgency.Critical) return 0;
        return n.expireTimeout > 0 ? Math.max(3000, n.expireTimeout) : 5500;
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            // Chromium's push fallback ("site updated in the background"): noise, drop it
            if (/updated in the background|mis à jour en arrière-plan/i.test(n.body + " " + n.summary))
                return;
            n.tracked = true;
            persist.arrived = Object.assign({}, persist.arrived, { [n.id]: Date.now() });
            root.now = Date.now();
            n.closed.connect(() => root.queue = root.queue.filter(x => x && x !== n));
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.queue = [...root.queue, n];
        }
    }

    // "5 min" style age of a notification
    function ago(n) {
        if (!n) return "";
        const t = arrived[n.id];
        if (t === undefined) return "";              // arrived before arrival times were kept
        const s = Math.floor((now - t) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return `${Math.floor(s / 60)} min`;
        if (s < 86400) return `${Math.floor(s / 3600)} h`;
        return `${Math.floor(s / 86400)} d`;
    }
}
