import QtQuick

// Filled area chart of the last N samples, auto-scaled (or to `max` if set).
Canvas {
    id: root

    property var values: []
    property var values2: []        // optional second series, drawn as a line
    property real max: 0
    property color accent: Colors.primary
    property color accent2: Colors.tertiary

    implicitHeight: 48
    onValuesChanged: requestPaint()
    onAccentChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const all = values.concat(values2);
        const top = max > 0 ? max : Math.max(1, ...all) * 1.15;
        const step = width / Math.max(1, values.length - 1);
        const y = v => height - 2 - (v / top) * (height - 4);

        const trace = series => {
            ctx.beginPath();
            series.forEach((v, i) => i ? ctx.lineTo(i * step, y(v)) : ctx.moveTo(0, y(v)));
        };

        trace(values);
        ctx.lineTo(width, height);
        ctx.lineTo(0, height);
        ctx.closePath();
        const grad = ctx.createLinearGradient(0, 0, 0, height);
        grad.addColorStop(0, Qt.alpha(accent, 0.45));
        grad.addColorStop(1, Qt.alpha(accent, 0.02));
        ctx.fillStyle = grad;
        ctx.fill();

        trace(values);
        ctx.strokeStyle = accent;
        ctx.lineWidth = 2;
        ctx.stroke();

        if (values2.length) {
            trace(values2);
            ctx.strokeStyle = accent2;
            ctx.lineWidth = 1.5;
            ctx.stroke();
        }
    }
}
