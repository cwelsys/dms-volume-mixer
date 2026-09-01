import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "StreamLogic.js" as Logic

QtObject {
    id: identity

    readonly property SteamAppIds steamAppIds: SteamAppIds {}
    readonly property int steamRevision: identity.steamAppIds.revision

    function _steamAppId(props) {
        return identity.steamAppIds.appIdFor(props["application.process.id"]);
    }

    function _niriAppId(props) {
        if (!CompositorService.isNiri)
            return "";
        return Logic.niriAppIdForPid(NiriService.windows, props["application.process.id"]);
    }

    function _candidatesFor(props) {
        var cands = Logic.buildCandidates(props);
        var niriAppId = identity._niriAppId(props);
        if (niriAppId)
            cands.unshift(niriAppId);
        var steamIcon = Logic.steamIconName(identity._steamAppId(props));
        if (steamIcon)
            cands.unshift(steamIcon);
        return cands;
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

    function _iconNameResolves(name) {
        if (!name)
            return false;
        var modded = Paths.moddedAppId(String(name));
        if (modded.charAt(0) === "/" || modded.charAt(0) === "~" || modded.indexOf("file://") === 0)
            return true;
        return !!Quickshell.iconPath(modded, true);
    }

    function _entryFor(node, cache) {
        var key = node ? node.id : "?";
        if (cache && (key in cache))
            return cache[key];
        var props = (node && node.properties) ? node.properties : ({});
        var cands = identity._candidatesFor(props);
        var entry = null;
        for (var i = 0; i < cands.length; i++) {
            var e = DesktopEntries.heuristicLookup(cands[i]);
            if (e) {
                entry = e;
                break;
            }
        }
        if (!entry)
            entry = identity._steamEntry(identity._steamAppId(props));
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
        var cands = identity._candidatesFor(props);

        var named = Logic.buildCandidates(props);
        var appName = (entry && entry.name) ? String(entry.name)
            : (Logic.stripExe(props["application.name"]) || named[0] || AudioService.displayName(node));

        var iconValue = identity._iconFromEntry(entry);
        if (!iconValue && props["application.icon_name"])
            iconValue = String(props["application.icon_name"]);
        if (!iconValue) {
            for (var i = 0; i < cands.length; i++) {
                if (identity._iconNameResolves(cands[i])) {
                    iconValue = cands[i];
                    break;
                }
            }
        }
        // media.name is sometimes a real icon-theme name; try it before giving up.
        if (!iconValue && props["media.name"] && identity._iconNameResolves(props["media.name"]))
            iconValue = String(props["media.name"]);
        if (!iconValue)
            iconValue = Logic.UNRESOLVED_ICON;
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
        identity.steamAppIds.retain(nodes.map(function(n) {
            return (n && n.properties) ? n.properties["application.process.id"] : null;
        }));
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
