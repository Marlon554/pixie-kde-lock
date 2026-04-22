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

    property color extractedAccent: "#A9C78F"

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

    // ══════════════════════════════════════════════════════════════════════
    // COLOR EXTRACTION — reads kscreenlockerrc via XMLHttpRequest to obtain the
    // actual path of the wallpaper image and loads it using standard QML Image.
    // This avoids all issues with opaque Item / ShaderEffectSource / Qt6.
    // ══════════════════════════════════════════════════════════════════════

    // Wallpaper image loaded directly from the file system
    Image {
        id: wallpaperImg
        width: 64; height: 64
        visible: false
        cache: false
        fillMode: Image.Stretch
        smooth: false   // without anti-aliasing — we want the raw pixels

        onStatusChanged: {
            if (status === Image.Ready)
                accentCanvas.requestPaint();
        }
    }

    // A canvas that processes pixels and extracts the highlight
    Canvas {
        id: accentCanvas
        width: 64; height: 64
        x: -200; y: -200
        visible: false
        property bool processed: false

        onPaint: {
            if (processed || wallpaperImg.status !== Image.Ready) return;
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(wallpaperImg, 0, 0, width, height);

            var d = ctx.getImageData(0, 0, width, height).data;
            if (!d || d.length < 4) return;

            // Check to make sure the pixels are not zero.
            var hasPixels = false;
            for (var k = 0; k < Math.min(d.length, 128); k += 4) {
                if (d[k] > 5 || d[k+1] > 5 || d[k+2] > 5) { hasPixels = true; break; }
            }
            if (!hasPixels) return;

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
            if (!vibrantFound) return;

            histogram[0] += histogram[35];
            var maxCount = -1, winnerIdx = -1;
            for (var j = 0; j < 35; j++) {
                if (histogram[j] > maxCount) { maxCount = histogram[j]; winnerIdx = j; }
            }
            if (winnerIdx !== -1 && sampleColors[winnerIdx]) {
                var fc = sampleColors[winnerIdx];
                var s  = Math.max(0.35, Math.min(0.65, fc.hsvSaturation * 0.85));
                lockScreenUi.extractedAccent = Qt.hsva(fc.hsvHue, s, 0.95, 1.0);
                processed = true;
            }
        }
    }

    // Reads kscreenlockerrc and extracts the path to the wallpaper
    function readWallpaperPath() {
        // Get HOME via /proc/self/environ
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "file:///proc/self/environ", false);
        xhr.send();
        var home = "";
        if (xhr.status === 0 && xhr.responseText) {
            var vars = xhr.responseText.split("\0");
            for (var i = 0; i < vars.length; i++) {
                if (vars[i].startsWith("HOME=")) {
                    home = vars[i].substring(5);
                    break;
                }
            }
        }

        if (!home) return;

        var cfgXhr = new XMLHttpRequest();
        cfgXhr.open("GET", "file://" + home + "/.config/kscreenlockerrc", false);
        cfgXhr.send();

        if (cfgXhr.status !== 0 && cfgXhr.status !== 200) return;

        var text  = cfgXhr.responseText;
        var lines = text.split("\n");

        // Look for “Image=” or “PreviewImage=” in the wallpaper section
        var imagePath    = "";
        var previewPath  = "";
        var inSection    = false;

        for (var l = 0; l < lines.length; l++) {
            var line = lines[l].trim();
            // Detect section [Greeter][Wallpaper][org.kde.image][General]
            if (line.startsWith("[")) {
                inSection = line.indexOf("Wallpaper") !== -1 && line.indexOf("General") !== -1;
            }
            if (inSection) {
                if (line.startsWith("PreviewImage=") && !previewPath) {
                    previewPath = line.substring("PreviewImage=".length).trim();
                }
                if (line.startsWith("Image=") && !imagePath) {
                    imagePath = line.substring("Image=".length).trim();
                    // Remove file:// prefix if present
                    if (imagePath.startsWith("file://"))
                        imagePath = imagePath.substring(7);
                }
            }
        }

        // Prefer PreviewImage (small thumbnail = faster to process)
        var finalPath = previewPath || imagePath;
        if (!finalPath) return;

        // Ensure that it is a file:// URL
        if (!finalPath.startsWith("file://"))
            finalPath = "file://" + finalPath;

        wallpaperImg.source = finalPath;
    }

    // There is no StandardPaths in plain QML — use an alternative method
    // Reads the data as soon as the component is ready
    Component.onCompleted: {
        // A short delay while the system boots up completely
        Qt.callLater(readWallpaperPath);
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
            onTriggered: root.notification = "" }
        Timer { id: graceLockTimer; interval: 3000
            onTriggered: { root.clearPassword(); authenticator.startAuthenticating(); } }

        PropertyAnimation {
            id: launchAnimation; target: lockScreenRoot; property: "opacity"
            from: 0; to: 1; duration: Kirigami.Units.veryLongDuration * 2
        }
        Component.onCompleted: launchAnimation.start()

        // ── Wallpaper + blur via WallpaperFader ────────────────────────────
        WallpaperFader {
            anchors.fill: parent
            state: lockScreenRoot.uiVisible ? "on" : "off"
            source: wallpaper
            mainStack: mainStack
            footer: pixieFooter
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

        // ══════════════════════════════════════════════════════════════════
        // FIXED ELEMENTS (z:10) — always visible, independent of accent
        // ════════════════════════════════ ══════════════════════════════════

        // ── Date — upper left corner ────────────────────────────────
        Text {
            id: dateLabel
            z: 10
            anchors { top: parent.top; left: parent.left; topMargin: 44; leftMargin: 56 }
            text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
            color: accentCanvas.processed ? lockScreenUi.extractedAccent : "#AED68A"
            font.pixelSize: 20
            font.family: pixieFontMedium.name
            opacity: 0.9
            Behavior on color { ColorAnimation { duration: 800 } }
            Timer {
                interval: 60000; running: true; repeat: true
                onTriggered: dateLabel.text = Qt.formatDateTime(new Date(), "dddd, MMMM d")
            }
        }

        // ── Pause button — top right corner ──────────────────────
        Item {
            id: suspendButton
            z: 10
            anchors { top: parent.top; right: parent.right; topMargin: 30; rightMargin: 44 }
            width: 40; height: 40

            Text {
                anchors.centerIn: parent
                text: "󰤄"
                font.pixelSize: 24
                font.family: pixieFontMedium.name
                color: accentCanvas.processed ? lockScreenUi.extractedAccent : "#AED68A"
                opacity: suspendArea.containsMouse ? 1.0 : 0.8
                scale:   suspendArea.containsPress  ? 0.88 : 1.0
                Behavior on color   { ColorAnimation { duration: 800 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale   { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
            }
            MouseArea {
                id: suspendArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.suspendToRamSupported ? root.suspendToRam()
                                                      : sessionManagement.suspend()
            }
        }

        // ══════════════════════════════════════════════════════════════════
        // CLOCK — centered, hidden when uiVisible = true
        // ══════════════════════════════════════════════════════════════════
        Item {
            id: pixieClockContainer
            z: 5
            anchors.centerIn: parent
            width:  pixieClock.implicitWidth
            height: pixieClock.implicitHeight
            opacity: lockScreenRoot.uiVisible ? 0 : 1
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.veryLongDuration; easing.type: Easing.InOutQuad }
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

        // ══════════════════════════════════════════════════════════════════
        // FOOTER — Pixie style with real Plasma data
        // Left: on-screen keyboard (if available) + keyboard layout
        // Right: battery (percentage + Nerd Font icon)
        // ══════════════════════════════════════════════════════════════════
        Item {
            id: pixieFooter
            z: 10
            anchors {
                bottom: parent.bottom; left: parent.left; right: parent.right
                bottomMargin: 18; leftMargin: 24; rightMargin: 24
            }
            height: 30

            // ── Left: on-screen keyboard + layout ────────────────────────
            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 18

                // Virtual keyboard button — Nerd Font icon, functional
                Item {
                    width: 30; height: 30
                    visible: inputPanel.status === Loader.Ready
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: inputPanel.keyboardActive ? "󰌐" : "󰌌"
                        font.pixelSize: 20
                        font.family: pixieFontMedium.name
                        color: inputPanel.keyboardActive
                               ? (accentCanvas.processed ? lockScreenUi.extractedAccent : "white")
                               : Qt.rgba(1, 1, 1, 0.6)
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            mainBlock.mainPasswordBox.forceActiveFocus();
                            inputPanel.showHide();
                        }
                    }

                    // Keep containmentMask in line with Fitts's law
                    containmentMask: Item {
                        parent: pixieFooter
                        anchors {
                            left: pixieFooter.left; bottom: pixieFooter.bottom
                            top: pixieFooter.top
                        }
                        width: 48
                    }
                }

                // Keyboard layout — clickable short text
                PW.KeyboardLayoutSwitcher {
                    id: keyboardLayoutSwitcher
                    anchors.verticalCenter: parent.verticalCenter
                    width: keyboardLayoutText.implicitWidth + 8
                    height: 30
                    acceptedButtons: Qt.NoButton
                    visible: hasMultipleKeyboardLayouts

                    Text {
                        id: keyboardLayoutText
                        anchors.centerIn: parent
                        text: keyboardLayoutSwitcher.layoutNames.shortName ||
                              keyboardLayoutSwitcher.layoutNames.longName  || "?"
                        font.pixelSize: 13
                        font.family: pixieFontMedium.name
                        font.capitalization: Font.AllUppercase
                        color: Qt.rgba(1, 1, 1, 0.75)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: keyboardLayoutSwitcher.keyboardLayout.switchToNextLayout()
                    }
                }
            }

            // ── Right: battery via breeze's Battery{} ─────────────────
            // Battery is an opaque breeze component that internally uses
            // DataEngineConsumer — it does not expose percent or charging as properties.
            // We keep it as is (functional) and apply Pixie opacity.
            Item {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: batteryComponent.implicitWidth
                height: batteryComponent.implicitHeight
                opacity: 0.85

                Battery {
                    id: batteryComponent
                    anchors.centerIn: parent
                }
            }
        }
    }
}
