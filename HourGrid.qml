import QtQuick

// Weekday by hour: which hours of the week the work lands in. Plain QtQuick,
// like Heatmap, with every colour and size passed in.
Item {
  id: root

  // 168 amounts, Monday 00:00 first.
  property var values: []
  // One label per row, passed in so the owner picks the language.
  property var dayLabels: ["M", "T", "W", "T", "F", "S", "S"]
  property color foreground: "#cacccc"
  property color tint: foreground
  property string fontFamily: ""
  property real fontSize: 10
  property real gap: 2

  // The slot under the pointer, for the owner's tooltip; -1 when none.
  property int hoveredSlot: -1

  readonly property real labelWidth: Math.ceil(fontSize * 1.5)
  readonly property real footerHeight: Math.ceil(fontSize * 1.7)
  readonly property real step: Math.max(4, Math.floor((width - labelWidth) / 24))
  readonly property real cell: Math.max(2, step - gap)
  readonly property real gridHeight: 7 * step - gap
  readonly property var levels: build(values)

  implicitWidth: labelWidth + 24 * 12
  implicitHeight: gridHeight + footerHeight

  // Ranked like the calendar, so one marathon hour does not flatten the rest.
  function build(values) {
    var sorted = []
    for (var i = 0; i < values.length; i++) if (values[i] > 0) sorted.push(values[i])
    sorted.sort(function(a, b) { return a - b })
    var out = []
    for (var slot = 0; slot < 168; slot++) {
      var value = Number(values[slot] || 0)
      if (!(value > 0)) {
        out.push(0)
        continue
      }
      var lo = 0
      var hi = sorted.length
      while (lo < hi) {
        var mid = (lo + hi) >> 1
        if (sorted[mid] <= value) lo = mid + 1
        else hi = mid
      }
      out.push(Math.max(1, Math.ceil(lo / sorted.length * 4)))
    }
    return out
  }

  function levelColor(level) {
    if (level <= 0) return Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
    return Qt.rgba(tint.r, tint.g, tint.b, [0.3, 0.5, 0.74, 1.0][level - 1])
  }

  Repeater {
    model: root.dayLabels

    Text {
      required property string modelData
      required property int index
      y: index * root.step + (root.cell - height) / 2
      text: modelData
      color: Qt.darker(root.foreground, 1.55)
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
    }
  }

  Repeater {
    model: root.levels

    Rectangle {
      required property int modelData
      required property int index

      x: root.labelWidth + (index % 24) * root.step
      y: Math.floor(index / 24) * root.step
      width: root.cell
      height: root.cell
      radius: Math.min(2, root.cell / 4)
      color: root.levelColor(modelData)
      border.width: index === root.hoveredSlot ? 1 : 0
      border.color: root.foreground
    }
  }

  Repeater {
    model: [0, 6, 12, 18]

    Text {
      required property int modelData
      x: root.labelWidth + modelData * root.step
      y: root.gridHeight + root.footerHeight - height
      text: String(modelData).padStart(2, "0")
      color: Qt.darker(root.foreground, 1.55)
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
    }
  }

  MouseArea {
    x: root.labelWidth
    width: 24 * root.step
    height: root.gridHeight
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onPositionChanged: function(mouse) {
      var column = Math.floor(mouse.x / root.step)
      var row = Math.floor(mouse.y / root.step)
      if (column >= 0 && column < 24 && row >= 0 && row < 7) root.hoveredSlot = row * 24 + column
    }
    onExited: root.hoveredSlot = -1
  }
}
