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

    property color cardBg: "#111114"
    property color textPrimary: "#f0f0f2"
    property color textMuted: "#8a8a96"
    property color accent: "#7c6af7"
    property color hoverBg: "#1c1c22"
    property color borderColor: "#2a2a32"
    property int cornerRadius: 16

    function refreshApps() {
        root.allApps = Tools.buildAppList(root.appLibrary)
        root.applyFilter()
    }

    function applyFilter() {
        root.filteredApps = Tools.filterApps(root.allApps, root.filterText)
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

    function launchAt(index) {
        var list = root.filteredApps
        if (index < 0 || index >= list.length) return
        var app = list[index]
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

    function moveSelection(delta) {
        var n = root.filteredApps.length
        if (n === 0) return
        var next = root.selectedIndex + delta
        if (next < 0) next = n - 1
        if (next >= n) next = 0
        root.selectedIndex = next
        appList.positionViewAtIndex(next, ListView.Contain)
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
            color: Qt.rgba(0, 0, 0, 0.55)
            MouseArea {
                anchors.fill: parent
                onClicked: root.dismiss()
            }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(560, parent.width - 48)
            height: Math.min(640, parent.height - 64)
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
                anchors.margins: 20
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Apps"
                        color: root.textPrimary
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        font.family: "Inter, system-ui, sans-serif"
                    }
                    Text {
                        text: root.filteredApps.length + " installed"
                        color: root.textMuted
                        font.pixelSize: 12
                        font.family: "Inter, system-ui, sans-serif"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: root.hoverBg
                    border.color: searchField.activeFocus ? root.accent : root.borderColor
                    border.width: 1

                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.textPrimary
                        font.pixelSize: 14
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
                        text: "Search apps…"
                        color: root.textMuted
                        font.pixelSize: 14
                        visible: !searchField.text && !searchField.activeFocus
                        opacity: 0.7
                    }
                }

                ListView {
                    id: appList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.filteredApps
                    spacing: 2
                    currentIndex: root.selectedIndex
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 6
                    }

                    delegate: Rectangle {
                        width: appList.width
                        height: 44
                        radius: 8
                        color: {
                            if (index === root.selectedIndex) return Qt.rgba(0.49, 0.42, 0.97, 0.18)
                            if (rowMa.containsMouse) return root.hoverBg
                            return "transparent"
                        }
                        border.color: index === root.selectedIndex ? root.accent : "transparent"
                        border.width: index === root.selectedIndex ? 1 : 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
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
                                    radius: 6
                                    color: root.hoverBg
                                    visible: parent.children[0].status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: (modelData.name || "?").charAt(0).toUpperCase()
                                        color: root.textMuted
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: modelData.name || modelData.appId
                                    color: root.textPrimary
                                    font.pixelSize: 13
                                    font.family: "Inter, system-ui, sans-serif"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: !!(modelData.subtext)
                                    text: modelData.subtext || ""
                                    color: root.textMuted
                                    font.pixelSize: 11
                                    font.family: "Inter, system-ui, sans-serif"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedIndex = index
                                root.launchAt(index)
                            }
                            onContainsMouseChanged: {
                                if (containsMouse) root.selectedIndex = index
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
                    opacity: 0.65
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
}
