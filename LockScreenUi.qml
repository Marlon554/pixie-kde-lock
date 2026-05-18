/*
 * Pixie Lockscreen — LockScreenUi
 * Visual design adapted from Pixie SDDM by xCaptaiN09
 * https://github.com/xCaptaiN09/pixie-sddm (MIT License)
 *
 * Base: Plasma kscreenlocker (GPL-2.0-or-later)
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.workspace.components as PW
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.private.battery
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker

import org.kde.plasma.private.sessions
import org.kde.breeze.components

import "components"

Item {
    id: lockScreenUi

    // ── Accent colors derived from Plasma's highlight color ────────────────
    // The same updateColors() logic from Pixie's Clock.qml, applied to
    // Kirigami.Theme.highlightColor instead of the extracted wallpaper color.
    //
    // accentHours   — vibrant tone (sat×1.3, val 0.95) + 15 % white tint.
    //                 Used for: hours digits, date label, PowerBar icons.
    // accentMinutes — soft/pastel tone (sat×0.75, val 0.92) + 40 % white tint.
    //                 Used for: minutes digits only.
    readonly property color _h: Kirigami.Theme.highlightColor

    readonly property color accentHours: {
        var h = _h;
        var v;
        if (h.hsvValue < 0.3) {
            v = Qt.hsva(h.hsvHue, 0.6, 0.90, 1.0);
        } else if (h.hsvValue > 0.8 && h.hsvSaturation < 0.2) {
            v = Qt.hsva(h.hsvHue, 0.80, 0.70, 1.0);
        } else {
            v = Qt.hsva(h.hsvHue, Math.min(1.0, h.hsvSaturation * 1.3), 0.95, 1.0);
        }
        return Qt.tint(v, Qt.rgba(1, 1, 1, 0.15));
    }

    readonly property color accentMinutes: {
        var h = _h;
        var v;
        if (h.hsvValue < 0.3) {
            v = Qt.hsva(h.hsvHue, 0.35, 0.85, 1.0);
        } else if (h.hsvValue > 0.8 && h.hsvSaturation < 0.2) {
            v = Qt.hsva(h.hsvHue, 0.50, 0.75, 1.0);
        } else {
            v = Qt.hsva(h.hsvHue, Math.min(1.0, h.hsvSaturation * 0.75), 0.92, 1.0);
        }
        return Qt.tint(v, Qt.rgba(1, 1, 1, 0.40));
    }

    // accentHours is used everywhere outside the clock (date, PowerBar, card)
    readonly property color accent: accentHours

    property alias sessionManagement: sessionManagement
    property alias pixieFontMedium:   pixieFontMedium
    property alias pixieFontRegular:  pixieFontRegular
    property alias pixieFontBold:     pixieFontBold

    FontLoader { id: pixieFontRegular; source: "assets/fonts/FlexRounded-R.ttf" }
    FontLoader { id: pixieFontMedium;  source: "assets/fonts/FlexRounded-M.ttf" }
    FontLoader { id: pixieFontBold;    source: "assets/fonts/FlexRounded-B.ttf" }

    function handleMessage(msg) {
        if (!root.notification) {
            root.notification += msg;
        } else if (root.notification.includes(msg)) {
            root.notificationRepeated();
        } else {
            root.notification += "\n" + msg;
        }
    }

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind !== 0) return;
            lockScreenUi.handleMessage(
                i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Unlocking failed"));
            graceLockTimer.restart();
            notificationRemoveTimer.restart();
            rejectPasswordAnimation.start();
        }
        function onSucceeded() {
            if (authenticator.hadPrompt) {
                Qt.quit();
            } else {
                mainStack.replace(null, Qt.resolvedUrl("NoPasswordUnlock.qml"),
                    { userListModel: users }, StackView.Immediate);
                mainStack.forceActiveFocus();
            }
        }
        function onInfoMessageChanged()  { lockScreenUi.handleMessage(authenticator.infoMessage); }
        function onErrorMessageChanged() { lockScreenUi.handleMessage(authenticator.errorMessage); }
        function onPromptChanged()       { lockScreenUi.handleMessage(authenticator.prompt); }
        function onPromptForSecretChanged() {
            mainBlock.mainPasswordBox.forceActiveFocus();
        }
    }

    SessionManagement { id: sessionManagement }
    KeyboardIndicator.KeyState { id: capsLockState; key: Qt.Key_CapsLock }

    Connections {
        target: sessionManagement
        function onAboutToSuspend() { root.clearPassword(); }
    }

    RejectPasswordAnimation { id: rejectPasswordAnimation; target: mainBlock }

    ListModel {
        id: users
        Component.onCompleted: {
            users.append({
                name:     kscreenlocker_userName,
                realName: kscreenlocker_userName,
                icon:     kscreenlocker_userImage !== ""
                          ? "file://" + kscreenlocker_userImage
                                            .split("/").map(encodeURIComponent).join("/")
                          : "",
            });
        }
    }

    // ── Root mouse area ────────────────────────────────────────────────────
    MouseArea {
        id: lockScreenRoot

        property bool uiVisible: false
        property bool seenPositionChange: false
        property bool blockUI: containsMouse
                               && (mainStack.depth > 1
                                   || mainBlock.mainPasswordBox.text.length > 0
                                   || inputPanel.keyboardActive)

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        drag.filterChildren: true

        onPressed:         uiVisible = true
        onPositionChanged: { uiVisible = seenPositionChange; seenPositionChange = true; }
        onUiVisibleChanged: {
            if (uiVisible) Window.window.requestActivate();
            if (blockUI)        fadeoutTimer.running = false;
            else if (uiVisible) fadeoutTimer.restart();
            authenticator.startAuthenticating();
        }
        onBlockUIChanged: {
            if (blockUI) { fadeoutTimer.running = false; uiVisible = true; }
            else           fadeoutTimer.restart();
        }
        onExited: uiVisible = false

        Keys.onEscapePressed: {
            if (uiVisible) {
                uiVisible = false;
                if (inputPanel.keyboardActive) inputPanel.showHide();
                root.clearPassword();
            }
        }
        Keys.onPressed: event => { uiVisible = true; event.accepted = false; }

        Timer {
            id: fadeoutTimer; interval: 10000
            onTriggered: { if (!lockScreenRoot.blockUI) lockScreenRoot.uiVisible = false; }
        }
        Timer { id: notificationRemoveTimer; interval: 3000; onTriggered: root.notification = "" }
        Timer {
            id: graceLockTimer; interval: 3000
            onTriggered: { root.clearPassword(); authenticator.startAuthenticating(); }
        }

        PropertyAnimation {
            id: launchAnimation; target: lockScreenRoot; property: "opacity"
            from: 0; to: 1; duration: Kirigami.Units.veryLongDuration * 2
        }
        Component.onCompleted: launchAnimation.start()

        // ── Wallpaper + blur ───────────────────────────────────────────────
        WallpaperFader {
            anchors.fill: parent
            state: lockScreenRoot.uiVisible ? "on" : "off"
            source: wallpaper
            mainStack: mainStack
            clock:  stubClock
            footer: stubFooter
            alwaysShowClock: false
        }
        // Stubs satisfy WallpaperFader's required properties without
        // redeclaring the FINAL opacity property of QQuickItem.
        Item {
            id: stubClock
            visible: false; width: 0; height: 0
            property Item shadow: Item { visible: false; width: 0; height: 0 }
        }
        Item { id: stubFooter; visible: false; width: 0; height: 0 }

        // Dark overlay — idle: 0.4, login: 0.6 (Pixie Main.qml values)
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: lockScreenRoot.uiVisible ? 0.6 : 0.4
            Behavior on opacity { NumberAnimation { duration: 400 } }
            z: 1
        }

        // ── Top bar ────────────────────────────────────────────────────────
        Item {
            id: topBar
            z: 10
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 80

            // Date — accentHours color, topMargin:50 leftMargin:60 (Pixie values)
            Text {
                id: dateLabel
                anchors { top: parent.top; left: parent.left; topMargin: 50; leftMargin: 60 }
                text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
                color: lockScreenUi.accentHours
                font.pixelSize: 22
                font.family: pixieFontMedium.name
                opacity: 0.9
                Timer {
                    interval: 60000; running: true; repeat: true
                    onTriggered: dateLabel.text = Qt.formatDateTime(new Date(), "dddd, MMMM d")
                }
            }

            // PowerBar — accentHours color, topMargin:30 rightMargin:40 spacing:20
            Row {
                anchors { top: parent.top; right: parent.right; topMargin: 30; rightMargin: 40 }
                spacing: 20
                height: 30

                // Battery — hidden on desktops without a battery
                Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    visible: batteryControl.hasInternalBatteries

                    BatteryControlModel { id: batteryControl }

                    Text {
                        text: batteryControl.percent + "%"
                        color: lockScreenUi.accentHours
                        font.pixelSize: 14
                        font.family: pixieFontMedium.name
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: batteryControl.pluggedIn ? "󱐋" : "󰁹"
                        color: lockScreenUi.accentHours
                        font.pixelSize: 18
                        font.family: pixieFontMedium.name
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Keyboard layout
                PW.KeyboardLayoutSwitcher {
                    id: keyboardLayoutSwitcher
                    anchors.verticalCenter: parent.verticalCenter
                    width: kbLayoutText.implicitWidth
                    height: 30
                    acceptedButtons: Qt.NoButton
                    visible: hasMultipleKeyboardLayouts

                    Text {
                        id: kbLayoutText
                        anchors.centerIn: parent
                        text: keyboardLayoutSwitcher.layoutNames.shortName
                              || keyboardLayoutSwitcher.layoutNames.longName || "??"
                        color: lockScreenUi.accentHours
                        font.pixelSize: 14
                        font.family: pixieFontMedium.name
                        font.capitalization: Font.AllUppercase
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: keyboardLayoutSwitcher.keyboardLayout.switchToNextLayout()
                    }
                }

                // Virtual keyboard toggle
                Text {
                    text: inputPanel.keyboardActive ? "󰌐" : "󰌌"
                    color: lockScreenUi.accentHours
                    font.pixelSize: 20
                    font.family: pixieFontMedium.name
                    anchors.verticalCenter: parent.verticalCenter
                    visible: inputPanel.status === Loader.Ready
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            mainBlock.mainPasswordBox.forceActiveFocus();
                            inputPanel.showHide();
                        }
                    }
                }

                // Suspend — 󰤄 (Pixie PowerBar icon)
                Text {
                    text: "󰤄"
                    color: lockScreenUi.accentHours
                    font.pixelSize: 20
                    font.family: pixieFontMedium.name
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        id: suspendArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.suspendToRamSupported
                                   ? root.suspendToRam()
                                   : sessionManagement.suspend()
                    }
                }
            }
        }

        // ── Clock — centered, fades out when login UI appears ──────────────
        Item {
            z: 5
            anchors.centerIn: parent
            width:  pixieClock.implicitWidth
            height: pixieClock.implicitHeight
            opacity: lockScreenRoot.uiVisible ? 0 : 1
            Behavior on opacity {
                NumberAnimation { duration: 400; easing.type: Easing.InOutQuad }
            }
            PixieClock {
                id: pixieClock
                hoursColor:   lockScreenUi.accentHours
                minutesColor: lockScreenUi.accentMinutes
                fontFamily:   pixieFontMedium.name
            }
        }

        // ── Login card ─────────────────────────────────────────────────────
        StackView {
            id: mainStack
            anchors.fill: parent
            z: 8
            focus: true
            visible: opacity > 0

            initialItem: MainBlock {
                id: mainBlock
                lockScreenUiVisible: lockScreenRoot.uiVisible
                enabled: !graceLockTimer.running
                userListModel: users
                capsLockOn: capsLockState.locked

                StackView.onStatusChanged: {
                    if (StackView.status === StackView.Activating) {
                        mainPasswordBox.clear();
                        mainPasswordBox.focus = true;
                        root.notification = "";
                    }
                }

                notificationMessage: root.notification

                onPasswordResult: password => authenticator.respond(password)
            }
        }

        // ── Virtual keyboard ───────────────────────────────────────────────
        VirtualKeyboardLoader {
            id: inputPanel
            z: 9
            screenRoot: lockScreenRoot
            mainStack:  mainStack
            mainBlock:  mainBlock
            passwordField: mainBlock.mainPasswordBox
        }

        // ── OSD ────────────────────────────────────────────────────────────
        Loader {
            z: 11
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Kirigami.Units.gridUnit
            }
        }
    }
}
