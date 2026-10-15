/*
    "Get new" page of kOMA Plugins: the KDE Store, browsed from a local copy of
    its catalog (`komaplugin sync`, twice a day) so searching and scrolling need
    no network. Installs go through KDE's own installer, so they are tracked like
    System Settings' "Get New". Also: adding a plugin straight from a git repo.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: page

    // the PlasmoidItem from main.qml: state (busyId, updatable, ...) and runCli()
    required property var host
    property string mode: "store"   // store | git
    property var catalog: []
    property string syncedAt: ""
    property bool catalogLoaded: false
    // Store installs have no sync timer (that comes with bin/install), so the page
    // refreshes a copy older than this itself; at most once per interval, even if it fails
    readonly property int staleMs: 12 * 3600 * 1000
    property double autoSyncedAt: 0

    readonly property var storeTypes: [
        {
            type: "widget",
            label: "Widgets",
            icon: "plasma"
        },
        {
            type: "kwin-script",
            label: "KWin scripts",
            icon: "application-x-javascript"
        },
        {
            type: "effect",
            label: "Effects",
            icon: "preferences-desktop-effects"
        },
        {
            type: "decoration",
            label: "Window decorations",
            icon: "preferences-system-windows"
        },
        {
            type: "wallpaper",
            label: "Wallpaper plugins",
            icon: "preferences-desktop-wallpaper"
        },
        {
            type: "window-switcher",
            label: "Window switchers",
            icon: "preferences-system-tabbox"
        }
    ]
    readonly property var sorts: [
        {
            label: "Most downloaded",
            key: "downloads"
        },
        {
            label: "Recently updated",
            key: "changed"
        },
        {
            label: "Highest rated",
            key: "score"
        },
        {
            label: "Name",
            key: "name"
        }
    ]
    readonly property var currentType: storeTypes[typeBox.currentIndex]
    readonly property var shown: {
        var words = search.text.toLowerCase().split(/\s+/).filter(w => w.length > 0)
        var type = currentType.type
        var key = sorts[sortBox.currentIndex].key
        var items = catalog.filter(i => i.type === type && words.every(w => (i.name + " " + i.author + " " + i.summary).toLowerCase().indexOf(w) >= 0))
        return items.sort(function (a, b) {
            if (key === "name")
                return a.name.localeCompare(b.name)
            return a[key] < b[key] ? 1 : a[key] > b[key] ? -1 : 0
        })
    }

    function load() {
        host.cliOutput(["store", "--json"], function (code, out) {
            try {
                const data = JSON.parse(out || "{}")
                page.catalog = data.items || []
                page.syncedAt = data.syncedAt || ""
            } catch (e) {
                page.catalog = []
            }
            page.catalogLoaded = true
            page.syncIfStale()
        })
    }

    function syncIfStale() {
        const now = Date.now()
        const age = syncedAt ? now - new Date(syncedAt).getTime() : Infinity
        if (age < staleMs || now - autoSyncedAt < staleMs || host.busyId !== "")
            return
        autoSyncedAt = now
        host.runCli(["sync", "--quiet"], "sync")
    }

    function syncedText() {
        if (!syncedAt)
            return "No local copy of the store yet"
        var d = new Date(syncedAt)
        return "Store copy from " + Qt.formatDateTime(d, d.toDateString() === new Date().toDateString() ? "h:mm AP" : "MMM d, h:mm AP")
    }

    // Read once; afterwards only syncs, installs and removals reload it (storeGeneration)
    onVisibleChanged: if (visible && !catalogLoaded)
        load()
    Connections {
        target: page.host
        function onStoreGenerationChanged() {
            page.load()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {  // which source
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            PlasmaComponents.ToolButton {
                text: "KDE Store"
                icon.name: "get-hot-new-stuff"
                checkable: true
                checked: page.mode === "store"
                onClicked: page.mode = "store"
            }
            PlasmaComponents.ToolButton {
                text: "From git"
                icon.name: "vcs-normal"
                checkable: true
                checked: page.mode === "git"
                onClicked: page.mode = "git"
            }
            Item {
                Layout.fillWidth: true
            }
        }

        // ---- KDE Store, from the local catalog --------------------------------
        RowLayout {
            visible: page.mode === "store"
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            PlasmaComponents.ComboBox {
                id: typeBox
                objectName: "typeBox"
                model: page.storeTypes
                textRole: "label"
            }
            PlasmaComponents.TextField {
                id: search
                objectName: "searchField"
                Layout.fillWidth: true
                placeholderText: "Search " + page.currentType.label.toLowerCase()
                clearButtonShown: true
            }
            PlasmaComponents.ComboBox {
                id: sortBox
                objectName: "sortBox"
                model: page.sorts
                textRole: "label"
            }
        }

        PlasmaComponents.ScrollView {
            visible: page.mode === "store"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth - storeList.leftMargin - storeList.rightMargin

            contentItem: ListView {
                id: storeList
                model: page.shown
                clip: true
                reuseItems: true
                leftMargin: Kirigami.Units.smallSpacing
                rightMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: page.catalogLoaded && storeList.count === 0
                    icon.name: page.syncedAt ? "edit-none" : "get-hot-new-stuff"
                    text: page.syncedAt ? "Nothing matches" : "No local copy of the store yet"
                    explanation: page.syncedAt ? "" : "Download the KDE Store catalog once (about a minute); after that it refreshes twice a day."
                    helpfulAction: page.syncedAt ? null : downloadAction
                }

                delegate: PlasmaComponents.ItemDelegate {
                    id: item
                    required property var modelData
                    readonly property bool busy: page.host.busyId === "store:" + modelData.storeId
                    width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                    hoverEnabled: true

                    // Top-aligned, like the Installed list, so hovering doesn't move anything
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing

                        Item {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 3.2
                            Image {
                                id: thumb
                                anchors.fill: parent
                                source: item.modelData.thumb ? "file://" + item.modelData.thumb : ""
                                sourceSize.width: width
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                clip: true
                            }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Kirigami.Units.iconSizes.medium
                                height: width
                                visible: thumb.status !== Image.Ready
                                source: page.currentType.icon
                                opacity: 0.6
                            }
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            Layout.fillWidth: true
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: item.modelData.name
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                PlasmaComponents.Label {
                                    text: item.modelData.version || ""
                                    opacity: 0.7
                                    font: Kirigami.Theme.smallFont
                                }
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: item.busy && page.host.updateStatus ? page.host.updateStatus : item.modelData.author + "  ·  " + Number(item.modelData.downloads).toLocaleString(Qt.locale(), "f", 0) + " downloads  ·  ★ " + (item.modelData.score / 10).toFixed(1) + "  ·  " + item.modelData.changed
                                opacity: 0.7
                                font: Kirigami.Theme.smallFont
                                elide: Text.ElideRight
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: item.modelData.summary
                                opacity: 0.7
                                font: Kirigami.Theme.smallFont
                                wrapMode: Text.WordWrap
                                maximumLineCount: item.hovered ? 4 : 2
                                elide: Text.ElideRight
                            }
                        }

                        PlasmaComponents.BusyIndicator {
                            Layout.alignment: Qt.AlignTop
                            visible: item.busy
                            running: visible
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }
                        PlasmaComponents.ToolButton {
                            Layout.alignment: Qt.AlignTop
                            visible: !item.busy && item.hovered && item.modelData.page.length > 0
                            icon.name: "internet-web-browser"
                            onClicked: Qt.openUrlExternally(item.modelData.page)
                            PlasmaComponents.ToolTip {
                                text: "Open its store page"
                            }
                        }
                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignTop
                            visible: !item.busy && item.modelData.installed
                            text: "Installed"
                            opacity: 0.7
                        }
                        PlasmaComponents.Button {
                            Layout.alignment: Qt.AlignTop
                            visible: !item.busy && !item.modelData.installed
                            enabled: page.host.busyId === ""
                            text: "Install"
                            icon.name: "download"
                            onClicked: page.host.installFromStore(item.modelData)
                        }
                    }
                }
            }
        }

        RowLayout {
            visible: page.mode === "store"
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: page.host.busyId === "sync" ? "Downloading the store catalog…" : page.syncedText() + (page.syncedAt ? "  ·  " + page.shown.length + " shown" : "")
                opacity: 0.7
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
            }
            PlasmaComponents.BusyIndicator {
                visible: page.host.busyId === "sync"
                running: visible
                Layout.preferredHeight: syncButton.height
                Layout.preferredWidth: syncButton.height
            }
            PlasmaComponents.ToolButton {
                id: syncButton
                action: downloadAction
                display: PlasmaComponents.ToolButton.IconOnly
                PlasmaComponents.ToolTip {
                    text: "Refresh the local copy of the store now"
                }
            }
            PlasmaComponents.ToolButton {
                icon.name: "window-new"
                enabled: page.host.busyId === ""
                onClicked: page.host.runCli(["browse", page.currentType.type], "browse:" + page.currentType.type)
                PlasmaComponents.ToolTip {
                    text: "Open KDE's own store window (live, slower)"
                }
            }
        }

        Kirigami.Action {
            id: downloadAction
            text: "Download catalog"
            icon.name: "view-refresh"
            enabled: page.host.busyId === ""
            onTriggered: page.host.runCli(["sync", "--quiet"], "sync")
        }

        // ---- From git ----------------------------------------------------------
        ColumnLayout {
            visible: page.mode === "git"
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: "Plugins run as unsandboxed code with your user's access. Only add repos you trust, and read them first. They arrive switched off unless you tick the box."
                wrapMode: Text.WordWrap
                opacity: 0.7
            }
            PlasmaComponents.TextField {
                id: url
                Layout.fillWidth: true
                placeholderText: "https://github.com/someone/plasma-widget"
                onAccepted: add.clicked()
            }
            PlasmaComponents.TextField {
                id: subpath
                Layout.fillWidth: true
                placeholderText: "Folder inside the repo (only if it holds several plugins)"
            }
            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.CheckBox {
                    id: enableAfter
                    Layout.fillWidth: true
                    text: "Turn it on after installing"
                }
                PlasmaComponents.BusyIndicator {
                    visible: page.host.busyId === "add"
                    running: visible
                    Layout.preferredHeight: add.height
                    Layout.preferredWidth: add.height
                }
                PlasmaComponents.Button {
                    id: add
                    text: "Add"
                    icon.name: "list-add"
                    enabled: url.text.trim().length > 0 && page.host.busyId === ""
                    onClicked: {
                        var args = ["add", url.text.trim(), "--yes"]
                        if (subpath.text.trim())
                            args.push("--path", subpath.text.trim())
                        if (enableAfter.checked)
                            args.push("--enable")
                        page.host.showInstalledOnSuccess = true
                        page.host.runCli(args, "add")
                    }
                }
            }
        }
        Item {
            visible: page.mode === "git"
            Layout.fillHeight: true
        }
    }
}
