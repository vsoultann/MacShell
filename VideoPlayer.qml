// VideoPlayer — the QuickTime-looking player MacShell uses for video: Quick Look, previews, and the odd easter egg.
//
//   hub.player.play("/path/or/url.mp4", "Title")
//   hub.player.playYoutube("https://…", "Title")      resolves a stream with yt-dlp, falls back to the browser
import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property var hub: null
    // close through the shell, so its window captures are released first (see shell.qml → hideWindow)
    function hideWin(w) { if (root.hub && root.hub.hideWindow) root.hub.hideWindow(w); else w.visible = false; }
    readonly property var dock: hub ? hub.dock : null
    readonly property string fam: dock ? dock.fontFamily : "Inter Variable"
    readonly property var bar: hub ? hub.bar : null
    readonly property color accent: dock ? dock.accent : "#0A84FF"
    readonly property bool darkMode: dock ? dock.darkMode : true

    // Light and dark follow the system appearance, and every colour eases across so the switch is a fade.
    QtObject {
        id: pal
        readonly property bool dark: root.darkMode
        property color frame: dark ? "#0B0B0C" : "#161617"
        Behavior on frame { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
        property color edge: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.18)
        Behavior on edge { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
        property color chrome: dark ? Qt.rgba(0.14, 0.14, 0.16, 0.86) : Qt.rgba(0.97, 0.97, 0.98, 0.9)
        Behavior on chrome { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
        property color chromeEdge: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
        Behavior on chromeEdge { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
        property color fg: dark ? "#FFFFFF" : "#1D1D1F"
        Behavior on fg { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
        property color fg2: dark ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(0, 0, 0, 0.6)
        Behavior on fg2 { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
        property color track: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.18)
        Behavior on track { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
        property color veil: dark ? Qt.rgba(0, 0, 0, 0.65) : Qt.rgba(0, 0, 0, 0.45)
        Behavior on veil { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
        property color lightOff: dark ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.3)
        Behavior on lightOff { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }

    property string title: ""
    property bool resolving: false

    function play(src, t) {
        title = t || "";
        resolving = false;
        player.source = src.indexOf("://") >= 0 ? src : "file://" + src;
        win.visible = true; win.raise(); win.requestActivate();
        player.play();
    }
    function playYoutube(url, t) {
        title = t || "";
        resolving = true;
        win.visible = true; win.raise(); win.requestActivate();
        ytProc.running = false;
        ytProc.command = ["sh", "-c", "yt-dlp -f 'best[height<=720][ext=mp4]/best[ext=mp4]/best' -g \"$1\" 2>/dev/null | head -1", "sh", url];
        ytFallback = url;
        ytProc.running = true;
    }
    property string ytFallback: ""
    Process {
        id: ytProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.resolving = false;
                var u = text.trim();
                if (u === "") { root.hideWin(win); Quickshell.execDetached(["xdg-open", root.ytFallback]); return; }
                player.source = u;
                player.play();
            }
        }
    }

    MediaPlayer {
        id: player
        videoOutput: vout
        audioOutput: AudioOutput { id: aout; volume: 0.9 }
        onErrorOccurred: (err, str) => { if (root.ytFallback !== "") { root.hideWin(win); Quickshell.execDetached(["xdg-open", root.ytFallback]); } }
    }

    function toggle() { player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play(); }
    function fmt(ms) {
        if (!(ms > 0)) return "0:00";
        var s = Math.floor(ms / 1000), m = Math.floor(s / 60);
        return m + ":" + ("0" + (s % 60)).slice(-2);
    }

    Window {
        id: win
        // Super + Q, Super + W, the Dock's Quit: same careful close as the traffic light
        onClosing: close => { close.accepted = false; root.hideWin(win); }
        title: "Player"
        width: 900; height: 540
        minimumWidth: 420; minimumHeight: 260
        visible: false
        color: "transparent"
        flags: Qt.Window | Qt.FramelessWindowHint
        // arriving: the way Quick Look hands a video over — scale up, fade in, settle
        property real arrive: 0
        onVisibleChanged: {
            if (visible) { arrive = 0; arriveAnim.restart(); }
            else player.stop();
        }
        NumberAnimation { id: arriveAnim; target: win; property: "arrive"; from: 0; to: 1; duration: 420; easing.type: Easing.OutQuint }

        Rectangle {
            anchors.fill: parent
            radius: 12
            opacity: Math.min(1, win.arrive * 1.6)
            scale: 0.94 + 0.06 * win.arrive
            color: pal.frame
            border.width: 1; border.color: pal.edge
            clip: true

            VideoOutput { id: vout; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectFit }

            // spinner while yt-dlp works
            Item {
                anchors.centerIn: parent
                width: 44; height: 44
                visible: root.resolving || player.mediaStatus === MediaPlayer.LoadingMedia
                Repeater {
                    model: 12
                    delegate: Rectangle {
                        required property int index
                        width: 3; height: 10; radius: 1.5
                        color: Qt.rgba(1, 1, 1, 0.85)
                        x: 20.5; y: 0
                        transform: Rotation { origin.x: 1.5; origin.y: 22; angle: index * 30 }
                        opacity: 0.15 + 0.85 * ((index + spin.tick) % 12) / 12
                    }
                }
                Timer { id: spin; property int tick: 0; interval: 80; repeat: true; running: parent.visible; onTriggered: tick = (tick + 1) % 12 }
            }

            MouseArea {
                id: surface
                anchors.fill: parent
                hoverEnabled: true
                onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
                onDoubleClicked: win.visibility === Window.FullScreen ? win.showNormal() : win.showFullScreen()
            }
            DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }

            // title bar, fades with the controls
            Rectangle {
                width: parent.width; height: 52
                opacity: ui.shownUi ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                gradient: Gradient {
                    GradientStop { position: 0; color: pal.veil }
                    GradientStop { position: 1; color: "transparent" }
                }
                // the same traffic lights as every other MacShell window: the symbols come up on hover
                Item {
                    x: 16; y: 15; width: 58; height: 14
                    Row {
                        spacing: 8
                        Repeater {
                            model: [{ c: "#FF5F57", g: "\u00D7" }, { c: "#FEBC2E", g: "\u2212" }, { c: "#28C840", g: "\u2197" }]
                            delegate: Rectangle {
                                required property var modelData
                                width: 14; height: 14; radius: 7
                                color: ((root.bar && root.bar.tlColorOnHover) ? tlMa.containsMouse : (win.active || tlMa.containsMouse)) ? modelData.c : pal.lightOff
                                border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.14)
                                Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.g
                                    font.pixelSize: 11; font.bold: true
                                    color: Qt.rgba(0, 0, 0, 0.55)
                                    opacity: (tlMa.containsMouse || (root.bar && root.bar.tlAlwaysSymbols)) ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: tlMa
                        anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.x < 25) root.hideWin(win);
                            else if (mouse.x < 47) root.hub && root.hub.minimizeWindow ? root.hub.minimizeWindow(win.title) : win.showMinimized();
                            else win.visibility === Window.FullScreen ? win.showNormal() : win.showFullScreen();
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 16
                    text: root.title
                    color: "white"; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold
                }
            }

            // the floating glass control bar
            Item {
                id: ui
                readonly property bool shownUi: surface.containsMouse || player.playbackState !== MediaPlayer.PlayingState || hoverBar.containsMouse
                anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 40, 720); height: 54
                opacity: shownUi ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                transform: Translate { y: ui.shownUi ? 0 : 10; Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: pal.chrome
                    border.width: 1; border.color: pal.chromeEdge
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.8; shadowOpacity: 0.45; shadowVerticalOffset: 6 }
                }
                MouseArea { id: hoverBar; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                PGlyph {
                    x: 16; anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18
                    kind: player.playbackState === MediaPlayer.PlayingState ? "pause" : "play"
                    MouseArea { anchors.fill: parent; anchors.margins: -10; cursorShape: Qt.PointingHandCursor; onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play() }
                }
                Text {
                    x: 48; anchors.verticalCenter: parent.verticalCenter
                    text: root.fmt(player.position)
                    color: pal.fg2; font.family: root.fam; font.pixelSize: 11
                }
                // scrubber
                Item {
                    x: 92; width: parent.width - 92 - 250
                    height: 20; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { y: 8; width: parent.width; height: 4; radius: 2; color: pal.track }
                    Rectangle {
                        y: 8; height: 4; radius: 2; color: pal.fg
                        width: player.duration > 0 ? parent.width * (player.position / player.duration) : 0
                    }
                    Rectangle {
                        y: 4; width: 12; height: 12; radius: 6; color: pal.fg
                        x: (player.duration > 0 ? parent.width * (player.position / player.duration) : 0) - 6
                        scale: scrub.pressed ? 1.25 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    }
                    MouseArea {
                        id: scrub
                        anchors.fill: parent; anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => { if (player.duration > 0) player.position = Math.max(0, Math.min(1, (mouse.x - 8) / parent.width)) * player.duration; }
                        onPositionChanged: mouse => { if (pressed && player.duration > 0) player.position = Math.max(0, Math.min(1, (mouse.x - 8) / parent.width)) * player.duration; }
                    }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 212
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.fmt(player.duration)
                    color: pal.fg2; font.family: root.fam; font.pixelSize: 11
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    // subtitles, when the file carries any
                    PGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        kind: "cc"
                        opacity: player.subtitleTracks.length > 0 ? (player.activeSubtitleTrack >= 0 ? 1 : 0.45) : 0.2
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -8
                            enabled: player.subtitleTracks.length > 0
                            cursorShape: Qt.PointingHandCursor
                            onClicked: player.activeSubtitleTrack = player.activeSubtitleTrack >= 0 ? -1 : 0
                        }
                    }
                    // playback speed
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (player.playbackRate === 1 ? "1\u00D7" : player.playbackRate.toFixed(player.playbackRate < 1 ? 2 : 1).replace(/\.0$/, "") + "\u00D7")
                        color: pal.fg2; font.family: root.fam; font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var steps = [0.5, 0.75, 1, 1.25, 1.5, 2];
                                var i = steps.indexOf(player.playbackRate);
                                player.playbackRate = steps[(i + 1) % steps.length];
                            }
                        }
                    }
                    PGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 17; height: 17
                        kind: aout.muted ? "mute" : "volume"
                        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: aout.muted = !aout.muted }
                    }
                    // volume
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 56; height: 16
                        Rectangle { y: 6; width: parent.width; height: 4; radius: 2; color: pal.track }
                        Rectangle { y: 6; width: parent.width * aout.volume; height: 4; radius: 2; color: pal.fg }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            onPressed: mouse => { aout.muted = false; aout.volume = Math.max(0, Math.min(1, (mouse.x - 6) / parent.width)); }
                            onPositionChanged: mouse => { if (pressed) aout.volume = Math.max(0, Math.min(1, (mouse.x - 6) / parent.width)); }
                        }
                    }
                    PGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        kind: "expand"
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                            onClicked: win.visibility === Window.FullScreen ? win.showNormal() : win.showFullScreen()
                        }
                    }
                }
            }

            MouseArea { x: parent.width - 8; y: parent.height - 8; width: 8; height: 8; z: 100; cursorShape: Qt.SizeFDiagCursor; onPressed: win.startSystemResize(Qt.BottomEdge | Qt.RightEdge) }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Space) player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play();
                else if (event.key === Qt.Key_Escape) win.visibility === Window.FullScreen ? win.showNormal() : root.hideWin(win);
                else if (event.key === Qt.Key_Left) player.position = Math.max(0, player.position - 10000);
                else if (event.key === Qt.Key_Right) player.position = Math.min(player.duration, player.position + 10000);
                else return;
                event.accepted = true;
            }
            focus: true
        }
    }

    component PGlyph: Canvas {
        id: pg
        property string kind: ""
        property color color: pal.fg
        antialiasing: true
        onKindChanged: requestPaint()
        onColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"); c.reset();
            var s = width / 16; c.scale(s, s);
            c.fillStyle = pg.color; c.strokeStyle = pg.color; c.lineWidth = 1.5; c.lineCap = "round"; c.lineJoin = "round";
            if (kind === "play") { c.beginPath(); c.moveTo(4.5, 3); c.lineTo(13, 8); c.lineTo(4.5, 13); c.closePath(); c.fill(); }
            else if (kind === "pause") { c.beginPath(); c.roundedRect(4.2, 3, 2.8, 10, 0.9, 0.9); c.fill(); c.beginPath(); c.roundedRect(9, 3, 2.8, 10, 0.9, 0.9); c.fill(); }
            else if (kind === "cc") {
                c.lineWidth = 1.4;
                c.beginPath(); c.roundedRect(1.6, 3.4, 12.8, 9.2, 2, 2); c.stroke();
                c.beginPath(); c.moveTo(6.4, 6.6); c.lineTo(4.6, 6.6); c.lineTo(4.6, 9.4); c.lineTo(6.4, 9.4); c.stroke();
                c.beginPath(); c.moveTo(11.6, 6.6); c.lineTo(9.8, 6.6); c.lineTo(9.8, 9.4); c.lineTo(11.6, 9.4); c.stroke();
            }
            else if (kind === "expand") {
                c.lineWidth = 1.6;
                c.beginPath(); c.moveTo(2.4, 6.2); c.lineTo(2.4, 2.4); c.lineTo(6.2, 2.4); c.stroke();
                c.beginPath(); c.moveTo(13.6, 9.8); c.lineTo(13.6, 13.6); c.lineTo(9.8, 13.6); c.stroke();
                c.beginPath(); c.moveTo(2.4, 2.4); c.lineTo(6.6, 6.6); c.moveTo(13.6, 13.6); c.lineTo(9.4, 9.4); c.stroke();
            }
            else if (kind === "volume" || kind === "mute") {
                c.beginPath(); c.moveTo(2, 6.2); c.lineTo(4.6, 6.2); c.lineTo(7.8, 3.4); c.lineTo(7.8, 12.6); c.lineTo(4.6, 9.8); c.lineTo(2, 9.8); c.closePath(); c.fill();
                if (kind === "mute") { c.beginPath(); c.moveTo(10.2, 6); c.lineTo(14, 10); c.moveTo(14, 6); c.lineTo(10.2, 10); c.stroke(); }
                else { c.beginPath(); c.arc(9.4, 8, 2.2, -0.9, 0.9); c.stroke(); c.beginPath(); c.arc(9.4, 8, 4.2, -0.9, 0.9); c.stroke(); }
            }
        }
    }
}
