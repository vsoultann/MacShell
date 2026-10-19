// GlassText — words made of Liquid Glass: whatever is behind them is bent through the letters, with a bright
// rim on the side facing the light. It is the lock screen clock's material (glasstext.frag), packaged so
// Mac Hello's greeting can use the very same thing.
//
//   backdrop: the item whose pixels show through (it must sit behind this one, not contain it)
//   frame:    the item whose coordinate space the backdrop fills (usually the window's root item)
import QtQuick
import QtQuick.Effects

Item {
    id: gt
    property string text: ""
    property font font
    property int duration: 900
    property Item backdrop: null
    property Item frame: null
    property real intensity: 0.22       // 0 clear … 1 milky
    property real refract: 12           // how far the backdrop is bent at the edge, px
    property real margin: 70            // room around the letters for the morph and the refraction
    property real rimSoft: -1           // px over which a stroke rounds off (-1: thin rim, the lock clock's look; larger: thick lens-like glass)
    property real bevel: 4.5
    readonly property bool failed: glass.status === ShaderEffect.Error

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // the letters themselves are only a mask: they morph between words (fade + scale), never drawn directly
    MorphText {
        id: label
        anchors.centerIn: parent
        text: gt.text
        font: gt.font
        color: "white"
        duration: gt.duration
        useBlur: false
        animateWidth: false
        renderType: Text.QtRendering
        visible: false
    }
    ShaderEffectSource {
        id: maskTex
        sourceItem: label
        hideSource: true
        visible: false
        smooth: true
        sourceRect: Qt.rect(-gt.margin, -gt.margin, label.width + 2 * gt.margin, label.height + 2 * gt.margin)
    }
    // a lightly blurred copy whose slope finds the rim
    MultiEffect {
        id: heightFx
        width: maskTex.sourceRect.width
        height: maskTex.sourceRect.height
        source: maskTex
        blurEnabled: true
        blurMax: 32
        blur: gt.rimSoft > 0 ? Math.min(1, gt.rimSoft / 32) : Math.max(0.075, Math.min(0.3, gt.font.pixelSize * 0.015 / 16))
        autoPaddingEnabled: false
        visible: false
    }
    ShaderEffectSource { id: heightTex; sourceItem: heightFx; visible: false; smooth: true }
    ShaderEffectSource {
        id: backTex
        sourceItem: gt.backdrop
        visible: false
        live: true
        smooth: true
    }

    // a soft shadow so glass letters still lift off a bright sky
    MultiEffect {
        x: label.x - gt.margin
        y: label.y - gt.margin + 10
        width: maskTex.sourceRect.width
        height: maskTex.sourceRect.height
        source: maskTex
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        colorization: 1.0
        colorizationColor: "black"
        brightness: -1.0
        opacity: 0.22
    }
    ShaderEffect {
        id: glass
        x: label.x - gt.margin
        y: label.y - gt.margin
        width: maskTex.sourceRect.width
        height: maskTex.sourceRect.height
        visible: gt.backdrop !== null && gt.frame !== null
        fragmentShader: Qt.resolvedUrl("glasstext.frag.qsb")
        // where the glass really is inside the backdrop (follows the word's width as it changes)
        readonly property point fp: { gt.x; gt.y; label.x; label.width; return gt.frame ? glass.mapToItem(gt.frame, 0, 0) : Qt.point(0, 0); }
        property variant src: backTex
        property variant mask: maskTex
        property variant hmap: heightTex
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector2d srcSize: Qt.vector2d(gt.frame ? gt.frame.width : 1, gt.frame ? gt.frame.height : 1)
        property vector2d srcOffset: Qt.vector2d(fp.x, fp.y)
        property real mode: 1
        property real intensity: gt.intensity
        property real refract: gt.refract
        property real bevel: gt.bevel
        property color tint: "white"
        property vector2d lightDir: Qt.vector2d(-0.45, -0.89)
        onStatusChanged: if (status === ShaderEffect.Error) console.log("[machello] glass text shader:", log)
    }
    // no shader: plain white letters, so the greeting is never missing
    Text {
        visible: gt.failed || gt.backdrop === null
        anchors.centerIn: parent
        text: gt.text
        font: gt.font
        color: "white"
    }
}
