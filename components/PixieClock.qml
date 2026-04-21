/**
 * Pixie Clock Component - adapted for Plasma lockscreen
 * Original: xCaptaiN09 (pixie-sddm)
 */
import QtQuick

Item {
    id: clock

    property color baseAccent: "#A9C78F"
    property color smartHoursColor: "#AED68A"
    property color smartMinutesColor: "#D4E4BC"
    property string fontFamily: pixieFontMedium.name

    property string timeStr: Qt.formatTime(new Date(), "HHmm")

    function updateColors() {
        var base = clock.baseAccent;
        if (base.hsvValue < 0.3) {
            clock.smartHoursColor   = Qt.hsva(base.hsvHue, 0.6,  0.90, 1.0);
            clock.smartMinutesColor = Qt.hsva(base.hsvHue, 0.35, 0.85, 1.0);
        } else if (base.hsvValue > 0.8 && base.hsvSaturation < 0.2) {
            clock.smartHoursColor   = Qt.hsva(base.hsvHue, 0.80, 0.70, 1.0);
            clock.smartMinutesColor = Qt.hsva(base.hsvHue, 0.50, 0.75, 1.0);
        } else {
            clock.smartHoursColor   = Qt.hsva(base.hsvHue, Math.min(1.0, base.hsvSaturation * 1.3),  0.95, 1.0);
            clock.smartMinutesColor = Qt.hsva(base.hsvHue, Math.min(1.0, base.hsvSaturation * 0.75), 0.92, 1.0);
        }
    }

    onBaseAccentChanged: updateColors()
    Component.onCompleted: updateColors()

    implicitWidth: digitRow.implicitWidth
    implicitHeight: digitRow.implicitHeight

    Row {
        id: digitRow
        anchors.centerIn: parent
        spacing: 0

        // Column 1: tens of hour / tens of minute
        Column {
            spacing: -130
            Text {
                text: clock.timeStr.charAt(0)
                color: clock.smartHoursColor
                font.pixelSize: 200
                font.family: clock.fontFamily
                font.weight: Font.Medium
                width: 130
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
            Text {
                text: clock.timeStr.charAt(2)
                color: clock.smartMinutesColor
                font.pixelSize: 200
                font.family: clock.fontFamily
                font.weight: Font.Medium
                width: 130
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
        }

        // Column 2: ones of hour / ones of minute
        Column {
            spacing: -130
            Text {
                text: clock.timeStr.charAt(1)
                color: clock.smartHoursColor
                font.pixelSize: 200
                font.family: clock.fontFamily
                font.weight: Font.Medium
                width: 130
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
            Text {
                text: clock.timeStr.charAt(3)
                color: clock.smartMinutesColor
                font.pixelSize: 200
                font.family: clock.fontFamily
                font.weight: Font.Medium
                width: 130
                horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.timeStr = Qt.formatTime(new Date(), "HHmm")
    }
}
