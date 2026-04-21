/*
    SPDX-FileCopyrightText: 2022 Aleix Pol i Gonzalez <aleixpol@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    required property var userListModel

    spacing: Kirigami.Units.gridUnit

    Image {
        Layout.alignment: Qt.AlignHCenter
        source: root.userListModel.count > 0 ? root.userListModel.get(0).icon : ""
        Layout.preferredWidth: Kirigami.Units.gridUnit * 6
        Layout.preferredHeight: Kirigami.Units.gridUnit * 6
        fillMode: Image.PreserveAspectFit
    }

    PlasmaComponents3.Label {
        Layout.alignment: Qt.AlignHCenter
        text: root.userListModel.count > 0 ? root.userListModel.get(0).realName : ""
        font.bold: true
    }

    PlasmaComponents3.BusyIndicator {
        Layout.alignment: Qt.AlignHCenter
        running: true
    }

    Keys.onReturnPressed: Qt.quit()
    Keys.onEnterPressed: Qt.quit()
    Keys.onEscapePressed: Qt.quit()
}
