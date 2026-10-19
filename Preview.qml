// Preview — the macOS Preview window for pictures: thumbnails down the side, zoom, rotate, pan, and the arrow keys.
//
//   qs -c MacShell ipc call preview open <path>
//
// Finder, the desktop and Photos open pictures here instead of handing them to whatever xdg-open happens to be.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property var hub: null
    // close through the shell, so its window captures are released first (see shell.qml → hideWindow)
    function hideWin(w) { if (root.hub && root.hub.hideWindow) root.hub.hideWindow(w); else w.visible = false; }
    readonly property var dock: hub ? hub.dock : null
    readonly property var bar: hub ? hub.bar : null
    readonly property bool darkMode: dock ? dock.darkMode : true
    readonly property string fam: dock ? dock.fontFamily : "Inter Variable"
    property color accent: dock ? dock.accent : "#0A84FF"
    Behavior on accent { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }

    property string path: ""                 // the picture on screen
    property var siblings: []                // every picture in the same folder
    property int index: 0
    property real zoom: 1
    property bool fit: true
    property int rotation: 0
    property bool sidebar: true

    function open(p) {
        if (!p || p === "") return;
        path = p;
        zoom = 1; fit = true; rotation = 0;
        win.visible = true; win.raise(); win.requestActivate();
        scanSiblings();
    }
    function scanSiblings() {
        var dir = path.substring(0, path.lastIndexOf("/"));
        sibProc.running = false;
        sibProc.command = ["sh", "-c",
            "cd \"$1\" 2>/dev/null || exit 0; find . -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' "
            + "-o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.avif' -o -iname '*.tif' -o -iname '*.tiff' \\) "
            + "! -name '.*' -printf '%f\\n' 2>/dev/null | LC_ALL=C sort | head -400", "sh", dir];
        sibProc.running = true;
    }
    Process {
        id: sibProc
        stdout: StdioCollector {
            onStreamFinished: {
                var dir = root.path.substring(0, root.path.lastIndexOf("/"));
                var out = [], ls = text.split("\n");
                for (var i = 0; i < ls.length; i++) {
                    var n = ls[i].trim();
                    if (n === "") continue;
                    out.push({ name: n, path: dir + "/" + n });
                }
                root.siblings = out;
                for (var j = 0; j < out.length; j++) if (out[j].path === root.path) { root.index = j; break; }
            }
        }
    }
    property string prevPath: ""
    property int dir: 1                      // which way the next picture comes from
    function show(i) {
        if (i < 0 || i >= siblings.length || i === index) return;
        dir = i > index ? 1 : -1;
        prevPath = path;
        index = i;
        path = siblings[i].path;
        zoom = 1; fit = true; rotation = 0;
        swap.restart();
    }
    property real swapT: 1
    NumberAnimation { id: swap; target: root; property: "swapT"; from: 0; to: 1; duration: 420; easing.type: Easing.OutQuint }
    function trash() {
        Quickshell.execDetached(["sh", "-c", "gio trash \"$1\" 2>/dev/null || { mkdir -p \"$HOME/.local/share/Trash/files\" && mv \"$1\" \"$HOME/.local/share/Trash/files/\"; }", "sh", path]);
        var next = Math.min(index, siblings.length - 2);
        var keep = siblings.filter(function (s) { return s.path !== root.path; });
        siblings = keep;
        if (keep.length === 0) root.hideWin(win); else show(Math.max(0, next));
    }

    Window {
        id: win
        // Super + Q, Super + W, the Dock's Quit: same careful close as the traffic light
        onClosing: close => { close.accepted = false; root.hideWin(win); }
        title: "Preview"
        width: 960; height: 660
        minimumWidth: 520; minimumHeight: 360
        visible: false
        color: "transparent"
        flags: Qt.Window | Qt.FramelessWindowHint

        QtObject {
            id: pal
            readonly property bool dark: root.darkMode
            property color bg: dark ? "#1C1C1E" : "#FFFFFF"
            Behavior on bg { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color side: dark ? "#242426" : "#F4F4F6"
            Behavior on side { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color canvas: dark ? "#111113" : "#E9E9EC"
            Behavior on canvas { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color text: dark ? "#F5F5F7" : "#1D1D1F"
            Behavior on text { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color text2: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)
            Behavior on text2 { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color text3: dark ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.28)
            Behavior on text3 { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color sep: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.09)
            Behavior on sep { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color pill: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07)
            Behavior on pill { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color border: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.2)
            Behavior on border { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color lightOff: dark ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.15)
            Behavior on lightOff { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: pal.bg
            border.width: 1; border.color: pal.border
            clip: true
            focus: true

            MouseArea { x: parent.width - 8; y: parent.height - 8; width: 8; height: 8; z: 100; cursorShape: Qt.SizeFDiagCursor; onPressed: win.startSystemResize(Qt.BottomEdge | Qt.RightEdge) }
            MouseArea { x: parent.width - 5; y: 10; width: 5; height: parent.height - 20; z: 100; cursorShape: Qt.SizeHorCursor; onPressed: win.startSystemResize(Qt.RightEdge) }
            MouseArea { x: 10; y: parent.height - 5; width: parent.width - 20; height: 5; z: 100; cursorShape: Qt.SizeVerCursor; onPressed: win.startSystemResize(Qt.BottomEdge) }

            // ── toolbar ──
            Rectangle {
                id: tbar
                width: parent.width; height: 52
                color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.96)
                z: 5
                DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: pal.sep }
                Item {
                    x: 17; anchors.verticalCenter: parent.verticalCenter; width: 58; height: 14
                    Row {
                        spacing: 8
                        Repeater {
                            model: [{ c: "#FF5F57", g: "×" }, { c: "#FEBC2E", g: "−" }, { c: "#28C840", g: "↗" }]
                            delegate: Rectangle {
                                required property var modelData
                                width: 14; height: 14; radius: 7
                                color: ((root.bar && root.bar.tlColorOnHover) ? tlMa.containsMouse : (win.active || tlMa.containsMouse)) ? modelData.c : pal.lightOff
                                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.14)
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.g
                                    font.pixelSize: 11; font.bold: true
                                    color: Qt.rgba(0, 0, 0, 0.55)
                                    opacity: (tlMa.containsMouse || (root.bar && root.bar.tlAlwaysSymbols)) ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: tlMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: mouse => { if (mouse.x < 22) root.hideWin(win); else if (mouse.x < 44) root.hub && root.hub.minimizeWindow ? root.hub.minimizeWindow(win.title) : win.showMinimized(); else win.visibility === Window.FullScreen ? win.showNormal() : win.showFullScreen(); }
                    }
                }
                MorphText {
                    anchors.centerIn: parent
                    text: root.path === "" ? "Preview" : root.path.split("/").pop()
                    color: pal.text; font.family: root.fam; font.pixelSize: 14; font.weight: Font.DemiBold
                    duration: 300
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: ["sidebar", "zoomout", "zoomin", "fit", "rotate", "trash"]
                        delegate: Rectangle {
                            required property string modelData
                            width: 30; height: 26; radius: 7
                            color: tbMa.containsMouse ? pal.pill : "transparent"
                            PvGlyph { anchors.centerIn: parent; width: 15; height: 15; kind: parent.modelData; color: parent.modelData === "trash" && tbMa.containsMouse ? "#FF453A" : pal.text }
                            MouseArea {
                                id: tbMa
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var m = parent.modelData;
                                    if (m === "sidebar") root.sidebar = !root.sidebar;
                                    else if (m === "zoomin") { root.fit = false; root.zoom = Math.min(8, root.zoom * 1.25); }
                                    else if (m === "zoomout") { root.fit = false; root.zoom = Math.max(0.1, root.zoom / 1.25); }
                                    else if (m === "fit") { root.fit = true; root.zoom = 1; pan.x = 0; pan.y = 0; }
                                    else if (m === "rotate") root.rotation = (root.rotation + 90) % 360;
                                    else root.trash();
                                }
                            }
                        }
                    }
                }
            }

            // ── thumbnails ──
            Rectangle {
                id: side
                anchors.top: tbar.bottom; anchors.bottom: parent.bottom
                width: root.sidebar ? 132 : 0
                clip: true
                color: pal.side
                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: pal.sep }
                Flickable {
                    anchors.fill: parent; anchors.margins: 8
                    contentHeight: thumbCol.height
                    clip: true
                    Column {
                        id: thumbCol
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: root.siblings
                            delegate: Item {
                                id: th
                                required property var modelData
                                required property int index
                                width: parent.width; height: 86
                                Rectangle {
                                    anchors.fill: parent; radius: 8
                                    color: root.index === th.index ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.26) : (thMa.containsMouse ? pal.pill : "transparent")
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter; y: 5
                                    width: parent.width - 16; height: 58
                                    source: "file://" + th.modelData.path
                                    sourceSize.width: 200
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true; cache: true; smooth: true
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 66; width: parent.width - 12
                                    horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle
                                    text: th.modelData.name
                                    color: pal.text2; font.family: root.fam; font.pixelSize: 10
                                }
                                MouseArea { id: thMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.show(th.index) }
                            }
                        }
                    }
                }
            }

            // ── the picture ──
            Rectangle {
                id: canvas
                anchors.top: tbar.bottom; anchors.left: side.right; anchors.right: parent.right; anchors.bottom: parent.bottom
                color: pal.canvas
                clip: true

                Item {
                    id: pan
                    anchors.fill: parent
                    // the one you are leaving: slides out the other way and fades
                    Image {
                        id: outgoing
                        anchors.centerIn: parent
                        visible: root.swapT < 1 && root.prevPath !== ""
                        source: root.prevPath === "" ? "" : "file://" + root.prevPath
                        asynchronous: true; cache: true; smooth: true; mipmap: true
                        fillMode: Image.PreserveAspectFit
                        width: Math.min(parent.width - 48, implicitWidth)
                        height: Math.min(parent.height - 48, implicitHeight)
                        opacity: 1 - Math.min(1, root.swapT * 1.8)
                        transform: Translate { x: -root.dir * 40 * root.swapT }
                        scale: 1 - 0.04 * root.swapT
                    }
                    Image {
                        id: pic
                        anchors.centerIn: parent
                        source: root.path === "" ? "" : "file://" + root.path
                        asynchronous: true; cache: true; smooth: true; mipmap: true
                        fillMode: Image.PreserveAspectFit
                        width: root.fit ? Math.min(parent.width - 48, implicitWidth) : implicitWidth * root.zoom
                        height: root.fit ? Math.min(parent.height - 48, implicitHeight) : implicitHeight * root.zoom
                        rotation: root.rotation
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                        // arriving: in from the side you came from, fading up as it lands
                        opacity: status === Image.Ready ? Math.min(1, root.swapT * 1.4) : 0
                        scale: (status === Image.Ready ? 1 : 0.97) * (0.985 + 0.015 * root.swapT)
                        transform: Translate { x: root.dir * 44 * (1 - root.swapT) }
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.fit ? Qt.ArrowCursor : (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                        drag.target: root.fit ? null : pic
                        onWheel: wheel => {
                            if (wheel.modifiers & Qt.ControlModifier) {
                                root.fit = false;
                                root.zoom = Math.max(0.1, Math.min(8, root.zoom * (wheel.angleDelta.y > 0 ? 1.12 : 1 / 1.12)));
                            } else if (wheel.angleDelta.y < 0) root.show(root.index + 1);
                            else root.show(root.index - 1);
                        }
                        onDoubleClicked: { if (root.fit) { root.fit = false; root.zoom = 2; } else { root.fit = true; root.zoom = 1; } }
                    }
                }

                // page arrows: a soft glass disc with a thin chevron, the way Preview does it
                Repeater {
                    model: ["prev", "next"]
                    delegate: Item {
                        id: arrow
                        required property string modelData
                        readonly property bool can: modelData === "prev" ? root.index > 0 : root.index < root.siblings.length - 1
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: modelData === "prev" ? parent.left : undefined
                        anchors.right: modelData === "next" ? parent.right : undefined
                        anchors.margins: 16
                        width: 40; height: 40
                        opacity: can && (arrMa.containsMouse || canvasHover.hovered) ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: pal.dark ? Qt.rgba(0.18, 0.18, 0.2, arrMa.containsMouse ? 0.92 : 0.68)
                                            : Qt.rgba(1, 1, 1, arrMa.containsMouse ? 0.96 : 0.78)
                            border.width: 1
                            border.color: pal.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            scale: arrMa.pressed ? 0.9 : (arrMa.containsMouse ? 1.06 : 1)
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                            layer.enabled: true
                            layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowOpacity: 0.25; shadowVerticalOffset: 2 }
                        }
                        PvGlyph {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: arrow.modelData === "prev" ? -1 : 1
                            width: 14; height: 14
                            kind: arrow.modelData; color: pal.text
                        }
                        MouseArea {
                            id: arrMa
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.show(arrow.modelData === "prev" ? root.index - 1 : root.index + 1)
                        }
                    }
                }
                HoverHandler { id: canvasHover }

                // zoom readout
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                    width: 92; height: 26; radius: 13
                    color: Qt.rgba(0, 0, 0, 0.42)
                    opacity: root.fit ? 0 : 1
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    Text {
                        anchors.centerIn: parent
                        text: Math.round(root.zoom * 100) + "%"
                        color: "white"; font.family: root.fam; font.pixelSize: 11
                    }
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) root.show(root.index + 1);
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) root.show(root.index - 1);
                else if (event.key === Qt.Key_Escape) root.hideWin(win);
                else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) { root.fit = false; root.zoom = Math.min(8, root.zoom * 1.25); }
                else if (event.key === Qt.Key_Minus) { root.fit = false; root.zoom = Math.max(0.1, root.zoom / 1.25); }
                else if (event.key === Qt.Key_0) { root.fit = true; root.zoom = 1; }
                else return;
                event.accepted = true;
            }
        }
    }

    component PvGlyph: Canvas {
        id: pg
        property string kind: ""
        property color color: "white"
        antialiasing: true
        onKindChanged: requestPaint()
        onColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"); c.reset();
            var s = width / 16; c.scale(s, s);
            c.strokeStyle = color; c.fillStyle = color; c.lineWidth = 1.5; c.lineCap = "round"; c.lineJoin = "round";
            var k = kind;
            if (k === "sidebar") {
                c.beginPath(); c.roundedRect(1.6, 3, 12.8, 10, 1.6, 1.6); c.stroke();
                c.beginPath(); c.moveTo(6.2, 3); c.lineTo(6.2, 13); c.stroke();
            } else if (k === "zoomin" || k === "zoomout") {
                c.beginPath(); c.arc(7, 7, 4.4, 0, Math.PI * 2); c.stroke();
                c.beginPath(); c.moveTo(10.4, 10.4); c.lineTo(14, 14); c.stroke();
                c.beginPath(); c.moveTo(4.6, 7); c.lineTo(9.4, 7); c.stroke();
                if (k === "zoomin") { c.beginPath(); c.moveTo(7, 4.6); c.lineTo(7, 9.4); c.stroke(); }
            } else if (k === "fit") {
                c.beginPath(); c.roundedRect(2, 3.4, 12, 9.2, 1.4, 1.4); c.stroke();
                c.beginPath(); c.moveTo(5, 6.4); c.lineTo(5, 9.6); c.lineTo(8.2, 9.6); c.stroke();
            } else if (k === "rotate") {
                c.beginPath(); c.arc(8, 8.4, 4.8, Math.PI * 0.15, Math.PI * 1.75); c.stroke();
                c.beginPath(); c.moveTo(12.4, 2.6); c.lineTo(12.6, 6.4); c.lineTo(9, 6); c.stroke();
            } else if (k === "trash") {
                c.beginPath(); c.moveTo(3.4, 4.6); c.lineTo(12.6, 4.6); c.stroke();
                c.beginPath(); c.moveTo(4.6, 4.6); c.lineTo(5.4, 13.4); c.lineTo(10.6, 13.4); c.lineTo(11.4, 4.6); c.stroke();
                c.beginPath(); c.moveTo(6.4, 4.4); c.lineTo(6.8, 2.6); c.lineTo(9.2, 2.6); c.lineTo(9.6, 4.4); c.stroke();
            } else if (k === "prev" || k === "next") {
                var d = k === "prev" ? 1 : -1;
                c.lineWidth = 1.6;
                c.beginPath(); c.moveTo(8 + d * 2.2, 2.8); c.lineTo(8 - d * 2.6, 8); c.lineTo(8 + d * 2.2, 13.2); c.stroke();
            }
        }
    }
}
