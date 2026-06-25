pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // ── Matte Black palette ──────────────────────────────────────────
    readonly property color bg:        "#121212"  // page background
    readonly property color bar:       "#1a1a1a"  // bar surface (slightly raised)
    readonly property color surface:   "#1e1e1e"  // popout surface
    readonly property color elevated:  "#333333"  // cards / hovered
    readonly property color selection: "#515151"
    readonly property color text:      "#bebebe"
    readonly property color dim:       "#8a8a8d"
    readonly property color bright:    "#eaeaea"
    readonly property color accent:    "#e68e0d"  // orange
    readonly property color accent2:   "#f59e0b"  // amber
    readonly property color danger:    "#b91c1c"
    readonly property color blue:      "#7aa2f7"
    readonly property color magenta:   "#c678dd"

    // ── Nerd Font icon glyphs (codepoint → char; avoids escape mangling) ──
    readonly property string iArch:     String.fromCodePoint(0xf303)
    // Graded glyphs (Material Design, nf-md-*). Reactive when called in bindings.
    function volGlyph(vol, muted) {
        if (muted || vol < 0.01) return String.fromCodePoint(0xF075F); // volume-mute
        if (vol < 0.20)  return String.fromCodePoint(0xF057F);         // volume-low   (1 bar)
        if (vol <= 0.70) return String.fromCodePoint(0xF0580);         // volume-medium(2 bars)
        return String.fromCodePoint(0xF057E);                          // volume-high  (3 bars)
    }
    function wifiGlyph(on, connected, strength) {
        if (!on) return String.fromCodePoint(0xF092C);                 // wifi-strength-off-outline
        if (!connected) return String.fromCodePoint(0xF092D);          // wifi-strength-outline
        if (strength < 25) return String.fromCodePoint(0xF091F);       // _1
        if (strength < 50) return String.fromCodePoint(0xF0922);       // _2
        if (strength < 75) return String.fromCodePoint(0xF0925);       // _3
        return String.fromCodePoint(0xF0928);                          // _4
    }
    function btGlyph(on, connected) {
        if (!on) return String.fromCodePoint(0xF00B2);                 // bluetooth-off
        if (connected) return String.fromCodePoint(0xF00B1);           // bluetooth-connect
        return String.fromCodePoint(0xF00AF);                          // bluetooth
    }
    function batteryGlyph(pct, charging) {
        if (charging) return String.fromCodePoint(0xF0084);            // battery-charging
        var l = Math.round(pct / 10);
        if (l >= 10) return String.fromCodePoint(0xF0079);             // battery (full)
        if (l <= 0)  return String.fromCodePoint(0xF0083);             // battery-alert
        return String.fromCodePoint(0xF0079 + l);                      // battery_10 .. _90
    }
    // Display battery as a fraction of the BIOS charge cap, so a capped-full
    // pack reads 100% (and the glyph shows full). real/cap*100, clamped to 100.
    readonly property int chargeCap: 80
    function dispPct(p) { return Math.min(100, Math.round(p / chargeCap * 100)); }

    readonly property string iBolt:     String.fromCodePoint(0xf0e7)
    readonly property string iPlug:     String.fromCodePoint(0xf1e6)
    readonly property string iSun:      String.fromCodePoint(0xF00E0)  // md-brightness-7
    readonly property string iPower:    String.fromCodePoint(0xf011)
    readonly property string iLock:     String.fromCodePoint(0xf023)
    readonly property string iReboot:   String.fromCodePoint(0xf021)
    readonly property string iLogout:   String.fromCodePoint(0xf08b)
    readonly property string iSuspend:  String.fromCodePoint(0xf186)
    readonly property string iAirplane: String.fromCodePoint(0xF001D)  // md-airplane (orange when active)

    // ── Metrics ──────────────────────────────────────────────────────
    readonly property int  barHeight: 36
    readonly property int  radius:    10        // Material rounding for bar pills/popouts
    readonly property int  gap:       6
    readonly property int  pad:       10

    // ── Animation ────────────────────────────────────────────────────
    readonly property int  animFast: 120        // slider glide / quick UI feedback
    readonly property int  animMed:  160        // popout fade in / out

    // ── Typography ───────────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int    fontSize:   13
}
