// LiquidKnob — the knob of every switch and slider in the shell.
// At rest it is a solid white pill. While it is held (glass → 1) it swells into a lens, the way iOS 26 / macOS Tahoe
// controls do: clear glass with a bright rim when the material is Liquid Glass (the track shows through, magnified),
// frosted white for Frosted / Blur, and a plain white pill that only stretches for Opaque.
import QtQuick
import QtQuick.Effects

Item {
    id: k
    property real glass: 0                 // 0 solid … 1 fully glass
    property string material: "liquid"     // liquid | frosted | blur | opaque | custom
    property real restW: 20
    property real restH: 20
    property real grow: 1.6                // width multiplier when held
    property bool dark: true
    // what the lens magnifies: the track under it (fill colour left of the centre, the rest right of it)
    property color fillColor: "#0A84FF"
    property color restColor: Qt.rgba(1, 1, 1, 0.2)
    property real trackH: 4
    property real leftRoom: 1e6            // how much fill / track exists to the knob's left and right (slider ends)
    property real rightRoom: 1e6

    readonly property bool liquid: material === "liquid" || material === "custom"
    readonly property real lens: material === "opaque" ? 0 : Math.max(0, Math.min(1, glass))   // the size may overshoot (spring), the look does not
    width: restW + (restW * grow - restW) * glass
    height: restH + restH * 0.42 * glass

    // soft drop shadow
    Rectangle {
        anchors.fill: body
        anchors.topMargin: 1.5; anchors.bottomMargin: -1.5
        radius: body.radius
        color: Qt.rgba(0, 0, 0, 0.22 * (1 - k.lens * 0.6))
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 8; blur: 0.6; autoPaddingEnabled: true }
    }
    Rectangle {
        id: body
        anchors.fill: parent
        radius: height / 2
        // solid white melts into clear glass (liquid) or frosted white
        color: k.liquid ? Qt.rgba(1, 1, 1, 1 - 0.9 * k.lens)
                        : Qt.rgba(1, 1, 1, 1 - 0.45 * k.lens)
        border.width: 1
        border.color: Qt.rgba(k.dark ? 1 : 0, k.dark ? 1 : 0, k.dark ? 1 : 0, 0.10 + 0.25 * k.lens)
        clip: true

        // the track, magnified through the lens
        Item {
            visible: k.liquid && k.lens > 0.01
            opacity: k.lens
            anchors.fill: parent
            readonly property real mag: 1.7
            readonly property real th: k.trackH * mag
            Rectangle {
                x: parent.width / 2 - width; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width / 2, k.leftRoom * parent.mag); height: parent.th; radius: height / 2
                color: k.fillColor
            }
            Rectangle {
                x: parent.width / 2; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width / 2, k.rightRoom * parent.mag); height: parent.th; radius: height / 2
                color: k.restColor
            }
        }
        // specular: a bright crescent along the top edge and a faint one along the bottom
        Rectangle {
            visible: k.lens > 0.01
            opacity: k.lens
            x: 2; y: 1.5; width: parent.width - 4; height: parent.height * 0.5; radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, k.liquid ? 0.55 : 0.35) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
        Rectangle {
            visible: k.liquid && k.lens > 0.01
            opacity: k.lens * 0.5
            x: 4; y: parent.height * 0.62; width: parent.width - 8; height: parent.height * 0.34; radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.35) }
            }
        }
    }
    // the glass rim: a thin bright ring just inside the edge
    Rectangle {
        visible: k.lens > 0.01
        opacity: k.lens
        anchors.fill: parent; anchors.margins: 0.5
        radius: height / 2
        color: "transparent"
        border.width: 1.2
        border.color: Qt.rgba(1, 1, 1, k.liquid ? 0.85 : 0.5)
    }
}
