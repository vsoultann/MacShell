// Welcome — the screen that runs once after installing, the way macOS greets you.
//
//   qs -c MacShell ipc call welcome open      (it also runs itself the first time, unless ~/.config/macshell/welcome-done exists)
//
// hello in every language → your name and picture → the material, with a live preview → Welcome.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property var hub: null
    readonly property var dock: hub ? hub.dock : null
    readonly property var bar: hub ? hub.bar : null
    readonly property string fam: dock ? dock.fontFamily : "Inter Variable"
    readonly property color accent: dock ? dock.accent : "#0A84FF"
    readonly property string home: Quickshell.env("HOME")

    property bool shown: false
    property int step: 0                    // 0 hello · 1 you · 2 material · 3 welcome
    property int helloIdx: 0
    property string userName: Quickshell.env("USER") || ""
    property string avatar: ""
    property string material: "liquid"
    property real amount: 0.5               // blur / glass amount
    property int avatarPick: -1

    readonly property var hellos: [
        "hello", "مرحبا", "bonjour", "hola", "你好", "こんにちは", "안녕하세요", "olá", "привет",
        "ciao", "hallo", "नमस्ते", "merhaba", "שלום", "cześć", "hej", "xin chào", "สวัสดี"
    ]
    readonly property var avatars: [
        { c1: "#FF9F0A", c2: "#FF375F" }, { c1: "#0A84FF", c2: "#5E5CE6" }, { c1: "#30D158", c2: "#0A84FF" },
        { c1: "#BF5AF2", c2: "#FF375F" }, { c1: "#FFD60A", c2: "#FF9F0A" }, { c1: "#64D2FF", c2: "#0A84FF" }
    ]

    Timer {
        id: helloTimer
        interval: 900; repeat: true; running: root.shown && root.step === 0
        onTriggered: {
            root.helloIdx++;
            if (root.helloIdx >= root.hellos.length) { root.helloIdx = 0; root.step = 1; }
        }
    }

    function open() {
        step = 0; helloIdx = 0;
        userName = Quickshell.env("USER") || "";
        if (bar) { material = bar.material === "custom" ? "liquid" : bar.material; }
        shown = true;
        nameProc.running = true;
    }
    Process {
        id: nameProc
        command: ["sh", "-c", "n=$(getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1); printf '%s' \"${n:-$USER}\""]
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") root.userName = text.trim() }
    }
    function finish() {
        // apply everything the person picked
        if (bar) {
            bar.applyMaterial(material);
            if (material !== "opaque") {
                if (material === "liquid") { bar.glassLiquid = 0.4 + amount * 1.2; bar.glassBlur = 2 + amount * 16; }
                else bar.glassBlur = 6 + amount * 40;
                bar.material = material;        // the sliders are part of the chosen material, not "custom"
            }
            bar.userDisplayName = userName;
        }
        if (avatarPick >= 0) {
            // draw the chosen picture and keep it as ~/.face, where the lock screen and Settings read it
            avSave.grabToImage(function (r) { r.saveToFile(root.home + "/.face"); }, Qt.size(512, 512));
        }
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.config/macshell\" && date > \"$HOME/.config/macshell/welcome-done\""]);
        doneAnim.start();
    }
    SequentialAnimation {
        id: doneAnim
        PauseAnimation { duration: 1400 }
        ScriptAction { script: root.shown = false }
    }

    // the picture that gets saved, drawn off-screen
    Item {
        id: avSave
        width: 512; height: 512
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: root.avatarPick >= 0 ? root.avatars[root.avatarPick].c1 : "#0A84FF" }
                GradientStop { position: 1; color: root.avatarPick >= 0 ? root.avatars[root.avatarPick].c2 : "#5E5CE6" }
            }
            Text {
                anchors.centerIn: parent
                text: (root.userName || "?").charAt(0).toUpperCase()
                color: "white"; font.family: root.fam; font.pixelSize: 250; font.weight: Font.DemiBold
            }
        }
    }

    Variants {
        model: root.shown ? Quickshell.screens : []
        PanelWindow {
            id: w
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "macwelcome"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: isMain ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            readonly property bool isMain: Hyprland.focusedMonitor === null || Hyprland.focusedMonitor.name === modelData.name

            Rectangle {
                anchors.fill: parent
                color: "black"      // fully covers the bar and the Dock, like Setup Assistant
                opacity: 1
            }
            // a soft moving glow behind everything, like Apple's welcome
            Rectangle {
                anchors.centerIn: parent
                // big enough that rotating it never uncovers a corner
                width: Math.hypot(parent.width, parent.height) * 1.1; height: width
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0.05, 0.25, 0.65, 0.55) }
                    GradientStop { position: 1; color: Qt.rgba(0.35, 0.05, 0.45, 0.35) }
                }
                opacity: 0.6
                NumberAnimation on rotation { from: 0; to: 360; duration: 90000; loops: Animation.Infinite; running: root.shown }
            }

            // ── 0: hello in every language ──
            Item {
                anchors.fill: parent
                opacity: root.step === 0 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                MorphText {
                    anchors.centerIn: parent
                    text: root.hellos[Math.min(root.helloIdx, root.hellos.length - 1)]
                    color: "white"
                    font.family: root.fam; font.pixelSize: Math.round(w.height * 0.11); font.weight: Font.Light
                    duration: 620
                    blurMax: 60
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.72
                    text: "Click to skip"
                    color: Qt.rgba(1, 1, 1, 0.35); font.family: root.fam; font.pixelSize: 13
                }
                MouseArea { anchors.fill: parent; enabled: w.isMain; onClicked: root.step = 1 }
            }

            // ── 1: who you are ──
            Column {
                anchors.centerIn: parent
                width: Math.min(560, parent.width - 80)
                spacing: 22
                opacity: root.step === 1 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                transform: Translate { y: root.step === 1 ? 0 : 20 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Make it yours"
                    color: "white"; font.family: root.fam; font.pixelSize: 34; font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Your name and picture appear on the lock screen and in System Settings."
                    color: Qt.rgba(1, 1, 1, 0.6); font.family: root.fam; font.pixelSize: 13
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14
                    Repeater {
                        model: root.avatars
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: 56; height: 56; radius: 28
                            gradient: Gradient {
                                GradientStop { position: 0; color: modelData.c1 }
                                GradientStop { position: 1; color: modelData.c2 }
                            }
                            border.width: root.avatarPick === index ? 3 : 0
                            border.color: "white"
                            scale: root.avatarPick === index ? 1.08 : 1
                            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                            Text {
                                anchors.centerIn: parent
                                text: (root.userName || "?").charAt(0).toUpperCase()
                                color: "white"; font.family: root.fam; font.pixelSize: 24; font.weight: Font.DemiBold
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.avatarPick = parent.index }
                        }
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 300; height: 38; radius: 10
                    color: Qt.rgba(1, 1, 1, 0.12)
                    TextInput {
                        id: nameInput
                        anchors.fill: parent; anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.userName
                        onTextChanged: root.userName = text
                        color: "white"; font.family: root.fam; font.pixelSize: 15
                        selectByMouse: true
                    }
                }
                WButton { label: "Continue"; onPressed2: root.step = 2 }
            }

            // ── 2: the material, with a live preview ──
            Column {
                anchors.centerIn: parent
                width: Math.min(760, parent.width - 80)
                spacing: 18
                opacity: root.step === 2 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Pick a look"
                    color: "white"; font.family: root.fam; font.pixelSize: 34; font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "This sets the menu bar, Dock, Control Center, notifications and widgets. You can change it later in Settings."
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    color: Qt.rgba(1, 1, 1, 0.6); font.family: root.fam; font.pixelSize: 13
                }
                // live preview: a little desktop that reacts to the choice
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(560, parent.width); height: 170
                    radius: 14
                    clip: true
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#8C7A6B" }
                        GradientStop { position: 1; color: "#3E3530" }
                    }
                    // the "window" behind the glass
                    Rectangle { x: 40; y: 50; width: 220; height: 100; radius: 8; color: "#1b1b1f"; opacity: 0.9 }
                    Text { x: 54; y: 64; text: "A window"; color: Qt.rgba(1, 1, 1, 0.7); font.family: root.fam; font.pixelSize: 11 }
                    // the preview panel
                    Rectangle {
                        id: prevPanel
                        x: 150; y: 36; width: 250; height: 96; radius: 12
                        readonly property real a: root.material === "opaque" ? 0.97
                                               : (root.material === "frosted" ? 0.42 + root.amount * 0.35
                                               : (root.material === "blur" ? 0.18 + root.amount * 0.25 : 0.14 + root.amount * 0.18))
                        color: Qt.rgba(0.12, 0.12, 0.14, a)
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, root.material === "liquid" ? 0.35 : 0.12)
                        Behavior on color { ColorAnimation { duration: 260 } }
                        layer.enabled: root.material !== "opaque"
                        layer.effect: MultiEffect {
                            blurEnabled: false
                        }
                        Column {
                            x: 14; y: 14; spacing: 7
                            Text { text: "Control Center"; color: "white"; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold }
                            Row {
                                spacing: 8
                                Repeater {
                                    model: 3
                                    delegate: Rectangle { width: 34; height: 34; radius: 17; color: Qt.rgba(1, 1, 1, root.material === "opaque" ? 0.16 : 0.22) }
                                }
                            }
                            Rectangle { width: 210; height: 10; radius: 5; color: Qt.rgba(1, 1, 1, 0.25) }
                        }
                    }
                    // what is behind the glass, blurred to match the choice
                    Rectangle {
                        anchors.fill: prevPanel
                        visible: root.material !== "opaque"
                        radius: 12
                        color: "transparent"
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Repeater {
                        model: [{ id: "liquid", n: "Liquid Glass" }, { id: "frosted", n: "Frosted" }, { id: "blur", n: "Blur" }, { id: "opaque", n: "Opaque" }]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: root.material === modelData.id
                            width: 128; height: 36; radius: 10
                            color: sel ? root.accent : Qt.rgba(1, 1, 1, 0.12)
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Text { anchors.centerIn: parent; text: parent.modelData.n; color: "white"; font.family: root.fam; font.pixelSize: 13; font.weight: parent.sel ? Font.DemiBold : Font.Normal }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.material = parent.modelData.id }
                        }
                    }
                }
                // the amount slider — not shown for Opaque, and Blur never goes fully clear
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 360; height: 40
                    opacity: root.material === "opaque" ? 0 : 1
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 240 } }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 0; text: root.material === "blur" ? "How much blur" : "How much glass"; color: Qt.rgba(1, 1, 1, 0.6); font.family: root.fam; font.pixelSize: 12 }
                    Rectangle {
                        y: 26; width: parent.width; height: 5; radius: 2.5
                        color: Qt.rgba(1, 1, 1, 0.18)
                        Rectangle { width: parent.width * root.amount; height: parent.height; radius: 2.5; color: root.accent }
                        Rectangle {
                            x: parent.width * root.amount - 9; y: -6
                            width: 18; height: 18; radius: 9; color: "white"
                        }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -10
                            onPositionChanged: mouse => { if (pressed) root.amount = Math.max(root.material === "blur" ? 0.15 : 0, Math.min(1, mouse.x / width)); }
                            onPressed: mouse => root.amount = Math.max(root.material === "blur" ? 0.15 : 0, Math.min(1, mouse.x / width))
                        }
                    }
                }
                WButton { label: "Continue"; onPressed2: { root.step = 3; root.finish(); } }
            }

            // ── 3: Welcome ──
            Item {
                anchors.fill: parent
                opacity: root.step === 3 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Welcome"
                        color: "white"; font.family: root.fam; font.pixelSize: Math.round(w.height * 0.09); font.weight: Font.Light
                        opacity: root.step === 3 ? 1 : 0
                        scale: root.step === 3 ? 1 : 0.96
                        Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutQuint } }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.userName
                        color: Qt.rgba(1, 1, 1, 0.7); font.family: root.fam; font.pixelSize: 20
                    }
                }
            }
        }
    }

    component WButton: Rectangle {
        id: wb
        property string label: ""
        signal pressed2()
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        width: 200; height: 40; radius: 20
        color: wbMa.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
        Behavior on color { ColorAnimation { duration: 160 } }
        scale: wbMa.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
        Text { anchors.centerIn: parent; text: wb.label; color: "white"; font.family: root.fam; font.pixelSize: 14; font.weight: Font.DemiBold }
        MouseArea { id: wbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wb.pressed2() }
    }

    // first run: show it once, unless the marker file is already there
    Process {
        running: true
        command: ["sh", "-c", "[ -f \"$HOME/.config/macshell/welcome-done\" ] && echo done || echo first"]
        stdout: StdioCollector { onStreamFinished: if (text.trim() === "first") firstRun.restart() }
    }
    Timer { id: firstRun; interval: 2500; onTriggered: root.open() }
}
