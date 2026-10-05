/*
    kOMA Plugins — Omarchy-style plugin manager for KDE Plasma 6.

    The panel icon shows a badge when a plugin is in trouble; the popup lists
    installed plugins (widgets, KWin scripts, effects, decorations, ...) with
    their status. All data comes from the bundled `komaplugin` CLI
    (contents/code/komaplugin), run through Plasma's "executable" data engine.
    Store updates use KDE's installer on demand; listing reads the local cache.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    property var plugins: []
    property bool loading: false
    property string lastError: ""
    property string busyId: ""          // plugin an action is running on
    property string confirmId: ""       // plugin waiting for "really remove?"
    property string message: ""
    property bool messageIsError: false
    readonly property string selfId: "com.columbiafoundry.komaplugins"
    property string page: "installed"   // installed | getnew
    property bool showInstalledOnSuccess: false
    property var storeUpdate: null
    property string updateStatus: ""
    readonly property bool showAll: Plasmoid.configuration.showAll
    readonly property int errorCount: plugins.filter(p => p.status === "error").length
    readonly property int activeCount: plugins.filter(p => p.status === "active").length
    readonly property var updatable: plugins.filter(p => !!p.update)
    readonly property int updateCount: updatable.length
    property string checkedAt: ""        // when the hourly update check last ran
    readonly property string cli: decodeURIComponent(Qt.resolvedUrl("../code/komaplugin").toString().replace("file://", ""))

    switchWidth: Kirigami.Units.gridUnit * 16
    switchHeight: Kirigami.Units.gridUnit * 14
    toolTipMainText: "kOMA Plugins"
    toolTipSubText: (errorCount > 0 ? errorCount + " plugin" + (errorCount > 1 ? "s" : "") + " failed to load" : plugins.length + " add-ons, " + activeCount + " active") + (updateCount > 0 ? "\n" + updateCount + " update" + (updateCount > 1 ? "s" : "") + " available" : "")
    Plasmoid.icon: "com.columbiafoundry.komaplugins"
    Plasmoid.status: errorCount > 0 ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.ActiveStatus

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function refresh() {
        if (loading)
            return
        loading = true
        var cmd = "python3 " + shellQuote(cli) + " list --json" + (showAll ? " --all" : "")
        runner.connectSource(cmd + " # " + Date.now())
        checkInfo.connectSource("python3 " + shellQuote(cli) + " updates --json # " + Date.now())
    }

    P5Support.DataSource {
        id: checkInfo
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source)
            try {
                root.checkedAt = JSON.parse(String(data.stdout || "{}")).checkedAt || ""
            } catch (e) {}
        }
    }

    function checkedAtText() {
        if (!checkedAt)
            return "not checked yet"
        var d = new Date(checkedAt)
        return "last checked " + Qt.formatDateTime(d, d.toDateString() === new Date().toDateString() ? "h:mm AP" : "MMM d, h:mm AP")
    }

    // Every action is a CLI call that prints one line; busyKey marks what's running.
    function runCli(args, busyKey) {
        if (busyId)
            return
        busyId = busyKey
        confirmId = ""
        var cmd = "python3 " + shellQuote(cli) + " " + args.map(shellQuote).join(" ")
        actor.connectSource(cmd + " # " + Date.now())
    }
    // enable / disable / use / remove / clone / reload on one plugin
    function act(action, pluginId) {
        var plugin = plugins.find(p => p.id === pluginId)
        if (action === "update" && plugin && plugin.update.kind === "store") {
            if (busyId)
                return
            busyId = pluginId
            updateStatus = "Connecting to KDE Store…"
            storeUpdate = plugin
            return
        }
        var args = [action, pluginId]
        if (action !== "use" && action !== "reload")
            args.push("--yes")
        runCli(args, pluginId)
    }

    P5Support.DataSource {
        id: actor
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source)
            var err = String(data.stderr || "").trim()
            var out = String(data.stdout || "").trim()
            root.messageIsError = data["exit code"] !== 0
            if (!root.messageIsError && root.showInstalledOnSuccess)
                root.page = "installed"
            root.showInstalledOnSuccess = false
            root.message = (root.messageIsError ? err || out : out || err).replace(/^komaplugin: /, "")
            messageTimer.restart()
            root.busyId = ""
            root.loading = false
            root.refresh()
        }
    }

    Timer {
        id: messageTimer
        interval: 8000
        onTriggered: root.message = ""
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source)
            root.loading = false
            try {
                root.plugins = JSON.parse(String(data.stdout || "[]"))
                root.lastError = ""
            } catch (e) {
                root.lastError = String(data.stderr || e).trim()
            }
        }
    }

    Timer {
        interval: Math.max(1, Plasmoid.configuration.refreshMinutes) * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    onExpandedChanged: if (root.expanded)
        refresh()
    onShowAllChanged: refresh()

    compactRepresentation: MouseArea {
        onClicked: root.expanded = !root.expanded
        hoverEnabled: true
        Item {  // kOMA mark: "O" in the theme highlight color, "k" in the text color
            id: mark
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            opacity: parent.containsMouse ? 1 : 0.92
            Kirigami.Icon {
                anchors.fill: parent
                source: Qt.resolvedUrl("../icons/koma-ring.svg")
                isMask: true
                color: Kirigami.Theme.highlightColor
            }
            Kirigami.Icon {
                anchors.fill: parent
                source: Qt.resolvedUrl("../icons/koma-k.svg")
                isMask: true
                color: Kirigami.Theme.textColor
            }
        }
        Rectangle {
            visible: root.errorCount > 0 || root.updateCount > 0
            anchors {
                right: parent.right
                top: parent.top
            }
            width: Math.max(height, badgeText.implicitWidth + Kirigami.Units.smallSpacing)
            height: Math.round(parent.height * 0.45)
            radius: height / 2
            color: root.errorCount > 0 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
            border.width: Math.max(1, Math.round(height / 10))  // separates the badge from the ring
            border.color: Kirigami.Theme.backgroundColor
            PlasmaComponents.Label {
                id: badgeText
                anchors.centerIn: parent
                text: root.errorCount > 0 ? root.errorCount : root.updateCount
                font.pixelSize: parent.height * 0.75
                color: root.errorCount > 0 ? "white" : Kirigami.Theme.highlightedTextColor
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        id: popup

        Loader {
            active: root.storeUpdate !== null
            sourceComponent: StoreUpdater {
                plugin: root.storeUpdate
                dialogParent: popup
                onProgress: message => root.updateStatus = message
                onCompleted: (success, message) => {
                    var pluginId = root.storeUpdate.id
                    root.messageIsError = !success
                    root.message = message
                    messageTimer.restart()
                    root.busyId = ""
                    root.updateStatus = ""
                    // Defer destroying the engine until its signal handler returns.
                    Qt.callLater(function () {
                        root.storeUpdate = null
                        if (success)
                            root.runCli(["finish-update", pluginId], pluginId)
                        else
                            root.refresh()
                    })
                }
            }
        }

        Layout.minimumWidth: Kirigami.Units.gridUnit * 24
        Layout.minimumHeight: Kirigami.Units.gridUnit * 20
        Layout.preferredWidth: Kirigami.Units.gridUnit * 34
        Layout.preferredHeight: Kirigami.Units.gridUnit * 28
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 1
                    text: "Manage Plugins"
                    elide: Text.ElideRight
                    Layout.minimumWidth: Math.min(implicitWidth, Kirigami.Units.gridUnit * 6)
                }
                PlasmaComponents.ToolButton {
                    text: "Installed"
                    icon.name: "view-list-details"
                    checkable: true
                    checked: root.page === "installed"
                    onClicked: root.page = "installed"
                }
                PlasmaComponents.ToolButton {
                    text: "Get new"
                    icon.name: "get-hot-new-stuff"
                    checkable: true
                    checked: root.page === "getnew"
                    onClicked: root.page = "getnew"
                }
                PlasmaComponents.ToolButton {
                    text: root.updateCount > 0 ? "Updates (" + root.updateCount + ")" : "Updates"
                    icon.name: "update-none"
                    checkable: true
                    checked: root.page === "updates"
                    onClicked: root.page = "updates"
                }
                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    enabled: !root.loading
                    onClicked: root.refresh()
                    PlasmaComponents.ToolTip {
                        text: "Refresh"
                    }
                }
            }
        }

        Kirigami.InlineMessage {
            id: banner
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Kirigami.Units.smallSpacing
            }
            visible: root.message.length > 0
            type: root.messageIsError ? Kirigami.MessageType.Error : Kirigami.MessageType.Positive
            text: root.message
            showCloseButton: true
            onVisibleChanged: if (!visible)
                root.message = ""
        }

        UpdatesPage {
            host: root
            visible: root.page === "updates"
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                top: banner.visible ? banner.bottom : parent.top
            }
        }

        GetNewPage {
            host: root
            visible: root.page === "getnew"
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                top: banner.visible ? banner.bottom : parent.top
            }
        }

        RowLayout {  // Installed: which plugins to show
            id: scopeRow
            visible: root.page === "installed"
            anchors {
                left: parent.left
                right: parent.right
                top: banner.visible ? banner.bottom : parent.top
                leftMargin: Kirigami.Units.largeSpacing
                rightMargin: Kirigami.Units.largeSpacing
                topMargin: Kirigami.Units.smallSpacing
            }
            PlasmaComponents.Label {
                text: "Show"
                opacity: 0.7
            }
            PlasmaComponents.ToolButton {
                text: "Add-ons"
                checkable: true
                checked: !root.showAll
                onClicked: Plasmoid.configuration.showAll = false
                PlasmaComponents.ToolTip {
                    text: "What you added: store, git, local and third-party packages"
                }
            }
            PlasmaComponents.ToolButton {
                text: "All"
                checkable: true
                checked: root.showAll
                onClicked: Plasmoid.configuration.showAll = true
                PlasmaComponents.ToolTip {
                    text: "Also what ships with KDE"
                }
            }
            Item {
                Layout.fillWidth: true
            }
        }

        PlasmaComponents.ScrollView {
            visible: root.page === "installed"
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                top: scopeRow.bottom
            }
            contentWidth: availableWidth - list.leftMargin - list.rightMargin

            contentItem: ListView {
                id: list
                model: root.plugins
                clip: true
                topMargin: Kirigami.Units.smallSpacing
                bottomMargin: Kirigami.Units.smallSpacing
                leftMargin: Kirigami.Units.smallSpacing
                rightMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing
                section.property: "typeLabel"
                section.delegate: Kirigami.ListSectionHeader {
                    required property string section
                    width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                    text: section
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: list.count === 0 && !root.loading
                    iconName: root.lastError ? "dialog-error" : "preferences-plugin"
                    text: root.lastError ? "Couldn't read plugins" : "No add-ons installed"
                    explanation: root.lastError || "Plugins you add from the KDE Store or git show up here."
                }

                delegate: PlasmaComponents.ItemDelegate {
                    id: row
                    required property var modelData
                    width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                    hoverEnabled: true

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing

                        Rectangle {  // status dot
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Kirigami.Units.smallSpacing * 2.5
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: row.modelData.status === "active" ? Kirigami.Theme.highlightColor : row.modelData.status === "error" ? Kirigami.Theme.negativeTextColor : "transparent"
                            border.width: row.modelData.status === "off" ? 1 : 0
                            border.color: Kirigami.Theme.disabledTextColor
                        }

                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            source: row.modelData.icon || ({
                                    "widget": "plasma",
                                    "kwin-script": "application-x-javascript",
                                    "effect": "preferences-desktop-effects",
                                    "decoration": "preferences-system-windows",
                                    "wallpaper": "preferences-desktop-wallpaper",
                                    "window-switcher": "preferences-system-tabbox"
                                })[row.modelData.type] || "preferences-plugin"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                PlasmaComponents.Label {
                                    text: row.modelData.version || ""
                                    opacity: 0.7
                                    font: Kirigami.Theme.smallFont
                                }
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: row.modelData.statusText + "  ·  " + row.modelData.origin + (row.modelData.update ? "  ·  update " + row.modelData.update.latest : "") + (row.modelData.package && row.modelData.origin === "package" ? " (" + row.modelData.package + ")" : "")
                                color: row.modelData.status === "error" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                                opacity: row.modelData.status === "error" ? 1 : 0.7
                                font: Kirigami.Theme.smallFont
                                elide: Text.ElideRight
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                visible: row.hovered && text.length > 0
                                text: row.modelData.description || ""
                                opacity: 0.7
                                font: Kirigami.Theme.smallFont
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }

                        PlasmaComponents.BusyIndicator {
                            visible: root.busyId === row.modelData.id
                            running: visible
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }

                        RowLayout {  // actions
                            id: actionRow
                            readonly property var acts: row.modelData.id === root.selfId ? [] : (row.modelData.actions || [])
                            visible: root.busyId !== row.modelData.id && root.confirmId !== row.modelData.id && (row.hovered || row.activeFocus) && acts.length > 0
                            spacing: 0
                            PlasmaComponents.ToolButton {
                                id: primaryButton
                                readonly property string act: actionRow.acts.filter(a => ["enable", "disable", "use"].indexOf(a) >= 0)[0] || ""
                                visible: act !== ""
                                enabled: root.busyId === ""
                                text: ({
                                        "enable": "Enable",
                                        "disable": "Disable",
                                        "use": "Use"
                                    })[act] || ""
                                icon.name: ({
                                        "enable": "list-add",
                                        "disable": "list-remove",
                                        "use": "dialog-ok-apply"
                                    })[act] || ""
                                onClicked: root.act(act, row.modelData.id)
                                PlasmaComponents.ToolTip {
                                    text: primaryButton.act === "enable" && row.modelData.type === "widget" ? "Place on every panel (panels restart for a moment)" : primaryButton.text
                                }
                            }
                            PlasmaComponents.ToolButton {
                                visible: actionRow.acts.indexOf("update") >= 0
                                enabled: root.busyId === ""
                                icon.name: "update-none"
                                text: "Update"
                                onClicked: root.act("update", row.modelData.id)
                                PlasmaComponents.ToolTip {
                                    text: "Download and install this update"
                                }
                            }
                            PlasmaComponents.ToolButton {
                                visible: actionRow.acts.indexOf("reload") >= 0
                                enabled: root.busyId === ""
                                icon.name: "view-refresh"
                                onClicked: root.act("reload", row.modelData.id)
                                PlasmaComponents.ToolTip {
                                    text: "Reinstall from its source folder"
                                }
                            }
                            PlasmaComponents.ToolButton {
                                visible: actionRow.acts.indexOf("clone") >= 0
                                enabled: root.busyId === ""
                                icon.name: "edit-copy"
                                onClicked: root.act("clone", row.modelData.id)
                                PlasmaComponents.ToolTip {
                                    text: "Clone to your own copy to edit"
                                }
                            }
                            PlasmaComponents.ToolButton {
                                visible: actionRow.acts.indexOf("remove") >= 0
                                enabled: root.busyId === ""
                                icon.name: "edit-delete"
                                onClicked: root.confirmId = row.modelData.id
                                PlasmaComponents.ToolTip {
                                    text: "Remove"
                                }
                            }
                        }

                        RowLayout {  // inline "really remove?"
                            visible: root.confirmId === row.modelData.id
                            spacing: Kirigami.Units.smallSpacing
                            PlasmaComponents.Label {
                                text: "Remove?"
                            }
                            PlasmaComponents.Button {
                                text: "Remove"
                                icon.name: "edit-delete"
                                onClicked: root.act("remove", row.modelData.id)
                            }
                            PlasmaComponents.Button {
                                text: "Cancel"
                                onClicked: root.confirmId = ""
                            }
                        }
                    }
                }
            }
        }
    }
}
