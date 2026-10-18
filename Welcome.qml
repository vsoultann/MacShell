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
        "ciao", "hallo", "नमस्ते", "merhaba", "שלום", "cześć", "hej", "xin chào", "สวัสดี",
        "γεια", "ahoj", "salam", "কি খবর", "สบายดี", "سلام", "habari", "halo", "こんにちは",
        "szia", "tere", "sveiki", "bună", "zdravo", "selam", "hei", "aloha"
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
                    font.family: root.fam + ", Noto Sans, Noto Sans Arabic, Noto Sans Hebrew, Noto Sans Devanagari, Noto Sans CJK SC, Noto Sans Thai, Noto Sans Bengali"
                    font.pixelSize: Math.round(w.height * 0.11); font.weight: Font.Light
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
                // Live preview: a page you can actually scroll, with the shell's glass sitting over it,
                // so the effect is visible on moving content — the way the macOS sheet shows it.
                Rectangle {
                    id: prevCard
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(560, parent.width); height: 250
                    radius: 16
                    clip: true
                    color: "#15151A"

                    Item {
                        id: prevContent
                        anchors.fill: parent
                        Image {
                            anchors.fill: parent
                            source: root.bar && root.bar.wallpaperPath !== "" ? "file://" + root.bar.wallpaperPath : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true; smooth: true; mipmap: true
                            sourceSize: Qt.size(900, 500)
                        }
                        Rectangle {
                            anchors.fill: parent
                            visible: parent.children[0].status !== Image.Ready
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#8C7A6B" }
                                GradientStop { position: 1; color: "#3E3530" }
                            }
                        }
                        Flickable {
                            id: prevFlick
                            anchors.fill: parent
                            contentHeight: pcol.height + 150
                            clip: true
                            boundsBehavior: Flickable.OvershootBounds
                            Column {
                                id: pcol
                                x: 22; y: 20; width: prevCard.width - 44
                                spacing: 12
                                Text {
                                    text: "Scroll me"
                                    color: "white"; font.family: root.fam; font.pixelSize: 22; font.weight: Font.Bold
                                }
                                Repeater {
                                    model: 7
                                    delegate: Rectangle {
                                        required property int index
                                        width: pcol.width; height: 52; radius: 12
                                        color: Qt.rgba(1, 1, 1, 0.14)
                                        Rectangle {
                                            x: 12; anchors.verticalCenter: parent.verticalCenter
                                            width: 28; height: 28; radius: 8
                                            color: ["#FF375F", "#FF9F0A", "#FFD60A", "#30D158", "#64D2FF", "#0A84FF", "#BF5AF2"][index % 7]
                                        }
                                        Rectangle { x: 52; y: 15; width: parent.width * 0.42; height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.75) }
                                        Rectangle { x: 52; y: 30; width: parent.width * 0.62; height: 7; radius: 3.5; color: Qt.rgba(1, 1, 1, 0.4) }
                                    }
                                }
                            }
                        }
                    }

                    // what the chosen material does to everything behind it
                    Item {
                        id: prevGlass
                        x: 26; width: parent.width - 52
                        y: parent.height - 76; height: 54
                        readonly property real amt: root.amount
                        readonly property bool solid: root.material === "opaque"
                        property real blurPx: root.material === "blur" ? (6 + amt * 52)
                                                    : (root.material === "frosted" ? (10 + amt * 34) : (4 + amt * 22))
                        Behavior on blurPx { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        ShaderEffectSource {
                            id: prevSrc
                            anchors.fill: parent
                            visible: false
                            live: true
                            sourceItem: prevContent
                            sourceRect: Qt.rect(prevGlass.x, prevGlass.y, prevGlass.width, prevGlass.height)
                        }
                        Rectangle {
                            id: prevMask
                            anchors.fill: parent
                            radius: 16
                            color: "black"
                            visible: false
                            layer.enabled: true
                        }
                        Item {
                            anchors.fill: parent
                            visible: !prevGlass.solid
                            layer.enabled: true
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: prevMask }
                            MultiEffect {
                                anchors.fill: parent
                                source: prevSrc
                                blurEnabled: true
                                blurMax: 64
                                blur: Math.max(0, Math.min(1, prevGlass.blurPx / 64))
                                saturation: root.material === "liquid" ? 0.35 : 0.1
                                brightness: root.material === "liquid" ? 0.06 : 0
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: Qt.rgba(0.12, 0.12, 0.14,
                                           prevGlass.solid ? 0.97
                                         : (root.material === "frosted" ? 0.24 + root.amount * 0.3
                                         : (root.material === "blur" ? 0.12 + root.amount * 0.2 : 0.08 + root.amount * 0.16)))
                            Behavior on color { ColorAnimation { duration: 240 } }
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, root.material === "liquid" ? 0.3 + root.amount * 0.2 : 0.12)
                        }
                        // a search field, the way the macOS sheet shows one over the page
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 16; spacing: 10
                            Rectangle {
                                width: 26; height: 26; radius: 13
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(1, 1, 1, 0.18)
                                Canvas {
                                    anchors.centerIn: parent; width: 13; height: 13
                                    onPaint: {
                                        var c = getContext("2d"); c.reset();
                                        c.strokeStyle = "white"; c.lineWidth = 1.6; c.lineCap = "round";
                                        c.beginPath(); c.arc(5.4, 5.4, 4.1, 0, Math.PI * 2); c.stroke();
                                        c.beginPath(); c.moveTo(8.6, 8.6); c.lineTo(12, 12); c.stroke();
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search"
                                color: Qt.rgba(1, 1, 1, 0.8); font.family: root.fam; font.pixelSize: 14
                            }
                        }
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
                            scale: wma.pressed ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                            Text { anchors.centerIn: parent; text: parent.modelData.n; color: "white"; font.family: root.fam; font.pixelSize: 13; font.weight: parent.sel ? Font.DemiBold : Font.Normal }
                            MouseArea { id: wma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.material = parent.modelData.id }
                        }
                    }
                }
                // the amount slider — the System Settings one, with an icon at each end
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    opacity: root.material === "opaque" ? 0 : 1
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 240 } }
                    WSlider {
                        id: amtSlider
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 420
                        value: root.amount
                        accent: root.accent
                        minimum: root.material === "blur" ? 0.15 : 0
                        onMoved: v => root.amount = v
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 420; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        text: root.material === "blur"
                              ? "Less blur keeps more of the desktop visible; more blur hides it and makes text easier to read."
                              : "Clear is more transparent and tinted increases opacity, adding contrast to content and controls."
                        color: Qt.rgba(1, 1, 1, 0.55); font.family: root.fam; font.pixelSize: 12
                    }
                }
                WButton { label: "Continue"; onPressed2: root.step = 3 }
            }

            // ── 3: what you just installed, one card at a time ──
            Item {
                anchors.fill: parent
                opacity: root.step === 3 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

                Column {
                    id: tourCol
                    anchors.centerIn: parent
                    width: Math.min(820, parent.width - 80)
                    readonly property real cardW: Math.max(220, (width - 16) / 2)
                    spacing: 20
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "A quick tour"
                        color: "white"; font.family: root.fam; font.pixelSize: 34; font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        text: "Everything here is yours to change later \u2014 the Apple menu opens System Settings."
                        color: Qt.rgba(1, 1, 1, 0.6); font.family: root.fam; font.pixelSize: 13
                    }
                    Grid {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: tourCol.width
                        columns: 2
                        columnSpacing: 16; rowSpacing: 14
                        Repeater {
                            model: [
                                { g: "search", t: "Spotlight", c: "#0A84FF",
                                  d: "\u2318 Space. Apps, files, sums, unit conversions, emoji \u2014 and your clipboard history on \u2318 V." },
                                { g: "sliders", t: "Control Center", c: "#5E5CE6",
                                  d: "Wi\u2011Fi, Bluetooth, sound, brightness, Focus and AirDrop, all in the menu bar. Drag the tiles to rearrange them." },
                                { g: "dock", t: "The Dock", c: "#30D158",
                                  d: "Magnifies as you pass. Pin a folder from Finder and it fans its contents out in an arc." },
                                { g: "widget", t: "Widgets", c: "#FF9F0A",
                                  d: "Clock, weather, music, reminders and photos on the desktop. Right\u2011click one to resize or move it." },
                                { g: "share", t: "AirDrop", c: "#FF375F",
                                  d: "Send files to any phone or laptop running LocalSend \u2014 drop them on the window and pick who gets them." },
                                { g: "folder", t: "Finder", c: "#64D2FF",
                                  d: "Tags, coloured folders, Quick Look, USB sticks as you plug them in, and Preview for pictures." }
                            ]
                            delegate: Rectangle {
                                id: tcard
                                required property var modelData
                                required property int index
                                width: tourCol.cardW
                                height: 112
                                radius: 14
                                color: Qt.rgba(1, 1, 1, 0.07)
                                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                                // the cards arrive one after another, the way Apple's setup pages do
                                property real inT: 0
                                opacity: inT
                                transform: Translate { y: (1 - tcard.inT) * 14 }
                                SequentialAnimation {
                                    running: root.step === 3
                                    PauseAnimation { duration: 120 + tcard.index * 90 }
                                    NumberAnimation { target: tcard; property: "inT"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
                                }
                                Rectangle {
                                    x: 16; y: 16; width: 36; height: 36; radius: 10
                                    color: tcard.modelData.c
                                    WIcon { anchors.centerIn: parent; width: 20; height: 20; kind: tcard.modelData.g }
                                }
                                Text {
                                    x: 64; y: 18
                                    text: tcard.modelData.t
                                    color: "white"; font.family: root.fam; font.pixelSize: 15; font.weight: Font.DemiBold
                                }
                                Text {
                                    x: 64; y: 40; width: tcard.width - 78
                                    wrapMode: Text.WordWrap
                                    text: tcard.modelData.d
                                    color: Qt.rgba(1, 1, 1, 0.6); font.family: root.fam; font.pixelSize: 12
                                }
                            }
                        }
                    }
                    // written out here rather than reusing WButton: an inline component instantiated this deep
                    // cannot always resolve the file's ids, and the button came out grey instead of the accent
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 200; height: 40; radius: 20
                        color: tourMa.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
                        Behavior on color { ColorAnimation { duration: 160 } }
                        scale: tourMa.pressed ? 0.96 : 1
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                        Text { anchors.centerIn: parent; text: "Continue"; color: "white"; font.family: root.fam; font.pixelSize: 14; font.weight: Font.DemiBold }
                        MouseArea {
                            id: tourMa
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.step = 4; root.finish(); }
                        }
                    }
                }
            }

            // ── 4: Welcome ──
            Item {
                anchors.fill: parent
                opacity: root.step === 4 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Welcome"
                        color: "white"; font.family: root.fam; font.pixelSize: Math.round(w.height * 0.09); font.weight: Font.Light
                        opacity: root.step === 4 ? 1 : 0
                        scale: root.step === 4 ? 1 : 0.96
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
