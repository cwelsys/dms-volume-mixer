.pragma library

function stripExe(name) {
    return (name || "").replace(/\.(exe|bin)$/i, "");
}

function isBoilerplateMediaName(name) {
    if (!name)
        return true;
    // Generic audio-plumbing words.
    if (/playback|capture|audio|stream|alsa|pulse|pipewire/i.test(name))
        return true;
    // Device node names (routing targets), e.g. bluez_output.<addr>.
    if (/^(alsa|bluez|v4l2|libcamera)_|_(output|input)\./i.test(name))
        return true;
    return false;
}

// Steam exports these into the environment of everything it launches, Proton or
// native, and /proc/<pid>/environ is NUL-separated. SteamAppId is preferred:
// non-Steam shortcuts added to Steam report SteamAppId=0 alongside a synthesized
// 64-bit SteamGameId, and only the latter appears in their desktop entry.
function parseSteamAppId(environText) {
    var vars = String(environText || "").split("\u0000");
    var found = {};
    for (var i = 0; i < vars.length; i++) {
        var eq = vars[i].indexOf("=");
        if (eq <= 0)
            continue;
        var key = vars[i].substring(0, eq);
        if (key !== "SteamAppId" && key !== "STEAM_COMPAT_APP_ID" && key !== "SteamGameId")
            continue;
        var value = vars[i].substring(eq + 1).trim();
        if (/^[0-9]+$/.test(value) && value !== "0" && !(key in found))
            found[key] = value;
    }
    return found["SteamAppId"] || found["STEAM_COMPAT_APP_ID"] || found["SteamGameId"] || "";
}

// Steam names the icon it installs after the app id and writes the same string
// into StartupWMClass on most of the entries it generates, so this is the join
// key between a running game and its desktop entry.
function steamIconName(appId) {
    return appId ? "steam_icon_" + appId : "";
}

// Predicate matching the entry Steam generated for an app id, by the icon it
// installs (present on every generated entry) or by the steam://rungameid Exec
// (which also covers non-Steam shortcuts, whose Icon is an absolute path).
// Equality on a unique key, not a substring sweep: exactly one entry can match.
function steamEntryMatcher(appId) {
    if (!appId)
        return null;
    var icon = steamIconName(appId);
    var exec = new RegExp("rungameid/" + appId + "(?![0-9])");
    return function(entry) {
        if (!entry)
            return false;
        if (entry.icon && String(entry.icon) === icon)
            return true;
        return exec.test(entry.execString || "");
    };
}

function niriAppIdForPid(windows, pid) {
    if (!pid)
        return "";
    var target = Number(pid);
    if (!isFinite(target))
        return "";
    var list = windows || [];
    for (var i = 0; i < list.length; i++) {
        if (list[i] && Number(list[i].pid) === target)
            return String(list[i].app_id || "");
    }
    return "";
}

function parseStat(text) {
    var s = String(text || "");
    var open = s.indexOf("(");
    var close = s.lastIndexOf(")");
    if (open < 0 || close < open)
        return null;
    var rest = s.substring(close + 2).split(" ");
    return { comm: s.substring(open + 1, close), ppid: rest[1] || "" };
}

function programChain(pid, statOf) {
    var p = pid ? String(pid) : "";
    if (!p)
        return [];
    var chain = [p];
    var stat = statOf(p);
    while (stat && chain.length < 8) {
        var parent = stat.ppid;
        if (!parent || parent === "0" || parent === "1")
            break;
        var parentStat = statOf(parent);
        if (!parentStat || parentStat.comm !== stat.comm)
            break;
        chain.push(parent);
        stat = parentStat;
    }
    return chain;
}

function windowAppIdForPids(windows, pids) {
    for (var i = 0; i < pids.length; i++) {
        var appId = niriAppIdForPid(windows, pids[i]);
        if (appId)
            return appId;
    }
    return "";
}

// Handed to AppIconRenderer when nothing resolved. The renderer re-resolves
// iconValue through Paths.resolveIconPath, whose tail is a substring sweep over
// every desktop entry -- passing an unresolved app name there is how "disco"
// ends up wearing avahi-discover's ethernet icon. This matches no entry and no
// theme icon, so the renderer stays visible and draws the letter badge.
var UNRESOLVED_ICON = "volumemixer-unresolved-app-icon";

// "PathOfExileSteam" -> "Path Of Exile Steam". PipeWire reports the executable,
// while desktop entries are named for the product, so the two only meet once the
// run-together binary name is broken back into words.
function splitCamel(name) {
    return (name || "")
        .replace(/[_\-.]+/g, " ")
        .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
        .replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2")
        .replace(/\s+/g, " ")
        .trim();
}

// Launcher and build suffixes Steam/Wine append to the executable but that never
// appear in the entry name: "Path Of Exile Steam" -> "Path Of Exile".
function stripBuildSuffix(name) {
    return (name || "").replace(/\s+(steam|launcher|shipping|win64|win32|x64|x86)$/i, "").trim();
}

// Ordered, de-duplicated candidate identity strings for a stream's props.
// application.name / node.name before binary so Wine app names beat the loader.
function buildCandidates(props) {
    props = props || {};
    var raw = [
        props["application.id"],
        stripExe(props["application.name"]),
        stripExe(props["node.name"]),
        props["application.process.binary"]
    ];
    var seen = {}, out = [];
    function push(candidate) {
        var c = (candidate || "").trim();
        if (!c)
            return;
        var key = c.toLowerCase();
        if (seen[key])
            return;
        seen[key] = true;
        out.push(c);
    }
    for (var i = 0; i < raw.length; i++)
        push(raw[i]);
    // Word-split variants go last so an exact id/binary match always wins.
    var exact = out.slice();
    for (var j = 0; j < exact.length; j++) {
        var camel = splitCamel(exact[j]);
        push(camel);
        push(stripBuildSuffix(camel));
    }
    return out;
}

// media.name, or "" when boilerplate. media.role is ignored (generic category labels).
function chooseDescriptor(props) {
    props = props || {};
    var media = props["media.name"];
    if (media && !isBoilerplateMediaName(media))
        return String(media);
    return "";
}

// "Artist — Title", title alone, or "".
function formatNowPlaying(title, artist) {
    title = (title || "").trim();
    artist = (artist || "").trim();
    if (!title)
        return "";
    return artist ? (artist + " — " + title) : title;
}

// True when an MPRIS player's identity/desktopEntry matches the group (exact, not substring).
function playerMatchesGroup(playerIdentity, playerDesktopEntry, entryId, candidates) {
    var pd = (playerDesktopEntry || "").toLowerCase().trim();
    var pi = (playerIdentity || "").toLowerCase().trim();
    var eid = (entryId || "").toLowerCase().trim();
    if (pd && eid && pd === eid)
        return true;
    candidates = candidates || [];
    for (var i = 0; i < candidates.length; i++) {
        var c = (candidates[i] || "").toLowerCase().trim();
        if (c.length < 3)
            continue;
        if (pd === c || pi === c)
            return true;
    }
    return false;
}

// Group nodes by keyOf(node), preserving first-seen order.
function groupStreams(nodes, keyOf) {
    var map = {}, order = [];
    for (var i = 0; i < nodes.length; i++) {
        var k = keyOf(nodes[i]);
        if (!map[k]) {
            map[k] = { key: k, nodes: [] };
            order.push(k);
        }
        map[k].nodes.push(nodes[i]);
    }
    return order.map(function(k) { return map[k]; });
}
