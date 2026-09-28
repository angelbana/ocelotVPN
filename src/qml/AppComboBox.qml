/*
 * Copyright (C) 2014 Red Hat
 *
 * This file is part of Ocelot.
 *
 * Ocelot is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: control

    // Which value is the chosen one. ComboBox has indexOfValue for this, but it
    // is a plain function: a binding written against it is evaluated once,
    // before the model has been assigned, and then never again - which leaves
    // the box blank. Assigning through here keeps the two in step.
    property var selectedValue: undefined

    function syncSelection() {
        if (control.selectedValue === undefined || control.valueRole === "")
            return;
        const index = control.indexOfValue(control.selectedValue);
        if (index >= 0 && index !== control.currentIndex)
            control.currentIndex = index;
    }

    onSelectedValueChanged: syncSelection()
    onModelChanged: syncSelection()
    Component.onCompleted: syncSelection()

    implicitHeight: Theme.controlHeight
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontNormal

    background: Rectangle {
        radius: Theme.radius
        color: Theme.surface
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Theme.lineStrong
    }

    contentItem: Text {
        leftPadding: Math.round(10 * Theme.scale)
        rightPadding: control.indicator.width + Math.round(6 * Theme.scale)
        text: control.displayText
        color: Theme.ink
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - Math.round(10 * Theme.scale)
        y: control.topPadding + (control.availableHeight - height) / 2
        text: "▾"
        color: Theme.faint
        font.pixelSize: Theme.fontSmall
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 12, Math.round(280 * Theme.scale))
        padding: 6

        background: Rectangle {
            radius: Theme.radius
            color: Theme.raised
            border.width: 1
            border.color: Theme.line
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex

            ScrollBar.vertical: AppScrollBar {}
        }
    }

    delegate: ItemDelegate {
        required property var model
        required property int index

        width: control.width - 12
        height: Math.round(32 * Theme.scale)
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            leftPadding: 8
            text: control.textRole.length > 0 ? model[control.textRole] : model.modelData
            color: Theme.ink
            font.pixelSize: Theme.fontNormal
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: Theme.radius
            color: highlighted ? Theme.sunken : "transparent"
        }
    }
}
