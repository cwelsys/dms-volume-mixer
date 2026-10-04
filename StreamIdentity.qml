import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "StreamLogic.js" as Logic

QtObject {
    id: identity

    readonly property ProcInfo proc: ProcInfo {}
    readonly property int procRevision: identity.proc.revision

    function _steamAppId(props) {
        return identity.proc.steamAppIdFor(props["application.process.id"]);
    }

    function _windowAppId(props) {
        if (!CompositorService.isNiri)
            return "";
        var pid = props["application.process.id"];
        return Logic.niriAppIdForPid(NiriService.windows, pid)
            || Logic.windowAppIdForPids(NiriService.windows, Logic.programChain(pid, function(p) {
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
        return name ? DesktopEntries.heuristicLookup(Paths.moddedAppId(String(name))) : null;
    }

    function _entryFor(node, cache) {
        var key = node ? node.id : "?";
        if (cache && (key in cache))
            return cache[key];
        var props = (node && node.properties) ? node.properties : ({});
        var entry = identity._steamEntry(identity._steamAppId(props))
            || identity._lookup(identity._appId(props));
        var cands = Logic.buildCandidates(props);
        for (var i = 0; !entry && i < cands.length; i++)
            entry = identity._lookup(cands[i]);
        if (cache)
            cache[key] = entry;
        return entry;
    }

    function _iconForName(name) {
        var n = name ? String(name) : "";
        if (!n || n.charAt(0) === "/")
            return "";
        return Paths.moddedAppId(n) !== n ? Paths.resolveIconPath(n) : Paths.themedIconPath(n);
    }

    // -> { entry, appName, iconSource }
    function resolve(node, cache) {
        var props = (node && node.properties) ? node.properties : ({});
        var entry = identity._entryFor(node, cache);
        var appId = identity._appId(props);

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
        var entry = identity._entryFor(node, cache);
        if (entry && entry.id)
            return "entry:" + entry.id;
        if (props["application.process.id"])
            return "pid:" + props["application.process.id"];
        if (props["application.process.binary"])
            return "bin:" + props["application.process.binary"];
        if (props["application.name"])
            return "app:" + props["application.name"];
        return "serial:" + (props["object.serial"] || (node ? node.id : "?"));
    }

    // -> [{ key, appName, iconSource, entry, nodes, descriptors }]
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
