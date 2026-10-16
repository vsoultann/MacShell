// macOS desktop widgets for MacShell: Clock, World Clock, Calendar, Weather, Batteries, Music, Notes, Photos,
// Reminders and Stocks, in Small / Medium / Large, each in one of four looks:
//   glass   – Apple Liquid Glass (refracts the wallpaper through liquidglass.frag)
//   frosted – blurred wallpaper + a light/dark veil (classic macOS vibrancy)
//   tinted  – blurred wallpaper washed in the accent colour, monochrome content
//   opaque  – solid card, full colour
// They live on the desktop (layer "macwidgets", under windows). Drag a widget anywhere (it snaps to a 16 px grid).
// Right-click a widget, Settings → General → "Edit Widgets…", or `qs -c MacShell ipc call widgets edit` opens the gallery.
// Saved in ~/.config/macshell/widgets.json; Notes in notes.md, Reminders in reminders.md (same folder).
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

Scope {
    id: root
    property var hub: null
    readonly property var bar: hub ? hub.bar : null
    readonly property var dock: hub ? hub.dock : null
    readonly property bool dark: bar ? bar.darkMode : true
    readonly property color accent: bar ? bar.accent : "#0a84ff"
    readonly property string fam: bar ? bar.fontFamily : "Inter"
    readonly property url shaderUrl: dock ? dock.glassShaderUrl : ""
    readonly property bool shaderOk: dock ? dock.glassState === "ready" : false
    readonly property bool gaming: bar ? bar.gaming : false
    readonly property string home: Quickshell.env("HOME")
    readonly property string cfgDir: home + "/.config/macshell"

    // ═════════════ STATE / PERSISTENCE ═════════════
    property bool enabled: true
    property string style: "glass"
    property real glassAmt: 0.5          // Liquid Glass effect (refraction, bevel, rim): 0 = flat, 1 = strong
    property real blurAmt: 0.5           // blur of what's behind the widgets: 0 = clear, 1 = heavy
    property var widgets: []                 // [{ id, type, size: "s"|"m"|"l", x, y, screen, style? }]
    property bool editing: false
    property bool loaded: false
    property string selected: ""             // widget being edited (its toolbar shows)
    property var stockSymbols: ["AAPL", "NVDA", "^GSPC", "BTC-USD"]

    readonly property var types: [
        { type: "clock",     name: "Clock",       sizes: ["s", "m"], hint: "Analog clock · World Clock" },
        { type: "calendar",  name: "Calendar",    sizes: ["s", "m", "l"], hint: "Today · Month" },
        { type: "weather",   name: "Weather",     sizes: ["s", "m", "l"], hint: "Now · Hourly · 5-day" },
        { type: "batteries", name: "Batteries",   sizes: ["s", "m"], hint: "Mac and connected devices" },
        { type: "music",     name: "Music",       sizes: ["s", "m", "l"], hint: "Now Playing" },
        { type: "notes",     name: "Notes",       sizes: ["s", "m", "l"], hint: "notes.md" },
        { type: "photos",    name: "Photos",      sizes: ["s", "m", "l"], hint: "Featured photo" },
        { type: "reminders", name: "Reminders",   sizes: ["s", "m", "l"], hint: "reminders.md" },
        { type: "stocks",    name: "Stocks",      sizes: ["s", "m"], hint: "Watchlist" }
    ]
    function dims(size) {
        if (size === "l") return { w: 356, h: 356 };
        if (size === "m") return { w: 356, h: 170 };
        return { w: 170, h: 170 };
    }

    FileView {
        id: store
        path: root.cfgDir + "/widgets.json"
        printErrors: false
        onLoaded: {
            var o = {};
            try { o = JSON.parse(text()); } catch (e) { o = {}; }
            if (o.style) root.style = o.style;
            if (o.glassAmt !== undefined) root.glassAmt = o.glassAmt;
            if (o.blurAmt !== undefined) root.blurAmt = o.blurAmt;
            if (o.enabled !== undefined) root.enabled = o.enabled;
            if (o.stocks) root.stockSymbols = o.stocks;
            root.widgets = o.widgets || [];
            root.loaded = true;
        }
        onLoadFailed: {
            // first run: a small macOS-like starter set in the top-left corner of the first screen
            root.widgets = [
                { id: "w1", type: "weather",   size: "m", x: 32,  y: 56,  screen: "" },
                { id: "w2", type: "calendar",  size: "s", x: 32,  y: 242, screen: "" },
                { id: "w3", type: "batteries", size: "s", x: 218, y: 242, screen: "" },
                { id: "w4", type: "clock",     size: "s", x: 32,  y: 428, screen: "" },
                { id: "w5", type: "music",     size: "s", x: 218, y: 428, screen: "" }
            ];
            root.loaded = true;
            root.save();
        }
    }
    // The desktop draws from this model, which is patched in place (setProperty / append / remove). Re-assigning a
    // JS array as the Repeater model rebuilt EVERY widget on any change: drags got cut off mid-move, every widget
    // replayed its pop-in, and it lagged.
    ListModel { id: wmodel }
    onWidgetsChanged: syncModel()
    function syncModel() {
        var want = {}, i, w;
        for (i = 0; i < widgets.length; i++) want[widgets[i].id] = widgets[i];
        for (i = wmodel.count - 1; i >= 0; i--) if (!want[wmodel.get(i).wid]) wmodel.remove(i);
        for (i = 0; i < widgets.length; i++) {
            w = widgets[i];
            var row = { wid: w.id, wtype: w.type, wsize: w.size, wx: w.x, wy: w.y, wscreen: w.screen || "", wstyle: w.style || "" };
            var at = -1;
            for (var j = 0; j < wmodel.count; j++) if (wmodel.get(j).wid === w.id) { at = j; break; }
            if (at < 0) { wmodel.append(row); continue; }
            var cur = wmodel.get(at);
            for (var k in row) if (cur[k] !== row[k]) wmodel.setProperty(at, k, row[k]);
        }
    }
    function save() { saveTimer.restart(); }
    Timer {
        id: saveTimer
        interval: 300
        onTriggered: store.setText(JSON.stringify({ enabled: root.enabled, style: root.style, glassAmt: root.glassAmt, blurAmt: root.blurAmt, stocks: root.stockSymbols, widgets: root.widgets }, null, 2))
    }
    onStyleChanged: if (loaded) save()
    onGlassAmtChanged: if (loaded) save()
    onBlurAmtChanged: if (loaded) save()
    onEnabledChanged: if (loaded) save()

    function update(id, patch) {
        var out = [];
        for (var i = 0; i < widgets.length; i++) {
            var w = widgets[i];
            if (w.id === id) { var c = {}; for (var k in w) c[k] = w[k]; for (var p in patch) c[p] = patch[p]; out.push(c); }
            else out.push(w);
        }
        widgets = out; save();
    }
    function remove(id) { widgets = widgets.filter(function (w) { return w.id !== id; }); if (selected === id) selected = ""; save(); }
    // widgets without a screen go on the main display: an external monitor if there is one (not the laptop panel)
    readonly property string mainScreen: {
        var sc = Quickshell.screens;
        for (var i = 0; i < sc.length; i++) if (!/^(eDP|LVDS|DSI)/.test(sc[i].name)) return sc[i].name;
        return sc.length ? sc[0].name : "";
    }
    function screenOf(w) {
        if (w.screen && w.screen !== "") {
            for (var i = 0; i < Quickshell.screens.length; i++) if (Quickshell.screens[i].name === w.screen) return w.screen;
        }
        return mainScreen;      // no screen, or that monitor is unplugged right now
    }
    function overlaps(sname, x, y, ww, hh, skip) {
        for (var i = 0; i < widgets.length; i++) {
            var w = widgets[i];
            if (w.id === skip || screenOf(w) !== sname) continue;
            var d = dims(w.size);
            if (x < w.x + d.w + 2 && x + ww + 2 > w.x && y < w.y + d.h + 2 && y + hh + 2 > w.y) return true;
        }
        return false;
    }
    // nearest grid position to (x, y) where a w×h widget overlaps nothing (searched in growing rings)
    function freeSpot(sname, x, y, w, h, skip, sw, sh) {
        if (!overlaps(sname, x, y, w, h, skip)) return { x: x, y: y };
        for (var r = 16; r < 1600; r += 16) {
            var best = null, bd = 1e9;
            for (var dx = -r; dx <= r; dx += 16)
                for (var dy = -r; dy <= r; dy += 16) {
                    if (Math.abs(dx) !== r && Math.abs(dy) !== r) continue;
                    var cx = x + dx, cy = y + dy;
                    if (cx < 8 || cy < 36 || cx + w > sw - 8 || cy + h > sh - 8) continue;
                    if (overlaps(sname, cx, cy, w, h, skip)) continue;
                    var dd = dx * dx + dy * dy;
                    if (dd < bd) { bd = dd; best = { x: cx, y: cy }; }
                }
            if (best) return best;
        }
        return { x: x, y: y };
    }
    function add(type, size, sname) {
        var d = dims(size), sw = 1920, sh = 1080;
        for (var s = 0; s < Quickshell.screens.length; s++) if (Quickshell.screens[s].name === sname) { sw = Quickshell.screens[s].width; sh = Quickshell.screens[s].height; }
        var px = 32, py = 56, found = false;
        for (var y = 56; y + d.h < sh - 120 && !found; y += 16)
            for (var x = 32; x + d.w < sw - 32; x += 16)
                if (!overlaps(sname, x, y, d.w, d.h, "")) { px = x; py = y; found = true; break; }
        var id = "w" + Date.now();
        widgets = widgets.concat([{ id: id, type: type, size: size, x: px, y: py, screen: sname }]);
        selected = id;
        save();
        if (bar) bar.playSound("pop", 0.6);
    }

    // ═════════════ LIVE WALLPAPER UNDER THE GLASS ═════════════
    // a video wallpaper comes with a small looping animated WebP (macshell-setwall.sh); the glass refracts that
    FileView { id: glassVidFile; path: root.cfgDir + "/wallpaper-video-glass"; watchChanges: true; printErrors: false; onFileChanged: reload() }
    readonly property string glassAnim: {
        var t = glassVidFile.loaded ? glassVidFile.text().trim() : "";
        return (bar && bar.wallpaperVideo !== "" && t !== "") ? t : "";
    }

    // ═════════════ SHARED DATA ═════════════
    property var now: new Date()
    Timer { interval: 1000; repeat: true; running: root.enabled && !root.gaming && root.widgets.length > 0; onTriggered: root.now = new Date() }

    // location (once) → weather every 15 min (Open-Meteo, no key)
    property var geo: ({ city: "", lat: 0, lon: 0, tz: "" })
    property var weather: null
    readonly property bool wantsWeather: widgets.some(function (w) { return w.type === "weather" || w.type === "clock"; })
    Process {
        id: geoProc
        running: root.loaded && root.wantsWeather
        command: ["sh", "-c", "c=\"$HOME/.cache/macshell/geo.json\"; mkdir -p \"$(dirname \"$c\")\"; "
            + "if [ -s \"$c\" ] && [ $(( $(date +%s) - $(stat -c %Y \"$c\") )) -lt 86400 ]; then cat \"$c\"; else "
            + "curl -s --max-time 8 'http://ip-api.com/json/?fields=status,city,country,lat,lon,timezone' | tee \"$c\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { var o = JSON.parse(text); if (o.status === "success") { root.geo = { city: o.city.replace(/ City$/, ""), lat: o.lat, lon: o.lon, tz: o.timezone }; weatherProc.running = true; } } catch (e) {}
            }
        }
    }
    Process {
        id: weatherProc
        command: ["sh", "-c", "curl -s --max-time 10 \"https://api.open-meteo.com/v1/forecast?latitude=$1&longitude=$2&current=temperature_2m,weather_code,is_day&hourly=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=auto&forecast_days=6&forecast_hours=7\"", "sh", String(root.geo.lat), String(root.geo.lon)]
        stdout: StdioCollector { onStreamFinished: { try { var o = JSON.parse(text); if (o.current) root.weather = o; } catch (e) {} } }
    }
    Timer { interval: 15 * 60 * 1000; repeat: true; running: root.wantsWeather && root.geo.lat !== 0 && !root.gaming; onTriggered: weatherProc.running = true }
    function wmo(code, isDay) {
        // WMO weather code → [text, icon]
        var c = code | 0;
        if (c === 0) return [isDay ? "Sunny" : "Clear", isDay ? "sun" : "moon"];
        if (c === 1) return [isDay ? "Mostly Sunny" : "Mostly Clear", isDay ? "sun" : "moon"];
        if (c === 2) return ["Partly Cloudy", isDay ? "partly" : "partlynight"];
        if (c === 3) return ["Cloudy", "cloud"];
        if (c === 45 || c === 48) return ["Foggy", "fog"];
        if (c >= 51 && c <= 57) return ["Drizzle", "rain"];
        if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return ["Rain", "rain"];
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return ["Snow", "snow"];
        if (c >= 95) return ["Thunderstorms", "storm"];
        return ["—", "cloud"];
    }

    // stocks (Yahoo chart API) every 10 min
    property var stocks: ({})
    readonly property bool wantsStocks: widgets.some(function (w) { return w.type === "stocks"; })
    Process {
        id: stockProc
        running: root.loaded && root.wantsStocks
        command: ["sh", "-c", "for s in \"$@\"; do curl -s --max-time 8 -A 'Mozilla/5.0' -G \"https://query1.finance.yahoo.com/v8/finance/chart/$s\" -d range=1d -d interval=15m "
            + "| jq -c --arg s \"$s\" '{s: $s, name: (.chart.result[0].meta.shortName // $s), p: .chart.result[0].meta.regularMarketPrice, pc: .chart.result[0].meta.chartPreviousClose, c: [.chart.result[0].indicators.quote[0].close[] | select(. != null)]}' 2>/dev/null; sleep 0.3; done", "sh"].concat(root.stockSymbols)
        stdout: StdioCollector {
            onStreamFinished: {
                var m = {}, l = text.split("\n");
                for (var i = 0; i < l.length; i++) { try { var o = JSON.parse(l[i]); if (o && o.p) m[o.s] = o; } catch (e) {} }
                root.stocks = m;
            }
        }
    }
    Timer { interval: 10 * 60 * 1000; repeat: true; running: root.wantsStocks && !root.gaming; onTriggered: stockProc.running = true }

    // notes + reminders (plain files you can edit anywhere)
    FileView { id: notesFile; path: root.cfgDir + "/notes.md"; watchChanges: true; printErrors: false; onFileChanged: reload()
               onLoadFailed: setText("# Notes\n\nWrite anything here — it shows up on the desktop.\nOpen this file from the Notes widget.\n") }
    FileView { id: remFile; path: root.cfgDir + "/reminders.md"; watchChanges: true; printErrors: false; onFileChanged: reload()
               onLoadFailed: setText("- [ ] Try the new widgets\n- [x] Install MacShell\n- [ ] Click a circle to tick it off\n") }
    readonly property string notesText: notesFile.loaded ? notesFile.text() : ""
    readonly property var reminders: {
        var t = remFile.loaded ? remFile.text() : "", out = [], l = t.split("\n");
        for (var i = 0; i < l.length; i++) {
            var m = /^\s*[-*]\s*\[( |x|X)\]\s*(.*)$/.exec(l[i]);
            if (m) out.push({ line: i, done: m[1] !== " ", text: m[2] });
        }
        return out;
    }
    function toggleReminder(lineNo) {
        var l = remFile.text().split("\n");
        if (lineNo < 0 || lineNo >= l.length) return;
        l[lineNo] = /\[ \]/.test(l[lineNo]) ? l[lineNo].replace("[ ]", "[x]") : l[lineNo].replace(/\[(x|X)\]/, "[ ]");
        remFile.setText(l.join("\n"));
        if (bar) bar.playSound("tink", 0.6);
    }
    function openFile(p) { Quickshell.execDetached(["xdg-open", p]); }

    // photos: a random picture from ~/Pictures (not screenshots / wallpapers), changes every 15 min
    property var photoList: []
    property int photoIdx: 0
    readonly property string photo: photoList.length ? photoList[photoIdx % photoList.length] : ""
    readonly property bool wantsPhotos: widgets.some(function (w) { return w.type === "photos"; })
    Process {
        running: root.loaded && root.wantsPhotos
        command: ["sh", "-c", "find -L \"$HOME/Pictures\" -maxdepth 4 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) "
            + "! -ipath '*screenshot*' ! -ipath '*/Wallpapers/*' ! -ipath '*/.cache/*' -size +60k 2>/dev/null | shuf -n 60"]
        stdout: StdioCollector { onStreamFinished: root.photoList = text.split("\n").filter(function (x) { return x !== ""; }) }
    }
    Timer { interval: 15 * 60 * 1000; repeat: true; running: root.wantsPhotos && !root.gaming; onTriggered: root.photoIdx++ }

    // media
    readonly property var player: {
        var ps = Mpris.players.values, best = null;
        for (var i = 0; i < ps.length; i++) { if (ps[i].isPlaying) return ps[i]; if (!best && ps[i].trackTitle) best = ps[i]; }
        return best;
    }

    // batteries: this Mac + anything UPower knows about (headsets, mice, keyboards…)
    readonly property var batteries: {
        var out = [], ds = UPower.devices.values;
        for (var i = 0; i < ds.length; i++) {
            var d = ds[i];
            if (!d.isPresent && !d.isLaptopBattery) continue;
            if (d.type === UPowerDeviceType.LinePower) continue;
            var p = d.percentage <= 1.0 ? d.percentage * 100 : d.percentage;
            if (!(p >= 0)) continue;
            out.push({ name: d.isLaptopBattery ? "MacBook" : (d.model || "Device"), pct: Math.round(p), laptop: d.isLaptopBattery,
                       charging: d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.FullyCharged,
                       kind: d.isLaptopBattery ? "laptop" : (/head|cloud|buds|pods|ear/i.test(d.model || "") ? "headphones" : (/mouse/i.test(d.model || "") ? "mouse" : "device")) });
        }
        out.sort(function (a, b) { return (b.laptop ? 1 : 0) - (a.laptop ? 1 : 0); });
        return out;
    }

    // ═════════════ REUSABLE PIECES ═════════════
    // Weather / device icons drawn on an 18×18 grid
    component WIcon: Canvas {
        id: wi
        property string kind: "sun"
        property color color: "white"
        property bool tinted: false         // monochrome (Tinted style)
        width: 24; height: 24
        onKindChanged: requestPaint()
        onColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"); c.reset();
            var s = Math.min(width, height) / 18; c.scale(s, s);
            var mono = wi.tinted, PI = Math.PI;
            var sunC = mono ? wi.color : "#FFD60A", cloudC = mono ? wi.color : "#F2F2F7", rainC = mono ? wi.color : "#64D2FF";
            c.lineCap = "round"; c.lineJoin = "round";
            function sun(x, y, r) {
                c.fillStyle = sunC; c.beginPath(); c.arc(x, y, r, 0, PI * 2); c.fill();
                c.strokeStyle = sunC; c.lineWidth = 1.3;
                for (var i = 0; i < 8; i++) { var a = i * PI / 4; c.beginPath(); c.moveTo(x + Math.cos(a) * (r + 1.6), y + Math.sin(a) * (r + 1.6)); c.lineTo(x + Math.cos(a) * (r + 3), y + Math.sin(a) * (r + 3)); c.stroke(); }
            }
            function moon(x, y, r) {
                c.fillStyle = mono ? wi.color : "#E5E5EA"; c.beginPath(); c.arc(x, y, r, 0, PI * 2); c.fill();
                c.globalCompositeOperation = "destination-out"; c.beginPath(); c.arc(x + r * 0.55, y - r * 0.4, r * 0.85, 0, PI * 2); c.fill();
                c.globalCompositeOperation = "source-over";
            }
            function cloud(x, y, k) {
                c.fillStyle = cloudC; c.beginPath();
                c.arc(x - 3.2 * k, y + 0.8 * k, 2.6 * k, 0, PI * 2); c.arc(x, y - 1.2 * k, 3.6 * k, 0, PI * 2); c.arc(x + 3.6 * k, y + 0.6 * k, 2.8 * k, 0, PI * 2);
                c.rect(x - 3.2 * k, y + 0.8 * k, 6.8 * k, 2.6 * k); c.fill();
            }
            var k = wi.kind;
            if (k === "sun") sun(9, 9, 3.8);
            else if (k === "moon") moon(9, 9, 5.2);
            else if (k === "partly") { sun(6.2, 6.4, 2.8); cloud(10.2, 11, 1.0); }
            else if (k === "partlynight") { moon(6.4, 6.2, 3.6); cloud(10.2, 11, 1.0); }
            else if (k === "cloud") cloud(9, 9.4, 1.15);
            else if (k === "fog") { cloud(9, 7.4, 1.0); c.strokeStyle = cloudC; c.lineWidth = 1.3; c.beginPath(); c.moveTo(3.5, 13.5); c.lineTo(14.5, 13.5); c.moveTo(5, 16); c.lineTo(13, 16); c.stroke(); }
            else if (k === "rain") { cloud(9, 7, 1.05); c.strokeStyle = rainC; c.lineWidth = 1.4; for (var i = 0; i < 3; i++) { c.beginPath(); c.moveTo(5.6 + i * 3.2, 12.2); c.lineTo(4.6 + i * 3.2, 15.6); c.stroke(); } }
            else if (k === "snow") { cloud(9, 7, 1.05); c.fillStyle = cloudC; for (var j = 0; j < 3; j++) { c.beginPath(); c.arc(5.4 + j * 3.4, 13.8 + (j % 2) * 1.6, 1.0, 0, PI * 2); c.fill(); } }
            else if (k === "storm") { cloud(9, 6.6, 1.05); c.fillStyle = sunC; c.beginPath(); c.moveTo(9.6, 10.6); c.lineTo(6.8, 14.4); c.lineTo(9, 14.4); c.lineTo(7.8, 17.4); c.lineTo(11.6, 13); c.lineTo(9.4, 13); c.lineTo(10.8, 10.6); c.closePath(); c.fill(); }
            else if (k === "laptop") { c.strokeStyle = wi.color; c.lineWidth = 1.4; c.beginPath(); c.rect(3.5, 4, 11, 7.6); c.stroke(); c.beginPath(); c.moveTo(1.5, 14); c.lineTo(16.5, 14); c.stroke(); }
            else if (k === "headphones") { c.strokeStyle = wi.color; c.lineWidth = 1.5; c.beginPath(); c.arc(9, 10, 6, PI, 0); c.stroke(); c.fillStyle = wi.color; c.fillRect(2.4, 10, 2.8, 5); c.fillRect(12.8, 10, 2.8, 5); }
            else if (k === "mouse") { c.strokeStyle = wi.color; c.lineWidth = 1.4; c.beginPath(); c.moveTo(9, 2.5); c.arcTo(14, 2.5, 14, 8, 4.5); c.arcTo(14, 15.5, 9, 15.5, 4.5); c.arcTo(4, 15.5, 4, 8, 4.5); c.arcTo(4, 2.5, 9, 2.5, 4.5); c.stroke(); c.beginPath(); c.moveTo(9, 3); c.lineTo(9, 7); c.stroke(); }
            else { c.strokeStyle = wi.color; c.lineWidth = 1.4; c.beginPath(); c.rect(3, 5, 12, 8); c.stroke(); }
        }
    }

    // analog clock face (macOS Clock widget)
    component Analog: Canvas {
        id: an
        property var time: new Date()
        property real offsetMin: 0          // other time zone: minutes from local
        property color face: "white"
        property color ink: "#1d1d1f"
        property bool glassy: false         // transparent face, light ink
        property bool showSeconds: true
        onTimeChanged: requestPaint()
        onFaceChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"); c.reset();
            var r = Math.min(width, height) / 2, cx = width / 2, cy = height / 2, PI = Math.PI;
            var t = new Date(an.time.getTime() + an.offsetMin * 60000);
            var h = t.getHours() % 12, m = t.getMinutes(), s = t.getSeconds();
            if (!an.glassy) { c.fillStyle = an.face; c.beginPath(); c.arc(cx, cy, r, 0, PI * 2); c.fill(); }
            c.strokeStyle = an.ink; c.lineCap = "round";
            for (var i = 0; i < 60; i++) {
                var a = i * PI / 30, big = i % 5 === 0;
                c.globalAlpha = big ? 0.9 : 0.35; c.lineWidth = big ? r * 0.035 : r * 0.018;
                c.beginPath(); c.moveTo(cx + Math.cos(a) * r * (big ? 0.80 : 0.86), cy + Math.sin(a) * r * (big ? 0.80 : 0.86));
                c.lineTo(cx + Math.cos(a) * r * 0.92, cy + Math.sin(a) * r * 0.92); c.stroke();
            }
            c.globalAlpha = 1;
            function hand(angle, len, w, col) { c.strokeStyle = col; c.lineWidth = w; c.beginPath(); c.moveTo(cx - Math.cos(angle) * r * 0.08, cy - Math.sin(angle) * r * 0.08); c.lineTo(cx + Math.cos(angle) * len, cy + Math.sin(angle) * len); c.stroke(); }
            hand((h + m / 60) * PI / 6 - PI / 2, r * 0.48, r * 0.075, an.ink);
            hand((m + s / 60) * PI / 30 - PI / 2, r * 0.72, r * 0.055, an.ink);
            if (an.showSeconds) hand(s * PI / 30 - PI / 2, r * 0.8, r * 0.022, "#FF9F0A");
            c.fillStyle = an.showSeconds ? "#FF9F0A" : an.ink; c.beginPath(); c.arc(cx, cy, r * 0.055, 0, PI * 2); c.fill();
            c.fillStyle = an.glassy ? "#1d1d1f" : an.face; c.beginPath(); c.arc(cx, cy, r * 0.022, 0, PI * 2); c.fill();
        }
    }

    // small line chart (Stocks)
    component Spark: Canvas {
        id: sp
        property var values: []
        property real base: 0
        property color color: "#30D158"
        onValuesChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"); c.reset();
            var v = sp.values; if (!v || v.length < 2) return;
            var lo = Math.min.apply(null, v.concat([sp.base || v[0]])), hi = Math.max.apply(null, v.concat([sp.base || v[0]])), rg = (hi - lo) || 1;
            function px(i) { return i / (v.length - 1) * width; }
            function py(x) { return height - 2 - (x - lo) / rg * (height - 4); }
            if (sp.base) { c.strokeStyle = Qt.rgba(1, 1, 1, 0.3); c.setLineDash([2, 3]); c.lineWidth = 1; c.beginPath(); c.moveTo(0, py(sp.base)); c.lineTo(width, py(sp.base)); c.stroke(); c.setLineDash([]); }
            c.strokeStyle = sp.color; c.lineWidth = 1.8; c.lineJoin = "round"; c.beginPath();
            for (var i = 0; i < v.length; i++) { if (i === 0) c.moveTo(px(i), py(v[i])); else c.lineTo(px(i), py(v[i])); }
            c.stroke();
        }
    }

    // ═════════════ WIDGET CONTENT ═════════════
    // Each content component reads `parent.ctx` (set on its Loader): { w (record), size, style, fg, fg2, mono, sname }
    Component {
        id: cClock
        Item {
            readonly property var ctx: parent ? parent.ctx : null
            readonly property bool med: ctx && ctx.size !== "s"
            // small: one big analog clock with the city; medium: World Clock (four cities)
            Item {
                visible: !parent.med
                anchors.fill: parent
                Analog {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 2; width: parent.height - 30; height: width
                    time: root.now
                    glassy: ctx && ctx.style !== "opaque"
                    face: root.dark ? "#2C2C2E" : "white"
                    ink: ctx ? ctx.fg : "white"
                }
                Text {
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    text: root.geo.city || "Local"
                    color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold
                }
            }
            Row {
                visible: parent.med
                anchors.centerIn: parent
                spacing: 14
                Repeater {
                    model: [ { c: root.geo.city || "Local", o: 0 }, { c: "London", tz: 60 }, { c: "New York", tz: -240 }, { c: "Tokyo", tz: 540 } ]
                    delegate: Column {
                        required property var modelData
                        spacing: 6
                        // offset from local time using the local UTC offset (minutes)
                        readonly property real off: modelData.tz === undefined ? 0 : modelData.tz + root.now.getTimezoneOffset()
                        Analog {
                            width: 66; height: 66
                            time: root.now
                            offsetMin: parent.off
                            showSeconds: false
                            glassy: ctx && ctx.style !== "opaque"
                            face: root.dark ? "#2C2C2E" : "white"
                            ink: ctx ? ctx.fg : "white"
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.c; color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 11; font.weight: Font.DemiBold; width: 70; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            readonly property var t: new Date(root.now.getTime() + parent.off * 60000)
                            text: (t.getDate() === root.now.getDate() ? "Today" : (t > root.now ? "Tomorrow" : "Yesterday"))
                            color: ctx ? ctx.fg2 : "white"; font.family: root.fam; font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cCalendar
        Item {
            readonly property var ctx: parent ? parent.ctx : null
            readonly property string sz: ctx ? ctx.size : "s"
            readonly property color red: ctx && ctx.mono ? ctx.fg : "#FF453A"
            readonly property bool monday: root.bar ? root.bar.weekStartsMonday : false
            function cells(d) {
                var y = d.getFullYear(), m = d.getMonth(), first = new Date(y, m, 1), shift = (first.getDay() - (monday ? 1 : 0) + 7) % 7, out = [];
                for (var i = 0; i < 42; i++) { var x = new Date(y, m, 1 - shift + i); out.push({ n: x.getDate(), cur: x.getMonth() === m, today: x.toDateString() === root.now.toDateString() }); }
                if (!out[35].cur) out = out.slice(0, 35);
                return out;
            }
            readonly property var heads: monday ? ["M", "T", "W", "T", "F", "S", "S"] : ["S", "M", "T", "W", "T", "F", "S"]
            // today block (small, and the left half of medium)
            Column {
                visible: sz !== "l"
                width: sz === "m" ? 128 : parent.width
                spacing: 0
                Text { text: Qt.formatDate(root.now, "dddd").toUpperCase(); color: red; font.family: root.fam; font.pixelSize: 12; font.weight: Font.Bold }
                Text { text: root.now.getDate(); color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 56; font.weight: Font.Light; topPadding: -4 }
                Text { text: Qt.formatDate(root.now, "MMMM yyyy"); color: ctx ? ctx.fg2 : "white"; font.family: root.fam; font.pixelSize: 12; topPadding: 6 }
                Text { text: "No events today"; color: ctx ? ctx.fg2 : "white"; font.family: root.fam; font.pixelSize: 12; topPadding: 2 }
            }
            // month grid (medium: right half, large: whole widget)
            Column {
                visible: sz !== "s"
                x: sz === "m" ? 140 : 0
                width: parent.width - x
                spacing: sz === "l" ? 8 : 2
                Text { visible: sz === "l"; text: Qt.formatDate(root.now, "MMMM").toUpperCase(); color: red; font.family: root.fam; font.pixelSize: 14; font.weight: Font.Bold }
                Grid {
                    columns: 7
                    readonly property real cw: parent.width / 7
                    readonly property real ch: sz === "l" ? 40 : 19
                    Repeater {
                        model: parent.parent.parent.heads
                        delegate: Text { required property var modelData; width: parent.cw; height: sz === "l" ? 24 : 16; horizontalAlignment: Text.AlignHCenter; text: modelData; color: ctx ? ctx.fg2 : "white"; font.family: root.fam; font.pixelSize: sz === "l" ? 12 : 9; font.weight: Font.DemiBold }
                    }
                    Repeater {
                        model: parent.parent.parent.cells(root.now)
                        delegate: Item {
                            required property var modelData
                            width: parent.cw; height: parent.ch
                            Rectangle { anchors.centerIn: parent; visible: modelData.today; width: Math.min(parent.width, parent.height) - 1; height: width; radius: width / 2; color: red }
                            Text { anchors.centerIn: parent; text: modelData.n; color: modelData.today ? "white" : (ctx ? ctx.fg : "white"); opacity: modelData.cur ? 1 : 0.32
                                   font.family: root.fam; font.pixelSize: sz === "l" ? 15 : 10; font.weight: modelData.today ? Font.Bold : Font.Normal }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cWeather
        Item {
            readonly property var ctx: parent ? parent.ctx : null
            readonly property string sz: ctx ? ctx.size : "s"
            readonly property var wx: root.weather
            readonly property var cur: wx ? root.wmo(wx.current.weather_code, wx.current.is_day) : ["Loading…", "cloud"]
            function deg(v) { return v === undefined || v === null ? "--" : Math.round(v) + "°"; }
            Column {
                width: sz === "m" ? parent.width * 0.42 : parent.width
                spacing: 0
                Row {
                    spacing: 4
                    Text { text: root.geo.city || "Weather"; color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { text: "➤"; rotation: -45; color: ctx ? ctx.fg : "white"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                }
                Text { text: wx ? deg(wx.current.temperature_2m) : "--"; color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: sz === "l" ? 50 : 42; font.weight: Font.Light; topPadding: -2 }
            }
            // condition + high/low
            Column {
                y: sz === "s" ? parent.height - height : (sz === "m" ? parent.height - height : 78)
                x: sz === "l" ? parent.width - width : 0
                width: sz === "m" ? parent.width * 0.42 : implicitWidth
                spacing: 2
                WIcon { kind: cur[1]; width: 22; height: 22; tinted: ctx && ctx.mono; color: ctx ? ctx.fg : "white" }
                Text { text: cur[0]; color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold }
                Text { text: wx ? "H:" + deg(wx.daily.temperature_2m_max[0]) + " L:" + deg(wx.daily.temperature_2m_min[0]) : ""; color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 12 }
            }
            // hourly (medium: right side, large: middle row)
            Row {
                visible: sz !== "s" && wx !== null
                x: sz === "m" ? parent.width * 0.42 : 0
                y: sz === "m" ? parent.height - height - 2 : 136
                width: parent.width - x
                Repeater {
                    model: wx ? Math.min(6, wx.hourly.time.length) : 0
                    delegate: Column {
                        required property int index
                        width: (parent.width) / 6
                        spacing: 6
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: index === 0 ? "Now" : Qt.formatTime(new Date(wx.hourly.time[index]), "H"); color: ctx ? ctx.fg2 : "white"; font.family: root.fam; font.pixelSize: 11; font.weight: Font.DemiBold }
                        WIcon { anchors.horizontalCenter: parent.horizontalCenter; width: 20; height: 20; kind: root.wmo(wx.hourly.weather_code[index], wx.hourly.is_day[index])[1]; tinted: ctx && ctx.mono; color: ctx ? ctx.fg : "white" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: deg(wx.hourly.temperature_2m[index]); color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold }
                    }
                }
            }
            // 5-day (large)
            Column {
                visible: sz === "l" && wx !== null
                y: 214; width: parent.width
                spacing: 4
                readonly property real lo: wx ? Math.min.apply(null, wx.daily.temperature_2m_min.slice(0, 5)) : 0
                readonly property real hi: wx ? Math.max.apply(null, wx.daily.temperature_2m_max.slice(0, 5)) : 1
                Rectangle { width: parent.width; height: 1; color: ctx ? ctx.fg2 : "white"; opacity: 0.3 }
                Repeater {
                    model: wx ? 5 : 0
                    delegate: Item {
                        required property int index
                        width: parent.width; height: 21
                        readonly property real mn: wx.daily.temperature_2m_min[index]
                        readonly property real mx: wx.daily.temperature_2m_max[index]
                        Text { width: 46; anchors.verticalCenter: parent.verticalCenter; text: index === 0 ? "Today" : Qt.formatDate(new Date(wx.daily.time[index]), "ddd"); color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold }
                        WIcon { x: 52; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; kind: root.wmo(wx.daily.weather_code[index], 1)[1]; tinted: ctx && ctx.mono; color: ctx ? ctx.fg : "white" }
                        Text { x: 82; width: 34; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: deg(mn); color: ctx ? ctx.fg2 : "white"; font.family: root.fam; font.pixelSize: 13 }
                        Rectangle {
                            x: 124; width: parent.width - 124 - 44; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(1, 1, 1, 0.18)
                            readonly property real rg: (parent.parent.hi - parent.parent.lo) || 1
                            Rectangle {
                                x: (mn - parent.parent.parent.lo) / parent.rg * parent.width
                                width: Math.max(6, (mx - mn) / parent.rg * parent.width); height: 4; radius: 2
                                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: ctx && ctx.mono ? ctx.fg : "#FFD60A" } GradientStop { position: 1; color: ctx && ctx.mono ? ctx.fg : "#FF9F0A" } }
                            }
                        }
                        Text { anchors.right: parent.right; width: 36; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: deg(mx); color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold }
                    }
                }
            }
        }
    }

    Component {
        id: cBatteries
        Item {
            readonly property var ctx: parent ? parent.ctx : null
            readonly property bool med: ctx && ctx.size !== "s"
            readonly property var list: root.batteries
            function ringColor(b) { return ctx && ctx.mono ? ctx.fg : (b.pct <= 20 && !b.charging ? "#FF453A" : "#30D158"); }
            // small: up to four rings
            Grid {
                visible: !parent.med
                anchors.centerIn: parent
                columns: 2; spacing: 14
                Repeater {
                    model: Math.max(1, Math.min(4, list.length))
                    delegate: Item {
                        required property int index
                        readonly property var b: list[index]
                        width: 58; height: 58
                        Canvas {
                            anchors.fill: parent
                            property real pct: b ? b.pct : 0
                            property color col: b ? ringColor(b) : "gray"
                            onPctChanged: requestPaint(); onColChanged: requestPaint()
                            onPaint: {
                                var c = getContext("2d"); c.reset(); var r = width / 2 - 3;
                                c.lineWidth = 5; c.lineCap = "round";
                                c.strokeStyle = Qt.rgba(1, 1, 1, 0.16); c.beginPath(); c.arc(width / 2, height / 2, r, 0, Math.PI * 2); c.stroke();
                                c.strokeStyle = col; c.beginPath(); c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * pct / 100); c.stroke();
                            }
                        }
                        WIcon { anchors.centerIn: parent; width: 22; height: 22; kind: b ? b.kind : "laptop"; color: ctx ? ctx.fg : "white"; tinted: true }
                        Text { visible: !!(b && b.charging); anchors.top: parent.top; anchors.right: parent.right; text: "⚡"; color: ctx && ctx.mono ? ctx.fg : "#30D158"; font.pixelSize: 11 }
                    }
                }
            }
            // medium: list rows
            Column {
                visible: parent.med
                anchors.fill: parent
                spacing: 8
                Repeater {
                    model: Math.min(4, list.length)
                    delegate: Item {
                        required property int index
                        readonly property var b: list[index]
                        width: parent.width; height: 26
                        WIcon { anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; kind: b.kind; color: ctx ? ctx.fg : "white"; tinted: true }
                        Text { x: 32; anchors.verticalCenter: parent.verticalCenter; width: 110; elide: Text.ElideRight; text: b.name; color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Rectangle {
                            x: 150; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 150 - 54; height: 7; radius: 3.5; color: Qt.rgba(1, 1, 1, 0.16)
                            Rectangle { width: parent.width * b.pct / 100; height: parent.height; radius: 3.5; color: ringColor(b) }
                        }
                        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: (b.charging ? "⚡" : "") + b.pct + "%"; color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold }
                    }
                }
            }
        }
    }

    Component {
        id: cMusic
        Item {
            id: mus
            readonly property var ctx: parent ? parent.ctx : null
            readonly property bool med: ctx && ctx.size !== "s"
            readonly property bool big: ctx && ctx.size === "l"
            readonly property var pl: root.player
            readonly property color fg: ctx ? ctx.fg : "white"
            readonly property color fg2: ctx ? ctx.fg2 : "white"

            // ── cover with the "burning paper" hand-over (burn.frag): two picture slots, the new one shows through
            //    ragged spreading holes in the old one ──
            readonly property string url: pl && pl.trackArtUrl ? pl.trackArtUrl : ""
            property int curIdx: 0          // slot showing the current cover
            property real prog: 1
            property real seed: 0
            property bool pending: false
            onUrlChanged: {
                var target = 1 - curIdx;
                (target === 0 ? imgA : imgB).source = url;
                pending = true;
                tryStart();
            }
            Component.onCompleted: { imgA.source = url; }
            function tryStart() {
                if (!pending) return;
                var t = (curIdx === 0 ? imgB : imgA);
                if (t.status === Image.Loading) return;      // wait for it
                pending = false;
                curIdx = 1 - curIdx;
                seed = Math.random();
                burnAnim.restart();
            }
            NumberAnimation { id: burnAnim; target: mus; property: "prog"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

            // layout targets per size (content area: S 138×138, M 324×138, L 324×324); every element glides to its
            // new spot / size in step with the card (same 420 ms ease-out), so resizing is one continuous morph
            readonly property string sz: ctx ? ctx.size : "m"
            readonly property int morphMs: 420
            readonly property real artW: sz === "l" ? 200 : (sz === "m" ? 138 : 64)
            readonly property real artX: sz === "l" ? 62 : 0
            Item {
                id: mArt
                width: mus.artW; height: width
                x: mus.artX
                Behavior on width { NumberAnimation { duration: mus.morphMs; easing.type: Easing.OutQuint } }
                Behavior on x { NumberAnimation { duration: mus.morphMs; easing.type: Easing.OutQuint } }
                scale: artTap.pressed ? 0.95 : 1
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                Rectangle { anchors.fill: parent; radius: 10; color: Qt.rgba(1, 1, 1, 0.12) }
                Image { id: imgA; anchors.fill: parent; visible: false; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(300, 300); onStatusChanged: mus.tryStart() }
                Image { id: imgB; anchors.fill: parent; visible: false; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(300, 300); onStatusChanged: mus.tryStart() }
                ShaderEffectSource { id: srcA; sourceItem: imgA; hideSource: true; visible: false; smooth: true }
                ShaderEffectSource { id: srcB; sourceItem: imgB; hideSource: true; visible: false; smooth: true }
                ShaderEffect {
                    anchors.fill: parent
                    visible: mus.url !== "" || mus.prog < 1
                    fragmentShader: Qt.resolvedUrl("burn.frag.qsb")
                    property variant oldTex: mus.curIdx === 0 ? srcB : srcA
                    property variant newTex: mus.curIdx === 0 ? srcA : srcB
                    property real progress: mus.prog
                    property vector2d itemSize: Qt.vector2d(width, height)
                    property real radius: 10 + 4 * Math.max(0, Math.min(1, (mArt.width - 138) / 62))
                    property real seed: mus.seed
                }
                // nothing playing: like macOS, the Music app icon (MacTahoe icon theme, Apple Music style) on a soft tile
                Item {
                    anchors.fill: parent
                    opacity: mus.url === "" ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    Rectangle { anchors.fill: parent; radius: mus.big ? 14 : 10; color: Qt.rgba(1, 1, 1, 0.08); border.width: 0.5; border.color: Qt.rgba(1, 1, 1, 0.14) }
                    Image {
                        anchors.centerIn: parent
                        width: Math.round(parent.width * 0.62); height: width
                        source: Qt.resolvedUrl("assets/music-app.svg")
                        sourceSize: Qt.size(256, 256)
                        smooth: true; mipmap: true
                    }
                }
                MouseArea { id: artTap; anchors.fill: parent; enabled: !root.editing && mus.pl !== null; onClicked: { if (mus.pl && mus.pl.canRaise) mus.pl.raise(); } }
            }
            // title / artist: blur + morph
            Column {
                // title + artist travel to their new place and re-align (left ↔ centred) as they go
                x: mus.sz === "m" ? 152 : 0
                y: mus.sz === "l" ? 212 : (mus.sz === "m" ? 4 : 74)
                width: mus.sz === "m" ? 172 : (mus.sz === "l" ? 324 : 138)
                Behavior on x { NumberAnimation { duration: mus.morphMs; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: mus.morphMs; easing.type: Easing.OutQuint } }
                Behavior on width { NumberAnimation { duration: mus.morphMs; easing.type: Easing.OutQuint } }
                spacing: 1
                MorphText { width: parent.width; elide: Text.ElideRight; animateWidth: false; duration: 460; horizontalAlignment: mus.big ? Text.AlignHCenter : Text.AlignLeft
                            text: mus.pl ? (mus.pl.trackTitle || "") : "Not Playing"; color: mus.fg; font.family: root.fam; font.pixelSize: mus.big ? 15 : 13; font.weight: Font.DemiBold }
                MorphText { width: parent.width; elide: Text.ElideRight; animateWidth: false; duration: 460; horizontalAlignment: mus.big ? Text.AlignHCenter : Text.AlignLeft
                            text: mus.pl ? (mus.pl.trackArtist || mus.pl.identity || "") : "Music"; color: mus.fg2; font.family: root.fam; font.pixelSize: mus.big ? 13 : 12 }
            }
            // Large: progress bar with times
            Item {
                // progress bar: slides up into place and fades in on Large, out again when it shrinks
                opacity: mus.sz === "l" ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: mus.morphMs; easing.type: Easing.OutQuint } }
                y: mus.sz === "l" ? 256 : 290
                Behavior on y { NumberAnimation { duration: mus.morphMs; easing.type: Easing.OutQuint } }
                width: parent.width; height: 14
                readonly property real len: mus.pl && mus.pl.lengthSupported ? mus.pl.length : 0
                property real pos: 0
                function fmt(v) { v = Math.max(0, Math.floor(v)); var m = Math.floor(v / 60), r = v % 60; return m + ":" + (r < 10 ? "0" : "") + r; }
                Timer {
                    interval: 1000; repeat: true; triggeredOnStart: true
                    running: mus.big && mus.pl !== null && !root.gaming
                    onTriggered: { if (mus.pl && mus.pl.positionSupported) { mus.pl.positionChanged(); parent.pos = mus.pl.position; } }
                }
                Text { id: pL; anchors.verticalCenter: parent.verticalCenter; text: parent.fmt(parent.pos); color: mus.fg2; font.family: root.fam; font.pixelSize: 10 }
                Text { id: pR; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: parent.len > 0 ? "-" + parent.fmt(parent.len - parent.pos) : ""; color: mus.fg2; font.family: root.fam; font.pixelSize: 10 }
                Rectangle {
                    anchors.left: pL.right; anchors.right: pR.left; anchors.leftMargin: 8; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.2)
                    Rectangle {
                        height: 4; radius: 2; color: mus.fg
                        width: parent.parent.len > 0 ? parent.width * Math.min(1, parent.parent.pos / parent.parent.len) : 0
                        Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
                    }
                }
            }
            // controls: morphing icons, squish on press
            Row {
                id: ctlRow
                anchors.bottom: parent.bottom
                readonly property real fullW: 3 * 30 + 2 * spacing
                x: mus.sz === "l" ? (324 - fullW) / 2 : (mus.sz === "m" ? 146 : 138 - 30 + 4)
                spacing: mus.sz === "l" ? 34 : (mus.sz === "m" ? 18 : 0)
                Behavior on x { NumberAnimation { duration: mus.morphMs; easing.type: Easing.OutQuint } }
                Behavior on spacing { NumberAnimation { duration: mus.morphMs; easing.type: Easing.OutQuint } }
                Repeater {
                    model: ["prev", "play", "next"]
                    delegate: Item {
                        id: cb
                        required property string modelData
                        readonly property bool shown: modelData === "play" || mus.sz !== "s"
                        width: shown ? 30 : 0; height: 30
                        opacity: shown ? 1 : 0
                        scale: shown ? 1 : 0.5
                        Behavior on width { NumberAnimation { duration: mus.morphMs; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: mus.morphMs; easing.type: Easing.OutQuint } }
                        Behavior on scale { NumberAnimation { duration: mus.morphMs; easing.type: Easing.OutQuint } }
                        Rectangle {
                            anchors.centerIn: parent; width: 32; height: 32; radius: 16
                            color: Qt.rgba(1, 1, 1, cbMa.pressed ? 0.18 : 0.10)
                            opacity: cbMa.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }
                        // skip motion: the arrows shoot out in their direction and slide back in from the other side
                        property real shift: 0
                        property real shiftOp: 1
                        SequentialAnimation {
                            id: skipAnim
                            readonly property real dir: cb.modelData === "prev" ? -1 : 1
                            ParallelAnimation {
                                NumberAnimation { target: cb; property: "shift"; to: 14 * skipAnim.dir; duration: 160; easing.type: Easing.InCubic }
                                NumberAnimation { target: cb; property: "shiftOp"; to: 0; duration: 160; easing.type: Easing.InCubic }
                            }
                            PropertyAction { target: cb; property: "shift"; value: -14 * skipAnim.dir }
                            ParallelAnimation {
                                NumberAnimation { target: cb; property: "shift"; to: 0; duration: 360; easing.type: Easing.OutQuint }
                                NumberAnimation { target: cb; property: "shiftOp"; to: 1; duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                        MorphGlyph {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: cb.shift
                            opacity: cb.shiftOp
                            width: cb.modelData === "play" ? 20 : 17; height: width
                            kind: cb.modelData === "play" ? (mus.pl && mus.pl.isPlaying ? "pause" : "play") : cb.modelData
                            color: mus.fg
                            scale: cbMa.pressed ? 0.8 : 1
                            Behavior on scale { NumberAnimation { duration: cbMa.pressed ? 120 : 380; easing.type: Easing.OutQuint } }
                        }
                        MouseArea {
                            id: cbMa
                            anchors.fill: parent; anchors.margins: -3
                            hoverEnabled: true
                            enabled: mus.pl !== null && !root.editing
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (cb.modelData === "prev") { skipAnim.restart(); mus.pl.previous(); }
                                else if (cb.modelData === "next") { skipAnim.restart(); mus.pl.next(); }
                                else mus.pl.togglePlaying();
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cNotes
        Item {
            readonly property var ctx: parent ? parent.ctx : null
            Row {
                id: nHead
                spacing: 6
                Rectangle { width: 18; height: 18; radius: 5; color: ctx && ctx.mono ? ctx.fg : "#FFD60A"; anchors.verticalCenter: parent.verticalCenter
                            Rectangle { x: 3; y: 4; width: 12; height: 1.6; color: ctx && ctx.mono ? root.accent : "white" } }
                Text { text: "Notes"; color: ctx && ctx.mono ? ctx.fg : "#FFD60A"; font.family: root.fam; font.pixelSize: 14; font.weight: Font.Bold }
            }
            Text {
                y: nHead.height + 8
                width: parent.width; height: parent.height - y
                clip: true
                text: root.notesText.replace(/^#+\s*/gm, "")
                wrapMode: Text.Wrap; elide: Text.ElideRight
                color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 13; lineHeight: 1.12
            }
            MouseArea { anchors.fill: parent; enabled: !root.editing; cursorShape: Qt.PointingHandCursor; onClicked: root.openFile(root.cfgDir + "/notes.md") }
        }
    }

    Component {
        id: cPhotos
        Item {
            readonly property var ctx: parent ? parent.ctx : null
            // full bleed: the photo fills the widget (the Loader for photos has no margins)
            Item { id: pMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: 22; color: "black" } }
            Image {
                id: pImg
                anchors.fill: parent
                source: root.photo !== "" ? "file://" + root.photo : ""
                fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                sourceSize: Qt.size(720, 720)
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 700 } }
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: pMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 54; radius: 22
                gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) } }
            }
            Text {
                x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                text: root.photoList.length ? "Featured Photo" : "Add pictures to ~/Pictures"
                color: "white"; font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold
            }
            MouseArea { anchors.fill: parent; enabled: !root.editing && root.photo !== ""; cursorShape: Qt.PointingHandCursor
                        onClicked: root.openFile(root.photo); onDoubleClicked: root.photoIdx++ }
        }
    }

    Component {
        id: cReminders
        Item {
            readonly property var ctx: parent ? parent.ctx : null
            readonly property var open: root.reminders.filter(function (r) { return !r.done; })
            readonly property color blue: ctx && ctx.mono ? ctx.fg : "#0A84FF"
            Row {
                id: rHead
                width: parent.width
                Text { width: parent.width - cnt.width; text: "Reminders"; color: blue; font.family: root.fam; font.pixelSize: 14; font.weight: Font.Bold }
                Text { id: cnt; text: parent.parent.open.length; color: blue; font.family: root.fam; font.pixelSize: 22; font.weight: Font.Bold }
            }
            Column {
                y: rHead.height + 6
                width: parent.width
                spacing: 7
                clip: true
                height: parent.height - y
                Repeater {
                    model: root.reminders
                    delegate: Row {
                        required property var modelData
                        spacing: 8
                        width: parent.width
                        Rectangle {
                            width: 16; height: 16; radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.done ? blue : "transparent"
                            border.width: 1.5; border.color: modelData.done ? blue : (ctx ? ctx.fg2 : "white")
                            Text { anchors.centerIn: parent; visible: modelData.done; text: "✓"; color: "white"; font.pixelSize: 10; font.bold: true }
                            MouseArea { anchors.fill: parent; anchors.margins: -4; enabled: !root.editing; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleReminder(modelData.line) }
                        }
                        Text {
                            width: parent.width - 24; elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text; font.strikeout: modelData.done
                            color: ctx ? (modelData.done ? ctx.fg2 : ctx.fg) : "white"
                            font.family: root.fam; font.pixelSize: 13
                        }
                    }
                }
            }
            MouseArea { anchors.fill: rHead; enabled: !root.editing; cursorShape: Qt.PointingHandCursor; onClicked: root.openFile(root.cfgDir + "/reminders.md") }
        }
    }

    Component {
        id: cStocks
        Item {
            readonly property var ctx: parent ? parent.ctx : null
            readonly property bool med: ctx && ctx.size !== "s"
            readonly property var syms: root.stockSymbols
            function chg(q) { return q && q.pc ? (q.p - q.pc) / q.pc * 100 : 0; }
            function col(q) { return ctx && ctx.mono ? ctx.fg : (chg(q) >= 0 ? "#30D158" : "#FF453A"); }
            // small: first symbol, big
            Column {
                visible: !parent.med
                anchors.fill: parent
                spacing: 2
                readonly property var q: root.stocks[syms[0]]
                Text { text: syms[0]; color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 16; font.weight: Font.Bold }
                Text { width: parent.width; elide: Text.ElideRight; text: parent.q ? parent.q.name : "Loading…"; color: ctx ? ctx.fg2 : "white"; font.family: root.fam; font.pixelSize: 11 }
                Spark { width: parent.width; height: 52; values: parent.q ? parent.q.c : []; base: parent.q ? parent.q.pc : 0; color: parent.parent.col(parent.q) }
                Text { text: parent.q ? parent.q.p.toFixed(2) : "--"; color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 18; font.weight: Font.DemiBold }
                Text { text: parent.q ? (parent.parent.chg(parent.q) >= 0 ? "+" : "") + parent.parent.chg(parent.q).toFixed(2) + "%" : ""; color: parent.parent.col(parent.q); font.family: root.fam; font.pixelSize: 12; font.weight: Font.DemiBold }
            }
            // medium: watchlist
            Column {
                visible: parent.med
                anchors.fill: parent
                spacing: 4
                Repeater {
                    model: Math.min(4, syms.length)
                    delegate: Item {
                        required property int index
                        readonly property var q: root.stocks[syms[index]]
                        width: parent.width; height: 32
                        Column {
                            width: 110; anchors.verticalCenter: parent.verticalCenter
                            Text { text: syms[index]; color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 13; font.weight: Font.Bold }
                            Text { width: 110; elide: Text.ElideRight; text: q ? q.name : ""; color: ctx ? ctx.fg2 : "white"; font.family: root.fam; font.pixelSize: 10 }
                        }
                        Spark { x: 118; width: parent.width - 118 - 96; height: 24; anchors.verticalCenter: parent.verticalCenter; values: q ? q.c : []; base: q ? q.pc : 0; color: col(q) }
                        Column {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            Text { anchors.right: parent.right; text: q ? q.p.toFixed(2) : "--"; color: ctx ? ctx.fg : "white"; font.family: root.fam; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Rectangle {
                                anchors.right: parent.right; width: pct.implicitWidth + 10; height: 16; radius: 4; color: col(q)
                                Text { id: pct; anchors.centerIn: parent; text: q ? (chg(q) >= 0 ? "+" : "") + chg(q).toFixed(2) + "%" : ""; color: ctx && ctx.mono ? root.accent : "white"; font.family: root.fam; font.pixelSize: 10; font.weight: Font.Bold }
                            }
                        }
                    }
                }
            }
        }
    }

    // Large Weather, laid out like macOS: city + big temperature | condition + H/L, hourly row, 5-day list with range bars
    Component {
        id: cWeatherL
        Item {
            readonly property var ctx: parent ? parent.ctx : null
            readonly property var wx: root.weather
            readonly property var cur: wx ? root.wmo(wx.current.weather_code, wx.current.is_day) : ["Loading…", "cloud"]
            readonly property color fg: ctx ? ctx.fg : "white"
            readonly property color fg2: ctx ? ctx.fg2 : Qt.rgba(1, 1, 1, 0.62)
            function deg(v) { return v === undefined || v === null ? "--" : Math.round(v) + "°"; }
            function hourLabel(t) {
                var d = new Date(t), h = d.getHours();
                if (root.bar && root.bar.use24h) return h + "";
                return ((h % 12) || 12) + (h < 12 ? "AM" : "PM");
            }
            // header
            Column {
                x: 2; y: 0
                spacing: -2
                Row {
                    spacing: 6
                    Text { text: root.geo.city || "Weather"; color: fg; font.family: root.fam; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text { text: "➤"; rotation: -45; color: fg; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
                Text { text: wx ? deg(wx.current.temperature_2m) : "--"; color: fg; font.family: root.fam; font.pixelSize: 46; font.weight: Font.Light }
            }
            Column {
                anchors.right: parent.right; anchors.rightMargin: 2
                y: 30
                spacing: 2
                Text { anchors.right: parent.right; text: cur[0]; color: fg; font.family: root.fam; font.pixelSize: 14; font.weight: Font.DemiBold }
                Text { anchors.right: parent.right; text: wx ? "H:" + deg(wx.daily.temperature_2m_max[0]) + " L:" + deg(wx.daily.temperature_2m_min[0]) : ""; color: fg; font.family: root.fam; font.pixelSize: 14 }
            }
            // hourly
            Rectangle { y: 98; width: parent.width; height: 1; color: fg; opacity: 0.22 }
            Row {
                y: 106; width: parent.width
                Repeater {
                    model: wx ? Math.min(6, wx.hourly.time.length) : 0
                    delegate: Column {
                        required property int index
                        width: parent.width / 6
                        spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: index === 0 ? "Now" : hourLabel(wx.hourly.time[index]); color: fg; font.family: root.fam; font.pixelSize: 12 }
                        WIcon { anchors.horizontalCenter: parent.horizontalCenter; width: 18; height: 18; kind: root.wmo(wx.hourly.weather_code[index], wx.hourly.is_day[index])[1]; tinted: ctx && ctx.mono; color: fg }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: deg(wx.hourly.temperature_2m[index]); color: fg; font.family: root.fam; font.pixelSize: 16 }
                    }
                }
            }
            Rectangle { y: 170; width: parent.width; height: 1; color: fg; opacity: 0.22 }
            // 5 days
            Column {
                y: 176; width: parent.width
                readonly property real lo: wx ? Math.min.apply(null, wx.daily.temperature_2m_min.slice(0, 5)) : 0
                readonly property real hi: wx ? Math.max.apply(null, wx.daily.temperature_2m_max.slice(0, 5)) : 1
                Repeater {
                    model: wx ? 5 : 0
                    delegate: Item {
                        required property int index
                        width: parent.width; height: 29
                        readonly property real mn: wx.daily.temperature_2m_min[index]
                        readonly property real mx: wx.daily.temperature_2m_max[index]
                        Text { x: 2; width: 60; anchors.verticalCenter: parent.verticalCenter; text: index === 0 ? "Today" : Qt.formatDate(new Date(wx.daily.time[index]), "ddd"); color: fg; font.family: root.fam; font.pixelSize: 15 }
                        WIcon { x: 78; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; kind: root.wmo(wx.daily.weather_code[index], 1)[1]; tinted: ctx && ctx.mono; color: fg }
                        Text { x: 110; width: 34; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: deg(mn); color: fg2; font.family: root.fam; font.pixelSize: 15 }
                        Rectangle {
                            x: 154; width: parent.width - 154 - 46; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(1, 1, 1, 0.22)
                            readonly property real rg: (parent.parent.hi - parent.parent.lo) || 1
                            Rectangle {
                                x: (mn - parent.parent.parent.lo) / parent.rg * parent.width
                                width: Math.max(6, (mx - mn) / parent.rg * parent.width); height: 4; radius: 2
                                color: fg
                            }
                        }
                        Text { anchors.right: parent.right; anchors.rightMargin: 2; width: 40; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: deg(mx); color: fg; font.family: root.fam; font.pixelSize: 15 }
                    }
                }
            }
        }
    }

    function compFor(type, size) {
        switch (type) {
        case "clock": return cClock;
        case "calendar": return cCalendar;
        case "weather": return size === "l" ? cWeatherL : cWeather;
        case "batteries": return cBatteries;
        case "music": return cMusic;
        case "notes": return cNotes;
        case "photos": return cPhotos;
        case "reminders": return cReminders;
        case "stocks": return cStocks;
        }
        return null;
    }

    // ═════════════ ONE DESKTOP LAYER PER SCREEN ═════════════
    Variants {
        model: (root.loaded && root.enabled) ? Quickshell.screens : []
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property string sname: modelData.name
            readonly property var mine: root.widgets.filter(function (w) { return root.screenOf(w) === win.sname; })
            visible: mine.length > 0 || root.editing
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: root.editing ? WlrLayer.Top : WlrLayer.Bottom
            WlrLayershell.namespace: "macwidgets"
            WlrLayershell.keyboardFocus: root.editing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // input only where the widgets are (the rest of the desktop stays clickable); everywhere while editing
            Variants {
                id: maskRegs
                model: win.mine
                Region {
                    required property var modelData
                    readonly property var d: root.dims(modelData.size)
                    x: modelData.x; y: modelData.y; width: d.w; height: d.h
                }
            }
            mask: Region { item: root.editing ? win.contentItem : null; regions: root.editing ? [] : maskRegs.instances }

            // ── backdrop: the wallpaper this screen shows, pre-blurred once (the glass/frosted styles refract it) ──
            Item {
                id: wallLayer
                anchors.fill: parent
                Rectangle { anchors.fill: parent; color: "#101014" }
                Image {
                    id: wallImg
                    anchors.fill: parent
                    source: root.dock ? root.dock.fileUrl(root.dock.wallpaperFor(win.sname)) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: win.width
                    onStatusChanged: if (status === Image.Ready) wallTex.scheduleUpdate()
                }
                // live wallpaper: the small animated copy, stretched to the screen (it's blurred by the glass anyway);
                // paused while windows cover this desktop, in Game Mode, or when this screen has no widgets
                Loader {
                    id: liveWall
                    anchors.fill: parent
                    active: root.glassAnim !== "" && win.mine.length > 0
                    sourceComponent: AnimatedImage {
                        source: "file://" + root.glassAnim
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true; cache: false; smooth: false
                        playing: !root.gaming && !(root.bar && root.bar.wallPaused[win.sname] === true)
                    }
                }
            }
            // live wallpaper: refresh the glass's copy 8 times a second (plenty for a blurred refraction, far cheaper than per frame)
            Timer {
                interval: 125; repeat: true
                running: liveWall.active && liveWall.item && liveWall.item.playing
                onTriggered: wallTex.scheduleUpdate()
            }
            ShaderEffectSource {
                id: wallTex
                sourceItem: wallLayer
                hideSource: true
                live: false                            // captured once for a picture; a live wallpaper is re-captured 8×/s (below)
                visible: false
                // full resolution for a picture (crisp glass); half for a live wallpaper (it's a 480 px source anyway)
                textureSize: liveWall.active ? Qt.size(Math.max(1, Math.round(win.width / 2)), Math.max(1, Math.round(win.height / 2)))
                                             : Qt.size(Math.max(1, win.width), Math.max(1, win.height))
            }
            MultiEffect {
                id: wallBlurFx
                source: wallTex
                width: wallTex.textureSize.width; height: wallTex.textureSize.height
                blurEnabled: true; blurMax: 64; blur: 0.25 + root.blurAmt * 0.75
                autoPaddingEnabled: false
                visible: false
            }
            ShaderEffectSource { id: wallBlur; sourceItem: wallBlurFx; live: true; mipmap: true; visible: false }
            // Liquid Glass refracts a nearly clear copy (light ~5 px blur): real glass bends the wallpaper, it doesn't fog it
            MultiEffect {
                id: wallClearFx
                source: wallTex
                width: wallTex.textureSize.width; height: wallTex.textureSize.height
                // slider: Clear → (middle = the default look) → very blurred
                blurEnabled: true; blurMax: 64
                blur: root.blurAmt <= 0.5 ? 0.02 + root.blurAmt * 0.16 : 0.10 + (root.blurAmt - 0.5) * 1.8
                autoPaddingEnabled: false
                visible: false
            }
            ShaderEffectSource { id: wallClear; sourceItem: wallClearFx; live: true; mipmap: true; visible: false }

            // dim the desktop a little while editing (like macOS)
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.editing ? 0.28 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 260 } }
                MouseArea { anchors.fill: parent; enabled: root.editing; onClicked: root.selected = "" }
            }

            Repeater {
                model: wmodel
                delegate: Item {
                    id: wd
                    required property string wid
                    required property string wtype
                    required property string wsize
                    required property string wscreen
                    required property string wstyle
                    required property real wx
                    required property real wy
                    // same shape the rest of the code (and the content components) read
                    readonly property var modelData: ({ id: wid, type: wtype, size: wsize, x: wx, y: wy, screen: wscreen, style: wstyle })
                    // each screen's layer shows only its own widgets (hidden delegates cost nothing)
                    visible: root.screenOf(modelData) === win.sname
                    readonly property var d: root.dims(wsize)
                    // resize morph: the card glides to the new size at once; the content blurs + fades out, switches to
                    // the new layout (shownSize) and comes back into focus inside the moving card
                    property string shownSize: wsize
                    property real cf: 1
                    onWsizeChanged: {
                        if (shownSize === wsize) return;
                        if (root.compFor(wtype, wsize) === root.compFor(wtype, shownSize)) { shownSize = wsize; return; }   // same layout: it morphs itself
                        sizeMorph.restart();
                    }
                    SequentialAnimation {
                        id: sizeMorph
                        NumberAnimation { target: wd; property: "cf"; to: 0; duration: 170; easing.type: Easing.OutCubic }
                        ScriptAction { script: wd.shownSize = wd.wsize }
                        NumberAnimation { target: wd; property: "cf"; to: 1; duration: 520; easing.type: Easing.OutQuint }
                    }
                    readonly property string st: modelData.style || root.style
                    readonly property bool sel: root.editing && root.selected === modelData.id
                    property real dx: 0
                    property real dy: 0
                    readonly property bool held: wDrag.active || rsDrag.active
                    // follows the pointer 1:1 while dragged; glides to the snapped spot when let go
                    x: wx + dx; y: wy + dy
                    Behavior on x { enabled: !wDrag.active; NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }
                    Behavior on y { enabled: !wDrag.active; NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }
                    width: d.w; height: d.h
                    Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }
                    Behavior on height { NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }
                    // on top of every other widget while held, and until it has glided into its spot
                    property bool lifted: false
                    onHeldChanged: { if (held) { lifted = true; liftOff.stop(); } else liftOff.restart(); }
                    Timer { id: liftOff; interval: 460; onTriggered: wd.lifted = false }
                    z: lifted ? 50 : (sel ? 20 : 1)
                    // lifted a touch while held; a one-time pop-in when the widget is created (never replayed)
                    property real pop: 0
                    Component.onCompleted: pop = 1
                    Behavior on pop { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }
                    opacity: pop
                    scale: (0.92 + 0.08 * pop) * (wDrag.active ? 1.06 : 1)
                    // light wiggle while dragged (iOS-style), eases back to straight when dropped
                    property real wob: 0
                    rotation: wob
                    // edit mode (right-click): every widget shakes gently, each a little out of step; dragged ones a bit more
                    readonly property real wobA: wDrag.active ? 1.2 : 0.7
                    readonly property int wobMs: wDrag.active ? 110 : 130 + (wid.length * 7 + wid.charCodeAt(wid.length - 1)) % 30
                    SequentialAnimation {
                        id: wiggle
                        running: wDrag.active || (root.editing && wd.visible)
                        loops: Animation.Infinite
                        NumberAnimation { target: wd; property: "wob"; to: wd.wobA; duration: wd.wobMs; easing.type: Easing.InOutSine }
                        NumberAnimation { target: wd; property: "wob"; to: -wd.wobA; duration: wd.wobMs * 2; easing.type: Easing.InOutSine }
                        NumberAnimation { target: wd; property: "wob"; to: 0; duration: wd.wobMs; easing.type: Easing.InOutSine }
                        onRunningChanged: if (!running) settleWob.restart()
                    }
                    NumberAnimation { id: settleWob; target: wd; property: "wob"; to: 0; duration: 220; easing.type: Easing.OutQuint }
                    Behavior on scale { enabled: wd.pop >= 1; NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

                    // colours for the content
                    readonly property bool lightCard: st === "opaque" && !root.dark
                    readonly property var ctx: ({
                        w: modelData, size: wd.shownSize, style: st, sname: win.sname,
                        mono: st === "tinted",
                        fg: lightCard ? "#1d1d1f" : "white",
                        fg2: lightCard ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(1, 1, 1, 0.62)
                    })

                    // ── the card ──
                    RectangularShadow {
                        visible: st === "opaque"
                        anchors.fill: parent; radius: 22; blur: 24; offset.y: 6
                        color: Qt.rgba(0, 0, 0, 0.35)
                    }
                    ShaderEffect {
                        id: glassFx
                        readonly property real pad: 12
                        visible: st !== "opaque" && root.shaderOk && root.shaderUrl != ""
                        x: -pad; y: -pad
                        width: wd.width + 2 * pad; height: wd.height + 2 * pad
                        fragmentShader: root.shaderUrl
                        property variant src: st === "glass" ? wallClear : wallBlur
                        property vector2d itemSize: Qt.vector2d(width, height)
                        property vector2d glassSize: Qt.vector2d(wd.width, wd.height)
                        property vector2d srcSize: Qt.vector2d(win.width, win.height)
                        property vector2d srcOffset: Qt.vector2d(wd.x - pad, wd.y - pad)
                        property real radius: 22
                        // glass: a wide rounded bevel that visibly bends the wallpaper at the edges, bright rim, light fringe
                        readonly property real g: root.glassAmt * 2          // 1 = the default look
                        property real bezel: st === "glass" ? Math.min(wd.height * 0.30, 16 + 24 * g) : Math.min(wd.height * 0.36, 26)
                        property real thickness: st === "glass" ? 64 * g : 0
                        property real dispersion: st === "glass" ? 0.14 * g : 0
                        property real magnify: st === "glass" ? 0.04 * g : 0
                        property real rim: st === "glass" ? 0.35 + 0.65 * g : 0.28
                        property real grain: 0.003
                        property real blurPx: st === "glass" ? 1.0 + Math.max(0, root.blurAmt - 0.5) * 8 : 7
                        property real tintMix: st === "glass" ? 0.05 : 0
                        property real saturation: 1.3
                        property real dark: root.dark ? 1 : 0
                        property real debug: 0
                        property real shadowAmt: 0.55
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 22
                        color: st === "opaque" ? (root.dark ? "#1C1C1E" : "#F2F2F7")
                             : st === "tinted" ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.42)
                             : st === "frosted" ? (root.dark ? Qt.rgba(0.10, 0.10, 0.12, 0.40) : Qt.rgba(1, 1, 1, 0.42))
                             : (!root.shaderOk ? Qt.rgba(0.12, 0.12, 0.14, 0.5) : "transparent")
                        border.width: st === "opaque" ? 0.5 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        // the Weather widget's opaque card is the sky, like on macOS
                        gradient: (modelData.type === "weather" && st === "opaque") ? skyGrad : null
                        Gradient {
                            id: skyGrad
                            GradientStop { position: 0; color: root.weather && root.weather.current.is_day ? "#2F7FE0" : "#1B2A4A" }
                            GradientStop { position: 1; color: root.weather && root.weather.current.is_day ? "#6CB6F5" : "#2E3B5C" }
                        }
                    }

                    // ── content ──
                    Loader {
                        id: content
                        anchors.fill: parent
                        anchors.margins: modelData.type === "photos" ? 0 : 16
                        clip: true                  // nothing sticks out of the widget, even mid-resize
                        property var ctx: wd.ctx
                        opacity: wd.cf
                        scale: 0.96 + 0.04 * wd.cf
                        layer.enabled: wd.cf < 0.999
                        layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: Math.pow(1 - wd.cf, 0.8); autoPaddingEnabled: true }
                        sourceComponent: root.compFor(wd.wtype, wd.shownSize)
                    }

                    // drag anywhere (snaps to 16 px); right-click → edit
                    DragHandler {
                        id: wDrag
                        target: null
                        cursorShape: Qt.ClosedHandCursor
                        onTranslationChanged: { wd.dx = translation.x; wd.dy = translation.y; }
                        onActiveChanged: {
                            if (active) { root.selected = wd.modelData.id; return; }
                            var nx = Math.round((wd.wx + wd.dx) / 16) * 16, ny = Math.round((wd.wy + wd.dy) / 16) * 16;
                            nx = Math.max(8, Math.min(win.width - wd.width - 8, nx));
                            ny = Math.max(36, Math.min(win.height - wd.height - 8, ny));
                            // never on top of another widget: slide to the nearest free spot
                            var fp = root.freeSpot(win.sname, nx, ny, wd.width, wd.height, wd.wid, win.width, win.height);
                            root.update(wd.wid, { x: fp.x, y: fp.y });
                            wd.dx = 0; wd.dy = 0;
                        }
                    }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: { root.editing = true; root.selected = wd.modelData.id; }
                    }
                    TapHandler {
                        enabled: root.editing
                        onTapped: root.selected = wd.modelData.id
                    }

                    // ── resize: drag the bottom-right corner (edit mode); snaps to Small / Medium / Large ──
                    Item {
                        id: grip
                        visible: root.editing && !wDrag.active
                        width: 28; height: 28
                        x: parent.width - 20; y: parent.height - 20
                        z: 30
                        readonly property var sizes: { var t = root.types.filter(function (q) { return q.type === wd.wtype; })[0]; return t ? t.sizes : ["s"]; }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 16; height: 16; radius: 8
                            color: root.dark ? "#3A3A3C" : "#E5E5EA"
                            border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.25)
                            scale: rsDrag.active ? 1.25 : 1
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                        }
                        property real w0: 0
                        property real h0: 0
                        DragHandler {
                            id: rsDrag
                            target: null
                            cursorShape: Qt.SizeFDiagCursor
                            onActiveChanged: if (active) { grip.w0 = wd.d.w; grip.h0 = wd.d.h; root.selected = wd.wid; }
                            onTranslationChanged: {
                                if (!active) return;
                                var tw = grip.w0 + translation.x, th = grip.h0 + translation.y, best = wd.wsize, bd = 1e9;
                                for (var i = 0; i < grip.sizes.length; i++) {
                                    var dd = root.dims(grip.sizes[i]), dist = Math.abs(dd.w - tw) + Math.abs(dd.h - th);
                                    if (dist < bd) { bd = dist; best = grip.sizes[i]; }
                                }
                                if (best !== wd.wsize) root.update(wd.wid, { size: best });
                            }
                        }
                    }

                    // ── edit mode: remove badge + per-widget toolbar ──
                    Rectangle {
                        visible: root.editing
                        x: -9; y: -9; width: 24; height: 24; radius: 12
                        color: root.dark ? "#3A3A3C" : "#E5E5EA"
                        border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.25)
                        scale: rmMa.pressed ? 0.85 : 1
                        Behavior on scale { NumberAnimation { duration: 140 } }
                        Rectangle { anchors.centerIn: parent; width: 11; height: 2; radius: 1; color: root.dark ? "white" : "#1d1d1f" }
                        MouseArea { id: rmMa; anchors.fill: parent; anchors.margins: -4; onClicked: { root.remove(wd.modelData.id); if (root.bar) root.bar.playSound("trash", 0.5); } }
                    }
                }
            }

            // Escape leaves edit mode
            Item {
                focus: root.editing
                Keys.onEscapePressed: { root.editing = false; root.selected = ""; }
            }
        }
    }

    IpcHandler {
        target: "widgets"
        function edit(): void { root.editing = !root.editing; }
        function done(): void { root.editing = false; }
        function style(s: string): void { if (["glass", "frosted", "tinted", "opaque"].indexOf(s) >= 0) root.style = s; }
        function toggle(): void { root.enabled = !root.enabled; }
        function blur(v: real): void { root.blurAmt = Math.max(0, Math.min(1, v)); }
        function glass(v: real): void { root.glassAmt = Math.max(0, Math.min(1, v)); }
    }
}
