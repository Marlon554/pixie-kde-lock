/*
 * Pixie Lockscreen — PixieClock
 * Clock design and color logic adapted from Pixie SDDM by xCaptaiN09
 * https://github.com/xCaptaiN09/pixie-sddm (MIT License)
 *
 * Two-tone stacked clock: hours and minutes share the same digit columns,
 * offset vertically so they interleave. Colors come from LockScreenUi:
 *   hoursColor   — Plasma accent (raw highlightColor)
 *   minutesColor — accent tinted 40 % toward white via Qt.tint()
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Item {
    id: clock

    // Colors set by LockScreenUi — no internal derivation needed
    property color  hoursColor:   "#A9C78F"
    property color  minutesColor: "#D4E4BC"
    property string fontFamily:   ""

    property string timeStr: Qt.formatTime(new Date(), "HHmm")

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: clock.timeStr = Qt.formatTime(new Date(), "HHmm")
    }

    implicitWidth:  digitRow.implicitWidth
    implicitHeight: digitRow.implicitHeight

    Row {
        id: digitRow
        anchors.centerIn: parent
        spacing: 0

        // Column 1 — tens digit of hours (top) and tens digit of minutes (bottom)
        Column {
            spacing: -130
            Text {
                text: clock.timeStr.charAt(0)
                color: clock.hoursColor
                font { pixelSize: 200; family: clock.fontFamily; weight: Font.Medium }
                width: 130; horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
            Text {
                text: clock.timeStr.charAt(2)
                color: clock.minutesColor
                font { pixelSize: 200; family: clock.fontFamily; weight: Font.Medium }
                width: 130; horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
        }

        // Column 2 — ones digit of hours (top) and ones digit of minutes (bottom)
        Column {
            spacing: -130
            Text {
                text: clock.timeStr.charAt(1)
                color: clock.hoursColor
                font { pixelSize: 200; family: clock.fontFamily; weight: Font.Medium }
                width: 130; horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
            Text {
                text: clock.timeStr.charAt(3)
                color: clock.minutesColor
                font { pixelSize: 200; family: clock.fontFamily; weight: Font.Medium }
                width: 130; horizontalAlignment: Text.AlignHCenter
                antialiasing: true
            }
        }
    }
}
