/*
    Update a store entry, or install a new one (plugin.fresh), with KDE's own
    installer and registry. Created on demand.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.newstuff as NewStuff

Item {
    id: updater
    required property var plugin
    required property Item dialogParent
    property var entry: null
    property bool installing: false
    property bool finished: false
    // a new install from the local store catalog rather than an update
    readonly property bool fresh: !!plugin.fresh
    readonly property var engine: engineLoader.item
    // Injectable for offline tests; the default is KDE's asynchronous engine.
    property Component engineComponent: Component {
        NewStuff.Engine {}
    }
    signal completed(bool success, string message)
    signal progress(string message)

    function finish(success, message) {
        if (finished)
            return
        finished = true
        timeout.stop()
        completed(success, message)
    }

    function loadEntries(entries) {
        if (finished || entry || fresh)
            return
        for (var i = 0; i < entries.length; ++i) {
            if (entries[i].providerId === "api.kde-look.org" && entries[i].uniqueId === String(plugin.update.storeId)) {
                // Use the registry-backed entry, including its installed files.
                // __createEntry() only creates an uninstalled placeholder.
                entry = entries[i]
                console.log("[kOMA Store Update] matched", entry.uniqueId, "status", entry.status)
                progress("Checking update…")
                engine.updateEntryContents(entry)
                return
            }
        }
    }

    function handleEntryEvent(changedEntry, event) {
        if (finished || !entry || changedEntry.uniqueId !== entry.uniqueId || changedEntry.providerId !== entry.providerId)
            return
        if (event === NewStuff.Entry.DetailsLoadedEvent && !installing) {
            if (changedEntry.status === NewStuff.Entry.Installed) {
                finish(true, plugin.name + (fresh ? " is already installed" : " is already up to date"))
            } else if (changedEntry.status === NewStuff.Entry.Updateable || (fresh && changedEntry.status === NewStuff.Entry.Downloadable)) {
                installing = true
                console.log("[kOMA Store Update] installing", changedEntry.uniqueId)
                progress("Downloading and installing…")
                if (typeof engine.installLatest === "function")
                    engine.installLatest(changedEntry)
                else
                    engine.install(changedEntry, -1)
            } else {
                finish(false, fresh ? "KDE Store could not find " + plugin.name : "KDE Store could not match the installed copy of " + plugin.name)
            }
        } else if (event === NewStuff.Entry.StatusChangedEvent && installing) {
            if (changedEntry.status === NewStuff.Entry.Installed)
                finish(true, (fresh ? "Installed " : "Updated ") + plugin.name)
            else if (changedEntry.status === NewStuff.Entry.Updateable || changedEntry.status === NewStuff.Entry.Downloadable)
                finish(false, (fresh ? "Could not install " : "Could not update ") + plugin.name + "; please try again")
        }
    }

    Loader {
        id: engineLoader
        sourceComponent: updater.engineComponent
        onLoaded: {
            item.configFile = updater.plugin.update.catalog + ".knsrc"
        }
    }
    Connections {
        target: engineLoader.item
        function onSignalProvidersLoaded() {
            if (updater.fresh) {
                // Ask for just this entry, as KDE's own "show entry" link does.
                updater.entry = updater.engine.__createEntry("api.kde-look.org", String(updater.plugin.update.storeId))
                updater.progress("Fetching details…")
                updater.engine.updateEntryContents(updater.entry)
                return
            }
            // Loading the catalog resets the search filter. Set it after the
            // providers initialize, so we query updates rather than popular items.
            console.log("[kOMA Store Update] providers ready; querying updates")
            updater.engine.filter = 2
            updater.progress("Finding update…")
        }
        function onSignalEntriesLoaded(entries) {
            console.log("[kOMA Store Update] entries loaded", entries.length)
            updater.loadEntries(entries)
        }
        function onSignalEntryEvent(changedEntry, event) {
            updater.handleEntryEvent(changedEntry, event)
        }
        function onErrorCode(code, message, metadata) {
            updater.finish(false, message || "KDE Store update failed")
        }
    }
    NewStuff.QuestionAsker {
        parent: updater.dialogParent
    }
    Timer {
        id: timeout
        interval: 180000
        running: true
        onTriggered: updater.finish(false, "KDE Store update timed out; please try again")
    }
}
