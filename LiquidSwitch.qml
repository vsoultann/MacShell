// LiquidSwitch — the on/off switch used everywhere in the shell, after the iOS 26 / macOS Tahoe switch:
//   press  → the knob swells past the track into a clear glass lens (the track shows through it, magnified)
//   toggle → it travels across as glass, stretching along the way with a touch of motion blur
//   land   → it shrinks back into the solid white knob with a small spring
// The knob can also be dragged across. Frosted / Blur turn the lens frosted, Opaque keeps it solid (it still moves).
import QtQuick
import QtQuick.Effects

Item {
    id: sw
    property bool checked: false
    property color accent: "#0A84FF"
    property color offColor: Qt.rgba(0.47, 0.47, 0.5, 0.32)
    property string material: "liquid"
    property bool dark: true
    signal toggled(bool value)
    width: 38; height: 22
    opacity: enabled ? 1 : 0.4

    // how glassy / swollen the knob is: up quickly on press, down with a spring once it has landed
    property real glass: 0
    Behavior on glass {
        NumberAnimation {
            duration: sw.glass < 0.5 ? 200 : 340
            easing.type: sw.glass < 0.5 ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: 1.6
        }
    }
    // where along the track it is (0 off … 1 on)
    property real along: checked ? 1 : 0
    Behavior on along { enabled: !ma.dragging; NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
    // 0 at either end, 1 half way: drives the stretch and the motion blur while it travels
    readonly property real travel: Math.sin(Math.PI * Math.max(0, Math.min(1, along)))
    onAlongChanged: if (!ma.pressed) settle.restart()
    Timer { id: settle; interval: 90; onTriggered: if (!ma.pressed) sw.glass = 0 }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        // the colour follows the knob across rather than switching at once
        color: Qt.rgba(sw.offColor.r + (sw.accent.r - sw.offColor.r) * sw.along,
                       sw.offColor.g + (sw.accent.g - sw.offColor.g) * sw.along,
                       sw.offColor.b + (sw.accent.b - sw.offColor.b) * sw.along,
                       sw.offColor.a + (sw.accent.a - sw.offColor.a) * sw.along)
    }
    LiquidKnob {
        id: knob
        z: 2
        restW: sw.height - 4; restH: sw.height - 4
        grow: 1.5
        growH: 0.34                      // it swells past the track's edges, like on iOS
        glass: sw.glass
        material: sw.material
        dark: sw.dark
        fillColor: sw.accent; restColor: sw.offColor
        trackH: sw.height - 4
        leftRoom: sw.along * (sw.width - sw.height)
        rightRoom: (1 - sw.along) * (sw.width - sw.height)
        // the centre runs along the track; growing never shifts it, so the lens bulges evenly
        readonly property real cx: ma.dragging ? Math.max(sw.height / 2, Math.min(sw.width - sw.height / 2, ma.dragX))
                                               : sw.height / 2 + Math.max(0, Math.min(1, sw.along)) * (sw.width - sw.height)
        x: cx - width / 2
        y: (sw.height - height) / 2
        transform: Scale {
            origin.x: knob.width / 2; origin.y: knob.height / 2
            xScale: 1 + 0.22 * sw.travel
            yScale: 1 - 0.12 * sw.travel
        }
        layer.enabled: sw.travel > 0.08 && sw.material !== "opaque"
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 6; blur: 0.35 * sw.travel; autoPaddingEnabled: true }
    }
    MouseArea {
        id: ma
        anchors.fill: parent; anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        property bool dragging: false
        property real pressX: 0
        property real dragX: 0
        onPressed: mouse => { pressX = mouse.x; dragging = false; settle.stop(); sw.glass = 1; }
        onPositionChanged: mouse => {
            if (!dragging && Math.abs(mouse.x - pressX) > 4) dragging = true;
            dragX = mouse.x - 4;
        }
        onReleased: mouse => {
            var v = dragging ? (dragX > sw.width / 2) : !sw.checked;
            if (dragging) sw.along = Math.max(0, Math.min(1, (dragX - sw.height / 2) / (sw.width - sw.height)));
            dragging = false;
            if (v !== sw.checked) sw.toggled(v);
            sw.along = Qt.binding(function () { return sw.checked ? 1 : 0; });
            settle.restart();
        }
        onCanceled: { dragging = false; settle.restart(); }
    }
}
