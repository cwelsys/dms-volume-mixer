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
    for (var i = 0; i < raw.length; i++) {
        var c = (raw[i] || "").trim();
        if (!c)
            continue;
        var key = c.toLowerCase();
        if (seen[key])
            continue;
        seen[key] = true;
        out.push(c);
    }
    return out;
}

// Semantic "what is this stream doing", or "" when nothing meaningful.
function chooseDescriptor(props) {
    props = props || {};
    var role = props["media.role"];
    if (role)
        return String(role);
    var media = props["media.name"];
    if (media && !isBoilerplateMediaName(media))
        return String(media);
    return "";
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
