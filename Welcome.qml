// Welcome — the screen that runs once after installing, the way macOS greets you.
//
//   qs -c MacShell ipc call welcome open      (it also runs itself the first time, unless ~/.config/macshell/welcome-done exists)
//
// hello in every language → your name and picture → the material, with a live preview → Welcome.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtMultimedia
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
    property string appearance: "dark"
    property color pickAccent: "#0A84FF"
    property int avatarPick: -1
    readonly property var accents: [
        { n: "Blue", c: "#0a84ff" }, { n: "Purple", c: "#bf5af2" }, { n: "Pink", c: "#ff375f" }, { n: "Red", c: "#ff453a" },
        { n: "Orange", c: "#ff9f0a" }, { n: "Yellow", c: "#ffd60a" }, { n: "Green", c: "#30d158" }, { n: "Graphite", c: "#8e8e93" }
    ]
    // C: what the look page needs from the shell — the real glass shader, and a Mac picture to sit on
    readonly property url glassShader: bar && bar.glassShaderUrl ? bar.glassShaderUrl
                                     : "file://" + Quickshell.env("HOME") + "/.config/macbar/liquidglass.frag.qsb"
    readonly property string goldenGate: Quickshell.env("HOME") + "/Pictures/Wallpapers/macos-27-GoldenGate-" + (appearance === "dark" ? "Dark" : "Light") + ".png"
    property bool hasGoldenGate: false
    // One of Apple's aerials behind the greeting, nature first. They are the films Apple uses for its screen
    // savers and wallpapers; if there are none on this machine the Mac picture below is used instead.
    property string aerial: ""
    Process {
        id: aerialFind
        running: true
        command: ["sh", "-c",
            "for d in \"$HOME/Pictures/Wallpapers/Apple Aerials\" \"$HOME/.local/share/macshell/aerials\" \"$HOME/Videos/Apple Aerials\"; do "
            + "  [ -d \"$d\" ] || continue; "
            + "  for n in 'Greenland Icebergs' 'Zhangjiajie' 'Greenland Sunset' 'Iceland' 'Hawaii' 'Yosemite' 'Patagonia' 'Scotland'; do "
            + "    f=$(ls \"$d\"/*\"$n\"*.mp4 2>/dev/null | head -1); [ -n \"$f\" ] && { echo \"$f\"; exit 0; }; "
            + "  done; "
            + "done; exit 0"]
        stdout: StdioCollector { onStreamFinished: root.aerial = text.trim() }
    }
    readonly property string macWallpaper: hasGoldenGate ? "file://" + goldenGate
                                         : (bar && bar.wallpaperPath ? "file://" + bar.wallpaperPath : "")
    // how much tint the glass carries for the chosen material and amount (the same curve the shell uses)
    readonly property real glassTint: material === "opaque" ? 1
                                    : (material === "frosted" ? 0.28 + amount * 0.34
                                    : (material === "blur" ? 0.16 + amount * 0.22 : 0.10 + amount * 0.26))
    Process {
        id: ggCheck
        running: true
        command: ["sh", "-c", "[ -r \"$HOME/Pictures/Wallpapers/macos-27-GoldenGate-Dark.png\" ] && echo yes || echo no"]
        stdout: StdioCollector { onStreamFinished: root.hasGoldenGate = text.trim() === "yes" }
    }

    readonly property var hellos: [
        "hello", "مرحبا", "bonjour", "hola", "你好", "こんにちは", "안녕하세요", "olá", "привет",
        "ciao", "hallo", "नमस्ते", "merhaba", "שלום", "cześć", "hej", "xin chào", "สวัสดี",
        "γεια σου", "ahoj", "নমস্কার", "سلام", "habari", "halo", "szia", "tere", "sveiki",
        "bună", "zdravo", "selam", "hei", "kamusta", "aloha"
    ]
    readonly property var avatars: [
        { c1: "#FF9F0A", c2: "#FF375F" }, { c1: "#0A84FF", c2: "#5E5CE6" }, { c1: "#30D158", c2: "#0A84FF" },
        { c1: "#BF5AF2", c2: "#FF375F" }, { c1: "#FFD60A", c2: "#FF9F0A" }, { c1: "#64D2FF", c2: "#0A84FF" }
    ]

    Timer {
        id: helloTimer
        interval: 2600; repeat: true; running: root.shown && root.step === 0
        onTriggered: {
            root.helloIdx++;
            if (root.helloIdx >= root.hellos.length) { root.helloIdx = 0; root.step = 1; }
        }
    }

    function open() {
        step = 0; helloIdx = 0;
        userName = Quickshell.env("USER") || "";
        if (bar) {
            material = bar.material === "custom" ? "liquid" : bar.material;
            appearance = bar.darkMode ? "dark" : "light";
            pickAccent = bar.accent;
        }
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
        // appearance and accent are system settings: they go through the Dock, which every app reads
        if (hub && hub.dock && hub.dock.setLook) {
            hub.dock.setLook("darkMode", appearance === "dark");
            hub.dock.setLook("accent", pickAccent);
        } else if (bar) {
            bar.darkMode = (appearance === "dark");
            bar.accent = pickAccent;
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
            // A Mac picture behind everything: the macOS Golden Gate wallpaper when it is installed, otherwise
            // your own. Blurred and dimmed the way Setup Assistant sits over its backdrop, so text stays legible.
            Item {
                id: backdrop
                anchors.fill: parent
                // Apple's aerial: full and clear behind the greeting, then soft and dim behind the pages that follow
                Item {
                    id: aerialLayer
                    anchors.fill: parent
                    visible: w.isMain && root.aerial !== ""
                    MediaPlayer {
                        id: aerialPlayer
                        source: root.aerial !== "" ? "file://" + root.aerial : ""
                        loops: MediaPlayer.Infinite
                        videoOutput: aerialOut
                        audioOutput: AudioOutput { muted: true }
                    }
                    VideoOutput { id: aerialOut; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop; visible: false }
                    MultiEffect {
                        anchors.fill: parent
                        source: aerialOut
                        blurEnabled: true; blurMax: 64
                        blur: root.step === 0 ? 0 : 0.8
                        brightness: root.step === 0 ? -0.06 : -0.32
                        Behavior on blur { NumberAnimation { duration: 900; easing.type: Easing.InOutCubic } }
                        Behavior on brightness { NumberAnimation { duration: 900; easing.type: Easing.InOutCubic } }
                    }
                    Connections {
                        target: root
                        function onShownChanged() { if (root.shown && root.aerial !== "" && w.isMain) aerialPlayer.play(); else aerialPlayer.stop(); }
                        function onAerialChanged() { if (root.shown && root.aerial !== "" && w.isMain) aerialPlayer.play(); }
                    }
                    Component.onCompleted: if (root.shown && root.aerial !== "" && w.isMain) aerialPlayer.play()
                }
                Image {
                    id: helloWall
                    anchors.fill: parent
                    source: root.macWallpaper
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: true; smooth: true
                    sourceSize: Qt.size(1600, 1000)
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: helloWall
                    visible: helloWall.status === Image.Ready && !aerialLayer.visible
                    blurEnabled: true; blurMax: 64; blur: 0.85
                    saturation: 0.15
                    // dim in both modes: the page's text is white, and Light / Dark is shown in the preview card
                    brightness: root.appearance === "dark" ? -0.34 : -0.28
                    // a slow drift, so the backdrop feels alive without pulling the eye
                    scale: 1.06
                    SequentialAnimation on x {
                        running: root.shown; loops: Animation.Infinite
                        NumberAnimation { from: -18; to: 18; duration: 24000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 18; to: -18; duration: 24000; easing.type: Easing.InOutSine }
                    }
                }
                // no picture at all: the old soft glow
                Rectangle {
                    anchors.centerIn: parent
                    visible: helloWall.status !== Image.Ready && !aerialLayer.visible
                    width: Math.hypot(parent.width, parent.height) * 1.1; height: width
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0.05, 0.25, 0.65, 0.55) }
                        GradientStop { position: 1; color: Qt.rgba(0.35, 0.05, 0.45, 0.35) }
                    }
                    opacity: 0.6
                    NumberAnimation on rotation { from: 0; to: 360; duration: 90000; loops: Animation.Infinite; running: root.shown && !helloWall.visible }
                }
            }

            // ── 0: hello in every language ──
            Item {
                anchors.fill: parent
                opacity: root.step === 0 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                // the greeting is Liquid Glass — the lock screen clock's material — with the aerial bent through it.
                // One real font family: Qt then falls back glyph by glyph for every script Inter doesn't cover.
                GlassText {
                    anchors.centerIn: parent
                    text: root.hellos[Math.min(root.helloIdx, root.hellos.length - 1)]
                    font.family: root.fam
                    font.pixelSize: Math.round(w.height * 0.17)
                    font.weight: Font.Bold
                    duration: 1300
                    backdrop: backdrop
                    frame: w.contentItem
                    // thick, clear glass: each stroke rounds off over most of its width, so the whole letter bends the
                    // scene like a lens instead of only catching light at its rim
                    dome: true
                    intensity: 0.0
                    rimSoft: Math.round(w.height * 0.012)
                    bevel: 22
                    refract: Math.round(w.height * 0.035)
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
                // The preview uses the shell's own Liquid Glass component and shader, so what you pick here
                // is literally what you get: the slider moves the same uniforms the menu bar uses.
                Rectangle {
                    id: prevCard
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(640, parent.width); height: 300
                    radius: 16
                    clip: true
                    color: root.appearance === "dark" ? "#15151A" : "#E9E9EE"
                    Behavior on color { ColorAnimation { duration: 260 } }

                    Item {
                        id: prevContent
                        anchors.fill: parent

                        Image {
                            id: prevWall
                            anchors.fill: parent
                            source: root.macWallpaper
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true; smooth: true; mipmap: true
                            sourceSize: Qt.size(1000, 480)
                        }
                        Rectangle {
                            anchors.fill: parent
                            visible: prevWall.status !== Image.Ready
                            gradient: Gradient {
                                GradientStop { position: 0; color: root.appearance === "dark" ? "#2B3A55" : "#BBD3F2" }
                                GradientStop { position: 1; color: root.appearance === "dark" ? "#0E1018" : "#F2E7DA" }
                            }
                        }

                        Flickable {
                            id: prevFlick
                            anchors.fill: parent
                            anchors.topMargin: 30
                            contentHeight: pcol.height + 150
                            clip: true
                            boundsBehavior: Flickable.OvershootBounds
                            Column {
                                id: pcol
                                x: 22; y: 16; width: prevCard.width - 44
                                spacing: 10
                                Text {
                                    text: "Scroll me"
                                    color: root.appearance === "dark" ? "white" : "#1D1D1F"
                                    font.family: root.fam; font.pixelSize: 20; font.weight: Font.Bold
                                }
                                Repeater {
                                    model: 7
                                    delegate: Rectangle {
                                        required property int index
                                        width: pcol.width; height: 46; radius: 11
                                        color: root.appearance === "dark" ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.62)
                                        Rectangle {
                                            x: 10; anchors.verticalCenter: parent.verticalCenter
                                            width: 26; height: 26; radius: 7
                                            color: root.accents[index % root.accents.length].c
                                        }
                                        Rectangle { x: 48; y: 13; width: parent.width * 0.4; height: 7; radius: 3.5
                                                    color: root.appearance === "dark" ? Qt.rgba(1, 1, 1, 0.8) : Qt.rgba(0, 0, 0, 0.6) }
                                        Rectangle { x: 48; y: 26; width: parent.width * 0.6; height: 6; radius: 3
                                                    color: root.appearance === "dark" ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(0, 0, 0, 0.3) }
                                    }
                                }
                            }
                        }
                    }

                    // what the glass refracts (the page, never itself)
                    ShaderEffectSource {
                        id: prevTex
                        anchors.fill: parent
                        visible: false
                        live: true
                        mipmap: true
                        sourceItem: prevContent
                    }

                    // a menu bar and a Control Center card, both the real thing
                    WGlass {
                        x: 8; y: 6; width: prevCard.width - 16; height: 24
                        src: prevTex; frame: prevCard
                        shaderUrl: root.glassShader
                        material: root.material
                        dark: root.appearance === "dark"
                        cornerR: 10
                        thickness: 14
                        strength: 0.5 + root.amount * 1.1
                        tint: root.glassTint
                        rim: 0.45
                        shadowAmt: 0.2
                    }
                    WGlass {
                        id: prevPanel
                        x: prevCard.width - 236; y: prevCard.height - 150
                        width: 220; height: 130
                        src: prevTex; frame: prevCard
                        shaderUrl: root.glassShader
                        material: root.material
                        dark: root.appearance === "dark"
                        cornerR: 18
                        thickness: 26
                        strength: 0.5 + root.amount * 1.1
                        tint: root.glassTint
                        rim: 0.55
                        shadowAmt: 0.4
                    }
                    Column {
                        x: prevPanel.x + 14; y: prevPanel.y + 12
                        spacing: 9
                        Text {
                            text: "Control Center"
                            color: root.appearance === "dark" ? "white" : "#1D1D1F"
                            font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold
                        }
                        Row {
                            spacing: 8
                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    required property int index
                                    width: 34; height: 34; radius: 17
                                    color: index === 0 ? root.pickAccent
                                         : (root.appearance === "dark" ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12))
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }
                        Rectangle {
                            width: 190; height: 9; radius: 4.5
                            color: root.appearance === "dark" ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.15)
                            Rectangle { width: parent.width * 0.6; height: parent.height; radius: parent.radius; color: root.pickAccent }
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
                            color: sel ? root.pickAccent : Qt.rgba(1, 1, 1, 0.12)
                            Behavior on color { ColorAnimation { duration: 200 } }
                            scale: wma.pressed ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                            Text { anchors.centerIn: parent; text: parent.modelData.n; color: "white"; font.family: root.fam; font.pixelSize: 13; font.weight: parent.sel ? Font.DemiBold : Font.Normal }
                            MouseArea { id: wma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.material = parent.modelData.id }
                        }
                    }
                }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    opacity: root.material === "opaque" ? 0 : 1
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 240 } }
                    WSlider {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 420
                        value: root.amount
                        accent: root.pickAccent
                        minimum: root.material === "blur" ? 0.15 : 0
                        onMoved: v => root.amount = v
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 440; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        text: root.material === "blur"
                              ? "Less blur keeps more of the desktop visible; more blur hides it and makes text easier to read."
                              : "Clear is more transparent and tinted increases opacity, adding contrast to content and controls."
                        color: Qt.rgba(1, 1, 1, 0.55); font.family: root.fam; font.pixelSize: 12
                    }
                }

                // ── appearance and accent, both previewed above as you pick them ──
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 36
                    Column {
                        spacing: 8
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Appearance"; color: Qt.rgba(1, 1, 1, 0.6); font.family: root.fam; font.pixelSize: 12 }
                        Row {
                            spacing: 12
                            Repeater {
                                model: [{ k: "light", n: "Light" }, { k: "dark", n: "Dark" }]
                                delegate: Column {
                                    required property var modelData
                                    readonly property bool sel: root.appearance === modelData.k
                                    spacing: 5
                                    Rectangle {
                                        width: 86; height: 54; radius: 8
                                        color: parent.modelData.k === "dark" ? "#2A2A2E" : "#EDEDF0"
                                        border.width: parent.sel ? 3 : 1
                                        border.color: parent.sel ? root.pickAccent : Qt.rgba(1, 1, 1, 0.18)
                                        Behavior on border.color { ColorAnimation { duration: 180 } }
                                        Rectangle {
                                            x: 7; y: 7; width: parent.width - 14; height: 9; radius: 3
                                            color: parent.parent.modelData.k === "dark" ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.2)
                                        }
                                        Rectangle {
                                            x: 7; y: 22; width: (parent.width - 14) * 0.7; height: 7; radius: 3
                                            color: root.pickAccent
                                        }
                                        Rectangle {
                                            x: 7; y: 34; width: (parent.width - 14) * 0.5; height: 7; radius: 3
                                            color: parent.parent.modelData.k === "dark" ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.14)
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.appearance = parent.parent.modelData.k }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: parent.modelData.n
                                        color: parent.sel ? "white" : Qt.rgba(1, 1, 1, 0.55)
                                        font.family: root.fam; font.pixelSize: 12; font.weight: parent.sel ? Font.DemiBold : Font.Normal
                                    }
                                }
                            }
                        }
                    }
                    Column {
                        spacing: 8
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Accent colour"; color: Qt.rgba(1, 1, 1, 0.6); font.family: root.fam; font.pixelSize: 12 }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            topPadding: 14
                            Repeater {
                                model: root.accents
                                delegate: Item {
                                    required property var modelData
                                    readonly property bool sel: String(root.pickAccent).toLowerCase() === modelData.c.toLowerCase()
                                    width: 28; height: 28
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 20; height: 20; radius: 10
                                        color: parent.modelData.c
                                        border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.2)
                                        scale: swMa.pressed ? 0.88 : 1
                                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                                    }
                                    Rectangle {
                                        anchors.centerIn: parent
                                        visible: parent.sel
                                        width: 26; height: 26; radius: 13
                                        color: "transparent"
                                        border.width: 2; border.color: Qt.rgba(1, 1, 1, 0.75)
                                    }
                                    MouseArea { id: swMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pickAccent = parent.modelData.c }
                                }
                            }
                        }
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
                        color: tourMa.containsMouse ? Qt.lighter(root.pickAccent, 1.1) : root.pickAccent
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
        color: wbMa.containsMouse ? Qt.lighter(root.pickAccent, 1.1) : root.pickAccent
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
