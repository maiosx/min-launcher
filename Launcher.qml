import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Tools.js" as Tools

Item {
    id: root

    property var shell: null
    property var manifest: null
    property bool opened: false
    property int selectedIndex: 0
    property string filterText: ""
    property bool addDialogOpen: false
    property string addTitle: ""
    property string addUrl: ""

    // Disk size (looked up on hover) and RAM of running apps (polled while open)
    property var ramMap: ({})
    property var appInfo: ({})
    property var hoverApp: null
    property var pendingApp: null

    // "apps" or "files" (file search in the home directory)
    property string mode: "apps"
    property var fileResults: []
    property bool fileSearching: false
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property int listCount: mode === "files" ? fileResults.length : filteredApps.length

    // System-wide memory (kB), shown in the bottom-left meter
    property real sysUsedKb: 0
    property real sysTotalKb: 0
    readonly property real sysFraction: sysTotalKb > 0 ? Math.min(1, sysUsedKb / sysTotalKb) : 0

    readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : "min-launcher"
    readonly property var appLibrary: root.shell ? root.shell.appLibrary : null
    readonly property string infoScript: decodeURIComponent(String(Qt.resolvedUrl("appinfo.sh")).replace(/^file:\/\//, ""))
    readonly property string webAppsPath: Quickshell.env("HOME") + "/.config/omarchy/min-launcher-web-apps.json"

    property var webApps: []
    property bool webAppsLoaded: false
    property var allApps: []
    property var filteredApps: []
    property var sections: []

    property color cardBg: "#000000"
    property color textPrimary: "#f0f0f2"
    property color textMuted: "#8a8a96"
    property color accent: "#7c6af7"
    property color hoverBg: "#1c1c22"
    property color borderColor: "#2a2a32"
    property color danger: "#f87171"
    property int cornerRadius: 12

    // Omarchy 4.0.3+ only injects shell.appLibrary into "menu"-kind plugins, so
    // an overlay gets null. Fall back to Quickshell's own DesktopEntries.
    function desktopEntryList() {
        var out = []
        try {
            var vals = DesktopEntries.applications.values
            for (var i = 0; i < vals.length; i++) out.push(vals[i])
        } catch (e) {}
        return out
    }

    function iconSource(icon) {
        if (!icon) return ""
        var name = String(icon)
        if (root.appLibrary && typeof root.appLibrary.iconSource === "function") {
            try {
                var s = root.appLibrary.iconSource(name)
                if (s) return s
            } catch (e) {}
        }
        if (name.indexOf("/") === 0) return "file://" + name
        try { return Quickshell.iconPath(name, true) || "" } catch (e) { return "" }
    }

    function refreshApps() {
        root.allApps = Tools.buildAppList(root.appLibrary, root.webApps, root.desktopEntryList())
        root.applyFilter()
    }

    function applyFilter() {
        root.filteredApps = Tools.filterApps(root.allApps, root.filterText)
        root.sections = Tools.buildSections(root.filteredApps)
        if (root.mode === "files") root.scheduleFileSearch()
        if (root.selectedIndex >= root.listCount)
            root.selectedIndex = Math.max(0, root.listCount - 1)
    }

    function setMode(m) {
        if (root.mode === m) return
        root.mode = m
        root.selectedIndex = 0
        root.fileResults = []
        if (m === "files") root.scheduleFileSearch()
        else fileTimer.stop()
        searchField.forceActiveFocus()
    }

    function toggleMode() { setMode(root.mode === "apps" ? "files" : "apps") }

    function scheduleFileSearch() {
        if (String(root.filterText).trim().length < 2) {
            fileTimer.stop()
            root.fileResults = []
            root.fileSearching = false
            return
        }
        root.fileSearching = true
        fileTimer.restart()
    }

    function runFileSearch() {
        var term = String(root.filterText).trim()
        if (term.length < 2) { root.fileSearching = false; return }
        if (fileProc.running) { fileProc.rerun = true; return }
        fileProc.rerun = false
        fileProc.term = term
        fileProc.collected = ""
        fileProc.command = ["bash", root.infoScript, "files", term]
        fileProc.running = true
    }

    function parseFiles(text) {
        var out = []
        var lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
            var tab = lines[i].indexOf("\t")
            if (tab !== 1) continue
            var path = lines[i].slice(2)
            if (!path) continue
            var slash = path.lastIndexOf("/")
            var dir = path.slice(0, slash)
            if (dir === root.homeDir) dir = "~"
            else if (dir.indexOf(root.homeDir + "/") === 0) dir = "~" + dir.slice(root.homeDir.length)
            out.push({ path: path, name: path.slice(slash + 1), dir: dir, isDir: lines[i][0] === "d" })
        }
        return out
    }

    function openFile(f) {
        if (!f || !f.path) return
        Quickshell.execDetached([
            "sh", "-c",
            "setsid -f uwsm-app -- xdg-open \"$1\" >/dev/null 2>&1 || setsid -f xdg-open \"$1\" >/dev/null 2>&1",
            "sh", String(f.path)
        ])
        dismiss()
    }

    readonly property string cacheDir: Quickshell.env("XDG_CACHE_HOME") || (homeDir + "/.cache")
    readonly property var imageExts: ["png", "jpg", "jpeg", "webp", "bmp", "gif", "tiff", "avif", "svg"]

    function extOf(f) {
        var dot = f.name.lastIndexOf(".")
        return (dot > 0 && dot < f.name.length - 1) ? f.name.slice(dot + 1).toLowerCase() : ""
    }

    function isImageFile(f) {
        return !f.isDir && root.imageExts.indexOf(root.extOf(f)) >= 0
    }

    // freedesktop thumbnail cache entry (written by file managers); may not exist
    function thumbCachePath(f, size) {
        var uri = "file://" + encodeURI(f.path).replace(/\?/g, "%3F").replace(/#/g, "%23")
        return "file://" + root.cacheDir + "/thumbnails/" + size + "/" + Qt.md5(uri) + ".png"
    }

    function iconNameFor(f) {
        if (f.isDir) return "folder"
        var e = root.extOf(f)
        if (e === "pdf") return "application-pdf"
        if (["mp4", "mkv", "webm", "mov", "avi"].indexOf(e) >= 0) return "video-x-generic"
        if (["mp3", "flac", "ogg", "wav", "m4a", "opus"].indexOf(e) >= 0) return "audio-x-generic"
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2"].indexOf(e) >= 0) return "package-x-generic"
        if (["doc", "docx", "odt", "rtf"].indexOf(e) >= 0) return "x-office-document"
        if (["xls", "xlsx", "ods", "csv"].indexOf(e) >= 0) return "x-office-spreadsheet"
        if (["ppt", "pptx", "odp"].indexOf(e) >= 0) return "x-office-presentation"
        return "text-x-generic"
    }

    function moveRow(dir) {
        if (root.mode !== "files") { root.moveSelection(dir); return }
        var n = root.listCount
        if (n === 0) return
        var next = root.selectedIndex + dir * fileGrid.cols
        if (next >= 0 && next < n) root.selectedIndex = next
    }

    function fileExt(f) {
        if (f.isDir) return "DIR"
        var dot = f.name.lastIndexOf(".")
        if (dot <= 0 || dot === f.name.length - 1) return "FILE"
        return f.name.slice(dot + 1, dot + 4).toUpperCase()
    }

    function open(payloadJson) {
        root.filterText = ""
        root.selectedIndex = 0
        root.addDialogOpen = false
        root.addTitle = ""
        root.addUrl = ""
        root.mode = "apps"
        root.fileResults = []
        root.fileSearching = false
        root.appInfo = ({})
        root.ramMap = ({})
        root.refreshRam()
        root.refreshSysRam()
        root.hoverApp = null
        root.pendingApp = null
        if (!root.webAppsLoaded)
            loadWebApps()
        else
            root.refreshApps()
        root.opened = true
        Qt.callLater(function() {
            keyCatcher.forceActiveFocus()
            searchField.forceActiveFocus()
        })
    }

    function close() {
        root.opened = false
        root.hoverApp = null
        root.pendingApp = null
        root.filterText = ""
        root.selectedIndex = 0
        root.addDialogOpen = false
    }

    function dismiss() {
        root.close()
        if (root.shell && typeof root.shell.hide === "function")
            root.shell.hide(root.pluginId)
    }

    function toggle(payloadJson) {
        if (root.opened) dismiss()
        else open(payloadJson || "{}")
    }

    function loadWebApps() {
        loadProc.command = [
            "bash", "-c",
            "if [ -f \"$HOME/.config/omarchy/min-launcher-web-apps.json\" ]; then head -c 65536 \"$HOME/.config/omarchy/min-launcher-web-apps.json\"; fi"
        ]
        loadProc.running = true
    }

    function saveWebApps(list) {
        var json = Tools.serializeWebApps(list)
        saveProc.command = [
            "bash", "-c",
            "mkdir -p \"$HOME/.config/omarchy\" && printf '%s\\n' " + Tools.shellQuote(json) + " > \"$HOME/.config/omarchy/min-launcher-web-apps.json\""
        ]
        saveProc.running = true
    }

    function setWebApps(list) {
        root.webApps = list || []
        root.webAppsLoaded = true
        root.refreshApps()
    }

    function removeWebApp(app) {
        if (!app || !app.isWeb) return
        var next = Tools.removeWebApp(root.webApps, app.appId)
        root.setWebApps(next)
        root.saveWebApps(next)
    }

    function submitAddWebApp() {
        var name = String(root.addTitle || "").trim()
        var url = String(root.addUrl || "").trim()
        if (!name || !url) return
        var next = Tools.addWebApp(root.webApps, name, url)
        root.setWebApps(next)
        root.saveWebApps(next)
        root.addDialogOpen = false
        root.addTitle = ""
        root.addUrl = ""
        searchField.forceActiveFocus()
    }

    function launchApp(app) {
        if (!app) return
        if (app.isWeb || (app.url && String(app.url).length > 0)) {
            Qt.openUrlExternally(String(app.url))
            dismiss()
            return
        }
        if (!app.appId) return
        if (root.appLibrary && typeof root.appLibrary.launch === "function") {
            root.appLibrary.launch(app.appId, app.name || app.appId)
        } else {
            var deskId = String(app.appId)
            if (deskId.indexOf(".desktop") < 0)
                deskId = deskId + ".desktop"
            Quickshell.execDetached([
                "sh", "-c",
                "setsid -f uwsm-app -- gtk-launch \"$1\" >/dev/null 2>&1 || setsid -f gtk-launch \"$1\" >/dev/null 2>&1",
                "sh", deskId
            ])
        }
        dismiss()
    }

    function launchAt(index) {
        if (root.mode === "files") {
            if (index >= 0 && index < root.fileResults.length) openFile(root.fileResults[index])
            return
        }
        if (index < 0 || index >= root.filteredApps.length) return
        launchApp(root.filteredApps[index])
    }

    function requestInfo(app) {
        if (!app || app.isWeb || !app.appId) return
        root.pendingApp = app
        if (!infoProc.running) startInfo()
    }

    function startInfo() {
        var app = root.pendingApp
        if (!app) return
        root.pendingApp = null
        var cached = root.appInfo[app.appId]
        if (cached && cached.sized) return
        infoProc.appId = app.appId
        infoProc.collected = ""
        infoProc.command = ["bash", root.infoScript, "size", String(app.appId)]
        infoProc.running = true
    }

    function storeInfo(appId, text) {
        var size = ""
        var lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].indexOf("SIZE=") === 0) size = lines[i].slice(5).trim()
        }
        var map = ({})
        for (var k in root.appInfo) map[k] = root.appInfo[k]
        map[appId] = { size: size, sized: true }
        root.appInfo = map
    }

    function refreshRam() {
        if (ramProc.running) return
        ramProc.collected = ""
        ramProc.command = ["bash", root.infoScript, "ram"]
        ramProc.running = true
    }

    function refreshSysRam() {
        if (sysProc.running) return
        sysProc.collected = ""
        sysProc.command = ["bash", root.infoScript, "sys"]
        sysProc.running = true
    }

    function formatKb(kb) {
        var gb = kb / 1048576
        if (gb >= 1) return gb.toFixed(1) + " GB"
        return Math.round(kb / 1024) + " MB"
    }

    function ramFor(appId) {
        var key = String(appId || "").replace(/\.desktop$/, "")
        return root.ramMap[key] || ""
    }

    function flatIndexOf(app) {
        if (!app) return -1
        for (var i = 0; i < root.filteredApps.length; i++) {
            if (root.filteredApps[i].appId === app.appId) return i
        }
        return -1
    }

    function moveSelection(delta) {
        var n = root.listCount
        if (n === 0) return
        var next = root.selectedIndex + delta
        if (next < 0) next = n - 1
        if (next >= n) next = 0
        root.selectedIndex = next
    }

    onFilterTextChanged: root.applyFilter()

    Connections {
        target: root.appLibrary
        ignoreUnknownSignals: true
        function onAppsChanged() {
            if (root.opened) root.refreshApps()
        }
    }

    Connections {
        target: DesktopEntries.applications
        ignoreUnknownSignals: true
        function onValuesChanged() {
            if (root.opened) root.refreshApps()
        }
    }

    Process {
        id: loadProc
        property string collected: ""
        stdout: SplitParser {
            onRead: function(data) {
                if (loadProc.collected.length < 65536)
                    loadProc.collected += data.slice(0, 65536 - loadProc.collected.length)
            }
        }
        onExited: function(exitCode, exitStatus) {
            var parsed = Tools.parseWebAppsJson(loadProc.collected)
            loadProc.collected = ""
            if (parsed !== null)
                root.setWebApps(parsed)
            else
                root.setWebApps(Tools.defaultWebApps())
        }
    }

    Process {
        id: saveProc
    }

    Process {
        id: infoProc
        property string appId: ""
        property string collected: ""
        stdout: SplitParser {
            onRead: function(data) {
                if (infoProc.collected.length < 4096)
                    infoProc.collected += data + "\n"
            }
        }
        onExited: function(exitCode, exitStatus) {
            if (infoProc.appId) root.storeInfo(infoProc.appId, infoProc.collected)
            infoProc.collected = ""
            if (root.pendingApp) root.startInfo()
        }
    }

    Process {
        id: ramProc
        property string collected: ""
        stdout: SplitParser {
            onRead: function(data) {
                if (ramProc.collected.length < 65536)
                    ramProc.collected += data + "\n"
            }
        }
        onExited: function(exitCode, exitStatus) {
            var map = ({})
            var lines = ramProc.collected.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var tab = lines[i].indexOf("\t")
                if (tab > 0) map[lines[i].slice(0, tab)] = lines[i].slice(tab + 1).trim()
            }
            ramProc.collected = ""
            root.ramMap = map
        }
    }

    Process {
        id: fileProc
        property string term: ""
        property string collected: ""
        property bool rerun: false
        stdout: SplitParser {
            onRead: function(data) {
                if (fileProc.collected.length < 262144)
                    fileProc.collected += data + "\n"
            }
        }
        onExited: function(exitCode, exitStatus) {
            var stale = fileProc.rerun || fileProc.term !== String(root.filterText).trim()
            if (!stale && root.mode === "files") {
                root.fileResults = root.parseFiles(fileProc.collected)
                root.fileSearching = false
                root.selectedIndex = 0
            }
            fileProc.collected = ""
            if (stale && root.mode === "files") root.runFileSearch()
        }
    }

    Timer {
        id: fileTimer
        interval: 180
        onTriggered: root.runFileSearch()
    }

    Process {
        id: sysProc
        property string collected: ""
        stdout: SplitParser {
            onRead: function(data) {
                if (sysProc.collected.length < 1024)
                    sysProc.collected += data + "\n"
            }
        }
        onExited: function(exitCode, exitStatus) {
            var m = /USED=(\d+)\s+TOTAL=(\d+)/.exec(sysProc.collected)
            if (m) {
                root.sysUsedKb = parseInt(m[1])
                root.sysTotalKb = parseInt(m[2])
            }
            sysProc.collected = ""
        }
    }

    // Small delay so sweeping the mouse across rows doesn't spawn a lookup per row
    Timer {
        id: hoverTimer
        interval: 90
        onTriggered: root.requestInfo(root.hoverApp)
    }

    // Keep RAM numbers live while the launcher is open
    Timer {
        interval: 3000
        repeat: true
        running: root.opened
        onTriggered: { root.refreshRam(); root.refreshSysRam() }
    }

    PanelWindow {
        id: panel
        visible: root.opened
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "min-launcher"

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.addDialogOpen) {
                        root.addDialogOpen = false
                        return
                    }
                    root.dismiss()
                }
            }
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 0
            color: root.cardBg
            border.width: 0
            clip: true

            MouseArea {
                anchors.fill: parent
                onClicked: { }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 48
                spacing: 20

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Row {
                        spacing: 22
                        Repeater {
                            model: [
                                { key: "apps", label: "Apps" },
                                { key: "files", label: "Files" }
                            ]
                            Text {
                                text: modelData.label
                                color: root.mode === modelData.key ? root.textPrimary
                                       : (tabMa.containsMouse ? "#c4c4cc" : "#55555f")
                                font.pixelSize: 26
                                font.weight: Font.DemiBold
                                font.family: "Inter, system-ui, sans-serif"
                                MouseArea {
                                    id: tabMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setMode(modelData.key)
                                }
                            }
                        }
                    }
                    Text {
                        text: root.mode === "files"
                              ? (String(root.filterText).trim().length < 2 ? "Search ~ by file name"
                                 : (root.fileSearching && root.fileResults.length === 0 ? "Searching…"
                                    : root.fileResults.length + " results"))
                              : root.filteredApps.length + " items"
                        textFormat: Text.PlainText
                        color: root.textMuted
                        font.pixelSize: 13
                        font.family: "Inter, system-ui, sans-serif"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 8
                    color: "#000000"
                    border.color: searchField.activeFocus ? root.accent : "transparent"
                    border.width: searchField.activeFocus ? 1 : 0

                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.textPrimary
                        font.pixelSize: 13
                        font.family: "Inter, system-ui, sans-serif"
                        selectByMouse: true
                        clip: true
                        text: root.filterText
                        onTextChanged: root.filterText = text
                        enabled: !root.addDialogOpen
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                if (root.filterText.length > 0) {
                                    root.filterText = ""
                                    searchField.text = ""
                                } else root.dismiss()
                                event.accepted = true
                            } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                                       && (event.modifiers & Qt.ControlModifier)) {
                                root.toggleMode(); event.accepted = true
                            } else if (event.key === Qt.Key_Tab) {
                                root.moveSelection(1); event.accepted = true
                            } else if (event.key === Qt.Key_Backtab) {
                                root.moveSelection(-1); event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                root.moveRow(1); event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                root.moveRow(-1); event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launchAt(root.selectedIndex); event.accepted = true
                            }
                        }
                    }
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        text: root.mode === "files" ? "Search files in ~…" : "Filter apps…"
                        color: root.textMuted
                        font.pixelSize: 13
                        visible: !searchField.text && !searchField.activeFocus
                        opacity: 0.65
                    }
                }

                Flickable {
                    id: flick
                    visible: root.mode === "apps"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: sectionsFlow.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 6 }

                    Flow {
                        id: sectionsFlow
                        width: flick.width
                        spacing: 0
                        Repeater {
                            model: root.sections
                            Rectangle {
                                width: {
                                    var cols = Math.max(2, Math.min(4, Math.floor(flick.width / 220)))
                                    return Math.floor(flick.width / cols)
                                }
                                height: catCol.implicitHeight + 24
                                color: "transparent"
                                border.width: 0
                                ColumnLayout {
                                    id: catCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 14
                                    spacing: 8
                                    Text {
                                        text: modelData.title
                                        textFormat: Text.PlainText
                                        color: root.textPrimary
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        font.family: "Inter, system-ui, sans-serif"
                                        Layout.fillWidth: true
                                    }
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Repeater {
                                            model: modelData.tools
                                            Rectangle {
                                                width: catCol.width
                                                height: 26
                                                radius: 6
                                                color: {
                                                    var idx = root.flatIndexOf(modelData)
                                                    if (idx === root.selectedIndex) return Qt.rgba(0.49, 0.42, 0.97, 0.2)
                                                    if (rowMa.containsMouse) return root.hoverBg
                                                    return "transparent"
                                                }
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 4
                                                    anchors.rightMargin: 4
                                                    spacing: 6
                                                    Item {
                                                        Layout.preferredWidth: 16
                                                        Layout.preferredHeight: 16
                                                        Layout.alignment: Qt.AlignVCenter
                                                        Image {
                                                            anchors.fill: parent
                                                            source: root.iconSource(modelData.icon)
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                            asynchronous: true
                                                            visible: status === Image.Ready
                                                        }
                                                        Rectangle {
                                                            anchors.fill: parent
                                                            radius: 3
                                                            color: accentDot(index)
                                                            visible: parent.children[0].status !== Image.Ready
                                                        }
                                                    }
                                                    Text {
                                                        text: String(modelData.name || modelData.appId).slice(0, 128)
                                                        textFormat: Text.PlainText
                                                        color: {
                                                            var idx = root.flatIndexOf(modelData)
                                                            return (idx === root.selectedIndex || rowMa.containsMouse) ? root.textPrimary : root.textMuted
                                                        }
                                                        font.pixelSize: 12
                                                        font.family: "Inter, system-ui, sans-serif"
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                    Text {
                                                        id: sizeLabel
                                                        readonly property var entry: root.appInfo[modelData.appId]
                                                        visible: rowMa.containsMouse && !modelData.isWeb && !!entry && entry.size.length > 0
                                                        text: entry ? entry.size : ""
                                                        textFormat: Text.PlainText
                                                        color: root.textMuted
                                                        font.pixelSize: 11
                                                        font.family: "Inter, system-ui, sans-serif"
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }
                                                    Text {
                                                        id: ramLabel
                                                        readonly property string ram: modelData.isWeb ? "" : root.ramFor(modelData.appId)
                                                        visible: ram.length > 0
                                                        text: "● " + ram
                                                        textFormat: Text.PlainText
                                                        color: "#34d399"
                                                        font.pixelSize: 11
                                                        font.family: "Inter, system-ui, sans-serif"
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }
                                                    Rectangle {
                                                        visible: !!(modelData.isWeb)
                                                        Layout.preferredWidth: 18
                                                        Layout.preferredHeight: 18
                                                        Layout.alignment: Qt.AlignVCenter
                                                        radius: 4
                                                        color: removeMa.containsMouse ? Qt.rgba(0.97, 0.44, 0.44, 0.2) : "transparent"
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "−"
                                                            color: removeMa.containsMouse ? root.danger : root.textMuted
                                                            font.pixelSize: 14
                                                            font.weight: Font.DemiBold
                                                        }
                                                        MouseArea {
                                                            id: removeMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.removeWebApp(modelData)
                                                        }
                                                    }
                                                }
                                                MouseArea {
                                                    id: rowMa
                                                    anchors.fill: parent
                                                    anchors.rightMargin: modelData.isWeb ? 22 : 0
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.launchApp(modelData)
                                                    onContainsMouseChanged: {
                                                        if (containsMouse) {
                                                            var idx = root.flatIndexOf(modelData)
                                                            if (idx >= 0) root.selectedIndex = idx
                                                            if (!modelData.isWeb) {
                                                                root.hoverApp = modelData
                                                                hoverTimer.restart()
                                                            }
                                                        } else if (root.hoverApp && root.hoverApp.appId === modelData.appId) {
                                                            root.hoverApp = null
                                                            hoverTimer.stop()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                GridView {
                    id: fileGrid
                    visible: root.mode === "files"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.fileResults
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 6 }

                    readonly property int gap: 14
                    readonly property int cols: Math.max(3, Math.min(8, Math.floor(width / 190)))
                    // floor() so the columns always fit and never round down by one
                    cellWidth: Math.floor(width / cols)
                    cellHeight: Math.floor((cellWidth - gap) * 10 / 16) + gap

                    Connections {
                        target: root
                        function onSelectedIndexChanged() {
                            if (root.mode === "files" && root.selectedIndex < fileGrid.count)
                                fileGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                        }
                    }

                    delegate: Item {
                        id: tile
                        property int thumbStage: 0   // 0 large cache, 1 normal cache, 2 none
                        readonly property bool active: index === root.selectedIndex || tileMa.containsMouse
                        readonly property bool isImg: root.isImageFile(modelData)
                        width: fileGrid.cellWidth - fileGrid.gap
                        height: fileGrid.cellHeight - fileGrid.gap

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: "#101014"
                            border.width: index === root.selectedIndex ? 2 : 0
                            border.color: root.accent
                            clip: true

                            Image {
                                id: thumb
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                sourceSize.width: 640
                                sourceSize.height: 640
                                source: tile.isImg ? "file://" + modelData.path
                                        : (modelData.isDir || tile.thumbStage > 1) ? ""
                                        : root.thumbCachePath(modelData, tile.thumbStage === 0 ? "large" : "normal")
                                onStatusChanged: {
                                    if (status === Image.Error && !tile.isImg && tile.thumbStage < 2)
                                        tile.thumbStage++
                                }
                            }

                            // No thumbnail available: file-type icon + extension
                            Column {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -10
                                spacing: 6
                                visible: thumb.status !== Image.Ready
                                         && (!tile.isImg || thumb.status === Image.Error)
                                Image {
                                    id: typeIcon
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 44
                                    height: 44
                                    sourceSize.width: 88
                                    sourceSize.height: 88
                                    source: root.iconSource(root.iconNameFor(modelData))
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.fileExt(modelData)
                                    textFormat: Text.PlainText
                                    color: modelData.isDir ? root.accent : root.textMuted
                                    font.pixelSize: typeIcon.visible ? 10 : 22
                                    font.weight: Font.DemiBold
                                    font.family: "Inter, system-ui, sans-serif"
                                }
                            }

                            // Title at the bottom of the tile
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: tile.active ? 50 : 38
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#00000000" }
                                    GradientStop { position: 1.0; color: "#d8000000" }
                                }
                                Column {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 8
                                    spacing: 1
                                    Text {
                                        width: parent.width
                                        text: modelData.name
                                        textFormat: Text.PlainText
                                        elide: Text.ElideMiddle
                                        color: root.textPrimary
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        font.family: "Inter, system-ui, sans-serif"
                                    }
                                    Text {
                                        visible: tile.active
                                        width: parent.width
                                        text: modelData.dir
                                        textFormat: Text.PlainText
                                        elide: Text.ElideLeft
                                        color: root.textMuted
                                        font.pixelSize: 10
                                        font.family: "Inter, system-ui, sans-serif"
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: tileMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: if (containsMouse) root.selectedIndex = index
                            onClicked: root.openFile(modelData)
                        }
                    }
                }

                Text {
                    visible: root.mode === "files" && root.fileResults.length === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: String(root.filterText).trim().length < 2 ? "Type to search your home folder"
                          : (root.fileSearching ? "Searching…" : "No files found")
                    color: root.textMuted
                    font.pixelSize: 13
                    font.family: "Inter, system-ui, sans-serif"
                }

                Text {
                    Layout.fillWidth: true
                    text: root.mode === "files"
                          ? "↑↓ navigate  ·  Enter open  ·  Ctrl+Tab apps  ·  Esc close"
                          : "↑↓ navigate  ·  Enter launch  ·  Ctrl+Tab files  ·  Esc close"
                    color: root.textMuted
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.6
                }
            }

            Item {
                id: sysRamMeter
                visible: root.sysTotalKb > 0
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 48
                anchors.bottomMargin: 28
                height: 48
                width: 160
                z: 20

                readonly property color barColor: root.sysFraction >= 0.9 ? root.danger
                                                 : root.sysFraction >= 0.75 ? "#fbbf24"
                                                 : "#34d399"

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 6

                    Row {
                        width: parent.width
                        Text {
                            id: ramTitle
                            text: "RAM"
                            color: root.textMuted
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            font.family: "Inter, system-ui, sans-serif"
                        }
                        Item { width: parent.width - ramTitle.width - ramValue.width; height: 1 }
                        Text {
                            id: ramValue
                            text: root.formatKb(root.sysUsedKb) + " / " + root.formatKb(root.sysTotalKb)
                            textFormat: Text.PlainText
                            color: root.textPrimary
                            font.pixelSize: 11
                            font.family: "Inter, system-ui, sans-serif"
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: root.hoverBg
                        Rectangle {
                            width: Math.max(parent.radius * 2, parent.width * root.sysFraction)
                            height: parent.height
                            radius: parent.radius
                            color: sysRamMeter.barColor
                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }

            Rectangle {
                id: addFab
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 28
                width: 48
                height: 48
                radius: 24
                color: addFabMa.containsMouse ? Qt.lighter(root.accent, 1.15) : root.accent
                z: 20
                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: "#ffffff"
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: addFabMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.addTitle = ""
                        root.addUrl = ""
                        root.addDialogOpen = true
                        Qt.callLater(function() { titleField.forceActiveFocus() })
                    }
                }
            }

            Rectangle {
                visible: root.addDialogOpen
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.65)
                z: 30
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.addDialogOpen = false
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(420, parent.width - 48)
                    height: dialogCol.implicitHeight + 40
                    radius: 14
                    color: "#0c0c0e"
                    border.color: root.borderColor
                    border.width: 1
                    MouseArea { anchors.fill: parent; onClicked: { } }
                    ColumnLayout {
                        id: dialogCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 20
                        spacing: 14
                        Text {
                            text: "Add Web App"
                            color: root.textPrimary
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            font.family: "Inter, system-ui, sans-serif"
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "Title"; color: root.textMuted; font.pixelSize: 11 }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 8
                                color: "#121216"
                                border.color: titleField.activeFocus ? root.accent : root.borderColor
                                border.width: 1
                                TextInput {
                                    id: titleField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    color: root.textPrimary
                                    font.pixelSize: 13
                                    selectByMouse: true
                                    maximumLength: 128
                                    text: root.addTitle
                                    onTextChanged: root.addTitle = text
                                    Keys.onPressed: function(event) {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            urlField.forceActiveFocus(); event.accepted = true
                                        } else if (event.key === Qt.Key_Escape) {
                                            root.addDialogOpen = false; event.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "URL"; color: root.textMuted; font.pixelSize: 11 }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 8
                                color: "#121216"
                                border.color: urlField.activeFocus ? root.accent : root.borderColor
                                border.width: 1
                                TextInput {
                                    id: urlField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    color: root.textPrimary
                                    font.pixelSize: 13
                                    selectByMouse: true
                                    maximumLength: 2048
                                    text: root.addUrl
                                    onTextChanged: root.addUrl = text
                                    Keys.onPressed: function(event) {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            root.submitAddWebApp(); event.accepted = true
                                        } else if (event.key === Qt.Key_Escape) {
                                            root.addDialogOpen = false; event.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Layout.topMargin: 4
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 88; height: 34; radius: 8
                                color: cancelMa.containsMouse ? root.hoverBg : "transparent"
                                border.color: root.borderColor; border.width: 1
                                Text { anchors.centerIn: parent; text: "Cancel"; color: root.textMuted; font.pixelSize: 13 }
                                MouseArea {
                                    id: cancelMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.addDialogOpen = false
                                }
                            }
                            Rectangle {
                                width: 88; height: 34; radius: 8
                                color: (root.addTitle.trim().length && root.addUrl.trim().length)
                                       ? (addMa.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent)
                                       : root.hoverBg
                                opacity: (root.addTitle.trim().length && root.addUrl.trim().length) ? 1 : 0.5
                                Text { anchors.centerIn: parent; text: "Add"; color: "#ffffff"; font.pixelSize: 13; font.weight: Font.DemiBold }
                                MouseArea {
                                    id: addMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: root.addTitle.trim().length > 0 && root.addUrl.trim().length > 0
                                    onClicked: root.submitAddWebApp()
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: root.opened && !searchField.activeFocus && !root.addDialogOpen
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    if (root.addDialogOpen) root.addDialogOpen = false
                    else root.dismiss()
                    event.accepted = true
                } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier)) {
                    root.toggleMode(); event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    root.moveRow(1); event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    root.moveRow(-1); event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.launchAt(root.selectedIndex); event.accepted = true
                }
            }
        }
    }

    function accentDot(i) {
        var palette = [
            "#60a5fa", "#a78bfa", "#f472b6", "#34d399",
            "#fbbf24", "#fb7185", "#22d3ee", "#c084fc",
            "#4ade80", "#f97316"
        ]
        return palette[i % palette.length]
    }
}
