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
