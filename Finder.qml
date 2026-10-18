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
    property color accent: dock ? dock.accent : "#0A84FF"
    Behavior on accent { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
    readonly property string home: Quickshell.env("HOME")

    // ── where we are ──
    property string dir: home
    property var back: []
    property var fwd: []
    property string view: "list"            // list | icons
    property string tagFilter: ""           // a tag colour to filter by
    property string query: ""
    property var entries: []                // { name, path, isDir, size, mtime, kind }
    property string selected: ""            // the last one clicked
    property var selection: []              // everything selected right now
    function isSelected(p) { return selection.indexOf(p) >= 0; }
    // what a drag out of Finder carries: the whole selection when you drag part of it, else just that file
    function uriOf(p) { return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F"); }
    function dragUris(p) {
        var list = (isSelected(p) && selection.length > 0) ? selection : [p];
        var out = [];
        for (var i = 0; i < list.length; i++) out.push(uriOf(list[i]));
        return out.join("\r\n") + "\r\n";
    }
    function selectOne(p) { selected = p; selection = [p]; }
    function selectToggle(p) {
        var sel = selection.slice(), i = sel.indexOf(p);
        if (i >= 0) sel.splice(i, 1); else sel.push(p);
        selection = sel; selected = p;
    }
    function selectRange(p) {
        var a = -1, b = -1;
        for (var i = 0; i < shown.length; i++) {
            if (shown[i].path === selected) a = i;
            if (shown[i].path === p) b = i;
        }
        if (a < 0 || b < 0) { selectOne(p); return; }
        var lo = Math.min(a, b), hi = Math.max(a, b), sel = [];
        for (var j = lo; j <= hi; j++) sel.push(shown[j].path);
        selection = sel;
    }
    function click(p, mods) {
        if (mods & Qt.ControlModifier) selectToggle(p);
        else if (mods & Qt.ShiftModifier) selectRange(p);
        else selectOne(p);
    }
    readonly property var selectedImages: {
        var out = [];
        for (var i = 0; i < shown.length; i++)
            if (selection.indexOf(shown[i].path) >= 0 && shown[i].kind === "Image") out.push(shown[i].path);
        return out;
    }

    // ── Merge Photos: several pictures become one, side by side, stacked or in a grid ──
    property bool mergeSheet: false
    property string mergeMode: "grid"
    property bool merging: false
    function mergePhotos() {
        if (selectedImages.length < 2) return;
        merging = true;
        var args = ["sh", "-c",
            "mode=\"$1\"; shift; dir=$(dirname \"$1\"); out=\"$dir/Merged Photos.jpg\"; i=2; "
            + "while [ -e \"$out\" ]; do out=\"$dir/Merged Photos $i.jpg\"; i=$((i+1)); done; "
            + "case \"$mode\" in "
            + "  horizontal) magick \"$@\" -resize x1200 +append -quality 92 \"$out\" ;; "
            + "  vertical)   magick \"$@\" -resize 1200x -append -quality 92 \"$out\" ;; "
            + "  *)          magick montage -background none -geometry +8+8 -tile x0 \"$@\" \"$out\" 2>/dev/null "
            + "              || montage -background none -geometry +8+8 -tile x0 \"$@\" \"$out\" ;; "
            + "esac; printf '%s' \"$out\"", "sh", mergeMode].concat(selectedImages);
        mergeProc.running = false;
        mergeProc.command = args;
        mergeProc.running = true;
    }
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
        dir = path; selected = ""; selection = []; tagFilter = ""; read();
    }
    function goBack() { if (back.length === 0) return; fwd.push(dir); dir = back.pop(); selected = ""; read(); }
    function goFwd() { if (fwd.length === 0) return; back.push(dir); dir = fwd.pop(); selected = ""; read(); }
    function up() { var p = dir.replace(/\/+$/, ""); var i = p.lastIndexOf("/"); if (i > 0) go(p.substring(0, i)); else go("/"); }

    property bool showHidden: false
    onShowHiddenChanged: read()
    function read() {
        loading = true;
        lsProc.running = false;
        lsProc.command = ["sh", "-c",
            "cd \"$1\" 2>/dev/null || exit 0; "
            + "find . -mindepth 1 -maxdepth 1 " + (showHidden ? "" : "! -name '.*' ")
            + "-printf '%y\\t%s\\t%T@\\t%f\\n' 2>/dev/null | LC_ALL=C sort -t\"$(printf '\\t')\" -k1,1 -k4,4f | head -3000", "sh", dir];
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
        if (e.isDir) { go(e.path); return; }
        if (e.kind === "Image" && hub && hub.preview) { hub.preview.open(e.path); return; }
        if (e.kind === "Video" && hub && hub.player) { hub.player.play(e.path, e.name); return; }
        Quickshell.execDetached(["xdg-open", e.path]);
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

    // ── the everyday file-manager actions ──
    property var clipFiles: []          // what Copy / Cut put aside
    property bool clipCut: false
    function copyFiles(list) {
        clipFiles = (list || []).slice();
        clipCut = false;
        // and on the system clipboard, so pasting into other apps works too
        if (clipFiles.length > 0)
            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy --type text/uri-list", "sh",
                                     clipFiles.map(function (f) { return root.uriOf(f); }).join("\r\n")]);
    }
    function cutFiles(list) { copyFiles(list); clipCut = true; }
    function pasteFiles() {
        if (clipFiles.length === 0) return;
        var args = ["sh", "-c",
            "d=\"$1\"; shift; mode=\"$1\"; shift; for f; do "
            + "b=$(basename \"$f\"); t=\"$d/$b\"; i=2; "
            + "while [ -e \"$t\" ]; do t=\"$d/${b%.*} ($i)${b##*.}\"; "
            + "  case \"$b\" in *.*) t=\"$d/$(printf '%s' \"${b%.*}\") ($i).${b##*.}\";; *) t=\"$d/$b ($i)\";; esac; i=$((i+1)); done; "
            + "if [ \"$mode\" = cut ]; then mv -- \"$f\" \"$t\"; else cp -a -- \"$f\" \"$t\"; fi; done",
            "sh", dir, clipCut ? "cut" : "copy"].concat(clipFiles);
        Quickshell.execDetached(args);
        if (clipCut) { clipFiles = []; clipCut = false; }
        reloadLater.restart();
    }
    function duplicate(path) {
        Quickshell.execDetached(["sh", "-c",
            "f=\"$1\"; d=$(dirname \"$f\"); b=$(basename \"$f\"); "
            + "case \"$b\" in *.*) n=\"$d/${b%.*} copy.${b##*.}\";; *) n=\"$d/$b copy\";; esac; "
            + "i=2; while [ -e \"$n\" ]; do case \"$b\" in *.*) n=\"$d/${b%.*} copy $i.${b##*.}\";; *) n=\"$d/$b copy $i\";; esac; i=$((i+1)); done; "
            + "cp -a -- \"$f\" \"$n\"", "sh", path]);
        reloadLater.restart();
    }
    function compress(list) {
        if (!list || list.length === 0) return;
        var args = ["sh", "-c",
            "d=\"$1\"; shift; n=\"$1\"; shift; out=\"$d/$n.zip\"; i=2; "
            + "while [ -e \"$out\" ]; do out=\"$d/$n $i.zip\"; i=$((i+1)); done; "
            + "cd \"$d\" && zip -r -q \"$out\" \"$@\" 2>/dev/null || tar -czf \"${out%.zip}.tar.gz\" \"$@\"",
            "sh", dir, list.length === 1 ? list[0].split("/").pop() : "Archive"];
        for (var i = 0; i < list.length; i++) args.push(list[i].split("/").pop());
        Quickshell.execDetached(args);
        reloadLater.restart();
    }
    function renameTo(path, name) {
        var n = String(name || "").trim();
        if (n === "" || n.indexOf("/") >= 0) return;
        Quickshell.execDetached(["sh", "-c", "d=$(dirname \"$1\"); [ -e \"$d/$2\" ] || mv -- \"$1\" \"$d/$2\"", "sh", path, n]);
        reloadLater.restart();
    }
    function openWith(path) {
        // the desktop's own "Open With" chooser, whichever one is installed
        Quickshell.execDetached(["sh", "-c",
            "mimeopen -a \"$1\" 2>/dev/null || exo-open \"$1\" 2>/dev/null || xdg-open \"$1\"", "sh", path]);
    }
    // ── Get Info ──
    property var infoFor: null
    property string infoText: ""
    function getInfo(e) {
        infoFor = e;
        infoText = "";
        infoProc.running = false;
        infoProc.command = ["sh", "-c",
            "f=\"$1\"; stat -c 'Size:\t%s bytes%nKind:\t%F%nOwner:\t%U:%G%nPermissions:\t%A%nModified:\t%y%nCreated:\t%w' \"$f\" 2>/dev/null; "
            + "[ -d \"$f\" ] && printf 'Contains:\t%s items\n' \"$(find \"$f\" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)\"; "
            + "printf 'Where:\t%s\n' \"$(dirname \"$f\")\"; exit 0", "sh", e.path];
        infoProc.running = true;
    }
    Process { id: infoProc; stdout: StdioCollector { onStreamFinished: root.infoText = text } }
    Process {
        id: mergeProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.merging = false;
                root.mergeSheet = false;
                root.read();
                var out = text.trim();
                if (out !== "") {
                    Quickshell.execDetached(["sh", "-c", "notify-send -a MacShell 'Merged Photos' \"$(basename \"$1\")\"", "sh", out]);
                    root.selectOne(out);
                }
            }
        }
    }

    function open(where) {
        if (where !== undefined && where !== "") { back.push(dir); dir = where; }
        win.visible = true; win.raise(); win.requestActivate();
        read();
    }

    // Choosing files happens in Finder itself, the way an Open sheet does on macOS, instead of handing you a
    // file dialog from another desktop. chooseFiles(cb, "Send") → cb(["/path", …]) when you press the button.
    property var chooseCb: null
    property string chooseVerb: ""
    readonly property bool choosing: chooseCb !== null
    function chooseFiles(cb, verb, where) {
        chooseCb = cb;
        chooseVerb = verb || "Choose";
        selection = []; selected = "";
        open(where);
    }
    // ── Locations: USB sticks, SD cards and anything else you plug in ──
    property var drives: []            // { dev, name, size, mount, mounted }
    property string driveBusy: ""
    Process {
        id: drivesProc
        command: ["sh", "-c",
            "lsblk -J -o PATH,LABEL,SIZE,MOUNTPOINT,RM,HOTPLUG,TYPE,FSTYPE 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                try {
                    var o = JSON.parse(text);
                    var walk = function (list) {
                        for (var i = 0; i < list.length; i++) {
                            var d = list[i];
                            if (d.children && d.children.length) walk(d.children);
                            // a disk with partitions is not itself a volume: list what you can actually open
                            if (d.type === "disk" && d.children && d.children.length) continue;
                            if (d.type !== "part" && d.type !== "disk") continue;
                            if (!(d.rm || d.hotplug)) continue;
                            if (!d.fstype || d.fstype === "swap") continue;
                            if (d.mountpoint === "[SWAP]" || d.mountpoint === "/" ) continue;
                            out.push({ dev: d.path, name: d.label || d.path.split("/").pop(),
                                       size: d.size || "", mount: d.mountpoint || "",
                                       mounted: !!d.mountpoint });
                        }
                    };
                    walk(o.blockdevices || []);
                } catch (e) { }
                // a whole disk that also lists its partitions is not a volume you can open: drop it
                var keep = [];
                for (var a = 0; a < out.length; a++) {
                    var covered = false;
                    for (var b = 0; b < out.length; b++) {
                        if (a === b) continue;
                        if (out[b].dev.length > out[a].dev.length && out[b].dev.indexOf(out[a].dev) === 0) { covered = true; break; }
                    }
                    if (!covered) keep.push(out[a]);
                }
                if (JSON.stringify(keep) !== JSON.stringify(root.drives)) root.drives = keep;
            }
        }
    }
    function scanDrives() { if (!drivesProc.running) drivesProc.running = true; }
    function openDrive(d) {
        if (d.mounted) { go(d.mount); return; }
        driveBusy = d.dev;
        mountProc.running = false;
        mountProc.command = ["sh", "-c",
            "p=$(udisksctl mount -b \"$1\" 2>&1); echo \"$p\" | sed -n 's/.* at \\(.*\\)\\.$/\\1/p'", "sh", d.dev];
        mountProc.running = true;
    }
    Process {
        id: mountProc
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.trim().replace(/^[`'\"]+|[`'\".]+$/g, "");
                root.driveBusy = "";
                root.scanDrives();
                if (m !== "" && m.charAt(0) === "/") root.go(m);
            }
        }
        onExited: { root.driveBusy = ""; root.scanDrives(); }
    }
    function ejectDrive(d) {
        driveBusy = d.dev;
        ejectProc.running = false;
        // unmount, then spin it down so it is safe to pull out
        ejectProc.command = ["sh", "-c",
            "udisksctl unmount -b \"$1\" >/dev/null 2>&1; udisksctl power-off -b \"$1\" >/dev/null 2>&1; exit 0", "sh", d.dev];
        ejectProc.running = true;
        if (dir.indexOf(d.mount) === 0 && d.mount !== "") go(home);
    }
    Process { id: ejectProc; onExited: { root.driveBusy = ""; root.scanDrives(); } }

    function chooseDone(ok) {
        var cb = chooseCb, files = selection.slice();
        chooseCb = null; chooseVerb = "";
        if (ok && cb && files.length > 0) cb(files);
    }

    Window {
        id: win
        title: "Finder"
        width: 1020; height: 660
        minimumWidth: 720; minimumHeight: 460
        visible: false
        color: "transparent"
        flags: Qt.Window | Qt.FramelessWindowHint
        onVisibleChanged: {
            if (visible) root.scanDrives();
            else { root.chooseCb = null; root.chooseVerb = ""; root.entries = []; root.selection = []; root.qlText = ""; Qt.callLater(gc); }
        }
        // a stick you plug in shows up on its own
        Timer { interval: 3000; repeat: true; running: win.visible; onTriggered: root.scanDrives() }

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
            property color pill: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07)
            Behavior on pill { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            property color selRow: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.09)
            Behavior on selRow { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
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
                        Item { width: 1; height: 10; visible: root.drives.length > 0 }
                        Text {
                            x: 10; text: "Locations"; color: pal.text3
                            visible: root.drives.length > 0
                            font.family: root.fam; font.pixelSize: 11; font.weight: Font.DemiBold
                        }
                        Repeater {
                            model: root.drives
                            delegate: Rectangle {
                                id: drvRow
                                required property var modelData
                                readonly property bool sel: root.dir === drvRow.modelData.mount && drvRow.modelData.mounted
                                width: parent.width; height: 27; radius: 6
                                color: sel ? pal.selRow : (dMa.containsMouse ? pal.pill : "transparent")
                                Behavior on color { ColorAnimation { duration: 140 } }
                                // arriving drives slide in instead of appearing
                                property real inT: 0
                                opacity: inT
                                transform: Translate { x: (1 - drvRow.inT) * -8 }
                                Component.onCompleted: drvIn.start()
                                NumberAnimation { id: drvIn; target: drvRow; property: "inT"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
                                FnGlyph { x: 9; anchors.verticalCenter: parent.verticalCenter; width: 15; height: 15; kind: "drive"; color: root.accent }
                                Text {
                                    x: 32; anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 32 - (dMa.containsMouse ? 26 : 8); elide: Text.ElideRight
                                    text: drvRow.modelData.name
                                    color: drvRow.modelData.mounted ? pal.text : pal.text2
                                    font.family: root.fam; font.pixelSize: 12
                                    font.weight: drvRow.sel ? Font.DemiBold : Font.Normal
                                }
                                // eject
                                Item {
                                    anchors.right: parent.right; anchors.rightMargin: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 15; height: 15
                                    opacity: dMa.containsMouse && drvRow.modelData.mounted ? 1 : 0
                                    visible: opacity > 0.01
                                    Behavior on opacity { NumberAnimation { duration: 140 } }
                                    FnGlyph { anchors.fill: parent; kind: "eject"; color: ejMa.containsMouse ? root.accent : pal.text2 }
                                    MouseArea {
                                        id: ejMa
                                        anchors.fill: parent; anchors.margins: -4
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        enabled: dMa.containsMouse && drvRow.modelData.mounted
                                        onClicked: root.ejectDrive(drvRow.modelData)
                                    }
                                }
                                Text {
                                    anchors.right: parent.right; anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.driveBusy === drvRow.modelData.dev
                                    text: "\u2026"; color: pal.text3; font.family: root.fam; font.pixelSize: 13
                                }
                                MouseArea {
                                    id: dMa
                                    anchors.fill: parent; anchors.rightMargin: 24
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openDrive(drvRow.modelData)
                                }
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
                        // dotfiles on or off (⌘⇧. does the same)
                        Rectangle {
                            width: 26; height: 26; radius: 7
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.showHidden ? root.accent : (hidMa.containsMouse ? pal.pill : "transparent")
                            Behavior on color { ColorAnimation { duration: 160 } }
                            FnGlyph { anchors.centerIn: parent; width: 15; height: 15; kind: "eye"; color: root.showHidden ? "white" : pal.text }
                            MouseArea { id: hidMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.showHidden = !root.showHidden }
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
                                color: root.isSelected(modelData.path) ? root.accent : (index % 2 === 1 ? Qt.rgba(1, 1, 1, pal.dark ? 0.025 : 0.02) : "transparent")
                                property color ink: root.isSelected(modelData.path) ? "white" : pal.text
                                Behavior on ink { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
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
                                Text { x: parent.width - 300; anchors.verticalCenter: parent.verticalCenter; text: Qt.formatDateTime(new Date(rowItem.modelData.mtime * 1000), "d MMM yyyy HH:mm"); color: root.isSelected(rowItem.modelData.path) ? "white" : pal.text2; font.family: root.fam; font.pixelSize: 11 }
                                Text { x: parent.width - 150; anchors.verticalCenter: parent.verticalCenter; text: root.fmtSize(rowItem.modelData.size, rowItem.modelData.isDir); color: root.isSelected(rowItem.modelData.path) ? "white" : pal.text2; font.family: root.fam; font.pixelSize: 11 }
                                Text { x: parent.width - 90; anchors.verticalCenter: parent.verticalCenter; width: 80; elide: Text.ElideRight; text: rowItem.modelData.kind; color: root.isSelected(rowItem.modelData.path) ? "white" : pal.text2; font.family: root.fam; font.pixelSize: 11 }
                                // drag a row out of Finder and other apps receive the file itself
                                Item {
                                    id: rowProxy
                                    width: 1; height: 1
                                    Drag.active: rowMa.drag.active
                                    Drag.dragType: Drag.Automatic
                                    Drag.supportedActions: Qt.CopyAction
                                    Drag.proposedAction: Qt.CopyAction
                                    Drag.mimeData: ({ "text/uri-list": root.dragUris(rowItem.modelData.path) })
                                }
                                MouseArea {
                                    id: rowMa
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    drag.target: rowProxy
                                    drag.threshold: 8
                                    onPressed: mouse => {
                                        if (mouse.button === Qt.LeftButton && !root.isSelected(rowItem.modelData.path))
                                            root.selectOne(rowItem.modelData.path);
                                    }
                                    onReleased: { rowProxy.x = 0; rowProxy.y = 0; }
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            if (!root.isSelected(rowItem.modelData.path)) root.selectOne(rowItem.modelData.path);
                                            ctx.show(rowItem.modelData, mapToItem(content, mouse.x, mouse.y));
                                        } else root.click(rowItem.modelData.path, mouse.modifiers);
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
                                    color: root.isSelected(cellI.modelData.path) ? root.accent : (iMa.containsMouse ? pal.pill : "transparent")
                                }
                                FnGlyph {
                                    anchors.horizontalCenter: parent.horizontalCenter; y: 12
                                    width: 46; height: 46
                                    visible: cellI.modelData.kind !== "Image"
                                    kind: cellI.modelData.isDir ? "folder" : root.iconFor(cellI.modelData.kind)
                                    color: cellI.modelData.isDir ? root.tagColour(root.folderColours[cellI.modelData.path] || "blue") : (root.isSelected(cellI.modelData.path) ? "white" : pal.text2)
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
                                    color: root.isSelected(cellI.modelData.path) ? "white" : pal.text; font.family: root.fam; font.pixelSize: 11
                                }
                                Rectangle {
                                    visible: root.tags[cellI.modelData.path] !== undefined
                                    x: 30; y: 10; width: 9; height: 9; radius: 4.5
                                    color: root.tagColour(root.tags[cellI.modelData.path] || "grey")
                                }
                                Item {
                                    id: cellProxy
                                    width: 1; height: 1
                                    Drag.active: iMa.drag.active
                                    Drag.dragType: Drag.Automatic
                                    Drag.supportedActions: Qt.CopyAction
                                    Drag.proposedAction: Qt.CopyAction
                                    Drag.imageSource: cellI.modelData.kind === "Image" ? "file://" + cellI.modelData.path : ""
                                    Drag.mimeData: ({ "text/uri-list": root.dragUris(cellI.modelData.path) })
                                }
                                MouseArea {
                                    id: iMa
                                    anchors.fill: parent; hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    drag.target: cellProxy
                                    drag.threshold: 8
                                    onPressed: mouse => {
                                        if (mouse.button === Qt.LeftButton && !root.isSelected(cellI.modelData.path))
                                            root.selectOne(cellI.modelData.path);
                                    }
                                    onReleased: { cellProxy.x = 0; cellProxy.y = 0; }
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            if (!root.isSelected(cellI.modelData.path)) root.selectOne(cellI.modelData.path);
                                            ctx.show(cellI.modelData, mapToItem(content, mouse.x, mouse.y));
                                        } else root.click(cellI.modelData.path, mouse.modifiers);
                                    }
                                    onDoubleClicked: root.openEntry(cellI.modelData)
                                }
                            }
                        }
                    }
                }


                // feathered edges: rows fade out under the toolbar and above the status bar instead of being sliced
                Rectangle {
                    anchors.top: tbar.bottom; anchors.left: parent.left; anchors.right: parent.right
                    height: 18; z: 4
                    opacity: (listFlick.visible && listFlick.contentY > 2) ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: pal.bg }
                        GradientStop { position: 1; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0) }
                    }
                }
                Rectangle {
                    anchors.bottom: statusBar.top; anchors.left: parent.left; anchors.right: parent.right
                    height: 18; z: 4
                    opacity: (listFlick.visible && listFlick.contentHeight - listFlick.contentY - listFlick.height > 2) ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0) }
                        GradientStop { position: 1; color: pal.bg }
                    }
                }

                // feathered edges: rows fade out under the toolbar and above the status bar instead of being sliced
                Rectangle {
                    anchors.top: tbar.bottom; anchors.left: parent.left; anchors.right: parent.right
                    height: 18; z: 4
                    opacity: (iconFlick.visible && iconFlick.contentY > 2) ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: pal.bg }
                        GradientStop { position: 1; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0) }
                    }
                }
                Rectangle {
                    anchors.bottom: statusBar.top; anchors.left: parent.left; anchors.right: parent.right
                    height: 18; z: 4
                    opacity: (iconFlick.visible && iconFlick.contentHeight - iconFlick.contentY - iconFlick.height > 2) ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0) }
                        GradientStop { position: 1; color: pal.bg }
                    }
                }

                // ── status bar, and the Choose / Cancel bar when Finder is picking files for something ──
                Rectangle {
                    id: statusBar
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: root.choosing ? 52 : 24
                    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                    color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.95)
                    Rectangle { width: parent.width; height: 1; color: pal.sep }
                    Text {
                        anchors.centerIn: parent
                        visible: !root.choosing
                        text: root.loading ? "Loading\u2026" : (root.shown.length + (root.shown.length === 1 ? " item" : " items") + (root.selection.length > 0 ? ", " + root.selection.length + " selected" : ""))
                        color: pal.text3; font.family: root.fam; font.pixelSize: 11
                    }
                    Text {
                        x: 16; anchors.verticalCenter: parent.verticalCenter
                        visible: root.choosing
                        opacity: root.choosing ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        text: root.selection.length === 0 ? "Select the files to send"
                            : (root.selection.length === 1 ? "1 file selected" : root.selection.length + " files selected")
                        color: pal.text2; font.family: root.fam; font.pixelSize: 12
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        visible: root.choosing
                        opacity: root.choosing ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Rectangle {
                            width: 86; height: 28; radius: 8
                            color: cancelMa.containsMouse ? pal.selRow : pal.pill
                            Behavior on color { ColorAnimation { duration: 140 } }
                            scale: cancelMa.pressed ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                            Text { anchors.centerIn: parent; text: "Cancel"; color: pal.text; font.family: root.fam; font.pixelSize: 12 }
                            MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.chooseDone(false); win.visible = false; } }
                        }
                        Rectangle {
                            width: Math.max(86, okText.implicitWidth + 28); height: 28; radius: 8
                            color: root.accent
                            opacity: root.selection.length > 0 ? 1 : 0.45
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                            scale: okMa.pressed ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                            Text { id: okText; anchors.centerIn: parent; text: root.chooseVerb; color: "white"; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold }
                            MouseArea {
                                id: okMa; anchors.fill: parent; hoverEnabled: true
                                enabled: root.selection.length > 0
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.chooseDone(true); win.visible = false; }
                            }
                        }
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
                            model: ["Open", "Open With\u2026", "Quick Look", "sep",
                                    "Rename\u2026", "Duplicate", "Compress", "Merge Photos\u2026", "sep",
                                    "Copy", "Cut", "Paste", "Copy Path", "sep",
                                    "Share with AirDrop\u2026", "Pin to Dock", "Get Info", "Move to Trash"]
                            delegate: Item {
                                required property string modelData
                                width: parent.width; height: modelData === "sep" ? 7 : 26
                                visible: (modelData !== "Pin to Dock" || (ctx.item && ctx.item.isDir))
                                       && (modelData !== "Merge Photos\u2026" || root.selectedImages.length >= 2)
                                       && (modelData !== "Share with AirDrop\u2026" || (ctx.item && !ctx.item.isDir))
                                       && (modelData !== "Open With\u2026" || (ctx.item && !ctx.item.isDir))
                                       && (modelData !== "Paste" || root.clipFiles.length > 0)
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
                                        var sel = root.isSelected(it.path) && root.selection.length > 0 ? root.selection : [it.path];
                                        if (m === "Open") root.openEntry(it);
                                        else if (m === "Open With\u2026") root.openWith(it.path);
                                        else if (m === "Rename\u2026") renamer.begin(it);
                                        else if (m === "Duplicate") { for (var di = 0; di < sel.length; di++) root.duplicate(sel[di]); }
                                        else if (m === "Compress") root.compress(sel);
                                        else if (m === "Copy") root.copyFiles(sel);
                                        else if (m === "Cut") root.cutFiles(sel);
                                        else if (m === "Paste") root.pasteFiles();
                                        else if (m === "Get Info") root.getInfo(it);
                                        else if (m === "Quick Look") ql.showFor(it);
                                        else if (m === "Merge Photos\u2026") root.mergeSheet = true;
                                        else if (m === "Share with AirDrop\u2026") {
                                            var list = root.isSelected(it.path) && root.selection.length > 0 ? root.selection : [it.path];
                                            if (root.hub && root.hub.airdrop) root.hub.airdrop.stagePaths(list);
                                        }
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

                // the keys a file manager is expected to answer to
                focus: true
                Keys.onPressed: event => {
                    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    if (ctrl && event.key === Qt.Key_C) { root.copyFiles(root.selection); event.accepted = true; }
                    else if (ctrl && event.key === Qt.Key_X) { root.cutFiles(root.selection); event.accepted = true; }
                    else if (ctrl && event.key === Qt.Key_V) { root.pasteFiles(); event.accepted = true; }
                    else if (ctrl && event.key === Qt.Key_D && root.selected !== "") { root.duplicate(root.selected); event.accepted = true; }
                    else if (ctrl && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_Period) { root.showHidden = !root.showHidden; event.accepted = true; }
                    else if (ctrl && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_N) { root.newFolder(); event.accepted = true; }
                    else if (ctrl && event.key === Qt.Key_I && root.selected !== "") {
                        for (var i = 0; i < root.shown.length; i++)
                            if (root.shown[i].path === root.selected) { root.getInfo(root.shown[i]); break; }
                        event.accepted = true;
                    }
                    else if (event.key === Qt.Key_F2 && root.selected !== "") {
                        for (var j = 0; j < root.shown.length; j++)
                            if (root.shown[j].path === root.selected) { renamer.begin(root.shown[j]); break; }
                        event.accepted = true;
                    }
                    else if (event.key === Qt.Key_Delete && root.selection.length > 0) {
                        for (var k = 0; k < root.selection.length; k++) root.trash(root.selection[k]);
                        event.accepted = true;
                    }
                    else if (event.key === Qt.Key_Backspace && (event.modifiers & Qt.AltModifier)) { root.up(); event.accepted = true; }
                }

                // ── rename sheet ──
                Item {
                    id: renamer
                    property var item: null
                    readonly property bool open: item !== null
                    anchors.fill: parent
                    z: 70
                    visible: opacity > 0.01
                    opacity: open ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    function begin(it) { item = it; nameField.text = it.name; nameField.forceActiveFocus(); nameField.selectAll(); }
                    function commit() { if (item) root.renameTo(item.path, nameField.text); item = null; }
                    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.3); MouseArea { anchors.fill: parent; onClicked: renamer.item = null } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 360; height: 128; radius: 14
                        color: pal.bg
                        border.width: 1; border.color: pal.sep
                        scale: renamer.open ? 1 : 0.94
                        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        layer.enabled: true
                        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.9; shadowOpacity: 0.4; shadowVerticalOffset: 8 }
                        Text { x: 18; y: 16; text: "Rename"; color: pal.text; font.family: root.fam; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Rectangle {
                            x: 18; y: 44; width: parent.width - 36; height: 30; radius: 8; color: pal.field
                            TextInput {
                                id: nameField
                                x: 10; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter
                                color: pal.text; font.family: root.fam; font.pixelSize: 13
                                selectByMouse: true
                                onAccepted: renamer.commit()
                                Keys.onEscapePressed: renamer.item = null
                            }
                        }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 18
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                            spacing: 10
                            Rectangle {
                                width: 84; height: 28; radius: 8; color: rcMa.containsMouse ? pal.selRow : pal.pill
                                Text { anchors.centerIn: parent; text: "Cancel"; color: pal.text; font.family: root.fam; font.pixelSize: 12 }
                                MouseArea { id: rcMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: renamer.item = null }
                            }
                            Rectangle {
                                width: 84; height: 28; radius: 8; color: root.accent
                                Text { anchors.centerIn: parent; text: "Rename"; color: "white"; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: renamer.commit() }
                            }
                        }
                    }
                }

                // ── Get Info sheet ──
                Item {
                    id: infoSheet
                    readonly property bool open: root.infoFor !== null
                    anchors.fill: parent
                    z: 70
                    visible: opacity > 0.01
                    opacity: open ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.3); MouseArea { anchors.fill: parent; onClicked: root.infoFor = null } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 400; height: 300; radius: 14
                        color: pal.bg
                        border.width: 1; border.color: pal.sep
                        clip: true
                        scale: infoSheet.open ? 1 : 0.94
                        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        layer.enabled: true
                        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.9; shadowOpacity: 0.4; shadowVerticalOffset: 8 }
                        FnGlyph {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 18
                            width: 44; height: 44
                            kind: root.infoFor ? (root.infoFor.isDir ? "folder" : root.iconFor(root.infoFor.kind)) : "doc"
                            color: root.infoFor && root.infoFor.isDir ? root.accent : pal.text2
                            filled: root.infoFor ? root.infoFor.isDir : false
                        }
                        Text {
                            y: 68; width: parent.width - 36; x: 18
                            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle
                            text: root.infoFor ? root.infoFor.name : ""
                            color: pal.text; font.family: root.fam; font.pixelSize: 14; font.weight: Font.DemiBold
                        }
                        Flickable {
                            x: 18; y: 96; width: parent.width - 36; height: parent.height - 96 - 52
                            contentHeight: infoCol.height
                            clip: true
                            Column {
                                id: infoCol
                                width: parent.width
                                spacing: 4
                                Repeater {
                                    model: root.infoText.split("\n").filter(function (l) { return l.indexOf("\t") > 0; })
                                    delegate: Item {
                                        required property string modelData
                                        width: parent.width; height: 20
                                        Text {
                                            width: 110
                                            text: modelData.split("\t")[0]
                                            color: pal.text2; font.family: root.fam; font.pixelSize: 12
                                        }
                                        Text {
                                            x: 114; width: parent.width - 114
                                            elide: Text.ElideMiddle
                                            text: modelData.split("\t").slice(1).join(" ")
                                            color: pal.text; font.family: root.fam; font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                            width: 96; height: 28; radius: 8; color: root.accent
                            Text { anchors.centerIn: parent; text: "Done"; color: "white"; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.infoFor = null }
                        }
                    }
                }

                // ── Merge Photos sheet ──
                Item {
                    id: mergeUi
                    anchors.fill: parent
                    z: 70
                    visible: opacity > 0.01
                    opacity: root.mergeSheet ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.45); MouseArea { anchors.fill: parent; onClicked: root.mergeSheet = false } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 400; height: 212; radius: 14
                        color: pal.dark ? "#232325" : "#FFFFFF"
                        border.width: 1; border.color: pal.sep
                        scale: root.mergeSheet ? 1 : 0.95
                        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 20
                            text: "Merge " + root.selectedImages.length + " Photos"
                            color: pal.text; font.family: root.fam; font.pixelSize: 15; font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 42
                            text: "They are combined into one picture in this folder."
                            color: pal.text3; font.family: root.fam; font.pixelSize: 12
                        }
                        Row {
                            id: modeRow
                            anchors.horizontalCenter: parent.horizontalCenter; y: 74
                            spacing: 10
                            Repeater {
                                model: [{ id: "grid", n: "Grid" }, { id: "horizontal", n: "Side by Side" }, { id: "vertical", n: "Stacked" }]
                                delegate: Rectangle {
                                    id: modeCard
                                    required property var modelData
                                    readonly property bool sel: root.mergeMode === modelData.id
                                    width: 118; height: 56; radius: 10
                                    color: sel ? root.accent : pal.pill
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 2
                                            Repeater {
                                                model: modeCard.modelData.id === "vertical" ? 3 : 4
                                                delegate: Rectangle {
                                                    width: modeCard.modelData.id === "vertical" ? 22 : (modeCard.modelData.id === "grid" ? 9 : 5)
                                                    height: modeCard.modelData.id === "vertical" ? 3 : (modeCard.modelData.id === "grid" ? 9 : 16)
                                                    radius: 1.5
                                                    color: Qt.rgba(1, 1, 1, 0.8)
                                                }
                                            }
                                        }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modeCard.modelData.n; color: "white"; font.family: root.fam; font.pixelSize: 11 }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mergeMode = modeCard.modelData.id }
                                }
                            }
                        }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 18
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 16
                            spacing: 10
                            Rectangle {
                                width: 88; height: 30; radius: 8; color: pal.pill
                                Text { anchors.centerIn: parent; text: "Cancel"; color: pal.text; font.family: root.fam; font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mergeSheet = false }
                            }
                            Rectangle {
                                width: 100; height: 30; radius: 8; color: root.accent
                                opacity: root.merging ? 0.6 : 1
                                Text { anchors.centerIn: parent; text: root.merging ? "Merging…" : "Merge"; color: "white"; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold }
                                MouseArea { anchors.fill: parent; enabled: !root.merging; cursorShape: Qt.PointingHandCursor; onClicked: root.mergePhotos() }
                            }
                        }
                    }
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
            } else if (k === "eye") {
                c.beginPath(); c.moveTo(1.6, 8); c.bezierCurveTo(4.5, 3.4, 11.5, 3.4, 14.4, 8);
                c.bezierCurveTo(11.5, 12.6, 4.5, 12.6, 1.6, 8); c.closePath(); c.stroke();
                c.beginPath(); c.arc(8, 8, 2.2, 0, Math.PI * 2); c.stroke();
            } else if (k === "drive") {
                c.beginPath(); c.roundedRect(1.8, 4.6, 12.4, 7, 1.6, 1.6); c.stroke();
                c.beginPath(); c.arc(11.4, 8.1, 0.95, 0, Math.PI * 2); c.fill();
                c.beginPath(); c.moveTo(3.6, 8.1); c.lineTo(8.2, 8.1); c.stroke();
            } else if (k === "eject") {
                c.beginPath(); c.moveTo(8, 3.2); c.lineTo(13, 9.2); c.lineTo(3, 9.2); c.closePath(); c.fill();
                c.beginPath(); c.roundedRect(3, 11, 10, 1.8, 0.9, 0.9); c.fill();
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
