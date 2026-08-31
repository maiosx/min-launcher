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
    property int selectedIndex: -1
    property string filterText: ""

    readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : "min-launcher"
    readonly property var allTools: Tools.flatTools()
    readonly property var categories: Tools.categories

    property color bg: "#0a0a0c"
    property color cardBg: "#111114"
    property color textPrimary: "#f0f0f2"
    property color textMuted: "#8a8a96"
    property color accent: "#7c6af7"
    property color hoverBg: "#1c1c22"
    property color borderColor: "#2a2a32"
    property int cornerRadius: 16

    function open(payloadJson) {
        root.opened = true
        root.selectedIndex = -1
        root.filterText = ""
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    function close() {
        root.opened = false
        root.selectedIndex = -1
        root.filterText = ""
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

    // Prefer native desktop app on Omarchy, then bare exec, then URL
    function launchTool(tool) {
        if (!tool) return

        // 1) Desktop entry via gtk-launch under uwsm-app (Omarchy standard)
        if (tool.desktop && String(tool.desktop).length > 0) {
            var deskId = String(tool.desktop)
            if (deskId.indexOf(".desktop") < 0)
                deskId = deskId + ".desktop"
            Quickshell.execDetached([
                "sh", "-c",
                "setsid -f uwsm-app -- gtk-launch \"$1\" >/dev/null 2>&1 || setsid -f gtk-launch \"$1\" >/dev/null 2>&1",
                "sh", deskId
            ])
            dismiss()
            return
        }

        // 2) Raw command (session-scoped via uwsm-app when possible)
        if (tool.exec && String(tool.exec).length > 0) {
            var cmd = String(tool.exec)
            Quickshell.execDetached([
                "sh", "-c",
                "setsid -f uwsm-app -- bash -c \"$1\" >/dev/null 2>&1 || setsid -f bash -c \"$1\" >/dev/null 2>&1",
                "sh", cmd
            ])
            dismiss()
            return
        }

        // 3) Web fallback
        if (tool.url && String(tool.url).length > 0) {
            Qt.openUrlExternally(String(tool.url))
            dismiss()
        }
    }

    function launchAt(index) {
        var flat = root.allTools
        if (index >= 0 && index < flat.length)
            launchTool(flat[index])
    }

    PanelWindow {
        id: panel
        visible: root.opened
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
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
            width: Math.min(980, parent.width - 48)
            height: Math.min(720, parent.height - 64)
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
                spacing: 18

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Design Engineer Tools"
                        color: root.textPrimary
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                        font.family: "Inter, system-ui, sans-serif"
                    }
                    Text {
                        text: "Native apps when installed · web links otherwise"
                        color: root.textMuted
                        font.pixelSize: 13
                        font.family: "Inter, system-ui, sans-serif"
                    }
                }

                Flickable {
                    id: flick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: gridColumn.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 6
                    }

                    ColumnLayout {
                        id: gridColumn
                        width: flick.width
                        spacing: 22

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20
                            Layout.alignment: Qt.AlignTop

                            CategoryBlock {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 2
                                title: "Inspiration"
                                tools: root.categories[0].tools
                                columns: 2
                            }

                            CategoryBlock {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                title: "AI Code"
                                tools: root.categories[1].tools
                                columns: 1
                            }

                            CategoryBlock {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                title: "Components"
                                tools: root.categories[2].tools
                                columns: 1
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20
                            Layout.alignment: Qt.AlignTop

                            CategoryBlock {
                                Layout.fillWidth: true
                                title: "Web Utility"
                                tools: root.categories[3].tools
                                columns: 1
                            }
                            CategoryBlock {
                                Layout.fillWidth: true
                                title: "Desktop Utility"
                                tools: root.categories[4].tools
                                columns: 1
                            }
                            CategoryBlock {
                                Layout.fillWidth: true
                                title: "Video & Capture"
                                tools: root.categories[5].tools
                                columns: 1
                            }
                            CategoryBlock {
                                Layout.fillWidth: true
                                title: "Whiteboard"
                                tools: root.categories[6].tools
                                columns: 1
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Esc to close  ·  Native apps via uwsm-app / gtk-launch"
                    color: root.textMuted
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.7
                }
            }
        }

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: root.opened
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.dismiss()
                    event.accepted = true
                }
            }
        }
    }

    component CategoryBlock: ColumnLayout {
        id: catRoot
        property string title: ""
        property var tools: []
        property int columns: 1
        spacing: 8

        Text {
            text: catRoot.title
            color: root.textPrimary
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.family: "Inter, system-ui, sans-serif"
            Layout.bottomMargin: 2
        }

        Flow {
            Layout.fillWidth: true
            spacing: 2
            flow: Flow.TopToBottom
            height: Math.ceil(catRoot.tools.length / Math.max(1, catRoot.columns)) * 26

            Repeater {
                model: catRoot.tools

                Rectangle {
                    width: catRoot.columns > 1
                           ? (catRoot.width - 8) / catRoot.columns
                           : catRoot.width
                    height: 24
                    radius: 6
                    color: toolMa.containsMouse ? root.hoverBg : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 6

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: accentFor(index)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: modelData.name
                            color: toolMa.containsMouse ? root.textPrimary : root.textMuted
                            font.pixelSize: 12
                            font.family: "Inter, system-ui, sans-serif"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: !!(modelData.desktop || modelData.exec)
                            text: "⌘"
                            color: root.accent
                            font.pixelSize: 10
                            opacity: 0.6
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: toolMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchTool(modelData)
                    }
                }
            }
        }

        function accentFor(i) {
            var palette = [
                "#60a5fa", "#a78bfa", "#f472b6", "#34d399",
                "#fbbf24", "#fb7185", "#22d3ee", "#c084fc",
                "#4ade80", "#f97316"
            ]
            return palette[i % palette.length]
        }
    }
}
