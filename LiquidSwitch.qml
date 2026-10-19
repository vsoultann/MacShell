// LiquidSwitch — the on/off switch used everywhere in the shell.
// Pressing it turns the knob into a glass lens (see LiquidKnob); it slides across as glass, then sets solid again.
// The knob can also be dragged across, like on iOS.
import QtQuick

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

    property real glass: 0
    // into glass quickly, back to solid slowly once it has landed
    Behavior on glass { NumberAnimation { duration: ma.pressed ? 220 : 380; easing.type: ma.pressed ? Easing.OutCubic : Easing.InOutCubic } }
    Timer { id: settle; interval: 380; onTriggered: if (!ma.pressed) sw.glass = 0 }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? sw.accent : sw.offColor
        Behavior on color { ColorAnimation { duration: 320; easing.type: Easing.InOutCubic } }
    }
    LiquidKnob {
        id: knob
        restW: sw.height - 4; restH: sw.height - 4
        grow: 1.5
        growH: 0.08
        glass: sw.glass
        material: sw.material
        dark: sw.dark
        fillColor: sw.accent; restColor: sw.offColor
        trackH: sw.height - 4
        leftRoom: sw.checked ? 1e6 : 0
        rightRoom: sw.checked ? 0 : 1e6
        // where along the track it sits (0 off … 1 on); animated on its own, so stretching never pushes it past the ends
        property real along: sw.checked ? 1 : 0
        Behavior on along { enabled: !ma.dragging; NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
        x: ma.dragging ? Math.max(2, Math.min(sw.width - 2 - width, ma.dragX - width / 2))
                       : 2 + Math.max(0, Math.min(1, along)) * (sw.width - 4 - width)
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
            dragging = false;
            if (v !== sw.checked) sw.toggled(v);
            settle.restart();
        }
        onCanceled: { dragging = false; settle.restart(); }
    }
}
