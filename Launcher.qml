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

    readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : "min-launcher"
    readonly property var appLibrary: root.shell ? root.shell.appLibrary : null
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

    function refreshApps() {
        root.allApps = Tools.buildAppList(root.appLibrary, root.webApps)
        root.applyFilter()
    }

    function applyFilter() {
        root.filteredApps = Tools.filterApps(root.allApps, root.filterText)
        root.sections = Tools.buildSections(root.filteredApps)
        if (root.selectedIndex >= root.filteredApps.length)
            root.selectedIndex = Math.max(0, root.filteredApps.length - 1)
    }

    function open(payloadJson) {
        root.filterText = ""
        root.selectedIndex = 0
        root.addDialogOpen = false
        root.addTitle = ""
        root.addUrl = ""
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
            "if [ -f \"$HOME/.config/omarchy/min-launcher-web-apps.json\" ]; then cat \"$HOME/.config/omarchy/min-launcher-web-apps.json\"; fi"
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
        if (index < 0 || index >= root.filteredApps.length) return
        launchApp(root.filteredApps[index])
    }

    function flatIndexOf(app) {
        if (!app) return -1
        for (var i = 0; i < root.filteredApps.length; i++) {
            if (root.filteredApps[i].appId === app.appId) return i
        }
        return -1
    }

    function moveSelection(delta) {
        var n = root.filteredApps.length
        if (n === 0) return
        var next = root.selectedIndex + delta
        if (next < 0) next = n - 1
        if (next >= n) next = 0
        root.selectedIndex = next
    }

    onFilterTextChanged: root.applyFilter()

    Connections {
        target: root.appLibrary
        function onAppsChanged() {
            if (root.opened) root.refreshApps()
        }
    }

    Process {
        id: loadProc
        property string collected: ""
        stdout: SplitParser {
            onRead: function(data) { loadProc.collected += data }
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
                    Text {
                        text: "Apps"
                        color: root.textPrimary
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                        font.family: "Inter, system-ui, sans-serif"
                    }
                    Text {
                        text: root.filteredApps.length + " items"
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
                            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                root.moveSelection(1); event.accepted = true
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                root.moveSelection(-1); event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launchAt(root.selectedIndex); event.accepted = true
                            }
                        }
                    }
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        text: "Filter apps…"
                        color: root.textMuted
                        font.pixelSize: 13
                        visible: !searchField.text && !searchField.activeFocus
                        opacity: 0.65
                    }
                }

                Flickable {
                    id: flick
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
                                                            source: {
                                                                if (!root.appLibrary || !modelData.icon) return ""
                                                                if (typeof root.appLibrary.iconSource === "function")
                                                                    return root.appLibrary.iconSource(modelData.icon)
                                                                return ""
                                                            }
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
                                                        text: modelData.name || modelData.appId
                                                        color: {
                                                            var idx = root.flatIndexOf(modelData)
                                                            return (idx === root.selectedIndex || rowMa.containsMouse) ? root.textPrimary : root.textMuted
                                                        }
                                                        font.pixelSize: 12
                                                        font.family: "Inter, system-ui, sans-serif"
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
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

                Text {
                    Layout.fillWidth: true
                    text: "↑↓ navigate  ·  Enter launch  ·  Esc close"
                    color: root.textMuted
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.6
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
                } else if (event.key === Qt.Key_Down) {
                    root.moveSelection(1); event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    root.moveSelection(-1); event.accepted = true
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
