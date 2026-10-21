// Polkit — MacShell's password sheet: whenever an app needs administrator rights (installing dependencies, the App
// Store removing a system app, pkexec, …) this asks for your password the way macOS does, instead of nothing
// happening because no polkit agent was running in the session.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit

Scope {
    id: root
    property var hub: null
    readonly property var dock: hub ? hub.dock : null
    readonly property bool dark: dock ? dock.darkMode : true
    readonly property color accent: dock ? dock.accent : "#0A84FF"
    readonly property string fam: dock ? dock.fontFamily : "Inter Variable"
    readonly property string user: Quickshell.env("USER") || ""

    PolkitAgent { id: agent }
    readonly property var flow: agent.flow
    readonly property bool asking: agent.isActive && flow !== null
    property real shake: 0
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shake"; to: -12; duration: 50 }
        NumberAnimation { target: root; property: "shake"; to: 10; duration: 60 }
        NumberAnimation { target: root; property: "shake"; to: -6; duration: 60 }
        NumberAnimation { target: root; property: "shake"; to: 3; duration: 50 }
        NumberAnimation { target: root; property: "shake"; to: 0; duration: 50 }
    }
    Connections {
        target: root.flow
        function onAuthenticationFailed() { shakeAnim.restart(); pw.text = ""; }
    }

    PanelWindow {
        id: win
        visible: root.asking || fade.running || card.opacity > 0.01
        screen: {
            var fm = Hyprland.focusedMonitor, ss = Quickshell.screens;
            for (var i = 0; i < ss.length; i++) if (fm && ss[i].name === fm.name) return ss[i];
            return ss.length ? ss[0] : null;
        }
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "macauth"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.asking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // the screen dims behind the sheet
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.asking ? 0.35 : 0
            Behavior on opacity { NumberAnimation { id: fade; duration: 260; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent }
        }

        Rectangle {
            id: card
            width: 300; height: col.height + 40
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.shake
            radius: 22
            color: root.dark ? Qt.rgba(0.16, 0.16, 0.17, 0.97) : Qt.rgba(0.97, 0.97, 0.98, 0.98)
            border.width: 1; border.color: root.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.1)
            // comes in with motion, blur and a little growth; leaves faster
            opacity: root.asking ? 1 : 0
            scale: root.asking ? 1 : 0.9
            Behavior on opacity { NumberAnimation { duration: root.asking ? 260 : 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.asking ? 420 : 200; easing.type: root.asking ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.2 } }
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 1.0; shadowOpacity: 0.45; shadowVerticalOffset: 10 }

            Column {
                id: col
                x: 20; y: 22; width: parent.width - 40
                spacing: 12
                // the padlock, like the macOS sheet
                Item {
                    width: parent.width; height: 64
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64; height: 64; radius: 15
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#8E8E93" }
                            GradientStop { position: 1; color: "#5A5A5F" }
                        }
                        Canvas {
                            anchors.centerIn: parent; width: 30; height: 34
                            onPaint: {
                                var c = getContext("2d"); c.reset();
                                c.strokeStyle = "white"; c.lineWidth = 3.4;
                                c.beginPath(); c.arc(15, 13, 8, Math.PI, 0); c.lineTo(23, 16); c.moveTo(7, 16); c.lineTo(7, 13); c.stroke();
                                c.fillStyle = "white";
                                c.beginPath(); c.roundedRect(2, 15, 26, 18, 4, 4); c.fill();
                            }
                        }
                    }
                }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: "MacShell wants to make changes."
                    color: root.dark ? "white" : "#1d1d1f"; font.family: root.fam; font.pixelSize: 14; font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: (root.flow && root.flow.message ? root.flow.message + "\n\n" : "") + "Enter your password to allow this."
                    color: root.dark ? Qt.rgba(1, 1, 1, 0.65) : Qt.rgba(0, 0, 0, 0.6); font.family: root.fam; font.pixelSize: 12
                }
                Rectangle {
                    width: parent.width; height: 30; radius: 8
                    color: root.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)
                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: root.user; color: root.dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5); font.family: root.fam; font.pixelSize: 13 }
                }
                Rectangle {
                    width: parent.width; height: 30; radius: 8
                    color: root.dark ? Qt.rgba(1, 1, 1, 0.1) : "white"
                    border.width: pw.activeFocus ? 2 : 1
                    border.color: pw.activeFocus ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.8) : (root.dark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15))
                    TextInput {
                        id: pw
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        color: root.dark ? "white" : "#1d1d1f"; font.family: root.fam; font.pixelSize: 13
                        focus: root.asking
                        onAccepted: root.submit()
                        Keys.onEscapePressed: root.cancel()
                        Text {
                            visible: pw.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.flow && root.flow.inputPrompt && root.flow.inputPrompt.indexOf("assword") < 0 ? root.flow.inputPrompt : "Password"
                            color: root.dark ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.3); font: pw.font
                        }
                    }
                }
                Text {
                    visible: text !== ""
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: root.flow && root.flow.supplementaryMessage ? root.flow.supplementaryMessage : ""
                    color: root.flow && root.flow.supplementaryIsError ? "#FF453A" : (root.dark ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(0, 0, 0, 0.55))
                    font.family: root.fam; font.pixelSize: 11
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Repeater {
                        model: [{ t: "Cancel", main: false }, { t: "OK", main: true }]
                        delegate: Rectangle {
                            required property var modelData
                            width: 120; height: 30; radius: 15
                            color: modelData.main ? (bMa.pressed ? Qt.darker(root.accent, 1.15) : root.accent)
                                                  : (bMa.pressed ? (root.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14)) : (root.dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.07)))
                            scale: bMa.pressed ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                            Text { anchors.centerIn: parent; text: parent.modelData.t; color: parent.modelData.main ? "white" : (root.dark ? "white" : "#1d1d1f"); font.family: root.fam; font.pixelSize: 13; font.weight: parent.modelData.main ? Font.DemiBold : Font.Normal }
                            MouseArea { id: bMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.modelData.main ? root.submit() : root.cancel() }
                        }
                    }
                }
            }
        }
    }
    function submit() { if (flow && flow.isResponseRequired) { flow.submit(pw.text); pw.text = ""; } }
    function cancel() { if (flow) flow.cancelAuthenticationRequest(); pw.text = ""; }
}
