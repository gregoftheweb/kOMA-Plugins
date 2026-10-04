/*
    "Get new" page of kOMA Plugins: the KDE Store per plugin type (KDE's own
    store window, so installs are tracked like System Settings' "Get New"),
    and adding a plugin straight from a git repo.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

PlasmaComponents.ScrollView {
    id: page

    // the PlasmoidItem from main.qml: state (busyId, updatable, ...) and runCli()
    required property var host
    contentWidth: availableWidth

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

    ColumnLayout {
        width: page.availableWidth
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.leftMargin: Kirigami.Units.largeSpacing
            level: 3
            text: "KDE Store"
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            text: "Opens KDE's store window for that kind of plugin. What you install there shows up under Installed."
            wrapMode: Text.WordWrap
            opacity: 0.7
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            columns: 2
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing
            Repeater {
                model: page.storeTypes
                delegate: PlasmaComponents.Button {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.label
                    icon.name: modelData.icon
                    enabled: page.host.busyId === ""
                    onClicked: page.host.runCli(["browse", modelData.type], "browse:" + modelData.type)
                    PlasmaComponents.BusyIndicator {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: Kirigami.Units.smallSpacing
                        }
                        height: parent.height * 0.7
                        width: height
                        visible: page.host.busyId === "browse:" + parent.modelData.type
                        running: visible
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        Kirigami.Heading {
            Layout.leftMargin: Kirigami.Units.largeSpacing
            level: 3
            text: "Add from git"
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            text: "Plugins run as unsandboxed code with your user's access. Only add repos you trust, and read them first. They arrive switched off unless you tick the box."
            wrapMode: Text.WordWrap
            opacity: 0.7
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing
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
            Layout.fillHeight: true
        }
    }
}
