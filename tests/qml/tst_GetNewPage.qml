import QtQuick
import QtTest
import "../../contents/ui" as UI

Item {
    id: root
    width: 600
    height: 500

    QtObject {
        id: fakeHost
        property string busyId: ""
        property string updateStatus: ""
        property int storeGeneration: 0
        property bool showInstalledOnSuccess: false
        property int loads: 0
        property var installed: []
        property string syncedAt: "2026-01-01T07:00:00"
        property var ran: []
        function cliOutput(args, callback) {
            loads++
            callback(0, JSON.stringify({
                syncedAt: fakeHost.syncedAt,
                items: [
                    {
                        storeId: "1",
                        name: "Big Clock",
                        type: "widget",
                        catalog: "plasmoids",
                        author: "ann",
                        summary: "a large clock",
                        downloads: 10,
                        score: 50,
                        changed: "2026-01-01",
                        installed: false,
                        thumb: "",
                        page: ""
                    },
                    {
                        storeId: "2",
                        name: "Weather",
                        type: "widget",
                        catalog: "plasmoids",
                        author: "bob",
                        summary: "forecast with clock",
                        downloads: 900,
                        score: 80,
                        changed: "2025-05-01",
                        installed: true,
                        thumb: "",
                        page: ""
                    },
                    {
                        storeId: "3",
                        name: "Tiler",
                        type: "kwin-script",
                        catalog: "kwinscripts",
                        author: "cy",
                        summary: "tiling",
                        downloads: 500,
                        score: 90,
                        changed: "2026-09-01",
                        installed: false,
                        thumb: "",
                        page: ""
                    }
                ]
            }), "")
        }
        function installFromStore(item) {
            installed.push(item.storeId)
        }
        function runCli(args, key) {
            ran.push(args[0])
        }
    }

    UI.GetNewPage {
        id: page
        anchors.fill: parent
        host: fakeHost
        visible: false
    }

    TestCase {
        name: "GetNewPage"
        when: windowShown

        function initTestCase() {
            page.visible = true
            tryCompare(page, "catalogLoaded", true)
        }

        function names() {
            return page.shown.map(i => i.name)
        }

        function test_filters_by_type_and_sorts_by_downloads() {
            compare(names(), ["Weather", "Big Clock"])
        }

        function test_search_matches_every_word_in_any_field() {
            var field = findChild(page, "searchField")
            field.text = "clock"
            compare(names(), ["Weather", "Big Clock"])
            field.text = "clock ANN"
            compare(names(), ["Big Clock"])
            field.text = ""
        }

        function test_other_type_and_sorts() {
            var sort = findChild(page, "sortBox")
            sort.currentIndex = 3
            // name
            compare(names(), ["Big Clock", "Weather"])
            sort.currentIndex = 1
            // recently updated
            compare(names(), ["Big Clock", "Weather"])
            sort.currentIndex = 2
            // rating
            compare(names(), ["Weather", "Big Clock"])
            sort.currentIndex = 0
            findChild(page, "typeBox").currentIndex = 1
            compare(names(), ["Tiler"])
            findChild(page, "typeBox").currentIndex = 0
        }

        function test_catalog_is_read_once_until_generation_changes() {
            var before = fakeHost.loads
            page.visible = false
            page.visible = true
            compare(fakeHost.loads, before)
            fakeHost.storeGeneration++
            compare(fakeHost.loads, before + 1)
        }

        function test_stale_copy_syncs_once_per_interval() {
            // the fixture's copy is old: opening the page synced it once
            compare(fakeHost.ran.filter(c => c === "sync").length, 1)
            fakeHost.storeGeneration++
            // a failed sync reloads the same old copy
            compare(fakeHost.ran.filter(c => c === "sync").length, 1)
        }

        function test_zz_fresh_copy_does_not_sync() {
            fakeHost.syncedAt = new Date().toISOString().slice(0, 19)
            page.autoSyncedAt = 0
            const before = fakeHost.ran.length
            fakeHost.storeGeneration++
            compare(fakeHost.ran.length, before)
        }
    }
}
