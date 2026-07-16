import QtQuick

// sailing: the wheelhouse watch — the dusk sea behind the gauges, wired to
// the machine it's watching: the sea state rides host.load, so an idle box
// drifts on a flat calm and a pinned one rolls. a brass inclinometer top-left
// hangs plumb off the same roll, swinging wider as the machine strains.
// re-sorting the table trims the watch — a small swell and settle; a kill is
// man overboard — the deck heels hard and the lifebuoy goes over the rail,
// one red-orange ring and its splash ripple in the water aft.
Item {
    id: chrome

    required property var pal
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    readonly property color cardBorder: Qt.alpha(pal.dim, 0.55)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14   // porthole-round, the popup's corner

    readonly property string wordmark: "☸ at the helm"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the whole sea in one pass — oversized so the roll never bares
            // an edge. the ambient roll IS the load: amplitude widens as the
            // machine strains, flat calm when it idles. `heel` carries the
            // one-shot swells on top of the ambient sine.
            ShaderEffect {
                id: sea
                anchors.fill: parent
                anchors.margins: -44
                fragmentShader: Qt.resolvedUrl("sea.frag.qsb")
                property real time: 0
                property real ph: 0
                property real heel: 0
                rotation: Math.sin(ph) * (0.2 + 1.1 * chrome.load) + heel
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake && bd.visible
                }
                // one roll every ~7s; ends on a whole cycle so the loop seam is flat
                NumberAnimation on ph {
                    from: 0; to: 1800 * Math.PI; duration: 6300000
                    loops: Animation.Infinite
                    running: chrome.awake && bd.visible
                }
                // trimming the watch: a re-sort takes a small swell and settles
                SequentialAnimation {
                    id: trim
                    NumberAnimation { target: sea; property: "heel"; from: -0.5; to: 0.3; duration: 240; easing.type: Easing.InOutSine }
                    NumberAnimation { target: sea; property: "heel"; from: 0.3; to: 0; duration: 260; easing.type: Easing.OutSine }
                }
                // man overboard: the deck heels hard and damps back to level
                SequentialAnimation {
                    id: hardHeel
                    NumberAnimation { target: sea; property: "heel"; from: -1.6; to: 0.9; duration: 420; easing.type: Easing.InOutSine }
                    NumberAnimation { target: sea; property: "heel"; from: 0.9; to: -0.4; duration: 360; easing.type: Easing.InOutSine }
                    NumberAnimation { target: sea; property: "heel"; from: -0.4; to: 0; duration: 320; easing.type: Easing.OutSine }
                }
                Connections {
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onSortIdChanged() { if (chrome.awake) trim.restart() }
                    function onKillPulseChanged() { if (chrome.awake) hardHeel.restart() }
                }
            }

            // deck chrome, level while the sea rolls: the taffrail +
            // stanchions along the footer, the masthead lamp top-right, and
            // the inclinometer's brass ticks. one static draw — free at idle.
            Canvas {
                id: deck
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    const w = width, h = height
                    ctx.reset()
                    // taffrail above the footer: two hairlines + stanchion posts
                    const rx = 16, rw = w * 0.34, ry = h - 12
                    ctx.fillStyle = Qt.alpha(chrome.pal.text, 0.22)
                    ctx.fillRect(rx, ry, rw, 1)
                    ctx.fillStyle = Qt.alpha(chrome.pal.dim, 0.5)
                    ctx.fillRect(rx, ry + 4, rw, 1)
                    ctx.fillStyle = Qt.alpha(chrome.pal.text, 0.4)
                    for (let i = 0; i < 3; i++)
                        ctx.fillRect(rx + Math.round((rw - 2) * i / 2), ry, 2, 6)
                    // masthead lamp: a brass point in a faint halo
                    const lx = w - 20, ly = 13
                    ctx.beginPath(); ctx.arc(lx, ly, 7, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.alpha(chrome.pal.amber, 0.14); ctx.fill()
                    ctx.beginPath(); ctx.arc(lx, ly, 2.2, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.alpha(chrome.pal.amber, 0.9); ctx.fill()
                    // inclinometer: brass pivot screw + three ticks on the hanging arc
                    const px = 36, py = 9
                    ctx.strokeStyle = Qt.alpha(chrome.pal.dim, 0.7)
                    ctx.lineWidth = 1
                    for (let k = -1; k <= 1; k++) {
                        const a = Math.PI / 2 + k * 0.3
                        ctx.beginPath()
                        ctx.moveTo(px + Math.cos(a) * 15, py + Math.sin(a) * 15)
                        ctx.lineTo(px + Math.cos(a) * 19, py + Math.sin(a) * 19)
                        ctx.stroke()
                    }
                    ctx.beginPath(); ctx.arc(px, py, 1.8, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.alpha(chrome.pal.amber, 0.9); ctx.fill()
                }
            }

            // the inclinometer needle: hangs plumb while the boat rolls under
            // it — reads the sea's roll ×6 so the strain is legible at a
            // glance. pure transform, costs nothing beyond the ambient roll.
            Rectangle {
                x: 36 - width / 2; y: 9
                width: 1.5; height: 15
                transformOrigin: Item.Top
                rotation: Math.max(-16, Math.min(16, sea.rotation * 6))
                color: Qt.alpha(chrome.pal.amber, 0.85)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 4; height: 4; radius: 2
                    color: Qt.alpha(chrome.pal.neon, 0.9)
                }
            }
        }
    }

    // ── man overboard: the kill sends the lifebuoy over the rail — one
    // red-orange ring and its splash ripple in the water aft, gone in a
    // second. nothing resident above the gauges. ──
    readonly property Component overlay: Component {
        Item {
            id: ov
            property real mob: 0   // 1 the instant the signal goes out, 0 at rest
            visible: mob > 0.01

            // the buoy
            Rectangle {
                x: ov.width * 0.72 - width / 2
                y: ov.height * 0.74 - height / 2
                width: 24 + 46 * (1 - ov.mob); height: width; radius: width / 2
                color: "transparent"
                border.color: Qt.alpha(chrome.pal.neon, 0.9 * ov.mob)
                border.width: Math.max(1.5, 4 * ov.mob)
            }
            // the splash ripple, running ahead of it
            Rectangle {
                x: ov.width * 0.72 - width / 2
                y: ov.height * 0.74 - height / 2
                width: 34 + 110 * (1 - ov.mob); height: width; radius: width / 2
                color: "transparent"
                border.color: Qt.alpha(chrome.pal.text, 0.3 * ov.mob)
                border.width: 1
            }
            NumberAnimation {
                id: lifebuoy
                target: ov; property: "mob"
                from: 1; to: 0; duration: 1000
                easing.type: Easing.OutQuad
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onKillPulseChanged() { if (chrome.awake) lifebuoy.restart() }
            }
        }
    }
}
