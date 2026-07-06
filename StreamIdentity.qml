import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "StreamLogic.js" as Logic

QtObject {
    id: identity

    // Per-pass entry cache passed in as `cache`. Plain JS, not a QML property:
    // a reactive cache loops the streamGroups binding.
    function _entryFor(node, cache) {
        var key = node ? node.id : "?";
        if (cache && (key in cache))
            return cache[key];
        var props = (node && node.properties) ? node.properties : ({});
        var cands = Logic.buildCandidates(props);
        var entry = null;
        for (var i = 0; i < cands.length; i++) {
            var e = DesktopEntries.heuristicLookup(cands[i]);
            if (e) {
                entry = e;
                break;
            }
        }
        if (cache)
            cache[key] = entry;
        return entry;
    }

    // Absolute-path icons (e.g. Wine/Steam Icon=/path.png) must go through the
    // image: prefix; resolveIconPath only reliably handles theme names.
    function _iconFromEntry(entry) {
        if (!entry || !entry.icon)
            return "";
        var ic = String(entry.icon);
        if (ic.indexOf("file://") === 0)
            return "image:" + ic.substring(7);
        if (ic.charAt(0) === "/")
            return "image:" + ic;
        return ic;
    }

    // -> { entry, appName, iconValue }
    function resolve(node, cache) {
        var props = (node && node.properties) ? node.properties : ({});
        var entry = identity._entryFor(node, cache);
        var cands = Logic.buildCandidates(props);

        var appName = (entry && entry.name) ? String(entry.name)
            : (Logic.stripExe(props["application.name"]) || cands[0] || AudioService.displayName(node));

        var iconValue = identity._iconFromEntry(entry);
        if (!iconValue && props["application.icon_name"])
            iconValue = String(props["application.icon_name"]);
        if (!iconValue) {
            for (var i = 0; i < cands.length; i++) {
                if (Paths.resolveIconPath(cands[i])) {
                    iconValue = cands[i];
                    break;
                }
            }
        }
        // media.name is sometimes a real icon-theme name (e.g. mpd) even when no
        // desktop entry or identity candidate resolves; try it before giving up.
        if (!iconValue && props["media.name"] && Paths.resolveIconPath(props["media.name"]))
            iconValue = String(props["media.name"]);
        // Non-empty last resort: AppIconRenderer is hidden when iconValue is "",
        // so fall back to appName to keep it visible and render its letter badge.
        if (!iconValue)
            iconValue = appName;
        return { entry: entry, appName: appName, iconValue: iconValue };
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

    // -> [{ key, appName, iconValue, entry, nodes, descriptors }]
    function buildGroups(nodes) {
        var cache = ({});
        var groups = Logic.groupStreams(nodes, function(n) { return identity.groupKey(n, cache); });
        return groups.map(function(g) {
            var head = identity.resolve(g.nodes[0], cache);
            return {
                key: g.key,
                appName: head.appName,
                iconValue: head.iconValue,
                entry: head.entry,
                nodes: g.nodes,
                descriptors: g.nodes.map(function(n) { return identity.descriptor(n); })
            };
        });
    }
}
