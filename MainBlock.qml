/*
 * Pixie Lockscreen — MainBlock
 * Visual design adapted from Pixie SDDM by xCaptaiN09
 * https://github.com/xCaptaiN09/pixie-sddm (MIT License)
 *
 * Base: Plasma kscreenlocker (GPL-2.0-or-later)
 *
 * Does NOT inherit SessionManagementScreen to avoid duplicate rendering of
 * avatar / username / actionItems that the parent auto-generates.
 * Implements the minimum API expected by LockScreenUi and VirtualKeyboardLoader.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker

import org.kde.breeze.components

Item {
    id: mainBlock

    // ── API required by LockScreenUi / VirtualKeyboardLoader ──────────────
    readonly property alias mainPasswordBox: passwordField

    property bool   lockScreenUiVisible: false
    property string notificationMessage: ""
    property var    userListModel:        null
    property bool   showUserList:         false
    property bool   capsLockOn:           false
    property bool   isLoggingIn:          false
    property list<Item> actionItems

    property int visibleBoundary: height * 0.7
    readonly property Item userList: _dummyUserList
    Item { id: _dummyUserList; y: mainBlock.height * 0.3; height: 0 }

    signal passwordResult(string password)

    function playHighlightAnimation() { _highlightAnim.start(); }
    function startLogin() {
        if (isLoggingIn) return;
        isLoggingIn = true;
        passwordResult(passwordField.text);
    }

    Connections {
        target: authenticator
        function onFailed(kind)  { if (kind === 0) mainBlock.isLoggingIn = false; }
        function onSucceeded()   { mainBlock.isLoggingIn = false; }
    }
    Connections {
        target: root
        function onClearPassword() { mainBlock.isLoggingIn = false; }
    }

    // Accent and font resolved by walking up the parent chain to LockScreenUi
    property color  accent:    _resolve("accent",               "#A9C78F")
    property string pixieFont: _resolve("pixieFontMedium.name", "")

    function _resolve(path, fallback) {
        var keys = path.split(".");
        var node = parent;
        while (node) {
            var val = node; var ok = true;
            for (var i = 0; i < keys.length; i++) {
                if (typeof val[keys[i]] !== "undefined") val = val[keys[i]];
                else { ok = false; break; }
            }
            if (ok && val !== node) return val;
            node = node.parent;
        }
        return fallback;
    }

    property string userName: (userListModel && userListModel.count > 0)
                              ? (userListModel.get(0).realName || userListModel.get(0).name) : ""
    property string userIcon: (userListModel && userListModel.count > 0)
                              ? userListModel.get(0).icon : ""

    SequentialAnimation {
        id: _highlightAnim
        PropertyAnimation { target: cardVisual; property: "opacity"; to: 0.4; duration: 80 }
        PropertyAnimation { target: cardVisual; property: "opacity"; to: 0.7; duration: 80 }
    }

    // ── Login card — width:380 height:480 opacity:0.7 radius:32 color:#1A1C18
    Rectangle {
        id: cardVisual
        width: 380; height: 480
        anchors.centerIn: parent

        property bool isError: false
        color:   isError ? "#442222" : "#1A1C18"
        radius:  32
        opacity: mainBlock.lockScreenUiVisible ? 0.7 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
        Behavior on color   { ColorAnimation  { duration: 200 } }

        SequentialAnimation {
            id: shakeAnimation; loops: 2
            PropertyAnimation {
                target: cardVisual; property: "anchors.horizontalCenterOffset"
                from: 0; to: -10; duration: 50; easing.type: Easing.InOutQuad
            }
            PropertyAnimation {
                target: cardVisual; property: "anchors.horizontalCenterOffset"
                from: -10; to: 10; duration: 50; easing.type: Easing.InOutQuad
            }
            PropertyAnimation {
                target: cardVisual; property: "anchors.horizontalCenterOffset"
                from: 10; to: 0; duration: 50; easing.type: Easing.InOutQuad
            }
            onStopped: cardVisual.isError = false
        }

        Connections {
            target: authenticator
            function onFailed(kind) {
                if (kind !== 0) return;
                cardVisual.isError = true;
                shakeAnimation.start();
            }
        }

        ColumnLayout {
            anchors { fill: parent; margins: 40 }
            spacing: 15

            // ── Avatar ─────────────────────────────────────────────────────
            Item {
                Layout.preferredWidth: 120; Layout.preferredHeight: 120
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    anchors.fill: parent; color: "#2D2F27"; radius: width / 2
                    visible: avatarImage.status !== Image.Ready
                    Text {
                        anchors.centerIn: parent
                        text: mainBlock.userName.charAt(0).toUpperCase() || "?"
                        color: mainBlock.accent
                        font.pixelSize: 48; font.family: mainBlock.pixieFont; font.weight: Font.Bold
                    }
                }

                Canvas {
                    id: avatarCanvas
                    anchors.fill: parent
                    visible: avatarImage.status === Image.Ready
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI);
                        ctx.closePath(); ctx.clip();
                        ctx.drawImage(avatarImage, 0, 0, width, height);
                    }
                    Timer { id: repaintTimer; interval: 500; onTriggered: avatarCanvas.requestPaint() }
                    Image {
                        id: avatarImage
                        anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                        smooth: true; visible: false; source: mainBlock.userIcon
                        onStatusChanged: { if (status === Image.Ready) repaintTimer.start(); }
                    }
                }
            }

            // ── Username ───────────────────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 10
                text: mainBlock.userName
                      || i18ndc("plasma_shell_org.kde.plasma.desktop", "@label", "User")
                color: "white"; font.pixelSize: 24; font.weight: Font.Bold
                font.family: mainBlock.pixieFont
            }

            // ── Switch User pill — mirrors Pixie sessionPill exactly ────────
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: switchPill.width; Layout.preferredHeight: switchPill.height
                visible: {
                    var p = mainBlock.parent;
                    while (p) {
                        if (typeof p.sessionManagement !== "undefined")
                            return p.sessionManagement.canSwitchUser;
                        p = p.parent;
                    }
                    return false;
                }
                Rectangle {
                    id: switchPill
                    anchors.centerIn: parent
                    width: 180; height: 36; radius: 18
                    color:        switchArea.containsPress ? "#3D3F37" : "#2D2F27"
                    border.width: 1
                    border.color: switchArea.containsPress ? mainBlock.accent : "#3D3F37"
                    scale: switchArea.containsPress ? 0.95 : 1.0
                    Behavior on scale        { NumberAnimation { duration: 100 } }
                    Behavior on color        { ColorAnimation  { duration: 100 } }
                    Behavior on border.color { ColorAnimation  { duration: 100 } }
                    RowLayout {
                        anchors.centerIn: parent; spacing: 8
                        Text { text: "󰯄"; color: mainBlock.accent; font.pixelSize: 16; font.family: mainBlock.pixieFont }
                        Text {
                            text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button", "Switch User")
                            color: "white"; font.pixelSize: 13; font.weight: Font.Medium; font.family: mainBlock.pixieFont
                        }
                    }
                    MouseArea {
                        id: switchArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var p = mainBlock.parent;
                            while (p) {
                                if (typeof p.sessionManagement !== "undefined") { p.sessionManagement.switchUser(); return; }
                                p = p.parent;
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // ── Password field — matches Pixie TextField exactly ───────────
            // • background: #2D2F27, radius:16, border accent on focus (width:2)
            // • placeholder "Password" centered (separate Text item, Pixie style)
            // • cursor color set to accent so it's visible; no fade on focus
            // • show/hide eye icon on the right
            // • caps lock indicator icon on the left
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: passwordField.implicitHeight

                TextField {
                    id: passwordField
                    anchors.fill: parent
                    echoMode: TextInput.Password
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 18
                    font.family: mainBlock.pixieFont
                    color: "white"
                    rightPadding: mainBlock.capsLockOn ? 40 : 16
                    leftPadding:  mainBlock.capsLockOn ? 40 : 16
                    focus: true
                    enabled: !authenticator.graceLocked
                    placeholderText: ""

                    text: PasswordSync.password

                    background: Rectangle {
                        color: "#2D2F27"
                        radius: 16
                        border.width: passwordField.activeFocus ? 2 : 0
                        border.color: mainBlock.accent
                        // No Behavior on border.width — matches Pixie (instant)
                    }

                    onAccepted: {
                        if (mainBlock.lockScreenUiVisible) mainBlock.startLogin();
                    }

                    Keys.onTabPressed:      loginButton.forceActiveFocus()
                    Keys.onBacktabPressed:  loginButton.forceActiveFocus()

                    Connections {
                        target: root
                        function onClearPassword() {
                            passwordField.forceActiveFocus();
                            passwordField.clear();
                            passwordField.text = Qt.binding(() => PasswordSync.password);
                        }
                        function onNotificationRepeated() { mainBlock.playHighlightAnimation(); }
                    }
                }

                Binding { target: PasswordSync; property: "password"; value: passwordField.text }

                // Centered placeholder — visible when field is empty and unfocused
                Text {
                    anchors.centerIn: parent
                    text: i18ndc("plasma_shell_org.kde.plasma.desktop",
                                 "@info:placeholder in text field", "Password")
                    color: "gray"
                    font.pixelSize: 16; font.family: mainBlock.pixieFont
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.5
                    visible: !passwordField.text && !passwordField.activeFocus
                    enabled: false
                }

                // Caps Lock indicator inside the field on the left
                Item {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                    width: 20; height: 20
                    visible: mainBlock.capsLockOn
                    Text {
                        anchors.centerIn: parent
                        text: "󰘲"
                        color: mainBlock.accent
                        font.pixelSize: 16; font.family: mainBlock.pixieFont
                    }
                }
            }

            // ── Notification — wrong password / errors ─────────────────────
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: mainBlock.notificationMessage
                color: mainBlock.accent
                font.pixelSize: 14; font.family: mainBlock.pixieFont; font.weight: Font.Medium
                wrapMode: Text.WordWrap
                visible: text !== ""
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            // ── Fingerprint / smartcard hints ──────────────────────────────
            component FailableLabel : Text {
                id: _flab
                required property int    kind
                required property string label
                visible: authenticator.authenticatorTypes & kind
                text: label; horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true; font.pixelSize: 13
                opacity: 0.6; color: "white"; wrapMode: Text.WordWrap
                RejectPasswordAnimation { id: _rej; target: _flab; onFinished: _t.restart() }
                Connections {
                    target: authenticator
                    function onNoninteractiveError(kind, auth) {
                        if (kind & _flab.kind) { _flab.text = Qt.binding(() => auth.errorMessage); _rej.start(); }
                    }
                }
                Timer { id: _t; interval: Kirigami.Units.humanMoment; onTriggered: _flab.text = Qt.binding(() => _flab.label) }
            }
            FailableLabel {
                kind:  ScreenLocker.Authenticator.Fingerprint
                label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:usagetip", "(or scan your fingerprint on the reader)")
            }
            FailableLabel {
                kind:  ScreenLocker.Authenticator.Smartcard
                label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:usagetip", "(or scan your smartcard)")
            }

            Item { Layout.fillHeight: true }

            // ── Unlock button — matches Pixie RoundButton exactly ──────────
            // focusPolicy: Qt.NoFocus (Pixie value)
            // background color changes instantly (no Behavior) on isLoggingIn
            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 64
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    id: loginButton
                    width: 64; height: 64; radius: 32
                    anchors.centerIn: parent
                    // No keyboard focus — matches Pixie focusPolicy: Qt.NoFocus

                    color: mainBlock.isLoggingIn
                           ? "#3D3F37"
                           : (loginArea.containsPress
                              ? Qt.darker(mainBlock.accent, 1.1)
                              : mainBlock.accent)
                    opacity: mainBlock.isLoggingIn ? 0.5 : 1.0
                    // No Behavior — instant color/opacity change, same as Pixie

                    Text {
                        anchors.centerIn: parent
                        text: mainBlock.isLoggingIn ? "⋯" : "→"
                        color: "white"
                        font.pixelSize: 32
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }

                    MouseArea {
                        id: loginArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mainBlock.startLogin()
                    }
                }
            }
        }
    }
}
