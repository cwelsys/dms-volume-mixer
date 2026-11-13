import QtQuick
import Quickshell.Io
import "StreamLogic.js" as Logic

QtObject {
    id: cache

    property int revision: 0

    readonly property var _s: ({ steam: {}, stat: {}, exe: {}, queued: {}, queue: [], inFlight: "", dirty: false })

    readonly property FileView _reader: FileView {
        preload: true
        printErrors: false
        onLoaded: cache._settle(text())
        onLoadFailed: cache._settle("")
    }

    function steamAppIdFor(pid) {
        return cache._read(cache._s.steam, pid, "environ") || "";
    }

    function exeFor(pid) {
        return cache._read(cache._s.exe, pid, "cmdline") || "";
    }

    function statFor(pid) {
        return cache._read(cache._s.stat, pid, "stat") || null;
    }

    function _read(table, pid, file) {
        const key = /^\d+$/.test(pid) ? String(pid) : "";
        if (!key)
            return undefined;
        if (key in table)
            return table[key];
        const job = key + "/" + file;
        if (!(job in cache._s.queued)) {
            cache._s.queued[job] = true;
            cache._s.queue.push(job);
            Qt.callLater(cache._pump);
        }
        return undefined;
    }

    function retain(pids) {
        const s = cache._s;
        const live = ({});
        for (var i = 0; i < pids.length; i++) {
            var p = pids[i] ? String(pids[i]) : "";
            for (var hops = 0; p && !(p in live) && hops < 16; hops++) {
                live[p] = true;
                p = s.stat[p] ? s.stat[p].ppid : "";
            }
        }
        for (const known in s.steam) {
            if (!(known in live))
                delete s.steam[known];
        }
        for (const seen in s.exe) {
            if (!(seen in live))
                delete s.exe[seen];
        }
        for (const walked in s.stat) {
            if (!(walked in live))
                delete s.stat[walked];
        }
        for (const pending in s.queued) {
            if (!(pending.substring(0, pending.indexOf("/")) in live) && pending !== s.inFlight)
                delete s.queued[pending];
        }
        s.queue = s.queue.filter(job => job in s.queued);
    }

    function _pump() {
        const s = cache._s;
        if (s.inFlight)
            return;
        if (s.queue.length === 0) {
            if (s.dirty) {
                s.dirty = false;
                cache.revision++;
            }
            return;
        }
        s.inFlight = s.queue.shift();
        const path = "/proc/" + s.inFlight;
        if (cache._reader.path === path)
            cache._reader.reload();
        else
            cache._reader.path = path;
    }

    function _settle(text) {
        const s = cache._s;
        const job = s.inFlight;
        s.inFlight = "";
        if (job) {
            delete s.queued[job];
            const pid = job.substring(0, job.indexOf("/"));
            if (job.endsWith("/stat")) {
                const stat = Logic.parseStat(text);
                s.stat[pid] = stat;
                if (stat)
                    s.dirty = true;
            } else if (job.endsWith("/cmdline")) {
                const exe = Logic.exeFromCmdline(text);
                s.exe[pid] = exe;
                if (exe)
                    s.dirty = true;
            } else {
                const appId = Logic.parseSteamAppId(text);
                s.steam[pid] = appId;
                // Only a hit marks the cache dirty, so non-Steam streams don't re-run the grouping.
                if (appId)
                    s.dirty = true;
            }
        }
        Qt.callLater(cache._pump);
    }
}
