#!/usr/bin/env python3
"""QuickTime Player for VLC: draws MacShell's QuickTime skin for VLC's skin engine (skins2) and writes theme.xml.

    macshell-quicktime-skin.py [out-dir]        (default ~/.local/share/macshell/quicktime)

A dark window with round corners, the traffic lights and the title on top, the movie edge to edge, and
QuickTime's rounded control bar underneath: mute + volume, previous / play-pause / next, the … menu and full
screen, then elapsed time, the scrubber and the time left. Full screen gets the same bar, floating at the bottom.
Everything is drawn here (4x, then scaled down, so edges are smooth); nothing of Apple's is shipped.
"""
import os
import shutil
import sys

from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.local/share/macshell/quicktime")
SS = 4                      # supersampling

# window
W, H = 800, 550
TITLE, CTRL = 28, 76
VIDEO = H - TITLE - CTRL
R = 12                      # window corner radius
BG = (30, 30, 32, 255)
# the control bar
PW, PH, PR = 520, 56, 14
PILL = (50, 50, 53, 255)
PILL_EDGE = (255, 255, 255, 22)
FG = (236, 236, 238, 255)
FG2 = (236, 236, 238, 150)
SEEK_W, VOL_W = 392, 80


def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def done(im, name, under=None, hard=False):
    """Scale down and save. VLC's skin engine does not blend half-transparent pixels (it mixes them with black),
    so anything that sits on a known colour is flattened onto it first (`under`), and edges that must stay
    see-through are made fully on or off (`hard`)."""
    w, h = im.size[0] // SS, im.size[1] // SS
    im = im.resize((w, h), Image.LANCZOS)
    if under is not None:
        base = Image.new("RGBA", im.size, under)
        base.alpha_composite(im)
        im = base
    elif hard:
        a = im.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
        im.putalpha(a)
    im.save(os.path.join(OUT, name))


def s(*v):
    return [x * SS for x in v]


def rounded_window_piece(w, h, corners):
    """A slice of the window background; `corners` picks which of its corners are the window's round ones."""
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    # draw a bigger rounded rect and let the slice cut it, so only the chosen corners come out round
    x0 = 0 if "l" in corners else -R * 2
    x1 = w if "r" in corners else w + R * 2
    y0 = 0 if "t" in corners else -R * 2
    y1 = h if "b" in corners else h + R * 2
    d.rounded_rectangle(s(x0, y0, x1, y1), radius=R * SS, fill=BG)
    return im


def light(color, glyph, state):
    """One traffic light, 12 px: normal, hover (with its glyph) and pressed (darker)."""
    im = canvas(14, 14)
    d = ImageDraw.Draw(im)
    c = color if state != "down" else tuple(int(v * 0.78) for v in color[:3]) + (255,)
    d.ellipse(s(1, 1, 13, 13), fill=c, outline=(0, 0, 0, 40), width=SS)
    if state in ("over", "down"):
        g = (90, 20, 10, 210) if glyph == "x" else ((120, 80, 0, 210) if glyph == "-" else (10, 80, 20, 210))
        w = int(1.3 * SS)
        if glyph == "x":
            d.line(s(4.5, 4.5, 9.5, 9.5), fill=g, width=w)
            d.line(s(9.5, 4.5, 4.5, 9.5), fill=g, width=w)
        elif glyph == "-":
            d.line(s(4, 7, 10, 7), fill=g, width=w)
        else:
            # zoom: two small triangles pointing apart, like macOS
            d.polygon(s(4.2, 9.8, 4.2, 5.6, 8.4, 9.8), fill=g)
            d.polygon(s(9.8, 4.2, 9.8, 8.4, 5.6, 4.2), fill=g)
    return im


def glyph(kind, size, color=FG):
    w, h = size
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    cx, cy = w / 2, h / 2
    if kind == "play":
        d.polygon(s(cx - 6, cy - 8, cx - 6, cy + 8, cx + 8, cy), fill=color)
    elif kind == "pause":
        d.rounded_rectangle(s(cx - 6.5, cy - 8, cx - 2, cy + 8), radius=SS, fill=color)
        d.rounded_rectangle(s(cx + 2, cy - 8, cx + 6.5, cy + 8), radius=SS, fill=color)
    elif kind in ("next", "prev"):
        sign = 1 if kind == "next" else -1
        for off in (-5, 3):
            x = cx + sign * off
            d.polygon(s(x - sign * 5, cy - 6, x - sign * 5, cy + 6, x + sign * 3, cy), fill=color)
    elif kind in ("vol", "mute"):
        d.polygon(s(cx - 8, cy - 3, cx - 5, cy - 3, cx - 1, cy - 7, cx - 1, cy + 7, cx - 5, cy + 3, cx - 8, cy + 3), fill=color)
        lw = int(1.4 * SS)
        if kind == "vol":
            d.arc(s(cx - 4, cy - 4, cx + 4, cy + 4), -55, 55, fill=color, width=lw)
            d.arc(s(cx - 7.5, cy - 7.5, cx + 7.5, cy + 7.5), -55, 55, fill=color, width=lw)
        else:
            d.line(s(cx + 2, cy - 3.5, cx + 8, cy + 3.5), fill=color, width=lw)
            d.line(s(cx + 8, cy - 3.5, cx + 2, cy + 3.5), fill=color, width=lw)
    elif kind == "more":
        for x in (-6, 0, 6):
            d.ellipse(s(cx + x - 1.6, cy - 1.6, cx + x + 1.6, cy + 1.6), fill=color)
    elif kind == "full":
        lw = int(1.5 * SS)
        # two corner brackets, top-right and bottom-left, like QuickTime's full-screen button
        d.line(s(cx + 1.5, cy - 6, cx + 6, cy - 6), fill=color, width=lw)
        d.line(s(cx + 6, cy - 6, cx + 6, cy - 1.5), fill=color, width=lw)
        d.line(s(cx - 6, cy + 1.5, cx - 6, cy + 6), fill=color, width=lw)
        d.line(s(cx - 6, cy + 6, cx - 1.5, cy + 6), fill=color, width=lw)
        d.line(s(cx + 5, cy - 5, cx + 1, cy - 1), fill=color, width=lw)
        d.line(s(cx - 5, cy + 5, cx - 1, cy + 1), fill=color, width=lw)
    return im


def states(kind, size, name):
    """normal / over / down for a button: soft white, full white, a touch dimmer."""
    done(glyph(kind, size, FG2 if kind not in ("play", "pause") else FG), name + ".normal.png", under=PILL)
    done(glyph(kind, size, FG), name + ".over.png", under=PILL)
    done(glyph(kind, size, (200, 200, 204, 255)), name + ".down.png", under=PILL)


def track_frames(width, height, frames, name):
    """The fill of a slider as a strip of frames, one per position (skins2 shows the frame for the value)."""
    strip = Image.new("RGBA", (width * SS, height * SS * frames), (0, 0, 0, 0))
    d = ImageDraw.Draw(strip)
    y0, y1 = height / 2 - 2, height / 2 + 2
    for i in range(frames):
        oy = i * height
        d.rounded_rectangle(s(2, oy + y0, width - 2, oy + y1), radius=2 * SS, fill=(255, 255, 255, 60))
        f = 2 + (width - 4) * i / (frames - 1)
        if f > 3:
            d.rounded_rectangle(s(2, oy + y0, f, oy + y1), radius=2 * SS, fill=(245, 245, 247, 235))
    strip = strip.resize((width, height * frames), Image.LANCZOS)
    base = Image.new("RGBA", strip.size, PILL)          # the track sits on the bar: flatten onto it
    base.alpha_composite(strip)
    base.save(os.path.join(OUT, name))


def knob(d_px, name):
    im = canvas(d_px + 2, d_px + 2)
    dr = ImageDraw.Draw(im)
    dr.ellipse(s(1, 1, d_px + 1, d_px + 1), fill=(250, 250, 252, 255))
    # it moves over the track, so it can't be flattened onto one colour: a clean on/off edge instead
    done(im, name, hard=True)


def pill():
    im = canvas(PW, PH)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(s(0, 0, PW, PH), radius=PR * SS, fill=PILL)
    d.rounded_rectangle(s(0.5, 0.5, PW - 0.5, PH - 0.5), radius=PR * SS, outline=PILL_EDGE, width=SS)
    return im


def solid(w, h, color, name):
    Image.new("RGBA", (w, h), color).save(os.path.join(OUT, name))


def build_images():
    done(rounded_window_piece(R + 2, TITLE, "lt"), "title.l.png", hard=True)
    done(rounded_window_piece(R + 2, TITLE, "rt"), "title.r.png", hard=True)
    solid(W - 2 * (R + 2), TITLE, BG, "title.c.png")
    solid(W, VIDEO, (0, 0, 0, 255), "video.bg.png")
    done(rounded_window_piece(R + 2, CTRL, "lb"), "ctrl.l.png", hard=True)
    # the bottom-right corner is split: the lower part is the resize grip
    full = rounded_window_piece(R + 2, CTRL, "rb")
    done(full.crop((0, 0, (R + 2) * SS, (CTRL - 16) * SS)), "ctrl.r.png", hard=True)
    done(full.crop((0, (CTRL - 16) * SS, (R + 2) * SS, CTRL * SS)), "ctrl.grip.png", hard=True)
    solid(W - 2 * (R + 2), CTRL, BG, "ctrl.c.png")
    # the bar sits on the window's bottom strip, and floats over the movie in full screen
    done(pill(), "pill.png", under=BG)
    done(pill(), "pill.fs.png", hard=True)
    # QuickTime's scrubber has no knob, just the fill
    Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(os.path.join(OUT, "none.png"))
    for st in ("normal", "over", "down"):
        done(light((255, 95, 87, 255), "x", st), "close.%s.png" % st, under=BG)
        done(light((254, 188, 46, 255), "-", st), "min.%s.png" % st, under=BG)
        done(light((40, 200, 64, 255), "+", st), "zoom.%s.png" % st, under=BG)
    for kind, size in (("play", (28, 28)), ("pause", (28, 28)), ("next", (26, 20)), ("prev", (26, 20)),
                       ("vol", (22, 20)), ("mute", (22, 20)), ("more", (24, 20)), ("full", (22, 20))):
        states(kind, size, kind)
    track_frames(SEEK_W + 4, 12, 101, "seek.frames.png")
    track_frames(VOL_W + 4, 12, 51, "vol.frames.png")
    knob(9, "knob.png")
    knob(11, "knob.big.png")


def controls(prefix, pill_image="pill"):
    """The control bar's contents, in its own coordinates (PW x PH)."""
    return f'''
        <Image id="{prefix}.pill" image="{pill_image}" action="move"/>
        <Checkbox id="{prefix}.mute" x="12" y="8" state="vlc.isMute"
            up1="vol.normal" over1="vol.over" down1="vol.down" up2="mute.normal" over2="mute.over" down2="mute.down"
            action1="vlc.mute()" action2="vlc.mute()" tooltiptext1="Mute" tooltiptext2="Unmute"/>
        <Slider id="{prefix}.volume" x="38" y="12" points="(2,6),({VOL_W + 2},6)" thickness="12" value="volume"
            up="knob" tooltiptext="Volume: $V%">
            <SliderBackground image="vol.frames" nbvert="51"/>
        </Slider>
        <Button id="{prefix}.prev" x="214" y="8" up="prev.normal" over="prev.over" down="prev.down"
            action="playlist.previous()" tooltiptext="Previous"/>
        <Checkbox id="{prefix}.play" x="246" y="4" state="vlc.isPlaying"
            up1="play.normal" over1="play.over" down1="play.down" up2="pause.normal" over2="pause.over" down2="pause.down"
            action1="vlc.play()" action2="vlc.pause()" tooltiptext1="Play" tooltiptext2="Pause"/>
        <Button id="{prefix}.next" x="280" y="8" up="next.normal" over="next.over" down="next.down"
            action="playlist.next()" tooltiptext="Next"/>
        <Button id="{prefix}.more" x="452" y="8" up="more.normal" over="more.over" down="more.down"
            action="dialogs.popup()" tooltiptext="More"/>
        <Button id="{prefix}.full" x="486" y="8" up="full.normal" over="full.over" down="full.down"
            action="vlc.fullscreen()" tooltiptext="Full Screen"/>
        <Text id="{prefix}.elapsed" x="8" y="35" width="50" text="$t" font="small" color="#BDBDC2" alignment="right"/>
        <Slider id="{prefix}.seek" x="62" y="34" points="(2,6),({SEEK_W + 2},6)" thickness="12" value="time"
            up="none" visible="not vlc.isStopped" tooltiptext="$t">
            <SliderBackground image="seek.frames" nbvert="101"/>
        </Slider>
        <Text id="{prefix}.left" x="462" y="35" width="52" text="-$l" font="small" color="#BDBDC2"/>'''


def hide_in_fullscreen(xml):
    """The player window draws nothing while the movie is full screen (the engine shows it in its own window and
    the player would otherwise sit on top of it)."""
    import re

    def fix(m):
        tag = m.group(0)
        v = re.search(r'visible="([^"]*)"', tag)
        if v:
            return tag.replace(v.group(0), 'visible="%s and not vlc.isFullscreen"' % v.group(1))
        return tag.replace("<" + m.group(1), "<" + m.group(1) + ' visible="not vlc.isFullscreen"', 1)
    # (the Video element is left alone: the picture itself moves to the full-screen window)
    return re.sub(r"<(Image|Button|Checkbox|Slider|Text)\b[^>]*>", fix, xml)


def theme_xml():
    side = R + 2
    pill_x = (W - PW) // 2
    bitmaps = []
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".png"):
            bitmaps.append('  <Bitmap id="%s" file="%s" alphacolor="#FF00FF"/>' % (f[:-4], f))
    xml = f'''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE Theme PUBLIC "-//VideoLAN//DTD VLC Skins V2.0//EN" "skin.dtd">
<!-- written by macshell-quicktime-skin.py: MacShell's QuickTime Player for VLC -->
<Theme version="2.0" magnet="10" alpha="255" movealpha="255" tooltipfont="small">
  <ThemeInfo name="QuickTime Player" author="MacShell" webpage="https://github.com/vsoultann/MacShell"/>
  <Font id="title" file="Inter.ttf" size="13"/>
  <Font id="small" file="Inter.ttf" size="11"/>
{chr(10).join(bitmaps)}

  <Window id="main" position="Center" dragdrop="true" playondrop="true">
    <Layout id="normal" width="{W}" height="{H}" minwidth="{PW + 40}" maxwidth="9999" minheight="{TITLE + CTRL + 120}" maxheight="9999">
      <Panel id="titlebar" width="{W}" height="{TITLE}" rightbottom="righttop">
        <Image id="title.l" image="title.l" action="move" action2="vlc.fullscreen()"/>
        <Image id="title.c" x="{side}" image="title.c" action="move" action2="vlc.fullscreen()" resize="scale" rightbottom="righttop"/>
        <Image id="title.r" x="{W - side}" image="title.r" action="move" action2="vlc.fullscreen()" lefttop="righttop" rightbottom="righttop"/>
        <Button id="close" x="10" y="7" up="close.normal" over="close.over" down="close.down" action="vlc.quit()" tooltiptext="Close"/>
        <Button id="min" x="30" y="7" up="min.normal" over="min.over" down="min.down" action="vlc.minimize()" tooltiptext="Minimise"/>
        <Button id="zoom" x="50" y="7" up="zoom.normal" over="zoom.over" down="zoom.down" action="vlc.fullscreen()" tooltiptext="Full Screen"/>
        <Text id="name" x="80" y="6" width="{W - 160}" text="$N" font="title" color="#E6E6E8" alignment="center" rightbottom="righttop"/>
      </Panel>
      <Panel id="picture" y="{TITLE}" width="{W}" height="{VIDEO}" rightbottom="rightbottom">
        <Image id="video.bg" image="video.bg" action="move" action2="vlc.fullscreen()" resize="scale" rightbottom="rightbottom"/>
        <Image id="video.art" image="video.bg" resize="scale2" rightbottom="rightbottom" art="true" visible="not vlc.hasVout"/>
        <Video id="video" width="{W}" height="{VIDEO}" rightbottom="rightbottom" autoresize="true" visible="vlc.hasVout"/>
      </Panel>
      <Panel id="controls" y="{TITLE + VIDEO}" width="{W}" height="{CTRL}" lefttop="leftbottom" rightbottom="rightbottom">
        <Image id="ctrl.l" image="ctrl.l" action="move"/>
        <Image id="ctrl.c" x="{side}" image="ctrl.c" action="move" resize="scale" rightbottom="righttop"/>
        <Image id="ctrl.r" x="{W - side}" image="ctrl.r" action="move" lefttop="righttop" rightbottom="righttop"/>
        <Image id="ctrl.grip" x="{W - side}" y="{CTRL - 16}" image="ctrl.grip" action="resizeSE" lefttop="righttop" rightbottom="righttop"/>
        <Panel id="bar.track" x="{pill_x}" y="10" width="{PW}" height="{PH}" rightbottom="righttop">
          <Panel id="bar" width="{PW}" height="{PH}" rightbottom="righttop" xkeepratio="true">{controls("main")}
          </Panel>
        </Panel>
      </Panel>
    </Layout>
  </Window>

  <Window id="fullscreenController" position="South" ymargin="4%">
    <Layout id="fsc" width="{PW}" height="{PH}">{controls("fsc", "pill.fs")}
    </Layout>
  </Window>
</Theme>
'''
    head, rest = xml.split('  <Window id="main"', 1)
    main, tail = rest.split('  <Window id="fullscreenController"', 1)
    return head + hide_in_fullscreen('  <Window id="main"' + main) + '  <Window id="fullscreenController"' + tail


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".png"):
            os.remove(os.path.join(OUT, f))
    build_images()
    font = OUT + "/Inter.ttf"
    for cand in ("/usr/share/fonts/inter/InterVariable.ttf", "/usr/share/fonts/TTF/InterVariable.ttf",
                 "/usr/share/fonts/TTF/Inter-Regular.ttf", "/usr/share/fonts/inter/Inter-Regular.ttf",
                 "/usr/share/fonts/noto/NotoSans-Regular.ttf", "/usr/share/fonts/TTF/DejaVuSans.ttf"):
        if os.path.isfile(cand):
            shutil.copyfile(cand, font)
            break
    with open(os.path.join(OUT, "theme.xml"), "w") as fh:
        fh.write(theme_xml())
    print(os.path.join(OUT, "theme.xml"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
