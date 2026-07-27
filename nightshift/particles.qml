import QtQuick
import QtQuick.Particles

// nightshift: the air over the district. Cold haze drifts right to left across
// the lower third — the same direction the city's light smears in the frame —
// and every so often a warm mote lifts off a vent below and climbs. The motes
// are squares, not dust: in this theme the smallest thing on screen is always
// a room. Click-through scenery on the Bottom layer, above the wallpaper.
//
// The ParticleSystem is a bare logical node with the emitters and painters as
// siblings (the house arrangement — see pines). Giving the system its own
// geometry instead makes it drive a full-surface update every frame, which on
// a 5120x1440 panel measured ~15% CPU against ~3% for this shape, for exactly
// the same picture.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while locked or covered — the whole system parks
    property bool occluded: false

    readonly property color sodium: pal.neon
    readonly property color haze: pal.cyan
    readonly property real ui: pal.uiScale

    ParticleSystem {
        id: sys
        running: true
        paused: root.occluded
    }

    // the haze: slow and wide, right to left across the valley air. Born off
    // the right edge so nothing ever pops into existence mid-frame.
    Emitter {
        system: sys
        group: "haze"
        x: root.width + 40
        y: root.height * 0.52
        width: 1
        height: root.height * 0.46
        emitRate: 0.85
        lifeSpan: 34000
        lifeSpanVariation: 6000
        size: Math.round(3 * root.ui)
        sizeVariation: Math.round(2 * root.ui)
        // the spread lives in the velocity rather than in a Wander affector,
        // which re-solves every live mote each frame for the same look
        velocity: PointDirection { x: -13; y: -2; xVariation: 8; yVariation: 6 }
    }

    // warm motes off the vents below, climbing into the cold
    Emitter {
        system: sys
        group: "warm"
        x: root.width * 0.22
        y: root.height + 10
        width: root.width * 0.55
        height: 1
        emitRate: 0.14
        lifeSpan: 11000
        lifeSpanVariation: 2500
        size: Math.round(3 * root.ui)
        sizeVariation: Math.round(1 * root.ui)
        velocity: PointDirection { x: -6; y: -26; xVariation: 11; yVariation: 10 }
    }

    ImageParticle {
        system: sys
        groups: ["haze"]
        source: Qt.resolvedUrl("mote.png")
        color: Qt.rgba(root.haze.r, root.haze.g, root.haze.b, 0.17)
        colorVariation: 0.18
        entryEffect: ImageParticle.Fade
    }
    ImageParticle {
        system: sys
        groups: ["warm"]
        source: Qt.resolvedUrl("mote.png")
        color: Qt.rgba(root.sodium.r, root.sodium.g, root.sodium.b, 0.32)
        colorVariation: 0.12
        entryEffect: ImageParticle.Fade
    }
}
