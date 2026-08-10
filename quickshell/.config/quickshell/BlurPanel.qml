import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets

// A panel styled like the bar: translucent dark over a blurred backdrop.
//
// The bar gets its blur from the compositor, which is no help on a session
// lock surface — that covers the screen, so there is nothing behind it to
// blur. This samples `blurSource` at the panel's own position instead and
// blurs that, which gives the same look from inside the scene.
ClippingRectangle {
    id: root

    property Item blurSource        // item to sample, e.g. the wallpaper
    property Item blurRoot          // coordinate space blurSource fills
    property int pad: 28            // sampled margin, so the blur has real
                                    // pixels at the edges instead of fading
    property real blurRadius: 48
    property color tint: Theme.barBg

    // mapToItem isn't reactive on its own, so the geometry it depends on is
    // read explicitly to make this re-evaluate whenever anything moves.
    readonly property rect srcRect: {
        const deps = [root.x, root.y, root.width, root.height,
                      blurRoot ? blurRoot.width : 0,
                      blurRoot ? blurRoot.height : 0,
                      parent ? parent.x : 0, parent ? parent.y : 0,
                      parent ? parent.width : 0, parent ? parent.height : 0];
        if (!blurRoot)
            return Qt.rect(0, 0, 0, 0);
        const p = root.mapToItem(blurRoot, 0, 0);
        return Qt.rect(p.x - root.pad, p.y - root.pad,
                       root.width + root.pad * 2, root.height + root.pad * 2);
    }

    color: "transparent"

    ShaderEffectSource {
        id: backdrop
        x: -root.pad
        y: -root.pad
        width: root.width + root.pad * 2
        height: root.height + root.pad * 2
        sourceItem: root.blurSource
        sourceRect: root.srcRect
        visible: false
    }

    FastBlur {
        x: backdrop.x
        y: backdrop.y
        width: backdrop.width
        height: backdrop.height
        source: backdrop
        radius: root.blurRadius
    }

    Rectangle {
        anchors.fill: parent
        color: root.tint
    }
}
