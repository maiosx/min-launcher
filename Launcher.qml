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

    readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : "min-launcher"
    readonly property var appLibrary: root.shell ? root.shell.appLibrary : null

    property var allApps: []
    property var filteredApps: []
    property var sections: []

    property color cardBg: "#0a0a0c"
    property color textPrimary: "#f0f0f2"
    property color textMuted: "#8a8a96"
    property color accent: "#7c6af7"
    property color hoverBg: "#1c1c22"
    property color borderColor: "#2a2a32"
    property int cornerRadius: 12

    function refreshApps() {
        root.allApps = Tools.buildAppList(root.appLibrary)
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

    function launchApp(app) {
        if (!app || !app.appId) return
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
            color: Qt.rgba(0, 0, 0, 0.5)
            MouseArea {
                anchors.fill: parent
                onClicked: root.dismiss()
            }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(980, parent.width - 40)
            height: Math.min(700, parent.height - 48)
            radius: root.cornerRadius
            color: root.cardBg
            border.color: root.borderColor
            border.width: 1
            clip: true

            MouseArea {
                anchors.fill: parent
                onClicked: { /* absorb */ }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 16

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
                        text: root.filteredApps.length + " installed applications"
                        color: root.textMuted
                        font.pixelSize: 13
                        font.family: "Inter, system-ui, sans-serif"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 8
                    color: "#121216"
                    border.color: searchField.activeFocus ? root.accent : root.borderColor
                    border.width: 1

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

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                if (root.filterText.length > 0) {
                                    root.filterText = ""
                                    searchField.text = ""
                                } else {
                                    root.dismiss()
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                root.moveSelection(1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                root.moveSelection(-1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launchAt(root.selectedIndex)
                                event.accepted = true
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
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 6
                    }

                    Flow {
                        id: sectionsFlow
                        width: flick.width
                        spacing: 0

                        Repeater {
                            model: root.sections

                            Rectangle {
                                width: {
                                    var cols = Math.max(2, Math.min(4, Math.floor(flick.width / 200)))
                                    return Math.floor(flick.width / cols)
                                }
                                height: catCol.implicitHeight + 24
                                color: "transparent"
                                border.color: root.borderColor
                                border.width: 1

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
                                                    spacing: 8

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
                                                            return (idx === root.selectedIndex || rowMa.containsMouse)
                                                                   ? root.textPrimary : root.textMuted
                                                        }
                                                        font.pixelSize: 12
                                                        font.family: "Inter, system-ui, sans-serif"
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                }

                                                MouseArea {
                                                    id: rowMa
                                                    anchors.fill: parent
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
        }

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: root.opened && !searchField.activeFocus
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.dismiss()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    root.moveSelection(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    root.moveSelection(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.launchAt(root.selectedIndex)
                    event.accepted = true
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
