import QtQuick
import Quickshell
import Quickshell.Io

// Cyberpunk palette for the moon theme, read from this folder's config.toml so the
// whole look (clock, cava, bar, sysinfo) can be re-tinted from one place. Each of
// those components keeps a `Palette { id: pal }` and binds its colors to it.
//
// Keys (all optional — missing ones fall back to the neon defaults below):
//   accent       primary neon       accent_warn  amber / mid threshold
//   accent2      secondary cyan     accent_dim   muted trace (dividers, ghosts)
//   accent3      alert magenta
//
// Sibling config.toml is read once via cat; edit it then reload qs to re-tint.
QtObject {
    id: pal

    property color neon:    "#fcee0a"
    property color cyan:    "#00e5ff"
    property color magenta: "#ff2e6c"
    property color amber:   "#ffae3d"
    property color dim:     "#7c7a3a"

    // Per-machine UI scale for the desktop widgets (clock / cava / sysinfo). The
    // work laptop has an internal eDP-1 panel and small external monitors where
    // everything reads too big; the home Odyssey desktop has no eDP-1, so it
    // stays 1.0. Widgets apply this as a render `scale` so layout/anchors are
    // untouched — they just shrink in place. Tweak the 0.85 to taste.
    readonly property real uiScale: {
        const ss = Quickshell.screens
        for (let i = 0; i < ss.length; i++)
            if (ss[i].name === "eDP-1") return 0.85
        return 1.0
    }

    function _pick(text, key, fallback) {
        const re = new RegExp("^\\s*" + key + "\\s*=\\s*[\"']?(#[0-9a-fA-F]{3,8})[\"']?", "im")
        const m = text.match(re)
        return (m && m[1]) ? m[1] : fallback
    }
    function parse(text) {
        neon    = _pick(text, "accent",      "#fcee0a")
        cyan    = _pick(text, "accent2",     "#00e5ff")
        magenta = _pick(text, "accent3",     "#ff2e6c")
        amber   = _pick(text, "accent_warn", "#ffae3d")
        dim     = _pick(text, "accent_dim",  "#7c7a3a")
    }

    // resolve this file's own directory so we cat the sibling config.toml
    readonly property string _cfg: {
        let s = Qt.resolvedUrl("config.toml").toString()
        if (s.indexOf("file://") === 0) s = s.substring(7)
        return decodeURIComponent(s)
    }

    property Process _reader: Process {
        command: ["cat", pal._cfg]
        running: true
        stdout: StdioCollector { onStreamFinished: pal.parse(text) }
    }
}
