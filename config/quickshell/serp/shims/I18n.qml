pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// English strings from Serpantinum's language file.
// t("a.b.c") looks up the dotted key; a second argument is either a fallback string
// or an object of {placeholders}.
Singleton {
    id: root
    readonly property string currentLang: "en"
    readonly property bool rtl: false
    readonly property int layoutDirection: Qt.LeftToRight
    readonly property int textAlignment: Text.AlignLeft
    property var strings: ({})

    function t(key, arg) {
        let node = root.strings;
        for (const part of String(key).split(".")) {
            node = node ? node[part] : undefined;
        }
        let text = typeof node === "string" ? node : (typeof arg === "string" ? arg : key);
        if (arg && typeof arg === "object")
            for (const k in arg) text = text.replace(new RegExp("\\{" + k + "\\}", "g"), arg[k]);
        return text;
    }

    FileView {
        path: Quickshell.shellPath("serp/assets/languages/en.json")
        blockLoading: true
        onLoaded: { try { root.strings = JSON.parse(text()); } catch (e) {} }
    }
}
