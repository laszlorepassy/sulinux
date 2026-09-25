/* Sulinux: a telepítő oldalsávja. A Calamares 3.3 beépített QML-oldalsávja alapján
   (src/calamares/calamares-sidebar.qml), de bal alul a Névjegy gomb helyett a disztribúció
   neve áll. A branding.desc „sidebar: qml” sora kapcsolja be (lásd a hookot).

   SPDX-FileCopyrightText: 2020 Adriaan de Groot <groot@kde.org>
   SPDX-FileCopyrightText: 2021 Anke Boersma <demm@kaosx.us>
   SPDX-License-Identifier: GPL-3.0-or-later
*/
import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick 2.3
import QtQuick.Layouts 1.3

Rectangle {
    id: sideBar;
    color: Branding.styleString( Branding.SidebarBackground );
    anchors.fill: parent;

    ColumnLayout {
        anchors.fill: parent;
        spacing: 0;

        Image {
            Layout.topMargin: 12;
            Layout.bottomMargin: 12;
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            id: logo;
            width: 80;
            height: width;  // square
            source: "file:/" + Branding.imagePath(Branding.ProductLogo);
            sourceSize.width: width;
            sourceSize.height: height;
        }

        Repeater {
            model: ViewManager
            Rectangle {
                Layout.leftMargin: 6;
                Layout.rightMargin: 6;
                Layout.fillWidth: true;
                height: 35;
                radius: 6;
                color: Branding.styleString( index == ViewManager.currentStepIndex ? Branding.SidebarBackgroundCurrent : Branding.SidebarBackground );

                Text {
                    anchors.verticalCenter: parent.verticalCenter;
                    anchors.horizontalCenter: parent.horizontalCenter;
                    color: Branding.styleString( index == ViewManager.currentStepIndex ? Branding.SidebarTextCurrent : Branding.SidebarText );
                    text: display;
                }
            }
        }

        Item {
            Layout.fillHeight: true;
        }

        Text {
            Layout.fillWidth: true;
            Layout.bottomMargin: 12;
            horizontalAlignment: Text.AlignHCenter;
            color: Branding.styleString( Branding.SidebarText );
            font.bold: true;
            font.pointSize: 11;
            text: Branding.string( Branding.ShortProductName );
        }
    }
}
