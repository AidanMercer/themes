import QtQuick
import QtQuick.Shapes
import Quickshell

// Berserk desktop clock for the "griffith" wallpaper.
//
// Loaded by the quickshell themeclock module while this wallpaper is showing.
// Self-contained (it lives outside the repo's module tree, so no shared Theme).
//
// The Brand of Sacrifice, drawn as a real vector (QtQuick.Shapes / CurveRenderer)
// so it's crisp at any resolution: a trident crown, a hollow upper diamond, a
// hollow lower diamond, and a small tail spike — bold red bars, the only red in
// the scene (Berserk's signature). Time and date stay icy bone/steel, pulled
// from the castle and clouds. Hugs the dark left flank, clear of the subject.
Item {
    id: root
    anchors.fill: parent

    readonly property color ice:    "#dbe4ee"   // the castle / Griffith's white
    readonly property color steel:  "#8fa3bc"   // cold cloud blue
    readonly property color blood:  "#bf1622"   // the Brand

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // The Brand aches — a slow throb in the corruption around it.
    property real throb: 0
    SequentialAnimation on throb {
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 2400; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 2400; easing.type: Easing.InOutSine }
    }

    // ---- Brand geometry (authored in a 100×165 space, scaled by s) ----------
    readonly property real brandScale: 0.76
    function p(x, y) { return (x * brandScale).toFixed(2) + "," + (y * brandScale).toFixed(2) }

    // Stroked skeleton: the central spine, the two upper arms (each a bar that
    // hooks out to an elbow before its spike tip), and the hollow lower diamond.
    // The crown and the three spike tips are added filled (brandSpikes) so they
    // come to real points.
    readonly property string brandBody:
        "M" + p(50, 27) + " L" + p(50, 151) + " " +                                       // central spine
        "M" + p(50, 82) + " L" + p(9, 40) + " " +                                         // upper-left arm → elbow
        "M" + p(50, 82) + " L" + p(91, 40) + " " +                                        // upper-right arm → elbow
        "M" + p(50, 82) + " L" + p(16, 118) + " L" + p(50, 151) + " L" + p(84, 118) + " Z" // lower diamond

    // One tapered spike (base → sharp tip) as a filled SVG subpath.
    function spike(bx, by, tx, ty, hw) {
        const s = brandScale
        bx *= s; by *= s; tx *= s; ty *= s; hw *= s
        let ux = tx - bx, uy = ty - by
        const L = Math.hypot(ux, uy) || 1
        ux /= L; uy /= L
        const nx = -uy, ny = ux
        const blx = bx + nx * hw, bly = by + ny * hw
        const brx = bx - nx * hw, bry = by - ny * hw
        const cax = bx + ux * L * 0.55 + nx * hw * 0.5, cay = by + uy * L * 0.55 + ny * hw * 0.5
        const cbx = bx + ux * L * 0.55 - nx * hw * 0.5, cby = by + uy * L * 0.55 - ny * hw * 0.5
        return `M${blx},${bly} Q${cax},${cay} ${tx},${ty} Q${cbx},${cby} ${brx},${bry} Z`
    }

    // Crown at the top of the spine, the two hooked spike tips (from each elbow),
    // and the bottom tail — all filled so they taper to real points.
    readonly property string brandSpikes:
        spike(50, 30, 50, 3,  4.5) +    // crown centre prong
        spike(50, 31, 43, 14, 3) +      // crown left prong
        spike(50, 31, 57, 14, 3) +      // crown right prong
        spike(9, 40, 20, 9, 4) +        // upper-left spike tip
        spike(91, 40, 80, 9, 4) +       // upper-right spike tip
        spike(50, 149, 50, 164, 4)      // tail

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Math.round(root.width * 0.075)
        spacing: 30

        // ---- the Brand of Sacrifice ----------------------------------------
        Item {
            width: 100 * root.brandScale
            height: 165 * root.brandScale
            anchors.verticalCenter: parent.verticalCenter

            Canvas {                                // soft bleed behind it, throbbing
                anchors.centerIn: parent
                width: 150; height: 190
                opacity: 0.26 + 0.30 * root.throb
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2
                    const g = ctx.createRadialGradient(cx, cy, 3, cx, cy, width / 2)
                    g.addColorStop(0.0, Qt.rgba(0.72, 0.09, 0.13, 0.85))
                    g.addColorStop(1.0, Qt.rgba(0, 0, 0, 0))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                antialiasing: true

                ShapePath {                          // hollow diamonds
                    strokeColor: root.blood
                    strokeWidth: 8 * root.brandScale
                    joinStyle: ShapePath.MiterJoin
                    fillColor: "transparent"
                    PathSvg { path: root.brandBody }
                }
                ShapePath {                          // solid trident + tail
                    strokeColor: "transparent"
                    strokeWidth: 0
                    fillColor: root.blood
                    PathSvg { path: root.brandSpikes }
                }
            }
        }

        // ---- time + date ----------------------------------------------------
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.ice
                font.family: "Noto Serif Display"
                font.weight: Font.Light
                font.pixelSize: 84
                opacity: 0.95
            }

            Text {
                text: Qt.formatDateTime(clock.date, "dddd, dd MMMM").toUpperCase()
                color: root.steel
                font.family: "Noto Serif Display"
                font.weight: Font.Normal
                font.pixelSize: 15
                font.letterSpacing: 4
            }
        }
    }
}
