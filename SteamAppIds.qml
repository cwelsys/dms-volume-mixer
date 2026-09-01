import QtQuick
import Quickshell.Io
import "StreamLogic.js" as Logic

QtObject {
    id: cache

    property int revision: 0

    property var _byPid: ({})
    property var _queued: ({})
    property var _queue: []
    property string _inFlight: ""

    readonly property FileView _reader: FileView {
        preload: true
        printErrors: false
        onLoaded: cache._settle(text())
        onLoadFailed: cache._settle("")
    }

    function appIdFor(pid) {
        const key = pid ? String(pid) : "";
        if (!key)
            return "";
        if (key in cache._byPid)
            return cache._byPid[key];
        if (!(key in cache._queued)) {
            cache._queued[key] = true;
            cache._queue.push(key);
            // Deferred: appIdFor runs inside the streamGroups binding, and this
            // must not write a QML property while that binding is evaluating.
            Qt.callLater(cache._pump);
        }
        return "";
    }

    function retain(pids) {
        const live = ({});
        for (var i = 0; i < pids.length; i++) {
            if (pids[i])
                live[String(pids[i])] = true;
        }
        for (const known in cache._byPid) {
            if (!(known in live))
                delete cache._byPid[known];
        }
        for (const pending in cache._queued) {
            if (!(pending in live) && pending !== cache._inFlight)
                delete cache._queued[pending];
        }
        cache._queue = cache._queue.filter(p => p in cache._queued);
    }

    function _pump() {
        if (cache._inFlight || cache._queue.length === 0)
            return;
        cache._inFlight = cache._queue.shift();
        cache._reader.path = "/proc/" + cache._inFlight + "/environ";
    }

    function _settle(text) {
        const key = cache._inFlight;
        cache._inFlight = "";
        if (key) {
            delete cache._queued[key];
            const appId = Logic.parseSteamAppId(text);
            cache._byPid[key] = appId;
            // Only a hit re-runs the streamGroups binding. A miss must not churn
            // the ScriptModel for every non-Steam stream on the system.
            if (appId)
                cache.revision++;
        }
        Qt.callLater(cache._pump);
    }
}
