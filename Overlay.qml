import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property string inputText: ""
  property int selectedIndex: 0
  property var pinned: []

  readonly property string pluginId: (root.manifest && root.manifest.id) || "ussego.okata"

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.min(Style.space(560), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(600), panel.height - Style.gapsOut * 2)
  property int rowHeight: Math.max(Style.space(48), Style.font.caption + Style.font.body + Style.spacing.rowPaddingX * 2)

  property string pinsPath: Quickshell.env("HOME") + "/.local/state/omarchy/okata-pins.json"

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
    root.opened = true
    root.selectedIndex = 0
    root.inputText = typeof payload.text === "string" ? payload.text : ""
    root.rebuildRows()
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
    else root.close()
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function setInput(nextText) {
    root.inputText = nextText
  }

  function rebuildRows() {
    var selectedId = root.selectedIndex >= 0 && root.selectedIndex < rowsModel.count
      ? rowsModel.get(root.selectedIndex).caseId
      : ""
    rowsModel.clear()
    var ordered = Model.orderedCases(root.pinned)
    for (var i = 0; i < ordered.length; i++) {
      rowsModel.append({
        caseId: ordered[i].id,
        label: ordered[i].label,
        pinned: root.pinned.indexOf(ordered[i].id) !== -1
      })
      if (ordered[i].id === selectedId) root.selectedIndex = i
    }
    if (root.selectedIndex >= rowsModel.count) root.selectedIndex = Math.max(0, rowsModel.count - 1)
  }

  function moveSelection(delta) {
    if (rowsModel.count === 0) return
    var next = root.selectedIndex + delta
    if (next < 0) next = 0
    if (next >= rowsModel.count) next = rowsModel.count - 1
    root.selectedIndex = next
    rowsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function togglePin(caseId) {
    var next = root.pinned.slice()
    var idx = next.indexOf(caseId)
    if (idx === -1) next.push(caseId)
    else next.splice(idx, 1)
    root.pinned = next
    pinsFile.setText(JSON.stringify(root.pinned) + "\n")
    root.rebuildRows()
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function copyRow(index) {
    if (index < 0 || index >= rowsModel.count) return
    var row = rowsModel.get(index)
    var value = Model.transform(row.caseId, root.inputText)
    if (!value) return
    Quickshell.execDetached(["wl-copy", value])
    root.dismiss()
  }

  function loadPins(raw) {
    var next = []
    try {
      var arr = JSON.parse(String(raw || "[]"))
      if (Array.isArray(arr)) {
        for (var i = 0; i < arr.length; i++) {
          if (Model.hasCase(arr[i]) && next.indexOf(arr[i]) === -1) next.push(arr[i])
        }
      }
    } catch (e) {}
    root.pinned = next
    root.rebuildRows()
  }

  ListModel { id: rowsModel }

  FileView {
    id: pinsFile
    path: root.pinsPath
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadPins(text())
    onLoadFailed: root.loadPins("[]")
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "ussego-okata"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.inputText) root.setInput("")
            else root.dismiss()
            event.accepted = true
          } else if (Util.editsFilter(event, root.inputText)) {
            root.setInput(Util.editedFilter(event, root.inputText))
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.moveSelection(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.moveSelection(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.moveSelection(-6)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.moveSelection(6)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.copyRow(root.selectedIndex)
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
            root.setInput(root.inputText + event.text)
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Rectangle {
          width: parent.width
          height: root.headerHeight
          radius: root.cornerRadius
          color: "transparent"

          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.inputText || "Type text to transform…"
            color: root.foreground
            opacity: root.inputText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }
        }

        ListView {
          id: rowsList
          width: parent.width
          height: parent.height - root.headerHeight - root.contentSpacing
          model: rowsModel
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            required property int index
            required property string caseId
            required property string label
            required property bool pinned

            readonly property bool hasCursor: index === root.selectedIndex
            readonly property string value: Model.transform(caseId, root.inputText)

            width: rowsList.width
            height: root.rowHeight
            radius: root.cornerRadius
            color: hasCursor ? root.selectedBackground : "transparent"

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: if (containsMouse) root.selectedIndex = index
              onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) root.togglePin(caseId)
                else root.copyRow(index)
              }
            }

            Column {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(2)

              Row {
                width: parent.width
                spacing: Style.space(6)

                Text {
                  width: parent.width - (pinGlyph.visible ? pinGlyph.implicitWidth + Style.space(6) : 0)
                  text: label
                  color: hasCursor ? root.selectedText : root.foreground
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }

                Text {
                  id: pinGlyph
                  visible: pinned
                  text: "󰐃"
                  color: hasCursor ? root.selectedText : root.foreground
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Text {
                width: parent.width
                text: value || "…"
                color: hasCursor ? root.selectedText : root.foreground
                opacity: value ? 1 : 0.4
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }
  }
}
