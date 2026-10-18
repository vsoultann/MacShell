// Photos — the macOS Photos app: your pictures, grouped by day, with a zoom slider and a full-screen viewer.
//
//   qs -c MacShell ipc call photos open            (also: photos folder <path>)
//
// It reads the pictures already on your disk (~/Pictures by default, folders become albums) and never copies,
// moves or writes anything.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property var hub: null
    readonly property var dock: hub ? hub.dock : null
    readonly property var bar: hub ? hub.bar : null
    readonly property bool darkMode: dock ? dock.darkMode : true
    readonly property string fam: dock ? dock.fontFamily : "Inter Variable"
    property color accent: dock ? dock.accent : "#0A84FF"
    Behavior on accent { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
    readonly property string home: Quickshell.env("HOME")

    property string libraryDir: home + "/Pictures"
    property var photos: []                 // { path, name, dir, mtime }
    property var albums: []                 // { name, dir, count }
    property string album: ""               // "" = the whole library
    property bool scanning: false
    property int zoom: 3                    // 2 = big, 6 = small
    property int viewing: -1                // index in `shown` being viewed full screen
    property var favs: []

    readonly property var shown: {
        var a = [];
        for (var i = 0; i < photos.length; i++) {
            if (album === "fav") { if (favs.indexOf(photos[i].path) >= 0) a.push(photos[i]); }
            else if (album === "" || photos[i].dir === album) a.push(photos[i]);
        }
        return a;
    }
    // the grid is grouped by day, newest first, like Photos' "Days"
    readonly property var groups: {
        var g = [], last = "";
        for (var i = 0; i < shown.length; i++) {
            var d = Qt.formatDate(new Date(shown[i].mtime * 1000), "dddd, d MMMM yyyy");
            if (d !== last) { g.push({ title: d, items: [] }); last = d; }
            g[g.length - 1].items.push(shown[i]);
        }
        return g;
    }

    function scan() {
        if (scanning) return;
        scanning = true;
        scanProc.running = false;
        scanProc.command = ["sh", "-c",
            // hidden files and folders are pruned in find itself: the old grep tried to match a tab with \\t,
            // which plain grep reads as the letter t, so AppleDouble stubs (._NAME.jpg) were still listed
            "find \"$1\" -name '.*' -prune -o -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' "
            + "-o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.avif' -o -iname '*.heic' \\) "
            + "-printf '%T@\\t%h\\t%f\\n' 2>/dev/null | grep -v '/__MACOSX/' | sort -rn | head -4000", "sh", root.libraryDir];
        scanProc.running = true;
    }
    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], dirs = {}, ls = text.split("\n");
                for (var i = 0; i < ls.length; i++) {
                    var c = ls[i].split("\t");
                    if (c.length < 3) continue;
                    var dir = c[1], name = c[2];
                    out.push({ path: dir + "/" + name, name: name, dir: dir, mtime: parseFloat(c[0]) });
                    dirs[dir] = (dirs[dir] || 0) + 1;
                }
                root.photos = out;
                var al = [];
                for (var d in dirs) if (d !== root.libraryDir) al.push({ name: d.split("/").pop(), dir: d, count: dirs[d] });
                al.sort(function (x, y) { return y.count - x.count; });
                root.albums = al;
                root.scanning = false;
            }
        }
    }
    FileView {
        id: favFile
        path: root.home + "/.config/macshell/photo-favourites.json"
        printErrors: false
        onLoaded: { try { root.favs = JSON.parse(text()); } catch (e) { root.favs = []; } }
    }
    function toggleFav(p) {
        var f = favs.slice(), i = f.indexOf(p);
        if (i >= 0) f.splice(i, 1); else f.push(p);
        favs = f;
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.config/macshell\" && printf '%s' \"$1\" > \"$HOME/.config/macshell/photo-favourites.json\"", "sh", JSON.stringify(f)]);
    }

    function open(dir) {
        if (dir !== undefined && dir !== "") { libraryDir = dir; album = ""; photos = []; }
        win.visible = true; win.raise(); win.requestActivate();
        if (photos.length === 0) scan();
    }

    Window {
        id: win
        title: "Photos"
        width: 1100; height: 740
        minimumWidth: 760; minimumHeight: 520
        visible: false
        color: "transparent"
        flags: Qt.Window | Qt.FramelessWindowHint
        // closing the window drops the thumbnails: a library of a few hundred pictures is tens of megabytes
        // of decoded image that would otherwise sit in the cache until the shell restarts
        onVisibleChanged: if (!visible) { root.viewing = -1; root.photos = []; root.albums = []; Qt.callLater(gc); }

        QtObject {
            id: pal
            readonly property bool dark: root.darkMode
            property color bg: dark ? "#1C1C1E" : "#FFFFFF"
            Behavior on bg { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color side: dark ? "#2A2A2C" : "#F2F2F4"
            Behavior on side { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
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
            property color selRow: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.09)
            Behavior on selRow { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
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

            MouseArea { x: parent.width - 8; y: parent.height - 8; width: 8; height: 8; z: 100; cursorShape: Qt.SizeFDiagCursor; onPressed: win.startSystemResize(Qt.BottomEdge | Qt.RightEdge) }
            MouseArea { x: parent.width - 5; y: 10; width: 5; height: parent.height - 20; z: 100; cursorShape: Qt.SizeHorCursor; onPressed: win.startSystemResize(Qt.RightEdge) }
            MouseArea { x: 10; y: parent.height - 5; width: parent.width - 20; height: 5; z: 100; cursorShape: Qt.SizeVerCursor; onPressed: win.startSystemResize(Qt.BottomEdge) }

            // ── sidebar ──
            Rectangle {
                id: side
                width: 212; height: parent.height
                color: pal.side
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: pal.sep }
                DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }
                Item {
                    x: 17; y: 17; width: 58; height: 14
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
                        onClicked: mouse => {
                            if (mouse.x < 22) win.visible = false;
                            else if (mouse.x < 44) root.hub && root.hub.minimizeWindow ? root.hub.minimizeWindow(win.title) : win.showMinimized();
                            else win.visibility === Window.FullScreen ? win.showNormal() : win.showFullScreen();
                        }
                    }
                }
                Flickable {
                    x: 8; y: 52; width: parent.width - 16; height: parent.height - 60
                    contentHeight: navCol.height
                    clip: true
                    Column {
                        id: navCol
                        width: parent.width
                        spacing: 2
                        Repeater {
                            model: [{ id: "", n: "Library", g: "photo" }, { id: "fav", n: "Favourites", g: "heart" }]
                            delegate: Rectangle {
                                id: navRow
                                required property var modelData
                                readonly property bool sel: root.album === modelData.id
                                width: parent.width; height: 30; radius: 6
                                color: sel ? pal.selRow : (nMa.containsMouse ? pal.pill : "transparent")
                                PhGlyph { x: 9; anchors.verticalCenter: parent.verticalCenter; width: 15; height: 15; kind: navRow.modelData.g; color: navRow.sel ? root.accent : pal.text2 }
                                Text { x: 32; anchors.verticalCenter: parent.verticalCenter; text: navRow.modelData.n; color: pal.text; font.family: root.fam; font.pixelSize: 13; font.weight: navRow.sel ? Font.DemiBold : Font.Normal }
                                MouseArea { id: nMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.album = navRow.modelData.id; root.viewing = -1; } }
                            }
                        }
                        Item { width: 1; height: 12 }
                        Text { x: 10; text: "Albums"; color: pal.text3; font.family: root.fam; font.pixelSize: 11; font.weight: Font.DemiBold }
                        Item { width: 1; height: 4 }
                        Repeater {
                            model: root.albums
                            delegate: Rectangle {
                                id: alRow
                                required property var modelData
                                readonly property bool sel: root.album === modelData.dir
                                width: parent.width; height: 28; radius: 6
                                color: sel ? pal.selRow : (aMa.containsMouse ? pal.pill : "transparent")
                                PhGlyph { x: 9; anchors.verticalCenter: parent.verticalCenter; width: 15; height: 15; kind: "folder"; color: alRow.sel ? root.accent : pal.text2 }
                                Text {
                                    x: 32; anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 70; elide: Text.ElideRight
                                    text: alRow.modelData.name; color: pal.text; font.family: root.fam; font.pixelSize: 12.5 > 0 ? 12 : 12
                                }
                                Text { anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: alRow.modelData.count; color: pal.text3; font.family: root.fam; font.pixelSize: 11 }
                                MouseArea { id: aMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.album = alRow.modelData.dir; root.viewing = -1; } }
                            }
                        }
                    }
                }
            }

            // ── content ──
            Item {
                x: side.width; width: parent.width - side.width; height: parent.height

                Rectangle {
                    id: tbar
                    width: parent.width; height: 52
                    color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.92)
                    z: 5
                    DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: pal.sep; opacity: grid.contentY > 4 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 160 } } }
                    MorphText {
                        x: 20; anchors.verticalCenter: parent.verticalCenter
                        text: root.album === "" ? "Library" : (root.album === "fav" ? "Favourites" : root.album.split("/").pop())
                        color: pal.text; font.family: root.fam; font.pixelSize: 15; font.weight: Font.DemiBold
                        duration: 300
                    }
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 20; anchors.top: parent.verticalCenter; anchors.topMargin: 6
                        text: root.scanning ? "Loading…" : (root.shown.length + (root.shown.length === 1 ? " photo" : " photos"))
                        color: pal.text3; font.family: root.fam; font.pixelSize: 11
                    }
                    // zoom
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        PhGlyph { anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; kind: "small"; color: pal.text2 }
                        Item {
                            width: 90; height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle { y: 8; width: parent.width; height: 4; radius: 2; color: pal.pill }
                            Rectangle {
                                x: (6 - root.zoom) / 4 * (parent.width - 14); y: 4
                                width: 14; height: 14; radius: 7; color: "white"
                                layer.enabled: true
                                layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.4; shadowOpacity: 0.35 }
                            }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                onPositionChanged: mouse => { if (pressed) root.zoom = Math.max(2, Math.min(6, 6 - Math.round((mouse.x - 6) / (parent.width - 14) * 4))); }
                                onPressed: mouse => root.zoom = Math.max(2, Math.min(6, 6 - Math.round((mouse.x - 6) / (parent.width - 14) * 4)))
                            }
                        }
                        PhGlyph { anchors.verticalCenter: parent.verticalCenter; width: 17; height: 17; kind: "big"; color: pal.text2 }
                    }
                }

                // ── the grid, grouped by day ──
                Flickable {
                    id: grid
                    anchors.top: tbar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    contentWidth: width
                    contentHeight: gridCol.height + 30
                    clip: true
                    Column {
                        id: gridCol
                        x: 16; width: grid.width - 32
                        spacing: 6
                        Repeater {
                            model: root.groups
                            delegate: Column {
                                id: dayCol
                                required property var modelData
                                width: gridCol.width
                                spacing: 4
                                Item {
                                    width: parent.width; height: 34
                                    Text { x: 4; anchors.verticalCenter: parent.verticalCenter; text: dayCol.modelData.title; color: pal.text; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold }
                                }
                                Flow {
                                    width: parent.width
                                    spacing: 3
                                    Repeater {
                                        model: dayCol.modelData.items
                                        delegate: Item {
                                            id: cellItem
                                            required property var modelData
                                            readonly property real cw: Math.floor((gridCol.width - (root.zoom - 1) * 3) / root.zoom)
                                            width: cw; height: cw
                                            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                                            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                                            Rectangle { anchors.fill: parent; color: pal.pill; radius: 3 }
                                            Image {
                                                id: thumb
                                                anchors.fill: parent
                                                source: "file://" + cellItem.modelData.path
                                                // the grid cell is at most ~260 px wide: decoding bigger than that is memory for nothing
                                sourceSize.width: 260
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true; cache: true; smooth: true; mipmap: true
                                                opacity: status === Image.Ready ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                            }
                                            Rectangle {
                                                anchors.fill: parent; radius: 3; color: "white"
                                                opacity: cMa.containsMouse ? 0.10 : 0
                                                Behavior on opacity { NumberAnimation { duration: 140 } }
                                            }
                                            PhGlyph {
                                                visible: root.favs.indexOf(cellItem.modelData.path) >= 0
                                                anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 6
                                                width: 14; height: 14; kind: "heart"; color: "white"; filled: true
                                            }
                                            scale: cMa.pressed ? 0.97 : 1
                                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                                            MouseArea {
                                                id: cMa
                                                anchors.fill: parent; hoverEnabled: true
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: mouse => {
                                                    if (mouse.button === Qt.RightButton) { root.toggleFav(cellItem.modelData.path); return; }
                                                    for (var i = 0; i < root.shown.length; i++) if (root.shown[i].path === cellItem.modelData.path) { root.viewing = i; break; }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        visible: !root.scanning && root.shown.length === 0
                        anchors.centerIn: parent
                        text: root.album === "fav" ? "No favourites yet — right-click a photo to add one." : "No photos in " + root.libraryDir
                        color: pal.text3; font.family: root.fam; font.pixelSize: 13
                    }
                }

                // the grid fades out under the toolbar and at the bottom edge
                Rectangle {
                    anchors.top: tbar.bottom; anchors.left: parent.left; anchors.right: parent.right
                    height: 20; z: 4
                    opacity: grid.contentY > 2 ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: pal.bg }
                        GradientStop { position: 1; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0) }
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                    height: 20; z: 4
                    opacity: (grid.contentHeight - grid.contentY - grid.height > 2) ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0) }
                        GradientStop { position: 1; color: pal.bg }
                    }
                }

            }

            // ── full-screen viewer ──
            Item {
                id: viewer
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: root.viewing >= 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                focus: root.viewing >= 0
                readonly property var cur: (root.viewing >= 0 && root.viewing < root.shown.length) ? root.shown[root.viewing] : null
                Rectangle { anchors.fill: parent; color: pal.dark ? Qt.rgba(0, 0, 0, 0.97) : Qt.rgba(0.08, 0.08, 0.09, 0.97) }
                MouseArea { anchors.fill: parent; onClicked: root.viewing = -1 }
                Image {
                    anchors.fill: parent
                    anchors.margins: 34
                    anchors.topMargin: 56
                    source: viewer.cur ? "file://" + viewer.cur.path : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true; smooth: true; mipmap: true
                    scale: root.viewing >= 0 ? 1 : 0.97
                    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 18
                    text: viewer.cur ? viewer.cur.name : ""
                    color: "white"; font.family: root.fam; font.pixelSize: 13
                }
                Repeater {
                    model: ["prev", "next", "close", "fav"]
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool isNav: modelData === "prev" || modelData === "next"
                        width: 36; height: 36; radius: 18
                        color: bMa.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.10)
                        anchors.verticalCenter: isNav ? parent.verticalCenter : undefined
                        anchors.left: modelData === "prev" ? parent.left : undefined
                        anchors.right: modelData === "next" ? parent.right : undefined
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        x: modelData === "close" ? 16 : (modelData === "fav" ? parent.width - 52 : 0)
                        y: isNav ? 0 : 14
                        PhGlyph {
                            anchors.centerIn: parent; width: 16; height: 16
                            kind: parent.modelData === "fav" ? "heart" : parent.modelData
                            filled: parent.modelData === "fav" && viewer.cur && root.favs.indexOf(viewer.cur.path) >= 0
                            color: "white"
                        }
                        MouseArea {
                            id: bMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var m = parent.modelData;
                                if (m === "close") root.viewing = -1;
                                else if (m === "prev") root.viewing = Math.max(0, root.viewing - 1);
                                else if (m === "next") root.viewing = Math.min(root.shown.length - 1, root.viewing + 1);
                                else if (viewer.cur) root.toggleFav(viewer.cur.path);
                            }
                        }
                    }
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) root.viewing = -1;
                    else if (event.key === Qt.Key_Left) root.viewing = Math.max(0, root.viewing - 1);
                    else if (event.key === Qt.Key_Right) root.viewing = Math.min(root.shown.length - 1, root.viewing + 1);
                    else return;
                    event.accepted = true;
                }
            }
        }
    }

    // small vector glyphs, so no icon theme is needed
    component PhGlyph: Canvas {
        id: g
        property string kind: ""
        property color color: "white"
        property bool filled: false
        antialiasing: true
        onKindChanged: requestPaint()
        onColorChanged: requestPaint()
        onFilledChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"); c.reset();
            var s = width / 16; c.scale(s, s);
            c.strokeStyle = color; c.fillStyle = color; c.lineWidth = 1.6; c.lineCap = "round"; c.lineJoin = "round";
            var k = kind;
            if (k === "photo") {
                c.beginPath(); c.roundedRect(2, 3.5, 12, 9, 1.6, 1.6); c.stroke();
                c.beginPath(); c.arc(5.4, 6.6, 1.1, 0, Math.PI * 2); c.fill();
                c.beginPath(); c.moveTo(3, 11.5); c.lineTo(6.6, 8); c.lineTo(9, 10.2); c.lineTo(11, 8.6); c.lineTo(13.2, 11.5); c.stroke();
            } else if (k === "heart") {
                c.beginPath();
                c.moveTo(8, 13.2);
                c.bezierCurveTo(1.6, 9.2, 2.4, 4.2, 5.6, 3.6);
                c.bezierCurveTo(7, 3.3, 7.8, 4.4, 8, 5.1);
                c.bezierCurveTo(8.2, 4.4, 9, 3.3, 10.4, 3.6);
                c.bezierCurveTo(13.6, 4.2, 14.4, 9.2, 8, 13.2);
                c.closePath();
                g.filled ? c.fill() : c.stroke();
            } else if (k === "folder") {
                c.beginPath(); c.moveTo(2, 12.4); c.lineTo(2, 4.4); c.lineTo(6.4, 4.4); c.lineTo(7.6, 5.8); c.lineTo(14, 5.8); c.lineTo(14, 12.4); c.closePath(); c.stroke();
            } else if (k === "small" || k === "big") {
                var n = k === "small" ? 3 : 2, gap = 1.2, sz = (12 - gap * (n - 1)) / n;
                for (var i = 0; i < n; i++) for (var j = 0; j < n; j++) {
                    c.beginPath(); c.roundedRect(2 + i * (sz + gap), 2 + j * (sz + gap), sz, sz, 0.8, 0.8); c.fill();
                }
            } else if (k === "prev" || k === "next") {
                var d = k === "prev" ? 1 : -1;
                c.lineWidth = 1.9;
                c.beginPath(); c.moveTo(8 + d * 2, 3.5); c.lineTo(8 - d * 2.5, 8); c.lineTo(8 + d * 2, 12.5); c.stroke();
            } else if (k === "close") {
                c.lineWidth = 1.8;
                c.beginPath(); c.moveTo(4.2, 4.2); c.lineTo(11.8, 11.8); c.moveTo(11.8, 4.2); c.lineTo(4.2, 11.8); c.stroke();
            }
        }
    }
}
