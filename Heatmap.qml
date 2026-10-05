import QtQuick

// A GitHub-style activity calendar: one column per week (Monday first), one
// cell per day, the busiest days drawn strongest. Plain QtQuick with every
// colour and size passed in, so it renders the same outside the shell.
Item {
  id: root

  // "YYYY-MM-DD" -> amount for that day.
  property var values: ({})
  // Days known to be active whose amount was never recorded.
  property var faint: ({})
  property int weeks: 53
  property double nowMs: Date.now()

  // Labels are passed in too, so the owner picks the language. Weekdays run
  // Monday first; only every other row is labelled.
  property var monthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  property var dayLabels: ["M", "T", "W", "T", "F", "S", "S"]

  property color foreground: "#cacccc"
  property color tint: foreground
  property string fontFamily: ""
  property real fontSize: 10
  property real gap: 2

  // The day under the pointer, for the owner's tooltip.
  property string hoveredDate: ""
  // A day the owner has singled out; it keeps its outline.
  property string picked: ""

  signal dayClicked(string date)

  readonly property real labelWidth: Math.ceil(fontSize * 1.5)
  readonly property real headerHeight: Math.ceil(fontSize * 1.7)
  readonly property real step: Math.max(4, Math.floor((width - labelWidth) / Math.max(1, weeks)))
  readonly property real cell: Math.max(2, step - gap)
  readonly property real gridHeight: 7 * step - gap

  // Rebuilding on nowMs itself would recreate every cell each tick; the grid
  // only actually changes when the calendar day does.
  readonly property string today: iso(new Date(nowMs))
  readonly property var grid: build(values, faint, weeks, today, monthNames)

  implicitWidth: labelWidth + weeks * 8
  implicitHeight: headerHeight + gridHeight

  function iso(date) {
    return date.getFullYear()
      + "-" + String(date.getMonth() + 1).padStart(2, "0")
      + "-" + String(date.getDate()).padStart(2, "0")
  }

  // Levels are by rank, not by share of the peak: one enormous day would
  // otherwise push every ordinary day into the faintest step.
  function levelFor(sorted, value) {
    if (!(value > 0) || sorted.length === 0) return 0
    var lo = 0
    var hi = sorted.length
    while (lo < hi) {
      var mid = (lo + hi) >> 1
      if (sorted[mid] <= value) lo = mid + 1
      else hi = mid
    }
    return Math.max(1, Math.ceil(lo / sorted.length * 4))
  }

  function build(values, faint, weeks, today, names) {
    var end = new Date(today + "T00:00:00")
    var start = new Date(end)
    start.setDate(start.getDate() - ((end.getDay() + 6) % 7) - (weeks - 1) * 7)
    var first = iso(start)

    var sorted = []
    for (var key in values) {
      var amount = Number(values[key])
      if (amount > 0 && key >= first && key <= today) sorted.push(amount)
    }
    sorted.sort(function(a, b) { return a - b })

    var cells = []
    var months = []
    var lastMonth = -1
    var cursor = new Date(start)
    for (var i = 0; i < weeks * 7; i++) {
      var date = iso(cursor)
      if (i % 7 === 0) {
        if (cursor.getMonth() !== lastMonth) months.push({ column: i / 7, label: names[cursor.getMonth()] })
        lastMonth = cursor.getMonth()
      }
      var value = Number(values[date] || 0)
      cells.push({
        date: date,
        future: date > today,
        level: value > 0 ? levelFor(sorted, value) : (faint && faint[date] ? 1 : 0)
      })
      cursor.setDate(cursor.getDate() + 1)
    }
    // A partial first month would sit on top of the label right after it.
    if (months.length > 1 && months[1].column - months[0].column < 3) months.shift()
    return { cells: cells, months: months }
  }

  function levelColor(level) {
    if (level <= 0) return Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
    return Qt.rgba(tint.r, tint.g, tint.b, [0.3, 0.5, 0.74, 1.0][level - 1])
  }

  function dateAtPoint(x, y) {
    var column = Math.floor(x / step)
    var row = Math.floor(y / step)
    if (column < 0 || column >= weeks || row < 0 || row > 6) return ""
    var entry = grid.cells[column * 7 + row]
    return entry && !entry.future ? entry.date : ""
  }

  Repeater {
    model: root.grid.months

    Text {
      required property var modelData
      x: root.labelWidth + modelData.column * root.step
      text: modelData.label
      color: Qt.darker(root.foreground, 1.55)
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
    }
  }

  Repeater {
    model: [0, 2, 4]

    Text {
      required property int modelData
      y: root.headerHeight + modelData * root.step + (root.cell - height) / 2
      text: root.dayLabels[modelData]
      color: Qt.darker(root.foreground, 1.55)
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
    }
  }

  Repeater {
    model: root.grid.cells

    Rectangle {
      required property var modelData
      required property int index

      x: root.labelWidth + Math.floor(index / 7) * root.step
      y: root.headerHeight + (index % 7) * root.step
      width: root.cell
      height: root.cell
      radius: Math.min(2, root.cell / 4)
      visible: !modelData.future
      color: root.levelColor(modelData.level)
      border.width: modelData.date === root.hoveredDate || modelData.date === root.picked ? 1 : 0
      border.color: root.foreground
    }
  }

  // One area over the whole grid rather than one per cell: the gaps between
  // cells then keep the last day instead of flickering the tooltip off.
  MouseArea {
    x: root.labelWidth
    y: root.headerHeight
    width: root.weeks * root.step
    height: root.gridHeight
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPositionChanged: function(mouse) {
      var date = root.dateAtPoint(mouse.x, mouse.y)
      if (date !== "") root.hoveredDate = date
    }
    onExited: root.hoveredDate = ""
    onClicked: function(mouse) {
      var date = root.dateAtPoint(mouse.x, mouse.y)
      if (date !== "") root.dayClicked(date)
    }
  }
}
