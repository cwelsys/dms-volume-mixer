import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "StreamLogic.js" as Logic

QtObject {
    id: identity

    readonly property ProcInfo proc: ProcInfo {}
    readonly property int procRevision: identity.proc.revision
    readonly property string _windowKey: CompositorService.isNiri
        ? JSON.stringify((NiriService.windows || []).map(function(w) { return [w.pid, w.app_id]; }).sort()) : "[]"
    readonly property var _windows: JSON.parse(identity._windowKey).map(function(pair) {
        return { pid: pair[0], app_id: pair[1] };
    })

    function _steamAppId(props) {
        return identity.proc.steamAppIdFor(props["application.process.id"]);
    }

    function _windowAppId(props) {
        if (!CompositorService.isNiri)
            return "";
        var pid = props["application.process.id"];
        return Logic.niriAppIdForPid(identity._windows, pid)
            || Logic.windowAppIdForPids(identity._windows, Logic.programChain(pid, function(p) {
                return identity.proc.statFor(p);
            }));
    }

    function _appId(props) {
        return Logic.steamWindowClass(identity._steamAppId(props)) || identity._windowAppId(props);
    }

    function _steamEntry(appId) {
        var matches = Logic.steamEntryMatcher(appId);
        if (!matches)
            return null;
        var all = DesktopEntries.applications.values;
        for (var i = 0; i < all.length; i++) {
            if (matches(all[i]))
                return all[i];
        }
        return null;
    }

    function _lookup(name) {
        if (!name)
            return null;
        var raw = String(name);
        var modded = Paths.moddedAppId(raw);
        return DesktopEntries.heuristicLookup(modded)
            || (modded !== raw ? DesktopEntries.heuristicLookup(raw) : null);
    }

    function _identify(node, cache) {
        var key = node ? node.id : "?";
        if (cache && (key in cache))
            return cache[key];
        var props = (node && node.properties) ? node.properties : ({});
        var appId = identity._appId(props);
        var entry = identity._steamEntry(identity._steamAppId(props)) || identity._lookup(appId);
        var cands = Logic.buildCandidates(props);
        for (var i = 0; !entry && i < cands.length; i++)
            entry = identity._lookup(cands[i]);
        var found = { appId: appId, entry: entry };
        if (cache)
            cache[key] = found;
        return found;
    }

    function _iconForName(name) {
        var n = name ? String(name) : "";
        if (!n || n.charAt(0) === "/")
            return "";
        return Paths.moddedAppId(n) !== n ? Paths.resolveIconPath(n) : Paths.themedIconPath(n);
    }

    // Resolves the desktop entry, display name and icon source for a stream.
    function resolve(node, cache) {
        var props = (node && node.properties) ? node.properties : ({});
        var found = identity._identify(node, cache);
        var entry = found.entry;
        var appId = found.appId;

        var named = Logic.buildCandidates(props);
        var appName = (entry && entry.name) ? String(entry.name)
            : (Logic.stripExe(props["application.name"]) || named[0] || AudioService.displayName(node));

        var iconSource = "";
        if (appId || entry)
            iconSource = Paths.getAppIcon(appId || String(entry.id), entry)
                || Paths.themedIconPath(entry && entry.icon ? String(entry.icon) : "");
        var names = [props["application.icon-name"], props["application.icon_name"]].concat(named, [props["media.name"]]);
        for (var i = 0; !iconSource && i < names.length; i++)
            iconSource = identity._iconForName(names[i]);
        return { entry: entry, appName: appName, iconSource: iconSource };
    }

    function descriptor(node) {
        var props = (node && node.properties) ? node.properties : ({});
        return Logic.chooseDescriptor(props);
    }

    function groupKey(node, cache) {
        var props = (node && node.properties) ? node.properties : ({});
        var found = identity._identify(node, cache);
        if (found.entry && found.entry.id)
            return "entry:" + found.entry.id;
        if (found.appId)
            return "appid:" + found.appId;
        if (props["application.process.id"])
            return "pid:" + props["application.process.id"];
        if (props["application.process.binary"])
            return "bin:" + props["application.process.binary"];
        if (props["application.name"])
            return "app:" + props["application.name"];
        return "serial:" + (props["object.serial"] || (node ? node.id : "?"));
    }

    // Groups the stream nodes per app and resolves each group's name and icon.
    function buildGroups(nodes) {
        identity.proc.retain(nodes.map(function(n) {
            return (n && n.properties) ? n.properties["application.process.id"] : null;
        }));
        var cache = ({});
        var groups = Logic.groupStreams(nodes, function(n) { return identity.groupKey(n, cache); });
        return groups.map(function(g) {
            var head = identity.resolve(g.nodes[0], cache);
            return {
                key: g.key,
                appName: head.appName,
                iconSource: head.iconSource,
                entry: head.entry,
                nodes: g.nodes,
                descriptors: g.nodes.map(function(n) { return identity.descriptor(n); })
            };
        });
    }
}
