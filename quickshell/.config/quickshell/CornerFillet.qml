import QtQuick

// Concave corner that ties a surface's side edge into the bar above it: a
// square minus a quarter disc, so the bar's underside curves down into the
// panel instead of meeting it at a hard right angle.
//
// Unmirrored sits to the LEFT of the surface it curves into, mirrored to the
// right. Callers position it; it only knows its shape.
Canvas {
    id: root
    property bool mirrored: false
    property color fill: Theme.bg

    width: Theme.panelRadius
    height: Theme.panelRadius

    onFillChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const r = width;
        ctx.reset();
        ctx.fillStyle = root.fill;
        ctx.beginPath();
        if (mirrored) {
            ctx.moveTo(0, 0);
            ctx.lineTo(r, 0);
            ctx.lineTo(r, r);
            ctx.arc(0, r, r, 0, -Math.PI / 2, true);
        } else {
            ctx.moveTo(r, 0);
            ctx.lineTo(0, 0);
            ctx.lineTo(0, r);
            ctx.arc(r, r, r, Math.PI, 3 * Math.PI / 2, false);
        }
        ctx.closePath();
        ctx.fill();
    }
}
