import QtQuick
import Quickshell.Io

// The lock transition as an eye. Open = the desktop (the sharp, undimmed
// wallpaper fills the screen), closed = the dim lock view. Locking runs
// host.progress 0→1 so the lids close down to the dim; unlocking reverses and
// the eye opens back onto the desktop. The aperture is a clipped band showing
// the bright wallpaper over the dim LockContent beneath, with a neon lash line
// riding each lid edge. Invisible (and free) while the lock sits closed.
Item {
    id: fx

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host

    // eye openness: 1 = desktop visible, 0 = fully closed on the lock view
    readonly property real open: 1 - host.progress
    // lash lines only exist mid-blink — gone at both resting states
    readonly property real lash: Math.min(1, fx.open * 8) * Math.min(1, (1 - fx.open) * 8)

    // the wallpaper seen through the eye — same awww lookup the lock bg uses,
    // but unblurred/undimmed so the aperture reads as "the desktop"
    property string wall: ""
    function fileUrl(p) { return "file://" + p.split("/").map(encodeURIComponent).join("/") }
    Process {
        running: true
        command: ["bash", "-c",
            'name="$1"; ' +
            'if [ -n "$name" ]; then line=$(awww query 2>/dev/null | grep -m1 -- "$name:"); ' +
            'else line=$(awww query 2>/dev/null | head -1); fi; ' +
            'printf "%s" "$line" | sed -n "s/.*image: //p"',
            "_", fx.host.screenName]
        stdout: StdioCollector { onStreamFinished: fx.wall = text.trim() }
    }

    Item {
        id: aperture
        width: parent.width
        height: parent.height * fx.open
        y: (parent.height - height) / 2
        clip: true
        visible: fx.open > 0.001

        Image {
            width: fx.width
            height: fx.height
            y: -aperture.y
            source: fx.wall !== "" ? fx.fileUrl(fx.wall) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }

    // lid edges: neon core with the usual cyan/magenta fringe
    Rectangle {
        width: parent.width; height: 3
        y: aperture.y - 3
        color: fx.pal.cyan
        opacity: fx.lash * 0.4
    }
    Rectangle {
        width: parent.width; height: 2
        y: aperture.y - 1
        color: fx.pal.neon
        opacity: fx.lash * 0.9
    }
    Rectangle {
        width: parent.width; height: 2
        y: aperture.y + aperture.height - 1
        color: fx.pal.neon
        opacity: fx.lash * 0.9
    }
    Rectangle {
        width: parent.width; height: 3
        y: aperture.y + aperture.height + 1
        color: fx.pal.magenta
        opacity: fx.lash * 0.4
    }
}
