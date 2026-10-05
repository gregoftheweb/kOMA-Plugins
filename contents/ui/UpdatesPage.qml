/*
    "Updates" page of kOMA Plugins. Shows what the last update check found.
    The check itself (komaplugin refresh) runs
    from a systemd timer at login and hourly; "Check now" runs it on request.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

ColumnLayout {
    id: page

    // the PlasmoidItem from main.qml: state (busyId, updatable, ...) and runCli()
    required property var host
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: page.host.checkedAtText() + "  ·  checks run at login and hourly"
            opacity: 0.7
            elide: Text.ElideRight
        }
        PlasmaComponents.BusyIndicator {
            visible: page.host.busyId === "refresh" || page.host.busyId === "update-all"
            running: visible
            Layout.preferredHeight: checkNow.height
            Layout.preferredWidth: checkNow.height
        }
        PlasmaComponents.Button {
            id: checkNow
            text: "Check now"
            icon.name: "view-refresh"
            enabled: page.host.busyId === ""
            onClicked: page.host.runCli(["refresh"], "refresh")
        }
        PlasmaComponents.Button {
            visible: page.host.updatable.some(p => p.update.kind === "git")
            text: "Update git plugins"
            icon.name: "update-none"
            enabled: page.host.busyId === ""
            onClicked: page.host.runCli(["update", "--all", "--git-only", "--yes"], "update-all")
        }
    }

    PlasmaComponents.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth - list.leftMargin - list.rightMargin

        contentItem: ListView {
            id: list
            model: page.host.updatable
            clip: true
            leftMargin: Kirigami.Units.smallSpacing
            rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 4
                visible: list.count === 0
                iconName: "checkmark"
                text: "Everything is up to date"
                explanation: "Plugins from the KDE Store and git are checked for new versions."
            }

            delegate: PlasmaComponents.ItemDelegate {
                id: row
                required property var modelData
                width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: row.modelData.update.current + "  →  " + row.modelData.update.latest + "  ·  " + (row.modelData.update.kind === "git" ? row.modelData.update.behind + " new commit" + (row.modelData.update.behind > 1 ? "s" : "") : "KDE Store")
                            opacity: 0.7
                            font: Kirigami.Theme.smallFont
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.Label {  // what changed (git)
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: (row.modelData.update.log || "").split("\n").map(l => "• " + l.replace(/^\S+ /, "")).join("\n").replace(/^• $/, "")
                            opacity: 0.7
                            font: Kirigami.Theme.smallFont
                            wrapMode: Text.WordWrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                        }
                    }
                    PlasmaComponents.BusyIndicator {
                        visible: page.host.busyId === row.modelData.id
                        running: visible
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    }
                    PlasmaComponents.Button {
                        visible: page.host.busyId !== row.modelData.id
                        enabled: page.host.busyId === ""
                        text: "Update"
                        icon.name: "update-none"
                        onClicked: page.host.act("update", row.modelData.id)
                    }
                    PlasmaComponents.Label {
                        visible: page.host.busyId === row.modelData.id && page.host.updateStatus.length > 0
                        text: page.host.updateStatus
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }
    }
}
