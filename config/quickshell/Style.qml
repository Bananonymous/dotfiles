pragma Singleton

import QtQuick
import Quickshell

// Shared sizes, fonts, motion and Nerd Font glyphs (codepoints, so they survive any editor).
Singleton {
    // Text in a proportional UI face, glyphs from the Nerd Font
    // Same UI font as the reference shell (Serpantinum's default)
    readonly property string font: "Adwaita Mono"
    readonly property string iconFont: "Hack Nerd Font Propo"
    readonly property string monoFont: "Hack Nerd Font"
    readonly property int fontSize: 13

    readonly property int barHeight: 40
    readonly property int chipHeight: 28
    readonly property int pillRadius: 11
    readonly property int chipRadius: 8
    readonly property int panelRadius: 20
    readonly property int gap: 6

    // Motion: island morphs on a spring, contents cross-fade on top of it
    readonly property real springStiffness: 3.6
    readonly property real springDamping: 0.30
    readonly property int fadeMs: 220
    readonly property int moveMs: 380

    // Shared across every bar
    property bool idleInhibit: false
    // `qs ipc call panel toggle <name>` -> the focused screen opens that panel
    signal panelRequested(string name)
    // `qs ipc call panel eq <Preset>` -> apply a preset with the lightning sweep
    signal eqPresetRequested(string name)

    function glyph(cp) { return String.fromCodePoint(cp) }

    readonly property string iWindow: glyph(0xf2d0)
    readonly property string iCalendar: glyph(0xf073)
    readonly property string iClock: glyph(0xf0954)
    readonly property string iCpu: glyph(0xf2db)
    readonly property string iUptime: glyph(0xf0150)
    readonly property string iMemory: glyph(0xf0fb2)
    readonly property string iTemp: glyph(0xf050f)
    readonly property string iVolHigh: glyph(0xf057e)
    readonly property string iVolMid: glyph(0xf0580)
    readonly property string iVolLow: glyph(0xf057f)
    readonly property string iMuted: glyph(0xf075f)
    readonly property string iHeadset: glyph(0xf02ce)
    readonly property string iMic: glyph(0xf036c)
    readonly property string iMicMuted: glyph(0xf036d)
    readonly property string iDown: glyph(0xf01da)
    readonly property string iUp: glyph(0xf0552)
    readonly property string iOffline: glyph(0xf05aa)
    readonly property string iUpdates: glyph(0xf03d7)
    readonly property string iCoffee: glyph(0xf0176)
    readonly property string iBell: glyph(0xf009a)
    readonly property string iBellOff: glyph(0xf009b)
    readonly property string iTrash: glyph(0xf1f8)
    readonly property string iPower: glyph(0xf0425)
    readonly property string iReboot: glyph(0xf0709)
    readonly property string iLock: glyph(0xf033e)
    readonly property string iLogout: glyph(0xf0343)
    readonly property string iClose: glyph(0xf0156)
    readonly property string iPlay: glyph(0xf040a)
    readonly property string iPause: glyph(0xf03e4)
    readonly property string iNext: glyph(0xf04ad)
    readonly property string iPrev: glyph(0xf04ae)
    readonly property string iMusic: glyph(0xf075a)
    readonly property string iChevronLeft: glyph(0xf0141)
    readonly property string iChevronRight: glyph(0xf0142)
    readonly property string iCheck: glyph(0xf012c)
    readonly property string iSearch: glyph(0xf002)
    readonly property string iWifi: glyph(0xf05a9)
    readonly property string iWifiOff: glyph(0xf05aa)
    readonly property string iEthernet: glyph(0xf0200)
    readonly property string iBluetooth: glyph(0xf00af)
    readonly property string iBluetoothOff: glyph(0xf00b2)
    readonly property string iWallpaper: glyph(0xf0e8a)
    readonly property string iBattery: glyph(0xf0079)
    readonly property string iCharging: glyph(0xf0084)
    readonly property string iSleep: glyph(0xf04b2)
    readonly property string iGauge: glyph(0xf029a)
    readonly property string iScale: glyph(0xf05d1)
    readonly property string iLeaf: glyph(0xf032a)
    readonly property string iSun: glyph(0xf0599)
    readonly property string iHeadphones: glyph(0xf02cb)
    readonly property string iDevice: glyph(0xf0379)
    readonly property string iIp: glyph(0xf0a5f)
    readonly property string iShield: glyph(0xf0498)
    readonly property string iSignal: glyph(0xf08bf)
    readonly property string iRadar: glyph(0xf0437)
    readonly property string iWind: glyph(0xf059d)
    readonly property string iDrop: glyph(0xf058c)
    readonly property string iUmbrella: glyph(0xf054a)
    readonly property string iPlus: glyph(0xf0415)
    readonly property string iOpen: glyph(0xf03cc)
    readonly property string iHourglass: glyph(0xf051f)
    readonly property string iPickaxe: glyph(0xf08b7)

    function volumeIcon(vol, muted, headset) {
        if (muted) return iMuted;
        if (headset) return iHeadset;
        return vol < 0.34 ? iVolLow : vol < 0.67 ? iVolMid : iVolHigh;
    }
}
