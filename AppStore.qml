// App Store — the macOS App Store, with Flathub behind it instead of Apple's catalogue.
//
//   qs -c MacShell ipc call appstore open            (also: appstore page discover|updates, appstore search <text>)
//
// Everything is installed per user (`flatpak install --user`), so nothing ever asks for a password. Apps already
// installed system-wide are shown as installed and can be opened, but only removed with a polkit prompt.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root
    property var hub: null
    readonly property var dock: hub ? hub.dock : null
    readonly property var bar: hub ? hub.bar : null
    readonly property bool darkMode: dock ? dock.darkMode : true
    readonly property string fam: dock ? dock.fontFamily : "Inter Variable"
    property color accent: dock ? dock.accent : "#0A84FF"
    Behavior on accent { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }

    // ── where we are ──
    property string page: "discover"        // discover | cat:<Category> | updates | search
    property string appId: ""               // non-empty: the app page for this id
    property string query: ""
    property var back: []                   // history of { page, appId, query }

    function go(p, id, q) {
        back.push({ page: page, appId: appId, query: query });
        if (back.length > 40) back.shift();
        page = p === undefined ? page : p;
        appId = id === undefined ? "" : id;
        query = q === undefined ? query : q;
        if (appId !== "" && !details[appId]) fetchDetail(appId);
        if (p !== undefined && p.indexOf("cat:") === 0 && !coll[p]) fetchCollection(p);
    }
    function goBack() {
        if (back.length === 0) return;
        var s = back.pop();
        page = s.page; appId = s.appId; query = s.query;
    }

    // ── catalogue ──
    readonly property var cats: [
        { id: "Graphics",   name: "Create",   c1: "#FF6482", c2: "#E23F6B", glyph: "brush" },
        { id: "AudioVideo", name: "Audio & Video", c1: "#FF9F0A", c2: "#F06A00", glyph: "play" },
        { id: "Office",     name: "Work",     c1: "#30B0C7", c2: "#0A84FF", glyph: "case" },
        { id: "Game",       name: "Play",     c1: "#BF5AF2", c2: "#7D3DF3", glyph: "game" },
        { id: "Development", name: "Develop", c1: "#5E5CE6", c2: "#3634A3", glyph: "code" },
        { id: "Network",    name: "Internet", c1: "#0A84FF", c2: "#0040DD", glyph: "globe" },
        { id: "Education",  name: "Learn",    c1: "#32D74B", c2: "#15A52F", glyph: "book" },
        { id: "Utility",    name: "Utilities", c1: "#8E8E93", c2: "#5A5A5F", glyph: "tool" }
    ]
    function collName(k) { return k === "popular" ? "Popular on Flathub" : (k === "trending" ? "Trending" : "Recently Updated"); }
    function catName(id) { for (var i = 0; i < cats.length; i++) if (cats[i].id === id) return cats[i].name; return id; }

    property var coll: ({})                 // key → [app]        (key: "popular", "trending", "cat:Graphics", "search")
    property var details: ({})              // app id → appstream
    property var installed: ({})            // app id → { version, user }
    property var updatable: ({})            // app id → true
    property var busy: ({})                 // app id → "install" | "remove" | "update"
    property bool searchBusy: false         // a search is on its way: show the spinner, not "No results"
    property var loadingColl: ({})          // collection key → still fetching
    property string userName: Quickshell.env("USER") || ""
    property string avatar: ""
    Process {
        running: true
        command: ["sh", "-c", "n=$(getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1); printf '%s\\n' \"${n:-$USER}\"; "
                            + "for a in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$USER\"; do [ -f \"$a\" ] && { printf '%s' \"$a\"; break; }; done; echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n");
                if ((l[0] || "").trim() !== "") root.userName = l[0].trim();
                root.avatar = (l[1] || "").trim();
            }
        }
    }
    property int tick: 0                    // bumped so bindings re-read the maps above

    function put(key, val) {
        var m = {}; for (var k in coll) m[k] = coll[k]; m[key] = val; coll = m;
        var l = {}; for (var q in loadingColl) l[q] = loadingColl[q]; delete l[key]; loadingColl = l;
    }
    function markLoading(key) { var l = {}; for (var q in loadingColl) l[q] = loadingColl[q]; l[key] = true; loadingColl = l; }

    // ── Flathub (curl: no extra dependency, same as the rest of the shell) ──
    function api(url, key) {
        var p = fetchComp.createObject(root, { url: url, key: key });
        p.running = true;
    }
    Component {
        id: fetchComp
        Process {
            id: fp
            property string url: ""
            property string key: ""
            command: ["curl", "-sL", "--max-time", "20", url]
            stdout: StdioCollector {
                onStreamFinished: {
                    var o = null;
                    try { o = JSON.parse(text); } catch (e) { o = null; }
                    if (o) {
                        if (fp.key.indexOf("detail:") === 0) {
                            var id = fp.key.substring(7), m = {};
                            for (var k in root.details) m[k] = root.details[k];
                            m[id] = o; root.details = m;
                        } else {
                            root.put(fp.key, o.hits || []);
                        }
                    }
                    fp.destroy();
                }
            }
        }
    }
    function fetchCollection(key) {
        if (coll[key]) return;
        coll[key] = [];
        markLoading(key);
        var base = "https://flathub.org/api/v2/collection/";
        if (key.indexOf("cat:") === 0) api(base + "category/" + key.substring(4) + "?page=1&per_page=40", key);
        else api(base + key + "?page=1&per_page=24", key);
    }
    function fetchDetail(id) { api("https://flathub.org/api/v2/appstream/" + id, "detail:" + id); }
    property string searchFor: ""           // the query this request was made for
    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                var o = null;
                try { o = JSON.parse(text); } catch (e) { o = null; }
                // an answer for something you have already typed past: keep waiting for the current one
                if (root.searchFor !== root.query.trim()) return;
                root.put("search", o && o.hits ? o.hits : []);
                root.searchBusy = false;
            }
        }
    }
    Timer {
        id: searchDelay; interval: 260
        onTriggered: {
            if (root.query.trim() === "") { root.put("search", []); root.searchBusy = false; return; }
            searchProc.running = false;
            root.searchFor = root.query.trim();
            searchProc.command = ["curl", "-sL", "--max-time", "20", "-X", "POST", "https://flathub.org/api/v2/search",
                                  "-H", "Content-Type: application/json",
                                  "-d", JSON.stringify({ query: root.query.trim(), filters: [] })];
            searchProc.running = true;
        }
    }
    onQueryChanged: { searchBusy = query.trim() !== ""; if (query.trim() !== "") { if (page !== "search") { back.push({ page: page, appId: appId, query: "" }); page = "search"; appId = ""; } searchDelay.restart(); } }

    // ── what is installed, and what has an update ──
    Process {
        id: listProc
        command: ["sh", "-c", "flatpak list --app --columns=application,version,installation 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = {}, ls = text.trim().split("\n");
                for (var i = 0; i < ls.length; i++) {
                    var c = ls[i].split("\t");
                    if (c.length < 2 || c[0] === "") continue;
                    m[c[0].trim()] = { version: (c[1] || "").trim(), user: (c[2] || "").trim() === "user" };
                }
                root.installed = m; root.tick++;
            }
        }
    }
    Process {
        id: updProc
        command: ["sh", "-c", "flatpak remote-ls --updates --app --columns=application 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = {}, ls = text.trim().split("\n");
                for (var i = 0; i < ls.length; i++) if (ls[i].trim() !== "") m[ls[i].trim()] = true;
                root.updatable = m; root.tick++;
            }
        }
    }
    function refresh() { if (!listProc.running) listProc.running = true; }
    function refreshUpdates() { if (!updProc.running) updProc.running = true; }
    readonly property int updateCount: { tick; var n = 0; for (var k in updatable) if (installed[k]) n++; return n; }

    // ── install / remove / update ──
    function setBusy(id, what) { var m = {}; for (var k in busy) m[k] = busy[k]; if (what === "") delete m[id]; else m[id] = what; busy = m; tick++; }
    function act(id, what) {
        if (busy[id]) return;
        setBusy(id, what);
        var cmd;
        if (what === "install")
            cmd = "flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1; "
                + "flatpak install --user -y --noninteractive flathub \"$1\"";
        else if (what === "update") cmd = "flatpak update -y --noninteractive \"$1\" 2>/dev/null || flatpak update --user -y --noninteractive \"$1\"";
        else cmd = "flatpak uninstall --user -y --noninteractive \"$1\" 2>/dev/null || pkexec flatpak uninstall -y --noninteractive \"$1\"";
        var p = actComp.createObject(root, { appid: id, what: what, cmd: cmd });
        p.running = true;
    }
    Component {
        id: actComp
        Process {
            id: ap
            property string appid: ""
            property string what: ""
            property string cmd: ""
            command: ["sh", "-c", cmd, "sh", appid]
            onExited: (code, status) => {
                root.setBusy(ap.appid, "");
                root.refresh();
                if (ap.what !== "remove") root.refreshUpdates();
                if (code !== 0 && root.bar) root.bar.notify ? root.bar.notify("App Store", "Couldn't " + ap.what + " " + ap.appid) : 0;
                ap.destroy();
            }
        }
    }
    function run(id) { Quickshell.execDetached(["flatpak", "run", id]); }

    function open(p) {
        if (p !== undefined && p !== "") { page = p; appId = ""; }
        win.visible = true; win.raise(); win.requestActivate();
        refresh(); refreshUpdates();
        fetchCollection("popular"); fetchCollection("trending");
    }

    // ═════════════ WINDOW ═════════════
    Window {
        id: win
        title: "App Store"
        width: 1080; height: 720
        minimumWidth: 820; minimumHeight: 560
        visible: false
        color: "transparent"
        flags: Qt.Window | Qt.FramelessWindowHint
        // the listings and their icons are fetched again next time it opens, so let the cached ones go
        onVisibleChanged: if (!visible) { root.coll = ({}); root.details = ({}); root.appId = ""; root.query = ""; root.page = "discover"; Qt.callLater(gc); }

        QtObject {
            id: pal
            readonly property bool dark: root.darkMode
            property color bg: dark ? "#1E1E1E" : "#FFFFFF"
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
            property color pill: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.07)
            Behavior on pill { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color selRow: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.09)
            Behavior on selRow { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color getPill: dark ? Qt.rgba(1, 1, 1, 0.12) : "#E8E8EB"
            Behavior on getPill { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color pillHover: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12)
            Behavior on pillHover { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color field: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
            Behavior on field { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
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

            // ───────── sidebar ─────────
            Rectangle {
                id: side
                width: 232; height: parent.height
                color: pal.side
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: pal.sep }
                DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }

                // traffic lights
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
                            else if (mouse.x < 44) root.hub && root.hub.minimizeWindow ? root.hub.minimizeWindow(win.title) : win.showMinimized();
                            else win.visibility === Window.FullScreen ? win.showNormal() : win.showFullScreen();
                        }
                    }
                }

                // search
                Rectangle {
                    id: searchBox
                    x: 14; y: 48; width: parent.width - 28; height: 28; radius: 7
                    color: pal.field
                    ASGlyph { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 13; height: 13; kind: "search"; color: pal.text2 }
                    TextInput {
                        id: searchInput
                        x: 28; width: parent.width - 36
                        anchors.verticalCenter: parent.verticalCenter
                        color: pal.text; font.family: root.fam; font.pixelSize: 13
                        selectByMouse: true
                        onTextChanged: root.query = text
                        Keys.onEscapePressed: { text = ""; root.query = ""; root.page = "discover"; }
                        Text { visible: parent.text === ""; text: "Search"; color: pal.text3; font: parent.font }
                    }
                }

                // who you are (macOS puts the Apple ID here; this is your user, since Flathub needs no account)
                Item {
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                    x: 10; width: parent.width - 20; height: 40
                    Rectangle {
                        id: avatar
                        width: 26; height: 26; radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.accent
                        Text { anchors.centerIn: parent; text: (root.userName || "?").charAt(0).toUpperCase(); color: "white"; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold }
                        Item { id: avMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: width / 2; color: "black" } }
                        Image {
                            anchors.fill: parent
                            source: root.avatar !== "" ? "file://" + root.avatar : ""
                            fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                            sourceSize: Qt.size(64, 64)
                            layer.enabled: true
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: avMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                        }
                    }
                    Text {
                        x: 34; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40; elide: Text.ElideRight
                        text: root.userName
                        color: pal.text; font.family: root.fam; font.pixelSize: 12
                    }
                }

                // navigation
                Column {
                    x: 8; y: 90; width: parent.width - 16
                    spacing: 2
                    Repeater {
                        model: [{ p: "discover", n: "Discover", g: "star", c1: "#0A84FF", c2: "#0040DD" }].concat(
                               root.cats.map(function (c) { return { p: "cat:" + c.id, n: c.name, g: c.glyph, c1: c.c1, c2: c.c2 }; })).concat(
                               [{ p: "updates", n: "Updates", g: "down", c1: "#32D74B", c2: "#15A52F" }])
                        delegate: Rectangle {
                            id: navItem
                            required property var modelData
                            readonly property bool sel: root.page === modelData.p && root.appId === ""
                            width: parent.width; height: 30; radius: 6
                            color: sel ? pal.selRow : (navMa.containsMouse ? pal.pill : "transparent")
                            Behavior on color { ColorAnimation { duration: 130 } }
                            ASGlyph {
                                x: 10; anchors.verticalCenter: parent.verticalCenter
                                width: 15; height: 15
                                kind: navItem.modelData.g
                                color: navItem.sel ? pal.text : pal.text2
                            }
                            Text {
                                x: 34; anchors.verticalCenter: parent.verticalCenter
                                text: navItem.modelData.n
                                color: pal.text
                                font.family: root.fam; font.pixelSize: 13; font.weight: navItem.sel ? Font.DemiBold : Font.Normal
                            }
                            // how many updates are waiting
                            Rectangle {
                                visible: navItem.modelData.p === "updates" && root.updateCount > 0
                                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(18, cnt.implicitWidth + 10); height: 18; radius: 9
                                color: root.accent
                                Text { id: cnt; anchors.centerIn: parent; text: root.updateCount; color: "white"; font.family: root.fam; font.pixelSize: 11; font.weight: Font.DemiBold }
                            }
                            MouseArea {
                                id: navMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = ""; root.query = "";
                                    root.go(navItem.modelData.p, "");
                                    if (navItem.modelData.p === "updates") root.refreshUpdates();
                                }
                            }
                        }
                    }
                }
            }

            // ───────── content ─────────
            Item {
                id: content
                x: side.width; y: 0
                width: parent.width - side.width; height: parent.height

                // toolbar
                Rectangle {
                    id: tbar
                    width: parent.width; height: 52
                    color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.92)
                    z: 5
                    DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: pal.sep; opacity: pageFlick.contentY > 4 ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 160 } } }
                    Rectangle {
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 26; radius: 7
                        color: backMa.containsMouse && root.back.length > 0 ? pal.pill : "transparent"
                        opacity: root.back.length > 0 ? 1 : 0.35
                        ASGlyph { anchors.centerIn: parent; width: 14; height: 14; kind: "back"; color: pal.text }
                        MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.goBack() }
                    }
                    Item {
                        x: 54; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80; height: 20
                        readonly property bool searching: root.page === "search" && root.appId === ""
                        // searching: "Results for" stays put and only the term blurs + morphs into the next one
                        Row {
                            visible: parent.searching
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Results for"
                                color: pal.text2; font.family: root.fam; font.pixelSize: 15
                            }
                            CharText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.query
                                color: pal.text
                                font.family: root.fam; font.pixelSize: 15; font.weight: Font.DemiBold
                            }
                        }
                        MorphText {
                            visible: !parent.searching
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.appId !== "" ? (root.details[root.appId] ? root.details[root.appId].name : " ")
                                : (root.page === "discover" ? "Discover" : (root.page === "updates" ? "Updates"
                                : (root.page.indexOf("coll:") === 0 ? root.collName(root.page.substring(5)) : root.catName(root.page.substring(4)))))
                            color: pal.text; font.family: root.fam; font.pixelSize: 15; font.weight: Font.DemiBold
                            duration: 300
                        }
                    }
                }

                Flickable {
                    id: pageFlick
                    anchors.top: tbar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    contentWidth: width
                    contentHeight: pageLoader.height + 40
                    clip: true
                    Loader {
                        id: pageLoader
                        width: pageFlick.width
                        sourceComponent: root.appId !== "" ? pageApp : (root.page === "discover" ? pageDiscover : (root.page === "updates" ? pageUpdates : pageList))
                        onSourceComponentChanged: pageFlick.contentY = 0
                        // every page fades + rises in, like the App Store's
                        opacity: 0
                        Component.onCompleted: opacity = 1
                        onLoaded: { opacity = 0; inAnim.restart(); }
                        NumberAnimation { id: inAnim; target: pageLoader; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
                        transform: Translate { y: (1 - pageLoader.opacity) * 10 }
                    }
                }
            }
        }

        // ═════ Discover ═════
        Component {
            id: pageDiscover
            Column {
                width: parent.width
                spacing: 2
                // big cards
                Item {
                    width: parent.width; height: 268
                    ListView {
                        anchors.fill: parent
                        anchors.leftMargin: 24; anchors.rightMargin: 24
                        anchors.topMargin: 10
                        orientation: ListView.Horizontal
                        spacing: 16
                        clip: true
                        model: (root.coll["trending"] || []).slice(0, 8)
                        delegate: Item {
                            id: card
                            required property var modelData
                            width: 330; height: 238
                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                gradient: Gradient {
                                    GradientStop { position: 0; color: root.cardC1(card.modelData.app_id) }
                                    GradientStop { position: 1; color: root.cardC2(card.modelData.app_id) }
                                }
                                scale: cardMa.pressed ? 0.985 : 1
                                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                Text {
                                    x: 20; y: 18
                                    text: "TRENDING"
                                    color: Qt.rgba(1, 1, 1, 0.75); font.family: root.fam; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2
                                }
                                Text {
                                    x: 20; y: 36; width: parent.width - 40
                                    text: card.modelData.name
                                    elide: Text.ElideRight
                                    color: "white"; font.family: root.fam; font.pixelSize: 22; font.weight: Font.Bold
                                }
                                Text {
                                    x: 20; y: 66; width: parent.width - 40
                                    text: card.modelData.summary || ""
                                    wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                    color: Qt.rgba(1, 1, 1, 0.8); font.family: root.fam; font.pixelSize: 13
                                }
                                AppIcon { x: 20; y: parent.height - 78; width: 58; height: 58; appId: card.modelData.app_id; url: card.modelData.icon }
                                GetButton { anchors.right: parent.right; anchors.rightMargin: 20; y: parent.height - 58; appId: card.modelData.app_id; onDark: true }
                                MouseArea { id: cardMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.go(root.page, card.modelData.app_id) }
                            }
                        }
                    }
                }
                AppSection { title: "Popular on Flathub"; apps: (root.coll["popular"] || []).slice(0, 12); seeAll: "coll:popular" }
                AppSection { title: "Recently Updated"; apps: (root.coll["recently-updated"] || []).slice(0, 10); seeAll: "coll:recently-updated"
                             Component.onCompleted: root.fetchCollection("recently-updated") }
                AppSection { title: "Trending"; apps: (root.coll["trending"] || []).slice(8, 20); seeAll: "coll:trending" }
            }
        }

        // ═════ a category / search results ═════
        Component {
            id: pageList
            Column {
                width: parent.width
                AppSection {
                    title: ""
                    readonly property string key: root.page.indexOf("coll:") === 0 ? root.page.substring(5) : root.page
                    apps: root.page === "search" ? (root.coll["search"] || []) : (root.coll[key] || [])
                    loading: root.page === "search" ? root.searchBusy : root.loadingColl[key] === true
                    empty: root.page === "search" ? (root.query.trim() === "" ? "Type to search Flathub." : "No results found.") : "Nothing here."
                }
            }
        }

        // ═════ Updates ═════
        Component {
            id: pageUpdates
            Column {
                id: updCol
                width: parent.width
                spacing: 0
                readonly property var ups: { root.tick; var a = []; for (var k in root.updatable) if (root.installed[k]) a.push(k); return a.sort(); }
                readonly property var ins: { root.tick; var a = []; for (var k in root.installed) if (!root.updatable[k]) a.push(k); return a.sort(); }
                Item {
                    width: parent.width; height: 56
                    Text { x: 24; anchors.verticalCenter: parent.verticalCenter; text: updCol.ups.length > 0 ? "Available Updates" : "All Up to Date"; color: pal.text; font.family: root.fam; font.pixelSize: 17; font.weight: Font.Bold }
                    Text {
                        visible: updCol.ups.length > 1
                        anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter
                        text: "Update All"
                        color: allMa.containsMouse ? Qt.lighter(root.accent, 1.2) : root.accent
                        font.family: root.fam; font.pixelSize: 12
                        MouseArea { id: allMa; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { var u = updCol.ups; for (var i = 0; i < u.length; i++) root.act(u[i], "update"); } }
                    }
                }
                Repeater { model: updCol.ups; delegate: AppRow { required property string modelData; required property int index; x: 24; width: parent.width - 48; appId: modelData; divider: index < updCol.ups.length - 1 } }
                Item { width: 1; height: 18 }
                Item {
                    width: parent.width; height: 44
                    visible: parent.parent !== null
                    Text { x: 24; anchors.verticalCenter: parent.verticalCenter; text: "Installed"; color: pal.text; font.family: root.fam; font.pixelSize: 15; font.weight: Font.Bold }
                }
                Repeater { model: updCol.ins; delegate: AppRow { required property string modelData; required property int index; x: 24; width: parent.width - 48; appId: modelData; divider: index < updCol.ins.length - 1 } }
            }
        }

        // ═════ one app ═════
        Component {
            id: pageApp
            Column {
                width: parent.width
                spacing: 0
                readonly property var d: root.details[root.appId] || null
                readonly property var shots: d && d.screenshots ? d.screenshots : []

                // header
                Item {
                    width: parent.width; height: 168
                    AppIcon { id: bigIcon; x: 24; y: 22; width: 116; height: 116; appId: root.appId; url: parent.parent.d ? parent.parent.d.icon : "" }
                    Column {
                        x: 160; y: 30; width: parent.width - 180
                        spacing: 3
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: parent.parent.parent.d ? parent.parent.parent.d.name : root.appId
                            color: pal.text; font.family: root.fam; font.pixelSize: 26; font.weight: Font.Bold
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: parent.parent.parent.d ? (parent.parent.parent.d.developer_name || "") : ""
                            color: root.accent; font.family: root.fam; font.pixelSize: 14
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight; wrapMode: Text.WordWrap; maximumLineCount: 2
                            text: parent.parent.parent.d ? (parent.parent.parent.d.summary || "") : ""
                            color: pal.text2; font.family: root.fam; font.pixelSize: 13
                        }
                    }
                    GetButton { x: 160; y: 118; appId: root.appId; big: true }
                    Text {
                        x: 268; y: 124
                        text: root.installed[root.appId] ? ("Version " + root.installed[root.appId].version) : "Flathub"
                        color: pal.text3; font.family: root.fam; font.pixelSize: 11
                    }
                    Rectangle { anchors.bottom: parent.bottom; x: 24; width: parent.width - 48; height: 1; color: pal.sep }
                }

                // screenshots
                Item {
                    width: parent.width; height: visible ? 300 : 0
                    visible: parent.shots.length > 0
                    ListView {
                        anchors.fill: parent
                        anchors.leftMargin: 24; anchors.rightMargin: 24; anchors.topMargin: 20
                        orientation: ListView.Horizontal
                        spacing: 14
                        clip: true
                        model: parent.parent.shots
                        delegate: Rectangle {
                            required property var modelData
                            readonly property var best: {
                                var sz = modelData.sizes || [];
                                var pick = null;
                                for (var i = 0; i < sz.length; i++) if (!pick || parseInt(sz[i].width) > parseInt(pick.width)) pick = sz[i];
                                return pick;
                            }
                            height: 250
                            width: shot.status === Image.Ready ? Math.min(460, 250 * (shot.implicitWidth / Math.max(1, shot.implicitHeight))) : 380
                            radius: 10
                            color: pal.pill
                            clip: true
                            Image {
                                id: shot
                                anchors.fill: parent
                                source: parent.best ? parent.best.src : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true; smooth: true; mipmap: true
                                sourceSize.height: 500
                            }
                            Rectangle { anchors.fill: parent; radius: 10; color: "transparent"; border.width: 1; border.color: pal.sep }
                        }
                    }
                }

                // description
                Item {
                    width: parent.width; height: desc.implicitHeight + 36
                    Text {
                        id: desc
                        x: 24; y: 18; width: parent.width - 48
                        text: parent.parent.d ? root.plain(parent.parent.d.description || "") : ""
                        wrapMode: Text.WordWrap
                        color: pal.text; font.family: root.fam; font.pixelSize: 13; lineHeight: 1.35
                    }
                }

                // information
                Rectangle { x: 24; width: parent.width - 48; height: 1; color: pal.sep }
                Item {
                    width: parent.width; height: 40
                    Text { x: 24; anchors.verticalCenter: parent.verticalCenter; text: "Information"; color: pal.text; font.family: root.fam; font.pixelSize: 15; font.weight: Font.Bold }
                }
                Repeater {
                    model: {
                        var d = parent.d; if (!d) return [];
                        var rel = d.releases && d.releases.length ? d.releases[0] : null;
                        var out = [["Developer", d.developer_name || "Unknown"],
                                   ["Category", (d.categories || []).slice(0, 2).join(", ") || "—"],
                                   ["License", d.project_license || "—"],
                                   ["App ID", d.id || root.appId]];
                        if (rel && rel.version) out.splice(1, 0, ["Version", rel.version]);
                        return out;
                    }
                    delegate: Item {
                        required property var modelData
                        width: parent.width; height: 34
                        Rectangle { x: 24; width: parent.width - 48; height: 1; color: pal.sep; opacity: 0.6 }
                        Text { x: 24; anchors.verticalCenter: parent.verticalCenter; text: modelData[0]; color: pal.text2; font.family: root.fam; font.pixelSize: 12 }
                        Text { anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 200; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: modelData[1]; color: pal.text; font.family: root.fam; font.pixelSize: 12 }
                    }
                }
                Item { width: 1; height: 24 }
            }
        }
    }

    // appstream descriptions are HTML-ish
    function plain(s) {
        return String(s).replace(/<\/p>/g, "\n\n").replace(/<li>/g, "• ").replace(/<\/li>/g, "\n")
                        .replace(/<[^>]+>/g, "").replace(/&amp;/g, "&").replace(/&quot;/g, "\"").replace(/&#39;/g, "'")
                        .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/\n{3,}/g, "\n\n").trim();
    }
    // a stable colour per app, so the cards look designed rather than random
    function hash(s) { var h = 0; for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) & 0xffffff; return h; }
    function cardC1(id) { return Qt.hsla((hash(id || "") % 360) / 360, 0.62, 0.52, 1); }
    function cardC2(id) { return Qt.hsla(((hash(id || "") % 360) + 28) % 360 / 360, 0.68, 0.34, 1); }

    // ═════════════ pieces ═════════════
    component AppIcon: Item {
        id: ic
        property string appId: ""
        property string url: ""
        Rectangle { anchors.fill: parent; radius: width * 0.22; color: Qt.rgba(1, 1, 1, 0.10) }
        Image {
            anchors.fill: parent
            source: ic.url !== "" ? ic.url : ("https://dl.flathub.org/media/icons/128x128/" + ic.appId + ".png")
            fillMode: Image.PreserveAspectFit
            asynchronous: true; smooth: true; mipmap: true
            sourceSize: Qt.size(256, 256)
            onStatusChanged: if (status === Image.Error && source != Qt.resolvedUrl("")) fallback.visible = true
        }
        Text {
            id: fallback
            visible: false
            anchors.centerIn: parent
            text: (ic.appId.split(".").pop() || "?").charAt(0).toUpperCase()
            color: "white"; font.family: root.fam; font.pixelSize: parent.width * 0.45; font.weight: Font.Bold
        }
    }

    component GetButton: Item {
        id: gb
        property string appId: ""
        property bool big: false
        property bool onDark: false
        readonly property bool isInstalled: { root.tick; return root.installed[appId] !== undefined; }
        readonly property bool hasUpdate: { root.tick; return root.updatable[appId] === true && isInstalled; }
        readonly property string working: { root.tick; return root.busy[appId] || ""; }
        readonly property string label: working !== "" ? "" : (hasUpdate ? "UPDATE" : (isInstalled ? "OPEN" : "GET"))
        // the pill grows with its label, so every label keeps the same breathing room; whole pixels, so the
        // padding is identical on both sides
        width: 2 * Math.round((Math.max(big ? 92 : 58, lbl.implicitWidth + (big ? 32 : 26))) / 2)
        height: big ? 30 : 23
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: gb.onDark ? Qt.rgba(1, 1, 1, gbMa.containsMouse ? 0.35 : 0.22)
                             : (gbMa.containsMouse ? root.accent : pal.getPill)
            Behavior on color { ColorAnimation { duration: 140 } }
            scale: gbMa.pressed ? 0.94 : 1
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            FontMetrics { id: fm; font: lbl.font }
            Text {
                id: lbl
                // centred on the pill, then nudged by half the descender: these labels are all caps, so centring the
                // text box alone leaves them sitting high
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 0
                text: gb.label
                color: gb.onDark ? "white" : (gbMa.containsMouse ? "white" : root.accent)
                font.family: root.fam; font.pixelSize: gb.big ? 13 : 11; font.weight: Font.Bold; font.letterSpacing: 0.3
            }
            // working: a spinner, like the App Store's progress ring
            Canvas {
                id: spin
                anchors.centerIn: parent
                width: parent.height - 10; height: width
                visible: gb.working !== ""
                property real a: 0
                NumberAnimation on a { running: spin.visible; loops: Animation.Infinite; from: 0; to: Math.PI * 2; duration: 900 }
                onAChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d"); c.reset();
                    c.lineWidth = 2; c.lineCap = "round";
                    c.strokeStyle = gb.onDark ? "white" : root.accent;
                    c.beginPath(); c.arc(width / 2, height / 2, width / 2 - 1, a, a + 1.9); c.stroke();
                }
            }
        }
        MouseArea {
            id: gbMa
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: gb.working === ""
            onClicked: {
                if (gb.hasUpdate) root.act(gb.appId, "update");
                else if (gb.isInstalled) root.run(gb.appId);
                else root.act(gb.appId, "install");
            }
        }
    }

    component AppRow: Item {
        id: rowItem
        property string appId: ""
        property var app: null                   // a collection hit, when we have one
        property bool divider: true
        width: parent ? parent.width : 0
        height: 58
        readonly property var det: root.details[appId] || null
        Component.onCompleted: if (!app && !det) root.fetchDetail(appId)
        Rectangle { anchors.fill: parent; anchors.margins: -2; radius: 6; color: rowMa.containsMouse ? pal.pill : "transparent"; opacity: 0.5; Behavior on opacity { NumberAnimation { duration: 120 } } }
        Rectangle { visible: rowItem.divider; x: 52; width: parent.width - 52; height: 1; color: pal.sep; anchors.bottom: parent.bottom }
        AppIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 42; height: 42
            appId: rowItem.appId
            url: rowItem.app ? rowItem.app.icon : (rowItem.det ? rowItem.det.icon : "")
        }
        Column {
            x: 52; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 52 - 96
            spacing: 1
            Text {
                width: parent.width; elide: Text.ElideRight
                text: rowItem.app ? rowItem.app.name : (rowItem.det ? rowItem.det.name : rowItem.appId)
                color: pal.text; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: rowItem.app ? (rowItem.app.summary || "") : (rowItem.det ? (rowItem.det.summary || "") : "")
                color: pal.text2; font.family: root.fam; font.pixelSize: 11
            }
        }
        GetButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; appId: rowItem.appId }
        MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: -1; onClicked: root.go(root.page, rowItem.appId) }
    }

    component AppSection: Column {
        id: sec
        property string title: ""
        property var apps: []
        property string empty: ""
        property bool loading: false
        property string seeAll: ""               // page "See All" opens
        readonly property real colW: (width - 48 - 36) / 2
        width: parent ? parent.width : 0
        spacing: 0
        Item {
            width: parent.width; height: sec.title === "" ? 14 : 48
            visible: sec.title !== "" || sec.seeAll !== ""
            Text { x: 24; anchors.verticalCenter: parent.verticalCenter; text: sec.title; color: pal.text; font.family: root.fam; font.pixelSize: 17; font.weight: Font.Bold }
            Text {
                visible: sec.seeAll !== ""
                anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter
                text: "See All"; color: root.accent; font.family: root.fam; font.pixelSize: 12
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.go(sec.seeAll, "") }
            }
        }
        Item {
            visible: sec.apps.length === 0 && (sec.empty !== "" || sec.loading)
            width: parent.width; height: 90
            Row {
                x: 24; anchors.verticalCenter: parent.verticalCenter
                spacing: 9
                Canvas {
                    id: spinner
                    anchors.verticalCenter: parent.verticalCenter
                    visible: sec.loading
                    width: 15; height: 15
                    property real a: 0
                    NumberAnimation on a { running: spinner.visible; loops: Animation.Infinite; from: 0; to: Math.PI * 2; duration: 850 }
                    onAChanged: requestPaint()
                    onPaint: {
                        var c = getContext("2d"); c.reset();
                        c.lineWidth = 2; c.lineCap = "round"; c.strokeStyle = pal.text3;
                        c.beginPath(); c.arc(width / 2, height / 2, width / 2 - 1, a, a + 2.1); c.stroke();
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sec.loading ? "Searching\u2026" : sec.empty
                    color: pal.text3; font.family: root.fam; font.pixelSize: 13
                }
            }
        }
        // two columns, like the App Store's lists
        Grid {
            x: 24
            width: parent.width - 48
            columns: 2
            columnSpacing: 36
            Repeater {
                model: sec.apps
                delegate: AppRow {
                    required property var modelData
                    required property int index
                    width: sec.colW
                    app: modelData
                    appId: modelData.app_id || modelData.id || ""
                    divider: index < sec.apps.length - 2
                }
            }
        }
        Item { width: 1; height: 14 }
    }

    // small vector glyphs for the sidebar (no icon theme needed)
    component ASGlyph: Canvas {
        id: g
        property string kind: ""
        property color color: "white"
        onKindChanged: requestPaint()
        onColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        antialiasing: true
        onPaint: {
            var c = getContext("2d"); c.reset();
            var s = width / 16; c.scale(s, s);
            c.strokeStyle = color; c.fillStyle = color; c.lineWidth = 1.6; c.lineCap = "round"; c.lineJoin = "round";
            var k = kind;
            if (k === "star") {
                c.beginPath();
                for (var i = 0; i < 10; i++) {
                    var r = i % 2 === 0 ? 7 : 3, a = -Math.PI / 2 + i * Math.PI / 5;
                    var x = 8 + Math.cos(a) * r, y = 8 + Math.sin(a) * r;
                    i === 0 ? c.moveTo(x, y) : c.lineTo(x, y);
                }
                c.closePath(); c.fill();
            } else if (k === "brush") {
                c.beginPath(); c.moveTo(3, 13); c.lineTo(3, 10); c.lineTo(10, 3); c.lineTo(13, 6); c.lineTo(6, 13); c.closePath(); c.fill();
            } else if (k === "play") {
                c.beginPath(); c.moveTo(5, 3.5); c.lineTo(13, 8); c.lineTo(5, 12.5); c.closePath(); c.fill();
            } else if (k === "case") {
                c.beginPath(); c.roundedRect(2.5, 5.5, 11, 8, 1.6, 1.6); c.fill();
                c.lineWidth = 1.5; c.beginPath(); c.moveTo(6, 5.5); c.lineTo(6, 3.5); c.lineTo(10, 3.5); c.lineTo(10, 5.5); c.stroke();
            } else if (k === "game") {
                c.beginPath(); c.roundedRect(2, 5.5, 12, 7, 3.2, 3.2); c.fill();
                c.strokeStyle = "black"; c.globalAlpha = 0.35; c.lineWidth = 1.3;
                c.beginPath(); c.moveTo(5, 9); c.lineTo(7, 9); c.moveTo(6, 8); c.lineTo(6, 10); c.stroke();
                c.beginPath(); c.arc(10.5, 9, 0.9, 0, Math.PI * 2); c.stroke();
            } else if (k === "code") {
                c.beginPath(); c.moveTo(6, 4.5); c.lineTo(2.5, 8); c.lineTo(6, 11.5); c.stroke();
                c.beginPath(); c.moveTo(10, 4.5); c.lineTo(13.5, 8); c.lineTo(10, 11.5); c.stroke();
            } else if (k === "globe") {
                c.beginPath(); c.arc(8, 8, 5.6, 0, Math.PI * 2); c.stroke();
                c.beginPath(); c.ellipse(4.4, 2.4, 7.2, 11.2); c.stroke();
                c.beginPath(); c.moveTo(2.4, 8); c.lineTo(13.6, 8); c.stroke();
            } else if (k === "book") {
                c.beginPath(); c.moveTo(3, 3.5); c.lineTo(7.4, 3.5); c.lineTo(8, 4.6); c.lineTo(8, 12.5); c.lineTo(7.2, 11.8); c.lineTo(3, 11.8); c.closePath(); c.fill();
                c.beginPath(); c.moveTo(13, 3.5); c.lineTo(8.6, 3.5); c.lineTo(8, 4.6); c.lineTo(8, 12.5); c.lineTo(8.8, 11.8); c.lineTo(13, 11.8); c.closePath(); c.fill();
            } else if (k === "tool") {
                c.lineWidth = 2.2;
                c.beginPath(); c.moveTo(4, 12); c.lineTo(10, 6); c.stroke();
                c.beginPath(); c.arc(11.2, 4.8, 2.6, 0.6, 5.2); c.stroke();
            } else if (k === "down") {
                c.lineWidth = 1.8;
                c.beginPath(); c.moveTo(8, 3); c.lineTo(8, 11); c.stroke();
                c.beginPath(); c.moveTo(4.5, 7.6); c.lineTo(8, 11.2); c.lineTo(11.5, 7.6); c.stroke();
                c.beginPath(); c.moveTo(3.5, 13.2); c.lineTo(12.5, 13.2); c.stroke();
            } else if (k === "search") {
                c.lineWidth = 1.7;
                c.beginPath(); c.arc(7, 7, 4.2, 0, Math.PI * 2); c.stroke();
                c.beginPath(); c.moveTo(10.2, 10.2); c.lineTo(13.6, 13.6); c.stroke();
            } else if (k === "back") {
                c.lineWidth = 1.8;
                c.beginPath(); c.moveTo(10, 3.5); c.lineTo(5.5, 8); c.lineTo(10, 12.5); c.stroke();
            }
        }
    }
}
