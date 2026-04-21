/*
 * Pixie Lockscreen - Plasma kscreenlocker theme
 * Visual design adapted from Pixie SDDM by xCaptaiN09
 * Base structure: Plasma kscreenlocker (GPL-2.0-or-later)
 *
 * SPDX-License-Identifier: MIT OR GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.workspace.components as PW
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker

import org.kde.plasma.private.sessions
import org.kde.breeze.components

import "components"

Item {
    id: lockScreenUi

    // Accent extracted from the wallpaper
    property color extractedAccent: "#A9C78F"

    // Exposed so that MainBlock can access sessionManagement and fonts
    property alias sessionManagement: sessionManagement
    property alias pixieFontMedium:   pixieFontMedium
    property alias pixieFontRegular:  pixieFontRegular
    property alias pixieFontBold:     pixieFontBold

    // Save the result of `grabToImage` to prevent it from being collected by the GC
    property var _grabbedImage: null

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
        function onInfoMessageChanged()     { lockScreenUi.handleMessage(authenticator.infoMessage); }
        function onErrorMessageChanged()    { lockScreenUi.handleMessage(authenticator.errorMessage); }
        function onPromptChanged()          { lockScreenUi.handleMessage(authenticator.prompt); }
        function onPromptForSecretChanged() {
            mainBlock.showPassword = false;
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

    // ── Root MouseArea ─────────────────────────────────────────────────────
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

        Timer { id: fadeoutTimer; interval: 10000
            onTriggered: {
                if (!lockScreenRoot.blockUI) {
                    mainBlock.mainPasswordBox.showPassword = false;
                    lockScreenRoot.uiVisible = false;
                }
            }
        }
        Timer { id: notificationRemoveTimer; interval: 3000
            onTriggered: root.notification = ""
        }
        Timer { id: graceLockTimer; interval: 3000
            onTriggered: { root.clearPassword(); authenticator.startAuthenticating(); }
        }

        PropertyAnimation {
            id: launchAnimation; target: lockScreenRoot; property: "opacity"
            from: 0; to: 1; duration: Kirigami.Units.veryLongDuration * 2
        }
        Component.onCompleted: launchAnimation.start()

        // ── Wallpaper (WallpaperFader controls blur) ───────────────────────
        WallpaperFader {
            anchors.fill: parent
            state: lockScreenRoot.uiVisible ? "on" : "off"
            source: wallpaper
            mainStack: mainStack
            footer: footer
            clock: dummyClockRef
            alwaysShowClock: false
        }
        Item { id: dummyClockRef; visible: false; width: 0; height: 0 }

        // ── Permanent dark overlay ──────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.38
            z: 0
        }

        // ── Extracting color from the wallpaper ───────────────────────────────────
        //
        // Problem: `wallpaper` is an opaque Item injected by the C++ kscreenlocker.
        // ctx.drawImage(wallpaper) on a Canvas fails silently in Qt6.
        // grabToImage() directly on the wallpaper may fail if the item has not
        // been composited for at least one frame in the scene graph.
        //
        // Two-step solution:
        //   1. ShaderEffectSource points to wallpaper → forces GPU composition
        //   2. grabToImage() on ShaderEffectSource → real image:// URL
        //   3. QML Image loads this URL → pixels accessible via Canvas

        // Step 1: capture the wallpaper as a texture
        ShaderEffectSource {
            id: wallpaperCapture
            sourceItem: wallpaper
            width:  64; height: 64
            x: -300; y: -300
            visible: false
            hideSource: false   // doesn't hide the original wallpaper
            live: false         // freezes the frame — does not refresh continuamente
        }

        // Step 2: Image that will receive the URL from the grab
        Image {
            id: grabbedWallpaper
            width: 64; height: 64
            x: -300; y: -300
            visible: false
            cache: false
            fillMode: Image.Stretch

            onStatusChanged: {
                if (status === Image.Ready) {
                    accentCanvas.requestPaint();
                }
            }
        }

        // Step 3: Canvas analyzes the pixels in the captured image
        Canvas {
            id: accentCanvas
            width: 64; height: 64
            x: -300; y: -300
            visible: false

            property bool processed: false

            onPaint: {
                if (processed) return;
                if (grabbedWallpaper.status !== Image.Ready) return;

                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.drawImage(grabbedWallpaper, 0, 0, width, height);

                var d = ctx.getImageData(0, 0, width, height).data;
                if (!d || d.length < 4) {
                    grabRetryTimer.restart();
                    return;
                }

                // Check that they are not all zeros (empty capture)
                var hasPixels = false;
                for (var k = 0; k < Math.min(d.length, 64); k++) {
                    if (d[k] > 0) { hasPixels = true; break; }
                }
                if (!hasPixels) {
                    grabRetryTimer.restart();
                    return;
                }

                var histogram    = new Array(36).fill(0);
                var sampleColors = new Array(36).fill(null);
                var vibrantFound = false;

                for (var i = 0; i < d.length; i += 4) {
                    var r = d[i]   / 255;
                    var g = d[i+1] / 255;
                    var b = d[i+2] / 255;
                    var c = Qt.rgba(r, g, b, 1.0);

                    if (c.hsvSaturation > 0.20 && c.hsvValue > 0.15) {
                        var h = c.hsvHue * 360;
                        if (h < 0) continue;
                        var bIdx = Math.floor(h / 10) % 36;
                        var w    = c.hsvSaturation * c.hsvValue;
                        histogram[bIdx] += w;
                        if (!sampleColors[bIdx] ||
                                w > sampleColors[bIdx].hsvSaturation * sampleColors[bIdx].hsvValue)
                            sampleColors[bIdx] = c;
                        vibrantFound = true;
                    }
                }

                if (!vibrantFound) {
                    grabRetryTimer.restart();
                    return;
                }

                histogram[0] += histogram[35];
                var maxCount = -1, winnerIdx = -1;
                for (var j = 0; j < 35; j++) {
                    if (histogram[j] > maxCount) {
                        maxCount = histogram[j];
                        winnerIdx = j;
                    }
                }

                if (winnerIdx !== -1 && sampleColors[winnerIdx]) {
                    var fc = sampleColors[winnerIdx];
                    var s  = Math.max(0.35, Math.min(0.65, fc.hsvSaturation * 0.85));
                    lockScreenUi.extractedAccent = Qt.hsva(fc.hsvHue, s, 0.95, 1.0);
                    processed = true;
                }
            }
        }

        // Main timer: waits for the wallpaper to load, then takes the screenshot
        Timer {
            id: grabTimer
            interval: 1500
            repeat: false
            running: true
            onTriggered: doGrab()
        }

        // Retry timer in case the capture fails
        Timer {
            id: grabRetryTimer
            interval: 1000
            repeat: false
            onTriggered: doGrab()
        }

        function doGrab() {
            if (accentCanvas.processed) return;
            // Forces the ShaderEffectSource to update with the current frame
            wallpaperCapture.scheduleUpdate();
            // A short delay to allow the scheduleUpdate to propagate before the grab
            Qt.callLater(function() {
                wallpaperCapture.grabToImage(function(result) {
                    lockScreenUi._grabbedImage = result;
                    if (result && result.url && result.url !== "") {
                        grabbedWallpaper.source = result.url;
                        // if already loaded (cached), trigger onPaint directly
                        if (grabbedWallpaper.status === Image.Ready)
                            accentCanvas.requestPaint();
                    } else {
                        grabRetryTimer.restart();
                    }
                }, Qt.size(64, 64));
            });
        }

        // ════════════════════════════════ ══════════════════════════════════
        // FIXED ELEMENTS — date (top left) + suspend (top right)
        // Visible immediately, without depending on accentCanvas.processed,
        // since the accent will not yet be available in the first frame.
        // They use z:10 to appear above the overlay and the WallpaperFader.
        // ════════════════════════════════ ══════════════════════════════════

        // ── Date ──────────────────────────────────────────────────────────
        Text {
            id: dateLabel
            z: 10
            anchors {
                top: parent.top; left: parent.left
                topMargin: 44; leftMargin: 56
            }
            text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
            color: accentCanvas.processed
                   ? lockScreenUi.extractedAccent
                   : "#aed68a"
            font.pixelSize: 20
            font.family: pixieFontMedium.name
            // Always visible — no opacity condition
            opacity: 0.9
            Behavior on color { ColorAnimation { duration: 800 } }

            Timer {
                interval: 60000; running: true; repeat: true
                onTriggered: dateLabel.text = Qt.formatDateTime(new Date(), "dddd, MMMM d")
            }
        }

        // ── Suspend Button ────────────────────────────────────────────────
        // Always visible (z:10). In --testing, suspendToRamSupported = false,
        // so we show it anyway — clicking does nothing in testing.
        Item {
            id: suspendButton
            z: 10
            anchors {
                top: parent.top; right: parent.right
                topMargin: 28; rightMargin: 44
            }
            width: 40; height: 40

            Text {
                id: suspendIcon
                anchors.centerIn: parent
                text: "󰤄"
                font.pixelSize: 24
                font.family: pixieFontMedium.name
                color: accentCanvas.processed
                       ? lockScreenUi.extractedAccent
                       : "#aed68a"
                opacity: suspendArea.containsMouse ? 1.0 : 0.75
                Behavior on color   { ColorAnimation  { duration: 800 } }
                Behavior on opacity { NumberAnimation  { duration: 150 } }

                scale: suspendArea.containsPress ? 0.88 : 1.0
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
            }

            MouseArea {
                id: suspendArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.suspendToRamSupported)
                        root.suspendToRam();
                    else
                        sessionManagement.suspend();
                }
            }
        }

        // ════════════════════════════════ ══════════════════════════════════
        // CLOCK — centered, hidden when uiVisible = true
        // ════════════════════════════════ ══════════════════════════════════
        Item {
            id: pixieClockContainer
            z: 5
            anchors.centerIn: parent
            width:  pixieClock.implicitWidth
            height: pixieClock.implicitHeight

            opacity: lockScreenRoot.uiVisible ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.InOutQuad
                }
            }

            PixieClock {
                id: pixieClock
                baseAccent: lockScreenUi.extractedAccent
                fontFamily: pixieFontMedium.name
            }
        }

        // ══════════════════════════════════════════════════════════════════
        // LOGIN CARD
        // ══════════════════════════════════════════════════════════════════
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

        // ── OSD ───────────────────────────────────────────────────────────
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

        // ── Footer ────────────────────────────────────────────────────────
        RowLayout {
            id: footer
            z: 10
            anchors {
                bottom: parent.bottom; left: parent.left; right: parent.right
                margins: Kirigami.Units.smallSpacing
            }
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                id: virtualKeyboardButton
                focusPolicy: Qt.TabFocus
                text: i18ndc("plasma_shell_org.kde.plasma.desktop",
                             "Button to show/hide virtual keyboard", "Virtual Keyboard")
                icon.name: inputPanel.keyboardActive
                           ? "input-keyboard-virtual-on" : "input-keyboard-virtual-off"
                onClicked: {
                    mainBlock.mainPasswordBox.forceActiveFocus();
                    inputPanel.showHide();
                }
                visible: inputPanel.status === Loader.Ready
                Layout.fillHeight: true
                containmentMask: Item {
                    parent: virtualKeyboardButton
                    anchors.fill: parent
                    anchors.leftMargin:   -footer.anchors.margins
                    anchors.bottomMargin: -footer.anchors.margins
                }
            }

            PlasmaComponents3.ToolButton {
                id: keyboardButton
                focusPolicy: Qt.TabFocus
                Accessible.description: i18ndc("plasma_shell_org.kde.plasma.desktop",
                                               "Button to change keyboard layout", "Switch layout")
                icon.name: "input-keyboard"
                PW.KeyboardLayoutSwitcher {
                    id: keyboardLayoutSwitcher
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                }
                text: keyboardLayoutSwitcher.layoutNames.longName
                onClicked: keyboardLayoutSwitcher.keyboardLayout.switchToNextLayout()
                visible: keyboardLayoutSwitcher.hasMultipleKeyboardLayouts
                Layout.fillHeight: true
                containmentMask: Item {
                    parent: keyboardButton
                    anchors.fill: parent
                    anchors.leftMargin:   virtualKeyboardButton.visible ? 0 : -footer.anchors.margins
                    anchors.bottomMargin: -footer.anchors.margins
                }
            }

            Item { Layout.fillWidth: true }
            Battery {}
        }
    }
}
