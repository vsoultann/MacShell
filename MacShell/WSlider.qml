// WSlider — the System Settings slider: a thin track, a round knob and a glyph at each end.
import QtQuick

Item {
    id: ws
    property real value: 0.5
    property real minimum: 0
    property color accent: "#0A84FF"
    property string material: "liquid"
    signal moved(real v)
    height: 30
    readonly property real trackX: 34
    readonly property real trackW: Math.max(1, width - 34 - 34)
    readonly property real pos: Math.max(0, Math.min(1, ws.value))

    Canvas {
        x: 2; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22
        antialiasing: true
        onPaint: {
            var c = getContext("2d"); c.reset();
            c.scale(width / 22, width / 22);
            c.lineWidth = 1.4;
            c.strokeStyle = Qt.rgba(1, 1, 1, 0.55);
            c.beginPath(); c.roundedRect(3, 6, 11, 11, 3.2, 3.2); c.stroke();
            c.strokeStyle = Qt.rgba(1, 1, 1, 0.85);
            c.beginPath(); c.roundedRect(8, 3, 11, 11, 3.2, 3.2); c.stroke();
        }
    }
    Canvas {
        x: ws.width - 24; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22
        antialiasing: true
        onPaint: {
            var c = getContext("2d"); c.reset();
            c.scale(width / 22, width / 22);
            c.fillStyle = Qt.rgba(1, 1, 1, 0.55);
            c.beginPath(); c.roundedRect(3, 6, 11, 11, 3.2, 3.2); c.fill();
            c.fillStyle = Qt.rgba(1, 1, 1, 0.9);
            c.beginPath(); c.roundedRect(8, 3, 11, 11, 3.2, 3.2); c.fill();
        }
    }

    LiquidSlider {
        x: ws.trackX - 10; width: ws.trackW + 20
        anchors.verticalCenter: parent.verticalCenter
        value: ws.value; minimum: ws.minimum
        accent: ws.accent; trackColor: Qt.rgba(1, 1, 1, 0.18); trackH: 5; knobSize: 22
        material: ws.material
        onMoved: v => ws.moved(v)
    }
}
