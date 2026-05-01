/*
 * Pixie Lockscreen — LockScreenUi
 * Visual design: Pixie SDDM by xCaptaiN09 (MIT)
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

    // Fixed accent color from Pixie's default wallpaper palette
    readonly property color accent: "#A9C78F"

    // Exposed for MainBlock lookups
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
            id: fadeoutTimer
            interval: 10000
            onTriggered: {
                if (!lockScreenRoot.blockUI) lockScreenRoot.uiVisible = false;
            }
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
        // WallpaperFader expects clock and footer to have an opacity property.
        // We pass stub Items so it doesn't crash with "non-existent property".
        WallpaperFader {
            anchors.fill: parent
            state: lockScreenRoot.uiVisible ? "on" : "off"
            source: wallpaper
            mainStack: mainStack
            // Stub items with opacity so WallpaperFader's PropertyChanges work
            clock:  stubClock
            footer: stubFooter
            alwaysShowClock: false
        }

        // Stub items passed to WallpaperFader for clock and footer.
        // WallpaperFader animates their native opacity (QQuickItem.opacity)
        // and clock.shadow.opacity via PropertyChanges — we must NOT redeclare
        // opacity (it is FINAL in QQuickItem). Just provide a real Item for
        // clock.shadow so the property path resolves without crashing.
        Item {
            id: stubClock
            visible: false; width: 0; height: 0
            property Item shadow: Item { visible: false; width: 0; height: 0 }
        }
        Item {
            id: stubFooter
            visible: false; width: 0; height: 0
        }

        // Dark overlay — matches Pixie exactly:
        //   idle  → opacity 0.4
        //   login → opacity 0.6
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: lockScreenRoot.uiVisible ? 0.6 : 0.4
            Behavior on opacity { NumberAnimation { duration: 400 } }
            z: 1
        }

        // ── Top bar — date (left) + PowerBar (right) ───────────────────────
        // Always visible, z:10, position mirrors Pixie Main.qml exactly.
        Item {
            id: topBar
            z: 10
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 60

            // Date label — topMargin:50, leftMargin:60 (Pixie values)
            Text {
                id: dateLabel
                anchors { top: parent.top; left: parent.left; topMargin: 50; leftMargin: 60 }
                text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
                color: lockScreenUi.accent
                font.pixelSize: 22
                font.family: pixieFontMedium.name
                opacity: 0.9
                Timer {
                    interval: 60000; running: true; repeat: true
                    onTriggered: dateLabel.text = Qt.formatDateTime(new Date(), "dddd, MMMM d")
                }
            }

            // PowerBar — topMargin:30, rightMargin:40 (Pixie values)
            Row {
                id: powerBar
                anchors { top: parent.top; right: parent.right; topMargin: 30; rightMargin: 40 }
                spacing: 20
                height: 30

                // Battery — BatteryControlModel from org.kde.plasma.private.battery
                // exposes: hasInternalBatteries, pluggedIn, hasCumulative, percent
                Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    visible: batteryControl.hasInternalBatteries

                    BatteryControlModel { id: batteryControl }

                    Text {
                        text: batteryControl.percent + "%"
                        color: lockScreenUi.accent
                        font.pixelSize: 14
                        font.family: pixieFontMedium.name
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: batteryControl.pluggedIn ? "󱐋" : "󰁹"
                        color: lockScreenUi.accent
                        font.pixelSize: 18
                        font.family: pixieFontMedium.name
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Keyboard layout switcher
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
                              || keyboardLayoutSwitcher.layoutNames.longName
                              || "??"
                        color: lockScreenUi.accent
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
                    color: lockScreenUi.accent
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

                // Suspend
                Text {
                    text: "󰤄"
                    color: lockScreenUi.accent
                    font.pixelSize: 20
                    font.family: pixieFontMedium.name
                    anchors.verticalCenter: parent.verticalCenter
                    scale: suspendArea.containsPress ? 0.88 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                    MouseArea {
                        id: suspendArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.suspendToRamSupported
                                   ? root.suspendToRam()
                                   : sessionManagement.suspend()
                    }
                }
            }
        }

        // ── Clock — centered, fades out when UI becomes visible ────────────
        Item {
            id: pixieClockContainer
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
                baseAccent: lockScreenUi.accent
                fontFamily: pixieFontMedium.name
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

                StackView.onStatusChanged: {
                    if (StackView.status === StackView.Activating) {
                        mainPasswordBox.clear();
                        mainPasswordBox.focus = true;
                        root.notification = "";
                    }
                }

                notificationMessage: {
                    const parts = [];
                    if (capsLockState.locked)
                        parts.push(i18ndc("plasma_shell_org.kde.plasma.desktop",
                                          "@info:status", "Caps Lock is on"));
                    if (root.notification)
                        parts.push(root.notification);
                    return parts.join(" • ");
                }

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
