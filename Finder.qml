// Finder — the macOS Finder: sidebar, list and icon views, colour tags, coloured folders and Quick Look.
//
//   qs -c MacShell ipc call finder open             (also: finder folder <path>)
//
// It browses the files already on your disk. The only things it writes are its own small settings files:
// ~/.config/macshell/finder-tags.json and finder-folders.json.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property var hub: null
    readonly property var dock: hub ? hub.dock : null
    readonly property var bar: hub ? hub.bar : null
    readonly property bool darkMode: dock ? dock.darkMode : true
    readonly property string fam: dock ? dock.fontFamily : "Inter Variable"
    readonly property color accent: dock ? dock.accent : "#0A84FF"
    readonly property string home: Quickshell.env("HOME")

    // ── where we are ──
    property string dir: home
    property var back: []
    property var fwd: []
    property string view: "list"            // list | icons
    property string tagFilter: ""           // a tag colour to filter by
    property string query: ""
    property var entries: []                // { name, path, isDir, size, mtime, kind }
    property string selected: ""
    property bool loading: false

    readonly property var tagColours: [
        { id: "red", name: "Red", c: "#FF453A" }, { id: "orange", name: "Orange", c: "#FF9F0A" },
        { id: "yellow", name: "Yellow", c: "#FFD60A" }, { id: "green", name: "Green", c: "#30D158" },
        { id: "blue", name: "Blue", c: "#0A84FF" }, { id: "purple", name: "Purple", c: "#BF5AF2" },
        { id: "grey", name: "Grey", c: "#8E8E93" }
    ]
    function tagColour(id) { for (var i = 0; i < tagColours.length; i++) if (tagColours[i].id === id) return tagColours[i].c; return "#8E8E93"; }

    property var tags: ({})                 // path → tag id
    property var folderColours: ({})        // folder path → tag id
    FileView {
        id: tagFile
        path: root.home + "/.config/macshell/finder-tags.json"
        printErrors: false
        onLoaded: { try { root.tags = JSON.parse(text()); } catch (e) { root.tags = ({}); } }
    }
    FileView {
        id: folderFile
        path: root.home + "/.config/macshell/finder-folders.json"
        printErrors: false
        onLoaded: { try { root.folderColours = JSON.parse(text()); } catch (e) { root.folderColours = ({}); } }
    }
    function writeJson(file, obj) {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.config/macshell\" && printf '%s' \"$2\" > \"$HOME/.config/macshell/$1\"", "sh", file, JSON.stringify(obj)]);
    }
    function setTag(path, id) {
        var m = {}; for (var k in tags) m[k] = tags[k];
        if (id === "") delete m[path]; else m[path] = id;
        tags = m; writeJson("finder-tags.json", m);
    }
    function setFolderColour(path, id) {
        var m = {}; for (var k in folderColours) m[k] = folderColours[k];
        if (id === "") delete m[path]; else m[path] = id;
        folderColours = m; writeJson("finder-folders.json", m);
    }

    // ── reading a folder ──
    function go(path, remember) {
        if (path === dir) return;
        if (remember !== false) { back.push(dir); fwd = []; }
        dir = path; selected = ""; tagFilter = ""; read();
    }
    function goBack() { if (back.length === 0) return; fwd.push(dir); dir = back.pop(); selected = ""; read(); }
    function goFwd() { if (fwd.length === 0) return; back.push(dir); dir = fwd.pop(); selected = ""; read(); }
    function up() { var p = dir.replace(/\/+$/, ""); var i = p.lastIndexOf("/"); if (i > 0) go(p.substring(0, i)); else go("/"); }

    function read() {
        loading = true;
        lsProc.running = false;
        lsProc.command = ["sh", "-c",
            "cd \"$1\" 2>/dev/null || exit 0; "
            + "find . -mindepth 1 -maxdepth 1 ! -name '.*' -printf '%y\\t%s\\t%T@\\t%f\\n' 2>/dev/null | LC_ALL=C sort -t\"$(printf '\\t')\" -k1,1 -k4,4f | head -3000", "sh", dir];
        lsProc.running = true;
    }
    Process {
        id: lsProc
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], ls = text.split("\n");
                for (var i = 0; i < ls.length; i++) {
                    var c = ls[i].split("\t");
                    if (c.length < 4) continue;
                    var name = c[3], isDir = c[0] === "d";
                    out.push({ name: name, path: root.dir.replace(/\/+$/, "") + "/" + name, isDir: isDir,
                               size: parseFloat(c[1]), mtime: parseFloat(c[2]), kind: root.kindOf(name, isDir) });
                }
                root.entries = out;
                root.loading = false;
            }
        }
    }
    function kindOf(name, isDir) {
        if (isDir) return "Folder";
        var e = name.toLowerCase().split(".").pop();
        if (["png", "jpg", "jpeg", "webp", "gif", "bmp", "tif", "tiff", "avif", "heic", "svg"].indexOf(e) >= 0) return "Image";
        if (["mp4", "mkv", "webm", "mov", "avi", "m4v"].indexOf(e) >= 0) return "Video";
        if (["mp3", "flac", "wav", "ogg", "m4a", "opus"].indexOf(e) >= 0) return "Audio";
        if (["txt", "md", "json", "qml", "sh", "py", "js", "ts", "css", "html", "lua", "conf", "ini", "log", "yml", "yaml", "toml"].indexOf(e) >= 0) return "Text";
        if (e === "pdf") return "PDF";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar"].indexOf(e) >= 0) return "Archive";
        return e.toUpperCase() + " file";
    }
    readonly property var shown: {
        var a = [], q = query.trim().toLowerCase();
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i];
            if (q !== "" && e.name.toLowerCase().indexOf(q) < 0) continue;
            if (tagFilter !== "" && tags[e.path] !== tagFilter) continue;
            a.push(e);
        }
        return a;
    }
    function fmtSize(b, isDir) {
        if (isDir) return "--";
        var u = ["B", "KB", "MB", "GB", "TB"], i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (i === 0 ? b : b.toFixed(b < 10 ? 1 : 0)) + " " + u[i];
    }
    function openEntry(e) {
        if (e.isDir) go(e.path);
        else Quickshell.execDetached(["xdg-open", e.path]);
    }
    function newFolder() {
        Quickshell.execDetached(["sh", "-c", "cd \"$1\" && n='untitled folder'; i=2; while [ -e \"$n\" ]; do n=\"untitled folder $i\"; i=$((i+1)); done; mkdir \"$n\"", "sh", dir]);
        reloadLater.restart();
    }
    function trash(path) {
        Quickshell.execDetached(["sh", "-c", "gio trash \"$1\" 2>/dev/null || { mkdir -p \"$HOME/.local/share/Trash/files\" && mv \"$1\" \"$HOME/.local/share/Trash/files/\"; }", "sh", path]);
        reloadLater.restart();
    }
    Timer { id: reloadLater; interval: 350; onTriggered: root.read() }

    function open(where) {
        if (where !== undefined && where !== "") { back.push(dir); dir = where; }
        win.visible = true; win.raise(); win.requestActivate();
        read();
    }

    Window {
        id: win
        title: "Finder"
        width: 1020; height: 660
        minimumWidth: 720; minimumHeight: 460
        visible: false
        color: "transparent"
        flags: Qt.Window | Qt.FramelessWindowHint

        QtObject {
            id: pal
            readonly property bool dark: root.darkMode
            readonly property color bg: dark ? "#1E1E1E" : "#FFFFFF"
            readonly property color side: dark ? "#2A2A2C" : "#F2F2F4"
            readonly property color text: dark ? "#F5F5F7" : "#1D1D1F"
            readonly property color text2: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)
            readonly property color text3: dark ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.28)
            readonly property color sep: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.09)
            readonly property color pill: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07)
            readonly property color selRow: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.09)
            readonly property color field: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
            readonly property color border: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.2)
            readonly property color lightOff: dark ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.15)
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
                width: 200; height: parent.height
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
                                border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.14)
                                Text { anchors.centerIn: parent; visible: tlMa.containsMouse || (root.bar && root.bar.tlAlwaysSymbols); text: parent.modelData.g; font.pixelSize: 11; font.bold: true; color: Qt.rgba(0, 0, 0, 0.55) }
                            }
                        }
                    }
                    MouseArea {
                        id: tlMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: mouse => {
                            if (mouse.x < 22) win.visible = false;
                            else if (mouse.x < 44) win.showMinimized();
                            else win.visibility === Window.FullScreen ? win.showNormal() : win.showFullScreen();
                        }
                    }
                }
                Flickable {
                    x: 8; y: 50; width: parent.width - 16; height: parent.height - 58
                    contentHeight: navCol.height
                    clip: true
                    Column {
                        id: navCol
                        width: parent.width
                        spacing: 1
                        Text { x: 10; topPadding: 4; text: "Favourites"; color: pal.text3; font.family: root.fam; font.pixelSize: 11; font.weight: Font.DemiBold }
                        Repeater {
                            model: [
                                { n: "Home", p: root.home, g: "home" },
                                { n: "Desktop", p: root.home + "/Desktop", g: "desktop" },
                                { n: "Documents", p: root.home + "/Documents", g: "doc" },
                                { n: "Downloads", p: root.home + "/Downloads", g: "down" },
                                { n: "Pictures", p: root.home + "/Pictures", g: "image" },
                                { n: "Music", p: root.home + "/Music", g: "note" },
                                { n: "Videos", p: root.home + "/Videos", g: "video" },
                                { n: "Google Drive", p: root.home + "/GoogleDrive", g: "cloud" }
                            ]
                            delegate: Rectangle {
                                id: favRow
                                required property var modelData
                                readonly property bool sel: root.dir === modelData.p
                                width: parent.width; height: 27; radius: 6
                                visible: modelData.n !== "Google Drive" || root.driveExists
                                color: sel ? pal.selRow : (fMa.containsMouse ? pal.pill : "transparent")
                                FnGlyph { x: 9; anchors.verticalCenter: parent.verticalCenter; width: 15; height: 15; kind: favRow.modelData.g; color: root.accent }
                                Text { x: 32; anchors.verticalCenter: parent.verticalCenter; text: favRow.modelData.n; color: pal.text; font.family: root.fam; font.pixelSize: 12; font.weight: favRow.sel ? Font.DemiBold : Font.Normal }
                                MouseArea { id: fMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.go(favRow.modelData.p) }
                            }
                        }
                        Item { width: 1; height: 10 }
                        Text { x: 10; text: "Tags"; color: pal.text3; font.family: root.fam; font.pixelSize: 11; font.weight: Font.DemiBold }
                        Repeater {
                            model: root.tagColours
                            delegate: Rectangle {
                                id: tagRow
                                required property var modelData
                                readonly property bool sel: root.tagFilter === modelData.id
                                width: parent.width; height: 25; radius: 6
                                color: sel ? pal.selRow : (tMa.containsMouse ? pal.pill : "transparent")
                                Rectangle { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: tagRow.modelData.c }
                                Text { x: 32; anchors.verticalCenter: parent.verticalCenter; text: tagRow.modelData.name; color: pal.text; font.family: root.fam; font.pixelSize: 12 }
                                MouseArea { id: tMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.tagFilter = tagRow.sel ? "" : tagRow.modelData.id }
                            }
                        }
                    }
                }
            }

            // ── content ──
            Item {
                id: content
                x: side.width; width: parent.width - side.width; height: parent.height

                Rectangle {
                    id: tbar
                    width: parent.width; height: 52
                    color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.95)
                    z: 5
                    DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: pal.sep }
                    Row {
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Repeater {
                            model: ["back", "fwd", "up"]
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool can: modelData === "back" ? root.back.length > 0 : (modelData === "fwd" ? root.fwd.length > 0 : root.dir !== "/")
                                width: 28; height: 26; radius: 7
                                color: nMa2.containsMouse && can ? pal.pill : "transparent"
                                opacity: can ? 1 : 0.3
                                FnGlyph { anchors.centerIn: parent; width: 14; height: 14; kind: parent.modelData; color: pal.text }
                                MouseArea {
                                    id: nMa2; anchors.fill: parent; hoverEnabled: true; enabled: parent.can; cursorShape: Qt.PointingHandCursor
                                    onClicked: { var m = parent.modelData; if (m === "back") root.goBack(); else if (m === "fwd") root.goFwd(); else root.up(); }
                                }
                            }
                        }
                    }
                    MorphText {
                        anchors.centerIn: parent
                        text: root.dir === root.home ? "Home" : root.dir.split("/").pop()
                        color: pal.text; font.family: root.fam; font.pixelSize: 14; font.weight: Font.DemiBold
                        duration: 280
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        // view switch
                        Rectangle {
                            width: 58; height: 26; radius: 7; color: pal.pill
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                x: root.view === "icons" ? 2 : 29; y: 2
                                width: 27; height: 22; radius: 6
                                color: pal.dark ? "#636366" : "#FFFFFF"
                                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                            }
                            FnGlyph { x: 9; anchors.verticalCenter: parent.verticalCenter; width: 13; height: 13; kind: "grid"; color: pal.text }
                            FnGlyph { x: 36; anchors.verticalCenter: parent.verticalCenter; width: 13; height: 13; kind: "list"; color: pal.text }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mouse => root.view = mouse.x < width / 2 ? "icons" : "list" }
                        }
                        Rectangle {
                            width: 26; height: 26; radius: 7
                            anchors.verticalCenter: parent.verticalCenter
                            color: nfMa.containsMouse ? pal.pill : "transparent"
                            FnGlyph { anchors.centerIn: parent; width: 15; height: 15; kind: "newfolder"; color: pal.text }
                            MouseArea { id: nfMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.newFolder() }
                        }
                        Rectangle {
                            width: 150; height: 26; radius: 7; color: pal.field
                            anchors.verticalCenter: parent.verticalCenter
                            FnGlyph { x: 7; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; kind: "search"; color: pal.text2 }
                            TextInput {
                                x: 25; width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter
                                color: pal.text; font.family: root.fam; font.pixelSize: 12
                                selectByMouse: true
                                onTextChanged: root.query = text
                                Keys.onEscapePressed: { text = ""; root.query = ""; }
                                Text { visible: parent.text === ""; text: "Search"; color: pal.text3; font: parent.font }
                            }
                        }
                    }
                }

                // ── list view ──
                Flickable {
                    id: listFlick
                    visible: root.view === "list"
                    anchors.top: tbar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: statusBar.top
                    contentWidth: width
                    contentHeight: listCol.height + 10
                    clip: true
                    Column {
                        id: listCol
                        width: listFlick.width
                        Item {
                            width: parent.width; height: 24
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: pal.sep }
                            Text { x: 44; anchors.verticalCenter: parent.verticalCenter; text: "Name"; color: pal.text3; font.family: root.fam; font.pixelSize: 11 }
                            Text { x: parent.width - 300; anchors.verticalCenter: parent.verticalCenter; text: "Date Modified"; color: pal.text3; font.family: root.fam; font.pixelSize: 11 }
                            Text { x: parent.width - 150; anchors.verticalCenter: parent.verticalCenter; text: "Size"; color: pal.text3; font.family: root.fam; font.pixelSize: 11 }
                            Text { x: parent.width - 90; anchors.verticalCenter: parent.verticalCenter; text: "Kind"; color: pal.text3; font.family: root.fam; font.pixelSize: 11 }
                        }
                        Repeater {
                            model: root.shown
                            delegate: Rectangle {
                                id: rowItem
                                required property var modelData
                                required property int index
                                width: listCol.width; height: 26
                                color: root.selected === modelData.path ? root.accent : (index % 2 === 1 ? Qt.rgba(1, 1, 1, pal.dark ? 0.025 : 0.02) : "transparent")
                                readonly property color ink: root.selected === modelData.path ? "white" : pal.text
                                FnGlyph {
                                    x: 16; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16
                                    kind: rowItem.modelData.isDir ? "folder" : root.iconFor(rowItem.modelData.kind)
                                    color: rowItem.modelData.isDir ? root.tagColour(root.folderColours[rowItem.modelData.path] || "blue") : rowItem.ink
                                    filled: rowItem.modelData.isDir
                                }
                                Text {
                                    x: 44; anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 360; elide: Text.ElideMiddle
                                    text: rowItem.modelData.name; color: rowItem.ink; font.family: root.fam; font.pixelSize: 12
                                }
                                Rectangle {
                                    visible: root.tags[rowItem.modelData.path] !== undefined
                                    x: 36; y: 4; width: 7; height: 7; radius: 3.5
                                    color: root.tagColour(root.tags[rowItem.modelData.path] || "grey")
                                }
                                Text { x: parent.width - 300; anchors.verticalCenter: parent.verticalCenter; text: Qt.formatDateTime(new Date(rowItem.modelData.mtime * 1000), "d MMM yyyy HH:mm"); color: root.selected === rowItem.modelData.path ? "white" : pal.text2; font.family: root.fam; font.pixelSize: 11 }
                                Text { x: parent.width - 150; anchors.verticalCenter: parent.verticalCenter; text: root.fmtSize(rowItem.modelData.size, rowItem.modelData.isDir); color: root.selected === rowItem.modelData.path ? "white" : pal.text2; font.family: root.fam; font.pixelSize: 11 }
                                Text { x: parent.width - 90; anchors.verticalCenter: parent.verticalCenter; width: 80; elide: Text.ElideRight; text: rowItem.modelData.kind; color: root.selected === rowItem.modelData.path ? "white" : pal.text2; font.family: root.fam; font.pixelSize: 11 }
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: mouse => {
                                        root.selected = rowItem.modelData.path;
                                        if (mouse.button === Qt.RightButton) ctx.show(rowItem.modelData, mapToItem(content, mouse.x, mouse.y));
                                    }
                                    onDoubleClicked: root.openEntry(rowItem.modelData)
                                }
                            }
                        }
                    }
                }

                // ── icon view ──
                Flickable {
                    id: iconFlick
                    visible: root.view === "icons"
                    anchors.top: tbar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: statusBar.top
                    contentWidth: width
                    contentHeight: iconFlow.height + 24
                    clip: true
                    Flow {
                        id: iconFlow
                        x: 16; y: 12; width: iconFlick.width - 32
                        spacing: 10
                        Repeater {
                            model: root.shown
                            delegate: Item {
                                id: cellI
                                required property var modelData
                                width: 108; height: 104
                                Rectangle {
                                    anchors.fill: parent; radius: 8
                                    color: root.selected === cellI.modelData.path ? root.accent : (iMa.containsMouse ? pal.pill : "transparent")
                                }
                                FnGlyph {
                                    anchors.horizontalCenter: parent.horizontalCenter; y: 12
                                    width: 46; height: 46
                                    visible: cellI.modelData.kind !== "Image"
                                    kind: cellI.modelData.isDir ? "folder" : root.iconFor(cellI.modelData.kind)
                                    color: cellI.modelData.isDir ? root.tagColour(root.folderColours[cellI.modelData.path] || "blue") : (root.selected === cellI.modelData.path ? "white" : pal.text2)
                                    filled: cellI.modelData.isDir
                                }
                                Image {
                                    visible: cellI.modelData.kind === "Image"
                                    anchors.horizontalCenter: parent.horizontalCenter; y: 12
                                    width: 50; height: 46
                                    source: cellI.modelData.kind === "Image" ? "file://" + cellI.modelData.path : ""
                                    sourceSize.width: 160
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; cache: true; smooth: true
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter; y: 66
                                    width: parent.width - 10; horizontalAlignment: Text.AlignHCenter
                                    text: cellI.modelData.name; elide: Text.ElideMiddle; maximumLineCount: 2; wrapMode: Text.Wrap
                                    color: root.selected === cellI.modelData.path ? "white" : pal.text; font.family: root.fam; font.pixelSize: 11
                                }
                                Rectangle {
                                    visible: root.tags[cellI.modelData.path] !== undefined
                                    x: 30; y: 10; width: 9; height: 9; radius: 4.5
                                    color: root.tagColour(root.tags[cellI.modelData.path] || "grey")
                                }
                                MouseArea {
                                    id: iMa
                                    anchors.fill: parent; hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: mouse => {
                                        root.selected = cellI.modelData.path;
                                        if (mouse.button === Qt.RightButton) ctx.show(cellI.modelData, mapToItem(content, mouse.x, mouse.y));
                                    }
                                    onDoubleClicked: root.openEntry(cellI.modelData)
                                }
                            }
                        }
                    }
                }

                // ── status bar ──
                Rectangle {
                    id: statusBar
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 24
                    color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.95)
                    Rectangle { width: parent.width; height: 1; color: pal.sep }
                    Text {
                        anchors.centerIn: parent
                        text: root.loading ? "Loading…" : (root.shown.length + (root.shown.length === 1 ? " item" : " items") + (root.selected !== "" ? ", 1 selected" : ""))
                        color: pal.text3; font.family: root.fam; font.pixelSize: 11
                    }
                }

                // ── right-click menu ──
                Rectangle {
                    id: ctx
                    property var item: null
                    visible: item !== null
                    z: 50
                    width: 208; height: ctxCol.height + 10
                    radius: 10
                    color: pal.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.98) : Qt.rgba(0.98, 0.98, 0.99, 0.99)
                    border.width: 1; border.color: pal.sep
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.9; shadowOpacity: 0.4; shadowVerticalOffset: 6 }
                    function show(it, pt) {
                        item = it;
                        x = Math.min(pt.x, content.width - width - 8);
                        y = Math.min(pt.y, content.height - height - 8);
                    }
                    Column {
                        id: ctxCol
                        y: 5; width: parent.width
                        Repeater {
                            model: ["Open", "Quick Look", "Pin to Dock", "sep", "Copy Path", "Move to Trash"]
                            delegate: Item {
                                required property string modelData
                                width: parent.width; height: modelData === "sep" ? 7 : 26
                                visible: modelData !== "Pin to Dock" || (ctx.item && ctx.item.isDir)
                                Rectangle { visible: parent.modelData === "sep"; x: 10; width: parent.width - 20; height: 1; y: 3; color: pal.sep }
                                Rectangle { visible: parent.modelData !== "sep" && cxMa.containsMouse; x: 5; width: parent.width - 10; height: 24; radius: 5; color: root.accent }
                                Text {
                                    visible: parent.modelData !== "sep"
                                    x: 14; anchors.verticalCenter: parent.verticalCenter
                                    text: parent.modelData
                                    color: cxMa.containsMouse ? "white" : pal.text
                                    font.family: root.fam; font.pixelSize: 12
                                }
                                MouseArea {
                                    id: cxMa
                                    anchors.fill: parent; hoverEnabled: true
                                    enabled: parent.modelData !== "sep"
                                    onClicked: {
                                        var m = parent.modelData, it = ctx.item;
                                        ctx.item = null;
                                        if (!it) return;
                                        if (m === "Open") root.openEntry(it);
                                        else if (m === "Quick Look") ql.showFor(it);
                                        else if (m === "Pin to Dock") root.pinFolder(it.path);
                                        else if (m === "Copy Path") Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", it.path]);
                                        else if (m === "Move to Trash") root.trash(it.path);
                                    }
                                }
                            }
                        }
                        // tags
                        Item {
                            width: parent.width; height: 34
                            Row {
                                x: 12; anchors.verticalCenter: parent.verticalCenter
                                spacing: 7
                                Repeater {
                                    model: root.tagColours
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 15; height: 15; radius: 7.5
                                        color: modelData.c
                                        border.width: ctx.item && (ctx.item.isDir ? root.folderColours[ctx.item.path] : root.tags[ctx.item.path]) === modelData.id ? 2 : 0
                                        border.color: pal.text
                                        MouseArea {
                                            anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var it = ctx.item; if (!it) return;
                                                // a folder takes the colour itself, a file gets a tag dot
                                                if (it.isDir) root.setFolderColour(it.path, root.folderColours[it.path] === parent.modelData.id ? "" : parent.modelData.id);
                                                else root.setTag(it.path, root.tags[it.path] === parent.modelData.id ? "" : parent.modelData.id);
                                                ctx.item = null;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    z: 40
                    visible: ctx.item !== null
                    onClicked: ctx.item = null
                }

                // ── Quick Look ──
                Item {
                    id: ql
                    anchors.fill: parent
                    z: 60
                    visible: opacity > 0.01
                    opacity: item !== null ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    property var item: null
                    function showFor(it) { item = it; if (it.kind === "Video") vid.play(); }
                    function close() { if (item && item.kind === "Video") vid.stop(); item = null; }
                    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.72); MouseArea { anchors.fill: parent; onClicked: ql.close() } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 80, 860); height: Math.min(parent.height - 80, 620)
                        radius: 12
                        color: pal.dark ? "#1C1C1E" : "#FFFFFF"
                        border.width: 1; border.color: pal.sep
                        scale: ql.item !== null ? 1 : 0.95
                        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                        Text {
                            anchors.top: parent.top; anchors.topMargin: 12; anchors.horizontalCenter: parent.horizontalCenter
                            text: ql.item ? ql.item.name : ""
                            color: pal.text; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold
                        }
                        Image {
                            visible: ql.item && ql.item.kind === "Image"
                            anchors.fill: parent; anchors.margins: 40
                            source: (ql.item && ql.item.kind === "Image") ? "file://" + ql.item.path : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true; smooth: true; mipmap: true
                        }
                        // video: our own player, no external window
                        Item {
                            visible: ql.item && ql.item.kind === "Video"
                            anchors.fill: parent; anchors.margins: 40
                            MediaPlayer {
                                id: vid
                                source: (ql.item && ql.item.kind === "Video") ? "file://" + ql.item.path : ""
                                videoOutput: vidOut
                                audioOutput: AudioOutput { }
                            }
                            VideoOutput { id: vidOut; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectFit }
                            Rectangle {
                                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                width: 120; height: 34; radius: 17
                                color: Qt.rgba(0, 0, 0, 0.5)
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 18
                                    FnGlyph { width: 15; height: 15; kind: "back"; color: "white"; MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: vid.position = Math.max(0, vid.position - 10000) } }
                                    FnGlyph { width: 15; height: 15; kind: vid.playing ? "pause" : "play"; color: "white"; MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: vid.playing ? vid.pause() : vid.play() } }
                                    FnGlyph { width: 15; height: 15; kind: "fwd"; color: "white"; MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: vid.position = Math.min(vid.duration, vid.position + 10000) } }
                                }
                            }
                        }
                        // text files
                        Flickable {
                            visible: ql.item && (ql.item.kind === "Text" || ql.item.kind === "PDF")
                            anchors.fill: parent; anchors.margins: 36; anchors.topMargin: 44
                            contentHeight: qlText.height
                            clip: true
                            Text {
                                id: qlText
                                width: parent.width
                                text: root.qlText
                                wrapMode: Text.Wrap
                                color: pal.text; font.family: "monospace"; font.pixelSize: 11
                            }
                        }
                        Text {
                            visible: ql.item && ["Image", "Video", "Text", "PDF"].indexOf(ql.item.kind) < 0
                            anchors.centerIn: parent
                            text: ql.item ? (ql.item.kind + " · " + root.fmtSize(ql.item.size, ql.item.isDir)) : ""
                            color: pal.text2; font.family: root.fam; font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    // text preview content
    property string qlText: ""
    Process {
        id: qlProc
        stdout: StdioCollector { onStreamFinished: root.qlText = text }
    }
    function pinFolder(path) {
        if (!dock) return;
        dock.pinFolder(path);
    }
    readonly property bool driveExists: driveCheck
    property bool driveCheck: false
    Process {
        running: true
        command: ["sh", "-c", "[ -d \"$HOME/GoogleDrive\" ] && echo yes || echo no"]
        stdout: StdioCollector { onStreamFinished: root.driveCheck = text.trim() === "yes" }
    }
    function iconFor(kind) {
        if (kind === "Image") return "image";
        if (kind === "Video") return "video";
        if (kind === "Audio") return "note";
        if (kind === "Text") return "doc";
        if (kind === "PDF") return "doc";
        if (kind === "Archive") return "archive";
        return "file";
    }

    component FnGlyph: Canvas {
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
            c.strokeStyle = color; c.fillStyle = color; c.lineWidth = 1.5; c.lineCap = "round"; c.lineJoin = "round";
            var k = kind;
            if (k === "folder") {
                c.beginPath(); c.moveTo(1.6, 12.8); c.lineTo(1.6, 4.2); c.lineTo(6.2, 4.2); c.lineTo(7.4, 5.6); c.lineTo(14.4, 5.6); c.lineTo(14.4, 12.8); c.closePath();
                g.filled ? c.fill() : c.stroke();
            } else if (k === "home") {
                c.beginPath(); c.moveTo(2.4, 8); c.lineTo(8, 3); c.lineTo(13.6, 8); c.stroke();
                c.beginPath(); c.moveTo(4, 7.4); c.lineTo(4, 13); c.lineTo(12, 13); c.lineTo(12, 7.4); c.stroke();
            } else if (k === "desktop") {
                c.beginPath(); c.roundedRect(2, 3.4, 12, 8, 1.4, 1.4); c.stroke();
                c.beginPath(); c.moveTo(5.5, 13.4); c.lineTo(10.5, 13.4); c.stroke();
            } else if (k === "doc" || k === "file") {
                c.beginPath(); c.moveTo(3.6, 2.4); c.lineTo(9.6, 2.4); c.lineTo(12.4, 5.4); c.lineTo(12.4, 13.6); c.lineTo(3.6, 13.6); c.closePath(); c.stroke();
                c.beginPath(); c.moveTo(9.4, 2.6); c.lineTo(9.4, 5.6); c.lineTo(12.2, 5.6); c.stroke();
            } else if (k === "down") {
                c.beginPath(); c.moveTo(8, 2.6); c.lineTo(8, 10.6); c.stroke();
                c.beginPath(); c.moveTo(4.6, 7.4); c.lineTo(8, 10.9); c.lineTo(11.4, 7.4); c.stroke();
                c.beginPath(); c.moveTo(3.4, 13.2); c.lineTo(12.6, 13.2); c.stroke();
            } else if (k === "image") {
                c.beginPath(); c.roundedRect(2, 3.4, 12, 9.2, 1.4, 1.4); c.stroke();
                c.beginPath(); c.arc(5.6, 6.6, 1.1, 0, Math.PI * 2); c.fill();
                c.beginPath(); c.moveTo(3, 11.8); c.lineTo(6.6, 8.2); c.lineTo(9, 10.4); c.lineTo(11, 8.8); c.lineTo(13.2, 11.8); c.stroke();
            } else if (k === "note") {
                c.beginPath(); c.moveTo(6, 11.4); c.lineTo(6, 3.6); c.lineTo(12.4, 2.4); c.lineTo(12.4, 10); c.stroke();
                c.beginPath(); c.arc(4.6, 11.6, 1.5, 0, Math.PI * 2); c.stroke();
                c.beginPath(); c.arc(11, 10.2, 1.5, 0, Math.PI * 2); c.stroke();
            } else if (k === "video") {
                c.beginPath(); c.roundedRect(1.8, 4, 9.4, 8, 1.4, 1.4); c.stroke();
                c.beginPath(); c.moveTo(11.6, 8.8); c.lineTo(14.4, 10.8); c.lineTo(14.4, 5.2); c.lineTo(11.6, 7.2); c.closePath(); c.stroke();
            } else if (k === "cloud") {
                c.beginPath(); c.arc(6.4, 8.6, 3.1, Math.PI * 0.5, Math.PI * 1.5); c.arc(10, 7.4, 3.4, Math.PI * 1.4, Math.PI * 0.4); c.closePath(); c.stroke();
            } else if (k === "archive") {
                c.beginPath(); c.roundedRect(2.6, 3, 10.8, 10.4, 1.4, 1.4); c.stroke();
                c.beginPath(); c.moveTo(8, 3.4); c.lineTo(8, 7.6); c.stroke();
                c.beginPath(); c.roundedRect(6.9, 7.4, 2.2, 2.6, 0.7, 0.7); c.stroke();
            } else if (k === "back" || k === "fwd") {
                var d = k === "back" ? 1 : -1;
                c.lineWidth = 1.8;
                c.beginPath(); c.moveTo(8 + d * 2, 3.6); c.lineTo(8 - d * 2.4, 8); c.lineTo(8 + d * 2, 12.4); c.stroke();
            } else if (k === "up") {
                c.lineWidth = 1.8;
                c.beginPath(); c.moveTo(8, 12.4); c.lineTo(8, 4); c.stroke();
                c.beginPath(); c.moveTo(4.4, 7.4); c.lineTo(8, 3.8); c.lineTo(11.6, 7.4); c.stroke();
            } else if (k === "grid") {
                for (var i = 0; i < 2; i++) for (var j = 0; j < 2; j++) { c.beginPath(); c.roundedRect(3 + i * 5.4, 3 + j * 5.4, 4.2, 4.2, 0.9, 0.9); c.fill(); }
            } else if (k === "list") {
                for (var r = 0; r < 3; r++) { c.beginPath(); c.moveTo(3, 4.2 + r * 3.8); c.lineTo(13, 4.2 + r * 3.8); c.lineWidth = 1.5; c.stroke(); }
            } else if (k === "newfolder") {
                c.beginPath(); c.moveTo(1.8, 12.6); c.lineTo(1.8, 4.4); c.lineTo(6, 4.4); c.lineTo(7.2, 5.8); c.lineTo(12, 5.8); c.lineTo(12, 8.4); c.stroke();
                c.beginPath(); c.moveTo(12.4, 9.6); c.lineTo(12.4, 14); c.moveTo(10.2, 11.8); c.lineTo(14.6, 11.8); c.stroke();
            } else if (k === "search") {
                c.lineWidth = 1.6;
                c.beginPath(); c.arc(7, 7, 4.2, 0, Math.PI * 2); c.stroke();
                c.beginPath(); c.moveTo(10.2, 10.2); c.lineTo(13.6, 13.6); c.stroke();
            } else if (k === "play") {
                c.beginPath(); c.moveTo(5, 3.4); c.lineTo(13, 8); c.lineTo(5, 12.6); c.closePath(); c.fill();
            } else if (k === "pause") {
                c.beginPath(); c.roundedRect(4.4, 3.4, 2.6, 9.2, 0.7, 0.7); c.fill();
                c.beginPath(); c.roundedRect(9, 3.4, 2.6, 9.2, 0.7, 0.7); c.fill();
            }
        }
    }

    // read a text file when Quick Look opens one
    Connections {
        target: ql
        function onItemChanged() {
            if (ql.item && (ql.item.kind === "Text" || ql.item.kind === "PDF")) {
                root.qlText = "";
                qlProc.running = false;
                qlProc.command = ["sh", "-c", "case \"$1\" in *.pdf) pdftotext -l 3 \"$1\" - 2>/dev/null | head -c 20000;; *) head -c 20000 \"$1\";; esac", "sh", ql.item.path];
                qlProc.running = true;
            }
        }
    }
}
