import QtQuick
import QtTest
import org.kde.newstuff as NewStuff
import "../../contents/ui" as UI

Item {
    id: root
    width: 400
    height: 300

    Component {
        id: fakeEngine
        QtObject {
            property string configFile: ""
            property int filter: 0
            property int detailsRequests: 0
            property int installs: 0
            onConfigFileChanged: filter = 0
            signal signalProvidersLoaded
            signal signalEntriesLoaded(var entries)
            signal signalEntryEvent(var entry, int event)
            signal errorCode(int code, string message, var metadata)
            function __createEntry(provider, id) {
                return {
                    providerId: provider,
                    uniqueId: id,
                    status: NewStuff.Entry.Updateable
                }
            }
            function updateEntryContents(entry) {
                detailsRequests++
            }
            function installLatest(entry) {
                installs++
            }
        }
    }
    Component {
        id: updaterFactory
        UI.StoreUpdater {}
    }

    TestCase {
        id: test
        name: "StoreUpdater"
        when: windowShown
        property var updater
        SignalSpy {
            id: finishedSpy
            signalName: "completed"
        }

        function init() {
            updater = createTemporaryObject(updaterFactory, root, {
                plugin: {
                    id: "org.test",
                    name: "Test widget",
                    update: {
                        catalog: "plasmoids",
                        storeId: "9"
                    }
                },
                dialogParent: root,
                engineComponent: fakeEngine
            })
            verify(updater !== null)
            finishedSpy.target = updater
            finishedSpy.clear()
            compare(updater.engine.filter, 0)
            updater.engine.signalProvidersLoaded()
            updater.engine.signalEntriesLoaded([
                {
                    providerId: "api.kde-look.org",
                    uniqueId: "9",
                    status: NewStuff.Entry.Updateable
                }
            ])
            compare(updater.engine.filter, 2)
            compare(updater.engine.configFile, "plasmoids.knsrc")
            compare(updater.engine.detailsRequests, 1)
        }

        function test_download_completes_only_after_installed_status() {
            updater.engine.signalEntryEvent(updater.entry, NewStuff.Entry.DetailsLoadedEvent)
            compare(updater.engine.installs, 1)
            compare(finishedSpy.count, 0)
            var installed = {
                providerId: "api.kde-look.org",
                uniqueId: "9",
                status: NewStuff.Entry.Installed
            }
            updater.engine.signalEntryEvent(installed, NewStuff.Entry.StatusChangedEvent)
            compare(finishedSpy.count, 1)
            compare(finishedSpy.signalArguments[0][0], true)
            updater.engine.signalEntryEvent(installed, NewStuff.Entry.StatusChangedEvent)
            compare(finishedSpy.count, 1)
        }

        function test_other_entry_does_not_complete_update() {
            updater.engine.signalEntryEvent(updater.entry, NewStuff.Entry.DetailsLoadedEvent)
            updater.engine.signalEntryEvent({
                providerId: "api.kde-look.org",
                uniqueId: "10",
                status: NewStuff.Entry.Installed
            }, NewStuff.Entry.StatusChangedEvent)
            compare(finishedSpy.count, 0)
        }

        function test_error_keeps_failure_message() {
            updater.engine.errorCode(1, "Download failed", {})
            compare(finishedSpy.count, 1)
            compare(finishedSpy.signalArguments[0][0], false)
            compare(finishedSpy.signalArguments[0][1], "Download failed")
        }

        function test_unknown_installation_is_refused() {
            updater.engine.signalEntryEvent({
                providerId: "api.kde-look.org",
                uniqueId: "9",
                status: NewStuff.Entry.Downloadable
            }, NewStuff.Entry.DetailsLoadedEvent)
            compare(updater.engine.installs, 0)
            compare(finishedSpy.signalArguments[0][0], false)
        }

        function test_already_updated_needs_no_download() {
            updater.engine.signalEntryEvent({
                providerId: "api.kde-look.org",
                uniqueId: "9",
                status: NewStuff.Entry.Installed
            }, NewStuff.Entry.DetailsLoadedEvent)
            compare(updater.engine.installs, 0)
            compare(finishedSpy.signalArguments[0][0], true)
        }
    }
}
