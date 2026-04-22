/*
 * Pixie Lockscreen - MainBlock
 * Visual design: Pixie SDDM (xCaptaiN09)
 * Base API:      Plasma kscreenlocker
 *
 * SPDX-License-Identifier: MIT OR GPL-2.0-or-later
 *
 * Does NOT inherit from SessionManagementScreen to prevent duplicate
 * rendering of
 * avatar/name/actionItems. Implements the minimum API required by
 * LockScreenUi.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker

import org.kde.breeze.components

Item {
    id: mainBlock

    // ── API required by LockScreenUi ─────────────────────────────────────
    // LockScreenUi accesses these properties directly
    readonly property alias mainPasswordBox: passwordBox
    property bool lockScreenUiVisible: false
    property bool showPassword: false

    // Notificationmessage: Caps Lock, errors, etc.
    property string notificationMessage: ""

    // userListModel: ListModel with { name, realName, icon }
    property var userListModel: null

    // showUserList: ignored — we do not display a list of users
    property bool showUserList: false

    // actionItems: ignored — “Switch User” is on the custom card
    property list<Item> actionItems

    // visibleBoundary: for VirtualKeyboardLoader
    property int visibleBoundary: height * 0.7

    // userList: VirtualKeyboardLoader accesses userList.y
    // We provide an empty Item in a safe position
    readonly property Item userList: dummyUserList
    Item { id: dummyUserList; y: mainBlock.height * 0.3; height: 0 }

    signal passwordResult(string password)

    // playHighlightAnimation: called by onNotificationRepeated
    function playHighlightAnimation() {
        highlightAnim.start();
    }

    function startLogin() {
        passwordResult(passwordBox.text);
    }

    // ── Accent colour forwarded from LockScreenUi ─────────────────────────
    // SessionManagementScreen sits inside LockScreenUi so we can walk up.
    property color accent: {
        var p = parent;
        while (p) {
            if (typeof p.extractedAccent !== "undefined") return p.extractedAccent;
            p = p.parent;
        }
        return "#A9C78F";
    }

    // Font: FlexRounded Medium from LockScreenUi
    property string pixieFont: {
        var p = parent;
        while (p) {
            if (typeof p.pixieFontMedium !== "undefined") return p.pixieFontMedium.name;
            p = p.parent;
        }
        return "";
    }

    property string userName: (userListModel && userListModel.count > 0)
                              ? (userListModel.get(0).realName || userListModel.get(0).name)
                              : ""
    property string userIcon: (userListModel && userListModel.count > 0)
                              ? userListModel.get(0).icon
                              : ""

    // ── Highlight animation (called when the notification repeats) ───────
    SequentialAnimation {
        id: highlightAnim
        PropertyAnimation { target: cardVisual; property: "opacity"; to: 0.6; duration: 80 }
        PropertyAnimation { target: cardVisual; property: "opacity"; to: 0.92; duration: 80 }
    }

    // ── Card centered on the screen ─────────────────────────────────────────
    Rectangle {
        id: cardVisual

        width:  360
        height: cardInner.implicitHeight + 48
        anchors.centerIn: parent

        property bool isError: false

        color:   isError ? "#3a1a1a" : "#1e201b"
        opacity: 0.92
        radius:  28

        Behavior on color   { ColorAnimation  { duration: 200 } }
        Behavior on opacity { NumberAnimation { duration: 100 } }

        // Shake when entering the wrong password
        SequentialAnimation {
            id: shakeAnimation
            loops: 2
            PropertyAnimation {
                target: cardVisual; property: "anchors.horizontalCenterOffset"
                from: 0;   to: -12; duration: 50; easing.type: Easing.InOutQuad
            }
            PropertyAnimation {
                target: cardVisual; property: "anchors.horizontalCenterOffset"
                from: -12; to:  12; duration: 50; easing.type: Easing.InOutQuad
            }
            PropertyAnimation {
                target: cardVisual; property: "anchors.horizontalCenterOffset"
                from:  12; to:   0; duration: 50; easing.type: Easing.InOutQuad
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

        // ── Card content ───────────────────────────────────────────────
        ColumnLayout {
            id: cardInner
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                margins: 36
                topMargin: 32
            }
            spacing: 14

            // ── Circular avatar ────────────────────────────────────────────
            Item {
                Layout.preferredWidth:  110
                Layout.preferredHeight: 110
                Layout.alignment: Qt.AlignHCenter

                // Fallback: circle with initial
                Rectangle {
                    anchors.fill: parent
                    color: "#2a2d24"
                    radius: width / 2
                    visible: avatarImage.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        text: mainBlock.userName.charAt(0).toUpperCase() || "?"
                        color: mainBlock.accent
                        font.pixelSize: 44
                        font.family: mainBlock.pixieFont
                        font.weight: Font.Bold
                    }
                }

                // Circular avatar via Canvas (no border/outline)
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
                        id: repaintTimer; interval: 300
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

            // ── Name ───────────────────────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mainBlock.userName
                      || i18ndc("plasma_shell_org.kde.plasma.desktop", "@label", "User")
                color: "white"
                font.pixelSize: 22
                font.weight: Font.Bold
                font.family: mainBlock.pixieFont
            }

            // ── Switch User pill — animations identical to Pixie's sessionPill ──
            // Reference: Main.qml #sessionPill
            //   color:        pressed||opened → “#3D3F37”  idle → “#2D2F27”
            //   border.color: pressed||opened → accent     idle → “#3D3F37”
            //   scale:        pressed → 0.95
            //   Behavior on scale: NumberAnimation { duration: 100 }
            Item {
                Layout.alignment: Qt.AlignHCenter
                // Leave a margin on the side so the scale doesn't cut the edge
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
                    width:  switchRow.implicitWidth + 48
                    height: 36
                    radius: 18

                    // Colors identical to sessionPill
                    color:        switchArea.containsPress ? "#3D3F37" : "#2D2F27"
                    border.width: 1
                    border.color: switchArea.containsPress ? mainBlock.accent : "#3D3F37"

                    // Scale identical to sessionPill
                    scale: switchArea.containsPress ? 0.95 : 1.0
                    Behavior on scale       { NumberAnimation  { duration: 100 } }
                    Behavior on color       { ColorAnimation   { duration: 100 } }
                    Behavior on border.color { ColorAnimation  { duration: 100 } }

                    RowLayout {
                        id: switchRow
                        anchors.centerIn: parent
                        spacing: 8
                        // Icon with the same accent color as the “󰟀” in sessionPill
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
                                    p.sessionManagement.switchUser();
                                    return;
                                }
                                p = p.parent;
                            }
                        }
                    }
                }
            }

            // ── Pixie-style password field ────────────────────────────────
            // We replaced PlasmaExtras.PasswordField with a custom TextField
            // featuring the Pixie SDDM dark theme and accent border.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 46

                // Dark background with an accent border when in focus
                Rectangle {
                    anchors.fill: parent
                    color: "#2D2F27"
                    radius: 14
                    border.width: passwordBox.activeFocus ? 2 : 1
                    border.color: passwordBox.activeFocus
                                  ? mainBlock.accent
                                  : Qt.rgba(1, 1, 1, 0.12)
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on border.width { NumberAnimation { duration: 100 } }
                }

                // Placeholder
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                    text: i18ndc("plasma_shell_org.kde.plasma.desktop",
                                 "@info:placeholder in text field", "Password")
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.pixelSize: 15
                    font.family: mainBlock.pixieFont
                    visible: !passwordBox.text && !passwordBox.activeFocus
                }

                // Native TextField (visually invisible, only captures input)
                TextInput {
                    id: passwordBox
                    anchors {
                        left: parent.left; right: showPasswordBtn.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 16; rightMargin: 8
                    }
                    echoMode: mainBlock.showPassword
                               ? TextInput.Normal
                               : TextInput.Password
                    color: "white"
                    font.pixelSize: 15
                    font.family: mainBlock.pixieFont
                    focus: true
                    enabled: !authenticator.graceLocked
                    // cursorVisible via activeFocus is automatic in TextInput
                    selectionColor: Qt.rgba(mainBlock.accent.r,
                                            mainBlock.accent.g,
                                            mainBlock.accent.b, 0.4)

                    // PasswordSync
                    text: PasswordSync.password

                    onAccepted: {
                        if (mainBlock.lockScreenUiVisible) mainBlock.startLogin();
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Left && !text) { event.accepted = true; }
                        if (event.key === Qt.Key_Right && !text) { event.accepted = true; }
                    }

                    Connections {
                        target: root
                        function onClearPassword() {
                            passwordBox.forceActiveFocus();
                            passwordBox.text = "";
                            passwordBox.text = Qt.binding(() => PasswordSync.password);
                        }
                        function onNotificationRepeated() {
                            mainBlock.playHighlightAnimation();
                        }
                    }
                }

                Binding {
                    target: PasswordSync
                    property: "password"
                    value: passwordBox.text
                }

                // Show/Hide Password button
                Text {
                    id: showPasswordBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
                    text: mainBlock.showPassword ? "󰛐" : "󰛑"
                    color: Qt.rgba(1, 1, 1, showPwArea.containsMouse ? 0.8 : 0.4)
                    font.pixelSize: 18
                    Behavior on color { ColorAnimation { duration: 100 } }

                    MouseArea {
                        id: showPwArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mainBlock.showPassword = !mainBlock.showPassword
                    }
                }
            }

            // ── Notification (Caps Lock / password error) ────────────────────
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: mainBlock.notificationMessage
                color: mainBlock.accent
                font.pixelSize: 13
                font.family: mainBlock.pixieFont
                wrapMode: Text.WordWrap
                visible: text !== ""
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            // ── Fingerprint / smartcard ────────────────────────────────────
            component FailableLabel : Text {
                id: _flab
                required property int kind
                required property string label
                visible: authenticator.authenticatorTypes & kind
                text: label
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                font.pixelSize: 13
                opacity: 0.6
                color: "white"
                wrapMode: Text.WordWrap

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

            // ── Round unlock button ──────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                Layout.topMargin: 2
                Layout.bottomMargin: 4

                Rectangle {
                    id: loginButton
                    width: 56; height: 56; radius: 28
                    anchors.centerIn: parent
                    color: loginArea.containsPress
                           ? Qt.darker(mainBlock.accent, 1.15)
                           : mainBlock.accent
                    Behavior on color { ColorAnimation { duration: 120 } }
                    scale: loginArea.containsPress ? 0.93 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "→"
                        color: "white"
                        font.pixelSize: 26
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
