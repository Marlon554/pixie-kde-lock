/*
 * Pixie Lockscreen — MainBlock
 * Visual design: Pixie SDDM by xCaptaiN09 (Licensed under MIT)
 * Base: Plasma kscreenlocker
 *
 * Does NOT inherit SessionManagementScreen to avoid duplicate rendering of
 * avatar / username / actionItems that the parent component auto-generates.
 * Implements the minimum API expected by LockScreenUi and VirtualKeyboardLoader.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker

import org.kde.breeze.components

Item {
    id: mainBlock

    // ── API required by LockScreenUi / VirtualKeyboardLoader ──────────────
    // mainPasswordBox must be a TextField (QQuickTextField), not TextInput,
    // because VirtualKeyboardLoader casts it to TextField internally.
    readonly property alias mainPasswordBox: passwordField

    property bool lockScreenUiVisible: false
    property string notificationMessage: ""
    property var    userListModel: null
    property bool   showUserList:  false
    property list<Item> actionItems   // unused — Switch User lives in the card

    // visibleBoundary: used by VirtualKeyboardLoader to keep the field visible
    property int visibleBoundary: height * 0.7

    // userList.y: also used by VirtualKeyboardLoader
    readonly property Item userList: _dummyUserList
    Item { id: _dummyUserList; y: mainBlock.height * 0.3; height: 0 }

    signal passwordResult(string password)

    function playHighlightAnimation() { _highlightAnim.start(); }
    function startLogin()             { passwordResult(passwordField.text); }

    // Resolved from parent chain — set in LockScreenUi
    property color  accent:    _resolveProperty("accent",         "#A9C78F")
    property string pixieFont: _resolveProperty("pixieFontMedium.name", "")

    function _resolveProperty(propPath, fallback) {
        var keys = propPath.split(".");
        var p = parent;
        while (p) {
            var val = p;
            var ok = true;
            for (var i = 0; i < keys.length; i++) {
                if (typeof val[keys[i]] !== "undefined") {
                    val = val[keys[i]];
                } else { ok = false; break; }
            }
            if (ok && val !== p) return val;
            p = p.parent;
        }
        return fallback;
    }

    property string userName: (userListModel && userListModel.count > 0)
                              ? (userListModel.get(0).realName || userListModel.get(0).name)
                              : ""
    property string userIcon: (userListModel && userListModel.count > 0)
                              ? userListModel.get(0).icon : ""

    // ── Highlight flash (notification repeated) ────────────────────────────
    SequentialAnimation {
        id: _highlightAnim
        PropertyAnimation { target: cardVisual; property: "opacity"; to: 0.4; duration: 80 }
        PropertyAnimation { target: cardVisual; property: "opacity"; to: 0.7; duration: 80 }
    }

    // ── Login card ─────────────────────────────────────────────────────────
    // Dimensions and colors match Pixie Main.qml loginCard exactly:
    //   width:380  height:480  opacity:0.7  radius:32  color:"#1A1C18"
    Rectangle {
        id: cardVisual

        width:  380
        height: 480
        anchors.centerIn: parent

        color:   cardVisual.isError ? "#442222" : "#1A1C18"
        opacity: 0.7
        radius:  32

        property bool isError: false

        Behavior on color   { ColorAnimation  { duration: 200 } }
        Behavior on opacity { NumberAnimation { duration: 100 } }

        // Shake on wrong password — mirrors Pixie shakeAnimation
        SequentialAnimation {
            id: shakeAnimation
            loops: 2
            PropertyAnimation {
                target: cardVisual; property: "anchors.horizontalCenterOffset"
                from: 0;   to: -10; duration: 50; easing.type: Easing.InOutQuad
            }
            PropertyAnimation {
                target: cardVisual; property: "anchors.horizontalCenterOffset"
                from: -10; to:  10; duration: 50; easing.type: Easing.InOutQuad
            }
            PropertyAnimation {
                target: cardVisual; property: "anchors.horizontalCenterOffset"
                from:  10; to:   0; duration: 50; easing.type: Easing.InOutQuad
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

        // Card content — anchors.margins:40, spacing:15 (Pixie values)
        ColumnLayout {
            id: cardInner
            anchors { fill: parent; margins: 40 }
            spacing: 15

            // ── Avatar ─────────────────────────────────────────────────────
            // 120×120, same as Pixie loginCard avatar item
            Item {
                Layout.preferredWidth:  120
                Layout.preferredHeight: 120
                Layout.alignment: Qt.AlignHCenter

                // Fallback initial circle — color "#2D2F27" (Pixie avatarFallback)
                Rectangle {
                    anchors.fill: parent
                    color: "#2D2F27"
                    radius: width / 2
                    visible: avatarImage.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        text: mainBlock.userName.charAt(0).toUpperCase() || "?"
                        color: mainBlock.accent
                        font.pixelSize: 48
                        font.family: mainBlock.pixieFont
                        font.weight: Font.Bold
                    }
                }

                // Circular avatar via Canvas clip (Pixie avatarCanvas method)
                Canvas {
                    id: avatarCanvas
                    anchors.fill: parent
                    visible: avatarImage.status === Image.Ready

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI);
                        ctx.closePath();
                        ctx.clip();
                        ctx.drawImage(avatarImage, 0, 0, width, height);
                    }

                    Timer {
                        id: repaintTimer; interval: 500
                        onTriggered: avatarCanvas.requestPaint()
                    }

                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        smooth: true; visible: false
                        source: mainBlock.userIcon
                        onStatusChanged: {
                            if (status === Image.Ready) repaintTimer.start();
                        }
                    }
                }
            }

            // ── Username ───────────────────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                text: mainBlock.userName
                      || i18ndc("plasma_shell_org.kde.plasma.desktop", "@label", "User")
                color: "white"
                font.pixelSize: 24
                font.weight: Font.Bold
                font.family: mainBlock.pixieFont
            }

            // ── Switch User pill ───────────────────────────────────────────
            // Mirrors Pixie sessionPill exactly:
            //   width:180  height:36  radius:18  color idle:"#2D2F27"
            //   border.color idle:"#3D3F37"  pressed → accent border + scale 0.95
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth:  switchPill.width
                Layout.preferredHeight: switchPill.height
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
                    width:  180; height: 36; radius: 18

                    color:        switchArea.containsPress ? "#3D3F37" : "#2D2F27"
                    border.width: 1
                    border.color: switchArea.containsPress ? mainBlock.accent : "#3D3F37"
                    scale: switchArea.containsPress ? 0.95 : 1.0

                    Behavior on scale        { NumberAnimation { duration: 100 } }
                    Behavior on color        { ColorAnimation  { duration: 100 } }
                    Behavior on border.color { ColorAnimation  { duration: 100 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "󰯄"
                            color: mainBlock.accent
                            font.pixelSize: 16
                            font.family: mainBlock.pixieFont
                        }
                        Text {
                            text: i18ndc("plasma_shell_org.kde.plasma.desktop",
                                         "@action:button", "Switch User")
                            color: "white"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            font.family: mainBlock.pixieFont
                        }
                    }

                    MouseArea {
                        id: switchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var p = mainBlock.parent;
                            while (p) {
                                if (typeof p.sessionManagement !== "undefined") {
                                    p.sessionManagement.switchUser(); return;
                                }
                                p = p.parent;
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // ── Password field ─────────────────────────────────────────────
            // Uses TextField (required by VirtualKeyboardLoader, not TextInput).
            // Mirrors Pixie passwordField:
            //   horizontalAlignment: center  font.pixelSize:18
            //   background: #2D2F27  radius:16  border accent on focus
            //   placeholder "Password" centered, color gray, opacity 0.5
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
                    focus: true
                    enabled: !authenticator.graceLocked
                    placeholderText: ""   // replaced by custom Text below

                    text: PasswordSync.password

                    background: Rectangle {
                        color: "#2D2F27"
                        radius: 16
                        border.width: passwordField.activeFocus ? 2 : 0
                        border.color: mainBlock.accent
                        Behavior on border.width { NumberAnimation { duration: 100 } }
                    }

                    onAccepted: {
                        if (mainBlock.lockScreenUiVisible) mainBlock.startLogin();
                    }

                    Connections {
                        target: root
                        function onClearPassword() {
                            passwordField.forceActiveFocus();
                            passwordField.clear();
                            passwordField.text = Qt.binding(() => PasswordSync.password);
                        }
                        function onNotificationRepeated() {
                            mainBlock.playHighlightAnimation();
                        }
                    }
                }

                // Centered placeholder — overlaid on the TextField
                Text {
                    anchors.centerIn: parent
                    text: i18ndc("plasma_shell_org.kde.plasma.desktop",
                                 "@info:placeholder in text field", "Password")
                    color: "gray"
                    font.pixelSize: 16
                    font.family: mainBlock.pixieFont
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.5
                    visible: !passwordField.text && !passwordField.activeFocus
                    // Sits above the TextField but doesn't capture input
                    enabled: false
                }
            }

            Binding {
                target: PasswordSync
                property: "password"
                value: passwordField.text
            }

            // ── Notification (Caps Lock / wrong password) ──────────────────
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: mainBlock.notificationMessage
                color: mainBlock.accent
                font.pixelSize: 14
                font.family: mainBlock.pixieFont
                font.weight: Font.Medium
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
                text: label
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                font.pixelSize: 13
                opacity: 0.6; color: "white"; wrapMode: Text.WordWrap

                RejectPasswordAnimation { id: _rej; target: _flab; onFinished: _t.restart() }
                Connections {
                    target: authenticator
                    function onNoninteractiveError(kind, auth) {
                        if (kind & _flab.kind) {
                            _flab.text = Qt.binding(() => auth.errorMessage);
                            _rej.start();
                        }
                    }
                }
                Timer {
                    id: _t; interval: Kirigami.Units.humanMoment
                    onTriggered: _flab.text = Qt.binding(() => _flab.label)
                }
            }

            FailableLabel {
                kind:  ScreenLocker.Authenticator.Fingerprint
                label: i18ndc("plasma_shell_org.kde.plasma.desktop",
                              "@info:usagetip", "(or scan your fingerprint on the reader)")
            }
            FailableLabel {
                kind:  ScreenLocker.Authenticator.Smartcard
                label: i18ndc("plasma_shell_org.kde.plasma.desktop",
                              "@info:usagetip", "(or scan your smartcard)")
            }

            Item { Layout.fillHeight: true }

            // ── Unlock button ──────────────────────────────────────────────
            // Matches Pixie loginButton: width:64 height:64 radius:32
            // color: accent (idle) → darker on press; arrow icon font.pixelSize:32
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 64

                Rectangle {
                    id: loginButton
                    width: 64; height: 64; radius: 32
                    anchors.centerIn: parent

                    color: loginArea.containsPress
                           ? Qt.darker(mainBlock.accent, 1.1)
                           : mainBlock.accent
                    Behavior on color { ColorAnimation { duration: 120 } }

                    scale: loginArea.containsPress ? 0.93 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "→"
                        color: "white"
                        font.pixelSize: 32
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }

                    MouseArea {
                        id: loginArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mainBlock.startLogin()
                    }
                }
            }
        }
    }
}
