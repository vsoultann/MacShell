// Finder and QuickTime Player, as the rest of the shell sees them. They are real apps now: Dolphin dressed as Finder
// and VLC in MacShell's QuickTime skin (session/qt, macshell-kde-theme.sh, macshell-quicktime.sh). This is the
// one place the shell opens folders, plays movies and asks for files, so every part of it goes through here.
//
//   finder: open(path), chooseFiles(cb, label, start), chooseFolder(cb, label, start)
//   player: play(src[, title]), playYoutube(url[, title])
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property var hub: null
    readonly property string home: Quickshell.env("HOME")
    readonly property string scripts: home + "/.config/hypr-macshell/scripts"

    // ── Finder ──
    function open(path) {
        var p = String(path || "").replace(/^file:\/\//, "");
        Quickshell.execDetached([scripts + "/macshell-finder.sh", p !== "" ? p : home]);
    }

    // file pickers: KDE's own dialog, which the MacShell session dresses like Finder's Open sheet
    property var pickCb: null
    function pick(args, cb) {
        pickCb = cb;
        picker.running = false;
        picker.command = ["kdialog"].concat(args);
        picker.running = true;
    }
    function chooseFiles(cb, label, start) {
        pick(["--title", label || "Open", "--multiple", "--separate-output", "--getopenfilename", start || home], cb);
    }
    function chooseFolder(cb, label, start) {
        pick(["--title", label || "Choose a Folder", "--getexistingdirectory", start || home], cb);
    }
    Process {
        id: picker
        stdout: StdioCollector {
            onStreamFinished: {
                var list = text.split("\n").filter(function (x) { return x.trim() !== ""; });
                var cb = root.pickCb;
                root.pickCb = null;
                if (cb && list.length > 0) cb(list);
            }
        }
    }

    // ── QuickTime Player ──
    readonly property QtObject player: QtObject {
        function play(src, title) {
            var s = String(src || "");
            if (s === "") return;
            Quickshell.execDetached([root.scripts + "/macshell-quicktime.sh", s]);
        }
        // a YouTube page: yt-dlp finds the stream (VLC's own YouTube script breaks whenever YouTube changes)
        function playYoutube(url, title) {
            Quickshell.execDetached(["sh", "-c",
                "u=$(yt-dlp -g -f 'b[height<=1080]/b' --no-playlist \"$1\" 2>/dev/null | head -1); "
                + "exec \"$2/macshell-quicktime.sh\" \"${u:-$1}\" --meta-title=\"$3\"",
                "sh", String(url), root.scripts, String(title || "Video")]);
        }
    }
}
