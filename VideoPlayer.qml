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
    readonly property var dock: hub ? hub.dock : null
    readonly property string fam: dock ? dock.fontFamily : "Inter Variable"
    readonly property color accent: dock ? dock.accent : "#0A84FF"

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
                if (u === "") { win.visible = false; Quickshell.execDetached(["xdg-open", root.ytFallback]); return; }
                player.source = u;
                player.play();
            }
        }
    }

    MediaPlayer {
        id: player
        videoOutput: vout
        audioOutput: AudioOutput { id: aout; volume: 0.9 }
        onErrorOccurred: (err, str) => { if (root.ytFallback !== "") { win.visible = false; Quickshell.execDetached(["xdg-open", root.ytFallback]); } }
    }

    function fmt(ms) {
        if (!(ms > 0)) return "0:00";
        var s = Math.floor(ms / 1000), m = Math.floor(s / 60);
        return m + ":" + ("0" + (s % 60)).slice(-2);
    }

    Window {
        id: win
        title: "Player"
        width: 900; height: 540
        minimumWidth: 420; minimumHeight: 260
        visible: false
        color: "transparent"
        flags: Qt.Window | Qt.FramelessWindowHint
        onVisibleChanged: if (!visible) player.stop()

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#0B0B0C"
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
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
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.65) }
                    GradientStop { position: 1; color: "transparent" }
                }
                Row {
                    x: 16; y: 18
                    spacing: 8
                    Repeater {
                        model: ["#FF5F57", "#FEBC2E", "#28C840"]
                        delegate: Rectangle {
                            required property string modelData
                            required property int index
                            width: 13; height: 13; radius: 6.5; color: modelData
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (parent.index === 0) win.visible = false;
                                    else if (parent.index === 1) win.showMinimized();
                                    else win.visibility === Window.FullScreen ? win.showNormal() : win.showFullScreen();
                                }
                            }
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
                width: Math.min(parent.width - 40, 560); height: 54
                opacity: shownUi ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                transform: Translate { y: ui.shownUi ? 0 : 10; Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Qt.rgba(0.14, 0.14, 0.16, 0.86)
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.16)
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
                    color: Qt.rgba(1, 1, 1, 0.75); font.family: root.fam; font.pixelSize: 11
                }
                // scrubber
                Item {
                    x: 92; width: parent.width - 92 - 92
                    height: 20; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { y: 8; width: parent.width; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
                    Rectangle {
                        y: 8; height: 4; radius: 2; color: "white"
                        width: player.duration > 0 ? parent.width * (player.position / player.duration) : 0
                    }
                    Rectangle {
                        y: 4; width: 12; height: 12; radius: 6; color: "white"
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
                    anchors.right: parent.right; anchors.rightMargin: 52
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.fmt(player.duration)
                    color: Qt.rgba(1, 1, 1, 0.75); font.family: root.fam; font.pixelSize: 11
                }
                PGlyph {
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17; height: 17
                    kind: aout.muted ? "mute" : "volume"
                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: aout.muted = !aout.muted }
                }
            }

            MouseArea { x: parent.width - 8; y: parent.height - 8; width: 8; height: 8; z: 100; cursorShape: Qt.SizeFDiagCursor; onPressed: win.startSystemResize(Qt.BottomEdge | Qt.RightEdge) }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Space) player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play();
                else if (event.key === Qt.Key_Escape) win.visibility === Window.FullScreen ? win.showNormal() : (win.visible = false);
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
        antialiasing: true
        onKindChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"); c.reset();
            var s = width / 16; c.scale(s, s);
            c.fillStyle = "white"; c.strokeStyle = "white"; c.lineWidth = 1.5; c.lineCap = "round"; c.lineJoin = "round";
            if (kind === "play") { c.beginPath(); c.moveTo(4.5, 3); c.lineTo(13, 8); c.lineTo(4.5, 13); c.closePath(); c.fill(); }
            else if (kind === "pause") { c.beginPath(); c.roundedRect(4.2, 3, 2.8, 10, 0.9, 0.9); c.fill(); c.beginPath(); c.roundedRect(9, 3, 2.8, 10, 0.9, 0.9); c.fill(); }
            else if (kind === "volume" || kind === "mute") {
                c.beginPath(); c.moveTo(2, 6.2); c.lineTo(4.6, 6.2); c.lineTo(7.8, 3.4); c.lineTo(7.8, 12.6); c.lineTo(4.6, 9.8); c.lineTo(2, 9.8); c.closePath(); c.fill();
                if (kind === "mute") { c.beginPath(); c.moveTo(10.2, 6); c.lineTo(14, 10); c.moveTo(14, 6); c.lineTo(10.2, 10); c.stroke(); }
                else { c.beginPath(); c.arc(9.4, 8, 2.2, -0.9, 0.9); c.stroke(); c.beginPath(); c.arc(9.4, 8, 4.2, -0.9, 0.9); c.stroke(); }
            }
        }
    }
}
