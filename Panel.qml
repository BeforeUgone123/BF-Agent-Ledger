import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

// One page for every agent. The sections stack in the order the `sections`
// setting lists them; the chip row narrows the same page to a single agent
// instead of switching to a different one.
Panel {
  id: root
  moduleName: "beforeugone.agents"
  ipcTarget: "beforeugone.agents"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var providers: usage.enabledProviders

  // "" is the merged view. The focus follows the agent, not its slot, so a
  // first scan landing while the panel is open cannot swap what you are reading.
  property string focusId: ""
  readonly property var focusChoices: {
    var ids = [""]
    for (var i = 0; i < providers.length; i++) ids.push(providers[i].providerId)
    return ids
  }
  readonly property int focusIndex: Math.max(0, focusChoices.indexOf(focusId))
  readonly property var provider: focusIndex > 0 ? providers[focusIndex - 1] : null
  readonly property var shown: provider ? [provider] : providers

  property bool cursorActive: false

  // Countdowns and "today" read this instead of Date.now() so the panel keeps
  // telling the truth while it sits open.
  property double nowMs: Date.now()

  // ---------------------------------------------------------------- settings

  // The id this widget is configured under in shell.json.
  readonly property string widgetId: "beforeugone.agents"
  readonly property var knownSections: ["summary", "heatmap", "limits", "capacity", "trend", "agents", "models", "projects", "breakdown", "hours", "sessions"]
  readonly property var sectionTitles: ({
    summary: tr("Summary"), heatmap: tr("Activity calendar"), limits: tr("Limits"), capacity: tr("Plan capacity"), trend: tr("Trend"),
    agents: tr("Tokens by agent"),
    models: tr("Tokens by model"), projects: tr("Tokens by project"), breakdown: tr("Token breakdown"), hours: tr("Hours of the week"),
    sessions: tr("Top sessions")
  })
  // Edits made in the panel show at once and are written to shell.json when
  // editing ends; the draft steps aside as soon as the setting catches up.
  property string sectionsDraft: ""
  property bool editing: false
  readonly property string sectionsSetting: String(usage.setting("sections", knownSections.join(",")))
  onSectionsSettingChanged: sectionsDraft = ""
  readonly property var sectionOrder: parseSections(sectionsDraft !== "" ? sectionsDraft : sectionsSetting)
  readonly property int heatmapWeeks: clamp(Math.round(Number(usage.setting("heatmapWeeks", 53))) || 53, 4, 53)
  readonly property color heatmapTint: String(usage.setting("heatmapTint", "Foreground")).toLowerCase() === "accent" ? Color.accent : foreground
  readonly property int panelWidth: clamp(Math.round(Number(usage.setting("panelWidth", 460))) || 460, 340, 720)
  readonly property int listRows: clamp(Math.round(Number(usage.setting("listRows", 5))) || 5, 1, 12)

  // Order and visibility in one string: sections draw in the order listed and
  // anything left out is hidden. Unknown names are dropped, not errors.
  function parseSections(value) {
    var names = String(value || "").toLowerCase().split(/[\s,]+/)
    var out = []
    for (var i = 0; i < names.length; i++)
      if (knownSections.indexOf(names[i]) >= 0 && out.indexOf(names[i]) < 0) out.push(names[i])
    return out
  }

  function sectionComponent(name) {
    if (name === "summary") return summarySection
    if (name === "heatmap") return heatmapSection
    if (name === "limits") return limitsSection
    if (name === "capacity") return capacitySection
    if (name === "trend") return trendSection
    if (name === "agents") return agentsSection
    if (name === "models") return modelsSection
    if (name === "projects") return projectsSection
    if (name === "breakdown") return breakdownSection
    if (name === "hours") return hoursSection
    if (name === "sessions") return sessionsSection
    return null
  }

  // Shown sections in their order, then the hidden ones.
  readonly property var editRows: {
    var rows = []
    for (var i = 0; i < sectionOrder.length; i++) rows.push({ name: sectionOrder[i], on: true })
    for (var k = 0; k < knownSections.length; k++)
      if (sectionOrder.indexOf(knownSections[k]) < 0) rows.push({ name: knownSections[k], on: false })
    return rows
  }

  function toggleSection(name) {
    var order = sectionOrder.slice()
    var at = order.indexOf(name)
    if (at >= 0) order.splice(at, 1)
    else order.push(name)
    // "none" keeps an emptied list from reading as "use the default".
    sectionsDraft = order.length > 0 ? order.join(",") : "none"
  }

  function moveSection(name, by) {
    var order = sectionOrder.slice()
    var at = order.indexOf(name)
    var to = at + by
    if (at < 0 || to < 0 || to >= order.length) return
    order.splice(at, 1)
    order.splice(to, 0, name)
    sectionsDraft = order.join(",")
  }

  function setEditing(on) {
    editing = on
    if (on || sectionsDraft === "" || sectionsDraft === sectionsSetting) return
    saveSections.command = ["omarchy", "bar", "set", widgetId, "sections", sectionsDraft]
    saveSections.running = true
  }

  // ---------------------------------------------------------------- language
  //
  // The page is written in English and Strings.js carries the Chinese. Every
  // binding that reaches tr() re-runs when the language flips, so the switch
  // in the hero changes the open page in place.

  readonly property var languageChoices: [["English", "EN"], ["Chinese", "中"]]
  // Like the sections draft: a click shows at once and leads the setting
  // until shell.json has caught up with it.
  property string languageDraft: ""
  property string languageWritten: ""
  readonly property string languageSetting: String(usage.setting("language", "English"))
  onLanguageSettingChanged: if (languageSetting === languageDraft) languageDraft = ""
  readonly property bool zh: ["chinese", "zh", "中文"].indexOf((languageDraft !== "" ? languageDraft : languageSetting).toLowerCase()) >= 0
  readonly property string language: languageChoices[zh ? 1 : 0][0]

  // Monday first, like both grids.
  readonly property var weekdayNames: zh ? ["周一", "周二", "周三", "周四", "周五", "周六", "周日"] : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
  readonly property var weekdayLetters: zh ? ["一", "二", "三", "四", "五", "六", "日"] : ["M", "T", "W", "T", "F", "S", "S"]
  readonly property var monthNames: zh ? ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]
    : ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  function tr(text) {
    return zh && Strings.zh[text] !== undefined ? Strings.zh[text] : text
  }

  function setLanguage(name) {
    if (name === language) return
    languageDraft = name
    if (!saveLanguage.running) writeLanguage()
  }

  function writeLanguage() {
    languageWritten = languageDraft
    saveLanguage.command = ["omarchy", "bar", "set", widgetId, "language", languageDraft]
    saveLanguage.running = true
  }

  // Status headlines arrive from the collectors in English. The help text
  // under them carries commands and raw errors, and is shown as written.
  function statusText(text) {
    var gone = String(text).match(/^(.+?)( limits)? unavailable$/)
    if (!gone || tr(text) !== text) return tr(text)
    return (gone[2] ? tr("%1 limits unavailable") : tr("%1 unavailable")).arg(gone[1])
  }

  // ---------------------------------------------------------------- filters
  //
  // One set of filters scopes every section below it, so the numbers agree.

  readonly property var rangeChoices: [["today", tr("Today")], ["7d", tr("7d")], ["30d", tr("30d")], ["90d", tr("90d")], ["all", tr("All")]]
  property string rangeId: String(usage.setting("defaultRange", "all")).toLowerCase()
  // A day picked on the calendar overrides the range until it is cleared.
  property string pickedDay: ""
  property string projectFilter: ""
  // Cache reads are most of every agent's volume; without them the totals
  // show the new work.
  property bool countCache: true

  // ---------------------------------------------------------------- derived

  readonly property var limitRows: buildLimitRows(shown, nowMs)
  readonly property var statusRows: buildStatusRows(shown)
  readonly property var view: buildView(usage.cubeRevision, usage.historyRevision, shown, rangeId, pickedDay, projectFilter, countCache, todayDate())
  readonly property var faintDates: buildFaintDates(shown, view.year, projectFilter)
  readonly property var activity: buildActivity(view.year, faintDates, heatmapWeeks, todayDate())
  readonly property var tiles: buildTiles(view, countCache)
  readonly property var capacityRows: buildCapacityRows(usage.cubeRevision, shown, countCache)

  readonly property bool alarming: {
    for (var i = 0; i < providers.length; i++) {
      var p = providers[i]
      var fullest = bindingWindow(p)
      if (fullest && fullest.percent >= 0.9) return true
      if (p.balance && p.balance.funded > 0 && p.balance.remaining / p.balance.funded <= 0.1) return true
    }
    return false
  }

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function refreshNow() {
    usage.refreshAll(true)
  }

  function launchAgent() {
    if (root.bar) root.bar.run("omarchy-agent --pick")
    root.close()
  }

  // ---------------------------------------------------------------- limits
  //
  // Both providers report the same two shapes: a short rolling session window
  // and a long weekly one. Everything below normalizes them into one record so
  // the meters and the hero speak a single language.

  // Claude spells its windows out ("Session (5-hour)"), Codex abbreviates
  // them ("5h window", "30m window"). Both have to land on the same record.
  function windowIsLong(text) {
    return text.indexOf("week") >= 0 || text.indexOf("7-day") >= 0 || text.indexOf("seven") >= 0
      || text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0
  }

  function windowSpanMs(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0) return 30 * 24 * 3600 * 1000
    if (windowIsLong(text)) return 7 * 24 * 3600 * 1000
    var hours = text.match(/(\d+)\s*-?\s*h(?:our)?\b/)
    if (hours) return Number(hours[1]) * 3600 * 1000
    var minutes = text.match(/(\d+)\s*-?\s*m(?:in(?:ute)?s?)?\b/)
    if (minutes) return Number(minutes[1]) * 60 * 1000
    return 0
  }

  function windowTitle(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0) return tr("Monthly")
    if (windowIsLong(text)) return tr("Weekly")
    if (text.indexOf("session") >= 0 || windowSpanMs(label) > 0) return tr("Session")
    var plain = String(label || "").replace(/\s*\(.*\)\s*/, "").trim()
    return plain === "" ? tr("Limit") : plain
  }

  // A collector that already knows which window a limit belongs to says so,
  // and that beats reading it back out of the label: a model-scoped limit is
  // titled after its model, and a name like "Opus 5 (1M context)" would parse
  // as a one-minute window.
  function limitWindow(label, percent, resetAt, title) {
    return {
      title: String(title || "") !== "" ? tr(String(title)) : windowTitle(label),
      percent: Number(percent),
      resetAt: String(resetAt || "")
    }
  }

  function limitWindows(p) {
    if (!p) return []
    var out = []
    var list = p.limits || []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i] || {}
      var percent = Number(entry.percent)
      if (percent >= 0) out.push(limitWindow(entry.label, percent, entry.resetsAt, entry.title))
    }
    return out
  }

  // The window that decides how much room is left — the fullest one, since
  // that is what stops the next prompt.
  function bindingWindow(p) {
    var windows = limitWindows(p)
    var best = null
    for (var i = 0; i < windows.length; i++) {
      if (!best || windows[i].percent > best.percent) best = windows[i]
    }
    return best
  }

  function resetMsFor(w) {
    if (!w || w.resetAt === "") return -1
    var ms = new Date(w.resetAt).getTime()
    return isFinite(ms) ? ms - root.nowMs : -1
  }

  function formatDuration(ms) {
    if (!(ms > 0)) return tr("now")
    var minutes = Math.floor(ms / 60000)
    var hours = Math.floor(minutes / 60)
    var days = Math.floor(hours / 24)
    if (days > 0) return tr("%1d %2h").arg(days).arg(hours % 24)
    if (hours > 0) return tr("%1h %2m").arg(hours).arg(minutes % 60)
    return tr("%1m").arg(Math.max(1, minutes))
  }

  // ---------------------------------------------------------------- balance
  //
  // Prepaid agents report a credit ledger instead of rate-limit windows: the
  // record's balance object carries remaining, funded, and spent amounts.

  function currencyPrefix(currency) {
    var code = String(currency || "USD").toUpperCase()
    if (code === "USD") return "$"
    if (code === "EUR") return "€"
    if (code === "GBP") return "£"
    return code + " "
  }

  function formatMoney(value, currency) {
    var amount = Number(value)
    if (!isFinite(amount)) amount = 0
    return currencyPrefix(currency) + amount.toFixed(2)
  }

  function balanceDetailText(b) {
    if (!b || !(b.funded > 0)) return ""
    var text = tr("%1 spent of %2 funded").arg(formatMoney(b.spent, b.currency)).arg(formatMoney(b.funded, b.currency))
    if (b.estimated) text += " · " + tr("estimated")
    return text
  }

  // ---------------------------------------------------------------- content

  // The plan you pay for, under the name of the tool it pays for. Limits live
  // in their own section; the hero just says what this is.
  function heroMeta(p) {
    if (!p) return ""
    if (String(p.usageStatusText || "") !== "") return statusText(p.usageStatusText)
    var tier = String(p.tierLabel || "")
    if (tier === "") return tr("Subscription")
    return tr(tier.charAt(0).toUpperCase() + tier.slice(1))
  }

  function setFocus(index) {
    if (focusChoices.length === 0) return
    var wrapped = ((index % focusChoices.length) + focusChoices.length) % focusChoices.length
    focusId = focusChoices[wrapped]
  }

  // "Claude Code" and "Kimi Code" have to share a chip row with four others.
  function shortName(p) {
    return String(p ? p.providerName : "").split(" ")[0]
  }

  function tokens(n) { return usage.formatTokenCount(Number(n || 0)) }

  // Every agent's windows and balances as one flat list, each row naming its
  // agent only when more than one is on the page.
  function buildLimitRows(list, now) {
    var rows = []
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      var prefix = list.length > 1 ? shortName(p) + " · " : ""
      var windows = limitWindows(p)
      for (var w = 0; w < windows.length; w++) {
        var remaining = resetMsFor(windows[w])
        rows.push({
          label: prefix + windows[w].title,
          value: windows[w].percent,
          alarming: windows[w].percent >= 0.9,
          text: Math.round(windows[w].percent * 100) + "%" + (remaining > 0 ? " · " + formatDuration(remaining) : ""),
          tip: remaining > 0 ? tr("Resets in %1").arg(formatDuration(remaining)) : ""
        })
      }
      var b = p.balance
      if (b) {
        // The meter shows what is left, not what is used: a prepaid account
        // drains toward empty rather than filling toward a cap.
        var ratio = b.funded > 0 ? clamp(b.remaining / b.funded, 0, 1) : -1
        rows.push({
          label: prefix + tr("Credits"),
          value: ratio,
          alarming: ratio >= 0 && ratio <= 0.1,
          text: tr("%1 left").arg(formatMoney(b.remaining, b.currency)),
          tip: balanceDetailText(b)
        })
      }
    }
    return rows
  }

  function buildStatusRows(list) {
    var rows = []
    for (var i = 0; i < list.length; i++) {
      var status = String(list[i].usageStatusText || "")
      if (status === "") continue
      var help = String(list[i].authHelpText || "")
      rows.push(list[i].providerName + ": " + statusText(status) + (help !== "" ? "\n" + help : ""))
    }
    return rows
  }

  function isoDate(date) {
    return date.getFullYear()
      + "-" + String(date.getMonth() + 1).padStart(2, "0")
      + "-" + String(date.getDate()).padStart(2, "0")
  }

  function addDays(date, n) {
    var d = new Date(date + "T00:00:00")
    d.setDate(d.getDate() + n)
    return isoDate(d)
  }

  function mondayOf(date) {
    var d = new Date(date + "T00:00:00")
    d.setDate(d.getDate() - ((d.getDay() + 6) % 7))
    return isoDate(d)
  }

  function rangeBounds(range, day, today) {
    if (day !== "") return { from: day, to: day, days: 1 }
    var span = ({ today: 1, "7d": 7, "30d": 30, "90d": 90 })[range]
    if (span) return { from: addDays(today, 1 - span), to: today, days: span }
    return { from: "", to: today, days: 0 }
  }

  function projectName(path) {
    if (usage.cube && path === usage.cube.home) return "~"
    var parts = String(path).split("/")
    return parts[parts.length - 1] || String(path)
  }

  function byTotal(a, b) { return b.total - a.total }

  // Everything the sections draw, from one pass over the cube. The revisions
  // are parameters only so the binding re-runs when the data changes in place.
  function buildView(cubeRevision, historyRevision, list, range, day, project, cache, today) {
    var bounds = rangeBounds(range, day, today)
    var prevFrom = bounds.days > 0 ? addDays(bounds.from, -bounds.days) : ""
    var prevTo = bounds.days > 0 ? addDays(bounds.from, -1) : ""
    var cube = usage.cube
    var slotOf = {}
    for (var i = 0; i < list.length; i++) slotOf[list[i].providerId] = i

    function slots() {
      var empty = []
      for (var k = 0; k < list.length; k++) empty.push(0)
      return empty
    }
    function inRange(date) { return (bounds.from === "" || date >= bounds.from) && date <= bounds.to }

    var v = {
      from: bounds.from, to: bounds.to, days: bounds.days,
      tokens: 0, output: 0, cost: 0, requests: 0, input: 0, cacheRead: 0, cacheWrite: 0, visible: 0, reasoning: 0,
      // The equal-length period just before this one, for the deltas.
      prev: bounds.days > 0 ? { tokens: 0, output: 0, cost: 0, sessions: 0 } : null,
      // The calendar ignores the range: date -> tokens, and the split per agent.
      year: {}, yearParts: {},
      hours: [], sessionCount: 0, activeDays: 0, cacheHit: -1, unpriced: [],
      agentRows: [], modelRows: [], projectRows: [], sessionRows: [], parts: [],
      trend: { buckets: [], peak: 0, unit: "" }
    }
    for (var h = 0; h < 168; h++) v.hours.push(0)

    var perDay = {}
    var perHour = {}
    var perAgent = {}
    var perModel = {}
    var perProject = {}
    var perSession = {}
    var prevSessions = {}
    var unpriced = {}
    var weekdayOf = {}
    var indexed = {}

    function addYear(date, slot, amount) {
      v.year[date] = (v.year[date] || 0) + amount
      if (!v.yearParts[date]) v.yearParts[date] = slots()
      v.yearParts[date][slot] += amount
    }

    if (cube) {
      for (var a = 0; a < cube.agents.length; a++) indexed[cube.agents[a]] = true
      for (var r = 0; r < cube.rows.length; r++) {
        // date, hour, agent, model, project, session, input, output,
        // reasoning, cacheRead, cacheWrite, cost, requests
        var row = cube.rows[r]
        var agent = cube.agents[row[2]]
        var slot = slotOf[agent]
        if (slot === undefined) continue
        var path = cube.projects[row[4]]
        if (project !== "" && path !== project) continue
        var date = row[0]
        var amount = row[6] + row[7] + row[8] + row[10] + (cache ? row[9] : 0)
        addYear(date, slot, amount)

        if (v.prev && date >= prevFrom && date <= prevTo) {
          v.prev.tokens += amount
          v.prev.output += row[7] + row[8]
          v.prev.cost += row[11] || 0
          prevSessions[row[5]] = true
          continue
        }
        if (!inRange(date)) continue

        v.tokens += amount
        v.input += row[6]
        v.visible += row[7]
        v.reasoning += row[8]
        v.cacheRead += row[9]
        v.cacheWrite += row[10]
        v.requests += row[12]
        var model = cube.models[row[3]]
        if (row[11] === null) unpriced[model] = true
        else v.cost += row[11]

        if (!perDay[date]) perDay[date] = slots()
        perDay[date][slot] += amount
        if (bounds.days === 1) {
          if (!perHour[row[1]]) perHour[row[1]] = slots()
          perHour[row[1]][slot] += amount
        }
        if (weekdayOf[date] === undefined) weekdayOf[date] = (new Date(date + "T00:00:00").getDay() + 6) % 7
        v.hours[weekdayOf[date] * 24 + row[1]] += amount

        perAgent[agent] = (perAgent[agent] || 0) + amount
        perProject[path] = (perProject[path] || 0) + amount
        var m = perModel[model] || (perModel[model] = { key: model, total: 0, input: 0, output: 0, cacheRead: 0, cacheWrite: 0 })
        m.total += amount
        m.input += row[6]
        m.output += row[7] + row[8]
        m.cacheRead += row[9]
        m.cacheWrite += row[10]
        var s = perSession[row[5]] || (perSession[row[5]] = { index: row[5], total: 0, cost: 0, priced: true, project: path, top: 0 })
        s.total += amount
        if (row[11] === null) s.priced = false
        else s.cost += row[11]
        // A session that moved between directories is filed under its busiest one.
        if (amount > s.top) {
          s.top = amount
          s.project = path
        }
      }
    }

    // Agents without a log adapter still have day totals in the ledger. They
    // join the calendar and the totals but carry no model, project or hour detail.
    if (project === "") {
      for (var n = 0; n < list.length; n++) {
        var id = list[n].providerId
        if (indexed[id]) continue
        var ledger = usage.history[id] || {}
        for (var d in ledger) {
          var total = Number(ledger[d] || 0)
          if (!(total > 0)) continue
          addYear(d, n, total)
          if (v.prev && d >= prevFrom && d <= prevTo) {
            v.prev.tokens += total
            continue
          }
          if (!inRange(d)) continue
          v.tokens += total
          if (!perDay[d]) perDay[d] = slots()
          perDay[d][n] += total
          perAgent[id] = (perAgent[id] || 0) + total
        }
      }
    }

    v.output = v.visible + v.reasoning
    v.unpriced = Object.keys(unpriced).sort()
    v.sessionCount = Object.keys(perSession).length
    if (v.prev) v.prev.sessions = Object.keys(prevSessions).length
    var prompt = v.cacheRead + v.cacheWrite + v.input
    v.cacheHit = prompt > 0 ? v.cacheRead / prompt : -1

    var firstDate = ""
    for (var key in perDay) {
      v.activeDays++
      if (firstDate === "" || key < firstDate) firstDate = key
    }

    for (var p = 0; p < list.length; p++)
      if (perAgent[list[p].providerId] > 0)
        v.agentRows.push({ key: list[p].providerId, label: list[p].providerName, total: perAgent[list[p].providerId], tip: heroMeta(list[p]) })
    v.agentRows.sort(byTotal)

    for (var modelId in perModel) {
      perModel[modelId].label = modelId ? usage.friendlyModelName(modelId) : tr("Unknown")
      v.modelRows.push(perModel[modelId])
    }
    v.modelRows.sort(byTotal)

    for (var projectPath in perProject)
      v.projectRows.push({ key: projectPath, label: projectName(projectPath), total: perProject[projectPath] })
    v.projectRows.sort(byTotal)

    for (var sessionKey in perSession) {
      var entry = perSession[sessionKey]
      // id, agent, title, start, end, peak context
      var meta = cube.sessions[entry.index]
      v.sessionRows.push({
        key: meta[0], label: meta[2] !== "" ? meta[2] : String(meta[0]).slice(0, 8), agent: cube.agents[meta[1]],
        total: entry.total, cost: entry.cost, priced: entry.priced, project: entry.project,
        start: meta[3], end: meta[4], peak: meta[5]
      })
    }
    v.sessionRows.sort(byTotal)

    v.parts = [
      { label: tr("Input (uncached)"), total: v.input },
      { label: tr("Cache read"), total: v.cacheRead },
      { label: tr("Cache write"), total: v.cacheWrite },
      { label: tr("Output"), total: v.visible },
      { label: tr("Reasoning"), total: v.reasoning }
    ]
    v.trend = buildTrend(bounds, perDay, perHour, firstDate, list.length)
    return v
  }

  // Hours for a single day, days up to a quarter, weeks beyond that.
  function buildTrend(bounds, perDay, perHour, firstDate, width) {
    function empty() {
      var values = []
      for (var k = 0; k < width; k++) values.push(0)
      return values
    }
    var buckets = []
    var unit = tr("by day")
    if (bounds.days === 1) {
      unit = tr("by hour")
      for (var h = 0; h < 24; h++) {
        var hh = String(h).padStart(2, "0")
        buckets.push({ label: hh + ":00", title: shortDate(bounds.from) + " " + hh + ":00", values: perHour[h] || empty() })
      }
    } else {
      var start = bounds.from !== "" ? bounds.from : (firstDate !== "" ? firstDate : bounds.to)
      var cursor = new Date(start + "T00:00:00")
      var span = Math.round((new Date(bounds.to + "T00:00:00").getTime() - cursor.getTime()) / 86400000) + 1
      var weekly = span > 92
      if (weekly) unit = tr("by week")
      var byKey = {}
      for (var date = isoDate(cursor); date <= bounds.to; cursor.setDate(cursor.getDate() + 1), date = isoDate(cursor)) {
        var key = weekly ? mondayOf(date) : date
        var bucket = byKey[key]
        if (!bucket) {
          bucket = byKey[key] = { label: shortDate(key).split(" ")[1], title: weekly ? tr("Week of %1").arg(shortDate(key)) : shortDate(key), values: empty() }
          buckets.push(bucket)
        }
        var day = perDay[date]
        if (day) for (var k = 0; k < width; k++) bucket.values[k] += day[k]
      }
    }
    var peak = 0
    for (var b = 0; b < buckets.length; b++) {
      var total = 0
      for (var j = 0; j < width; j++) total += buckets[b].values[j]
      buckets[b].total = total
      peak = Math.max(peak, total)
    }
    return { buckets: buckets, peak: peak, unit: unit }
  }

  // Days a collector knows were active but that nothing here has a total for:
  // they show as the faintest step instead of pretending nothing happened.
  function buildFaintDates(list, totals, project) {
    var faint = {}
    if (project !== "") return faint
    for (var i = 0; i < list.length; i++) {
      var dates = list[i].activeDates || []
      for (var d = 0; d < dates.length; d++)
        if (!(totals[dates[d]] > 0)) faint[String(dates[d])] = true
    }
    return faint
  }

  function buildActivity(totals, faint, weeks, today) {
    var cursor = new Date(today + "T00:00:00")
    cursor.setDate(cursor.getDate() - ((cursor.getDay() + 6) % 7) - (weeks - 1) * 7)
    var sum = 0
    var active = 0
    var longest = 0
    var run = 0
    var peakDate = ""
    for (var date = isoDate(cursor); date <= today; cursor.setDate(cursor.getDate() + 1), date = isoDate(cursor)) {
      var amount = Number(totals[date] || 0)
      var on = amount > 0 || faint[date] === true
      sum += amount
      if (on) active++
      // A streak still counts while today simply has not started yet.
      if (on || date !== today) run = on ? run + 1 : 0
      longest = Math.max(longest, run)
      if (amount > Number(totals[peakDate] || 0)) peakDate = date
    }
    return { total: sum, activeDays: active, streak: run, longest: longest, peakDate: peakDate, peak: Number(totals[peakDate] || 0) }
  }

  // What a plan's allowance amounts to: what was spent inside a limit window,
  // divided by the share of the window that spending used up. The index only
  // reports windows it could measure, so no limit reading means no estimate.
  function buildCapacityRows(revision, list, cache) {
    var rows = []
    var windows = usage.cube && Array.isArray(usage.cube.windows) ? usage.cube.windows : []
    for (var i = 0; i < windows.length; i++) {
      var w = windows[i]
      var owner = null
      for (var k = 0; k < list.length; k++)
        if (list[k].providerId === w.agent) owner = list[k]
      var used = w.input + w.output + w.cacheWrite + (cache ? w.cacheRead : 0)
      if (!owner || !(w.share > 0) || !(used > 0)) continue
      rows.push({
        label: (list.length > 1 ? shortName(owner) + " · " : "") + (w.title !== "" ? tr(w.title) : windowTitle(w.label)),
        share: w.share,
        // The share arrives in whole percent, so the truth lies within half a
        // point either side and the estimate inherits that spread.
        spread: 0.005 / w.share,
        span: w.span, start: w.start, readAt: w.readAt, requests: w.requests,
        usedTokens: used, usedCost: w.cost,
        fullTokens: used / w.share, fullCost: w.cost === null ? null : w.cost / w.share
      })
    }
    return rows
  }

  function capacityFigure(row) {
    var text = "~" + tokens(row.fullTokens)
    if (row.fullCost !== null) text += " · " + money(row.fullCost)
    if (row.spread >= 0.1) text += " ±" + Math.round(row.spread * 100) + "%"
    return text
  }

  function capacityTooltip(row) {
    var used = tokens(row.usedTokens) + tr(" tokens") + (row.usedCost !== null ? " (" + money(row.usedCost) + ")" : "")
    var text = tr("Used %1 in %2 requests since %3").arg(used).arg(row.requests).arg(clock(row.start))
      + "\n" + tr("= %1% of the window, measured %2").arg(Math.round(row.share * 100)).arg(clock(row.readAt))
      + "\n" + tr("Full window ≈ %1").arg(tokens(row.fullTokens) + tr(" tokens"))
      + (row.fullCost !== null ? " ≈ " + tr("%1 at list prices").arg(money(row.fullCost)) : "")
      + " (±" + Math.max(1, Math.round(row.spread * 100)) + "%)"
    if (row.fullCost !== null && row.span >= 86400000)
      text += "\n≈ " + tr("%1 per 30 days").arg(money(row.fullCost * 30 * 86400000 / row.span))
    return text + "\n" + tr("Counts only what ran on this machine: use elsewhere\non the account makes the real allowance larger.")
  }

  function money(amount) {
    var n = Number(amount || 0)
    if (n >= 100) return "$" + Math.round(n)
    return "$" + n.toFixed(n >= 1 || n === 0 ? 2 : 3)
  }

  function percent(ratio) {
    if (!(ratio >= 0)) return "—"
    return (ratio * 100).toFixed(ratio < 0.1 || ratio > 0.995 ? 1 : 0) + "%"
  }

  // More usage is neither good nor bad, so a delta is only ever a direction.
  function delta(current, previous) {
    if (!(previous > 0)) return ""
    var change = (current - previous) / previous * 100
    if (Math.abs(change) < 0.5) return tr("flat vs prior")
    return (change > 0 ? "▲ " : "▼ ") + tr("%1% vs prior").arg(Math.abs(change) > 999 ? ">999" : Math.abs(change).toFixed(0))
  }

  function buildTiles(v, cache) {
    var prev = v.prev || { tokens: 0, output: 0, cost: 0, sessions: 0 }
    return [
      { label: cache ? tr("Tokens") : tr("Tokens, no cache reads"), value: tokens(v.tokens), sub: delta(v.tokens, prev.tokens), tip: "" },
      { label: tr("Output"), value: tokens(v.output), sub: delta(v.output, prev.output), tip: tr("Visible output plus reasoning") },
      {
        label: tr("Est. cost"), value: money(v.cost),
        sub: v.unpriced.length > 0 ? tr("%1 unpriced").arg(v.unpriced.length) : delta(v.cost, prev.cost),
        tip: v.unpriced.length > 0 ? tr("No price in pricing.json for:") + "\n" + v.unpriced.join("\n") : tr("At the list prices in pricing.json")
      },
      { label: tr("Sessions"), value: String(v.sessionCount), sub: delta(v.sessionCount, prev.sessions), tip: tr("%1 requests").arg(v.requests) },
      { label: tr("Cache hit"), value: percent(v.cacheHit), sub: "", tip: tr("Share of prompt tokens served from cache") },
      { label: tr("Active days"), value: String(v.activeDays), sub: v.days > 1 ? tr("of %1").arg(v.days) : "", tip: "" }
    ]
  }

  function shortDate(date) {
    var parsed = new Date(String(date || "") + "T00:00:00")
    if (isNaN(parsed.getTime())) return String(date || "")
    return dayName(date) + " " + (parsed.getMonth() + 1) + "/" + parsed.getDate()
  }

  function clock(ms) {
    var at = new Date(ms)
    return (at.getMonth() + 1) + "/" + at.getDate() + " " + String(at.getHours()).padStart(2, "0") + ":" + String(at.getMinutes()).padStart(2, "0")
  }

  function rangeText() {
    if (pickedDay !== "") return shortDate(pickedDay)
    if (view.days === 1) return tr("today")
    if (view.days > 1) return tr("last %1 days").arg(view.days)
    return tr("all time")
  }

  function activityHeadline() {
    return tokens(activity.total) + tr(" tokens") + " · "
      + (activity.activeDays === 1 ? tr("%1 active day") : tr("%1 active days")).arg(activity.activeDays)
  }

  function activityFooter() {
    var text = tr("Streak %1d · longest %2d").arg(activity.streak).arg(activity.longest)
    if (activity.peakDate !== "") text += " · " + tr("peak %1").arg(shortDate(activity.peakDate) + " " + tokens(activity.peak))
    return text
  }

  function splitByAgent(values) {
    var parts = []
    for (var i = 0; i < shown.length; i++)
      if (values && values[i] > 0) parts.push(shortName(shown[i]) + " " + tokens(values[i]))
    return parts.length > 1 ? "\n" + parts.join(" · ") : ""
  }

  function heatmapTooltip(date) {
    if (date === "") return ""
    var total = Number(view.year[date] || 0)
    if (!(total > 0)) return shortDate(date) + " · " + (faintDates[date] ? tr("active, total not recorded") : tr("no activity"))
    return shortDate(date) + " · " + tokens(total) + tr(" tokens") + splitByAgent(view.yearParts[date])
      + "\n" + (pickedDay === date ? tr("Click to clear") : tr("Click to show only this day"))
  }

  function trendTooltip(bucket) {
    if (!bucket) return ""
    if (!(bucket.total > 0)) return bucket.title + " · " + tr("no activity")
    return bucket.title + " · " + tokens(bucket.total) + tr(" tokens") + splitByAgent(bucket.values)
  }

  function hourTooltip(slot) {
    if (slot < 0) return ""
    var hour = slot % 24
    var amount = Number(view.hours[slot] || 0)
    return weekdayNames[Math.floor(slot / 24)]
      + " " + String(hour).padStart(2, "0") + ":00–" + String(hour + 1).padStart(2, "0") + ":00 · "
      + (amount > 0 ? tokens(amount) + tr(" tokens") : tr("no activity"))
  }

  function modelTooltip(row) {
    return tr("In %1 · out %2 · cache read %3 · cache write %4")
      .arg(tokens(row.input)).arg(tokens(row.output)).arg(tokens(row.cacheRead)).arg(tokens(row.cacheWrite))
  }

  function sessionTooltip(row) {
    var name = row.agent
    for (var i = 0; i < providers.length; i++)
      if (providers[i].providerId === row.agent) name = providers[i].providerName
    return name + " · " + projectName(row.project) + " · " + clock(row.start)
      // An agent that logs a turn's total rather than each request has no context size.
      + "\n" + formatDuration(row.end - row.start) + (row.peak > 0 ? " · " + tr("peak context %1").arg(tokens(row.peak)) : "")
      + " · " + (row.priced ? money(row.cost) : row.cost > 0 ? money(row.cost) + "+" : tr("unpriced"))
  }

  // Stacked series are told apart by strength: the first agent is solid and
  // each one after it steps back. Past five the steps shrink to fit them all.
  function shade(index) {
    if (shown.length <= 5) return alpha(foreground, [1, 0.6, 0.36, 0.22, 0.14][Math.min(index, 4)])
    return alpha(foreground, Math.pow(0.12, index / (shown.length - 1)))
  }

  function share(total, peak) { return peak > 0 ? total / peak : 0 }

  function heroTitle() {
    return provider ? provider.providerName : tr("Agents")
  }

  function heroSubtitle() {
    if (provider) return heroMeta(provider)
    var today = Number(view.year[todayDate()] || 0)
    return (providers.length === 1 ? tr("%1 subscription") : tr("%1 subscriptions")).arg(providers.length)
      + " · " + tr("%1 tokens today").arg(tokens(today))
  }

  // Only speaks up when the numbers cover more than this machine.
  function footerText() {
    if (usage.syncStatusText !== "") return tr(usage.syncStatusText)
    for (var i = 0; i < shown.length; i++)
      if (shown[i].syncEnabled && shown[i].syncDeviceCount > 0)
        return (shown[i].syncDeviceCount === 1 ? tr("Merged from %1 device") : tr("Merged from %1 devices")).arg(shown[i].syncDeviceCount)
    return ""
  }

  // Local calendar date, recomputed from nowMs so a panel left open across
  // midnight moves the "Today" row with the clock.
  function todayDate() {
    var now = new Date(root.nowMs)
    return now.getFullYear()
      + "-" + String(now.getMonth() + 1).padStart(2, "0")
      + "-" + String(now.getDate()).padStart(2, "0")
  }

  function dayName(date) {
    var parsed = new Date(String(date || "") + "T00:00:00")
    if (isNaN(parsed.getTime())) return String(date || "")
    return weekdayNames[(parsed.getDay() + 6) % 7]
  }

  // Agents that ship a white mark carry an `assets/<id>-light.svg` twin for
  // light surfaces; marks that work on both (Claude's brand-orange) ship one
  // file. The luminance check decides which candidate to try first.
  function colorChannelLuminance(value) {
    var channel = Number(value)
    if (!isFinite(channel)) return 0
    return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
  }

  function colorLuminance(color) {
    return 0.2126 * colorChannelLuminance(color.r)
      + 0.7152 * colorChannelLuminance(color.g)
      + 0.0722 * colorChannelLuminance(color.b)
  }

  // Marks resolve by convention, so a new agent's data file needs nothing
  // from this panel: assets/<id>.svg if it ships one, the module's bar glyph
  // if it doesn't.
  function iconCandidatesForProvider(p, surfaceColor) {
    if (!p) return []
    var candidates = []
    if (colorLuminance(surfaceColor || Color.background) >= 0.5)
      candidates.push(Qt.resolvedUrl("assets/" + p.providerId + "-light.svg"))
    candidates.push(Qt.resolvedUrl("assets/" + p.providerId + ".svg"))
    return candidates
  }

  // Nothing to report, nothing in the bar: Bar.qml collapses a slot whose item
  // is invisible, so the icon appears the moment the first scan finds usage and
  // stays away entirely on a machine that has never run an agent.
  visible: providers.length > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onFocusIndexChanged: if (panelFlick) panelFlick.contentY = 0
  onOpenedChanged: if (!opened) {
    setEditing(false)
  } else {
    cursorActive = false
    nowMs = Date.now()
    if (panelFlick) panelFlick.contentY = 0
    usage.refreshLimits()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Main {
    id: usage
    settings: root.settings
  }

  Process {
    id: saveSections
    running: false
  }

  Process {
    id: saveLanguage
    running: false
    // A click that landed while the last write was still running goes out now.
    onExited: if (root.languageDraft !== "" && root.languageDraft !== root.languageWritten) root.writeLanguage()
  }

  // Cheap enough to keep running: it only re-evaluates text bindings, and a
  // stale "resets in 2h" on a panel that is open is worse than a timer.
  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refreshNow(); return "ok" }
    function next(): string { root.setFocus(root.focusIndex + 1); return "ok" }
    // What the page currently shows, for scripts and for checking a change.
    function status(): string {
      return JSON.stringify({
        opened: root.opened, focus: root.focusId, range: root.pickedDay !== "" ? root.pickedDay : root.rangeId,
        project: root.projectFilter, cache: root.countCache,
        sections: root.sectionOrder, language: root.language, agents: root.shown.length, tokens: root.view.tokens, sessions: root.view.sessionCount,
        capacity: root.capacityRows.length,
        indexRows: usage.cube ? usage.cube.rows.length : 0
      })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱚣"
    active: root.alarming
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.launchAgent()
      else if (buttonCode === Qt.MiddleButton) root.setFocus(root.focusIndex + 1)
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(root.panelWidth))
    // Taller than the control panels on purpose: this one is a dashboard, and
    // the whole point is reading limits and history without scrolling.
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          root.cursorActive = true
          root.setFocus(root.focusIndex + dx)
        }
        if (dy !== 0)
          panelFlick.contentY = root.clamp(panelFlick.contentY + dy * Style.space(56), 0,
                                           Math.max(0, panelFlick.contentHeight - panelFlick.height))
      }
      onActivateRequested: root.refreshNow()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") root.refreshNow() }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          // ---------- Hero: mark · name · what the page covers ----------
          PanelHero {
            id: hero
            visible: root.providers.length > 0
            width: parent.width
            title: root.heroTitle()
            meta: root.heroSubtitle()
            foreground: root.foreground
            fontFamily: root.fontFamily

            // EN / 中: the choice is saved to the `language` setting.
            trailingControl: Component {
              Row {
                spacing: Style.spacing.sm

                Repeater {
                  model: root.languageChoices

                  Button {
                    required property var modelData

                    width: Style.space(34)
                    text: modelData[1]
                    selected: modelData[0] === root.language
                    bordered: true
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    fontSize: Style.font.bodySmall
                    verticalPadding: Style.spacing.controlPaddingY
                    onClicked: root.setLanguage(modelData[0])
                  }
                }
              }
            }

            iconComponent: Component {
              Item {
                id: heroMark
                // The merged view has no single mark, so it keeps the bar glyph.
                property var candidates: root.iconCandidatesForProvider(root.provider, root.surface)
                // Provider objects are rebuilt on every refresh, which churns the
                // array's identity without changing its content. Restart the fallback
                // walk only when the URLs change: re-pointing source at a URL whose
                // load already failed emits no statusChanged, so an identity-only
                // reset would strand the walker on a missing -light twin.
                property string candidatesKey: candidates.join("\n")
                property int candidateIndex: 0
                onCandidatesKeyChanged: candidateIndex = 0

                width: Style.font.display
                height: Style.font.display

                Image {
                  id: heroMarkImage
                  anchors.fill: parent
                  source: heroMark.candidateIndex < heroMark.candidates.length ? heroMark.candidates[heroMark.candidateIndex] : ""
                  sourceSize.width: Style.font.display * 2
                  sourceSize.height: Style.font.display * 2
                  fillMode: Image.PreserveAspectFit
                  // Advancing source from inside its own status change trips the
                  // binding-loop detector; defer the step one tick.
                  onStatusChanged: if (status === Image.Error && heroMark.candidateIndex < heroMark.candidates.length)
                    Qt.callLater(function() { heroMark.candidateIndex++ })
                }

                Text {
                  anchors.centerIn: parent
                  visible: heroMarkImage.status !== Image.Ready
                  text: button.text
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }
              }
            }
          }

          Text {
            visible: root.providers.length === 0
            width: parent.width
            topPadding: Style.space(24)
            text: root.tr("No AI coding subscriptions found.\nAgents show up here once you've used them.")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          // ---------- Focus: everything, or one agent ----------
          Grid {
            id: focusSwitch
            visible: root.providers.length > 1
            width: parent.width
            spacing: Style.spacing.sm

            // A chip needs room for its name, so many agents wrap onto rows of
            // equal length rather than squeezing into one.
            readonly property int fits: Math.max(1, Math.floor((width + spacing) / (Style.space(72) + spacing)))
            readonly property int rowCount: Math.max(1, Math.ceil(root.focusChoices.length / fits))
            columns: Math.ceil(root.focusChoices.length / rowCount)
            // Whole pixels: a fractional width leaves the last chip's border between two.
            readonly property real cellWidth: Math.floor((width - spacing * (columns - 1)) / columns)

            Repeater {
              model: root.focusChoices

              Button {
                required property string modelData
                required property int index

                width: focusSwitch.cellWidth
                text: index === 0 ? root.tr("All") : root.shortName(root.providers[index - 1])
                selected: index === root.focusIndex
                hasCursor: root.cursorActive && index === root.focusIndex
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  root.cursorActive = true
                  root.setFocus(index)
                }
                onHovered: function(isHovered) { if (isHovered) root.cursorActive = true }
              }
            }
          }

          // ---------- Range: one filter row above everything it scopes ----------
          Row {
            id: rangeSwitch
            visible: root.providers.length > 0
            width: parent.width
            spacing: Style.spacing.sm

            // A day picked on the calendar joins the row as its own chip.
            readonly property var choices: root.pickedDay !== ""
              ? root.rangeChoices.concat([["day", root.shortDate(root.pickedDay)]])
              : root.rangeChoices
            readonly property real cacheWidth: Style.space(62)
            readonly property real cellWidth: Math.floor((width - cacheWidth - spacing * choices.length) / choices.length)

            Repeater {
              model: rangeSwitch.choices

              Button {
                required property var modelData

                width: rangeSwitch.cellWidth
                text: modelData[1]
                selected: root.pickedDay !== "" ? modelData[0] === "day" : modelData[0] === root.rangeId
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  root.pickedDay = ""
                  if (modelData[0] !== "day") root.rangeId = modelData[0]
                }
              }
            }

            // On: totals count cache reads. Off: only the new work.
            Button {
              width: rangeSwitch.cacheWidth
              text: root.tr("Cache")
              selected: root.countCache
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: root.countCache = !root.countCache
            }
          }

          // ---------- Project filter: named here, because its own section goes
          // away when the agent in focus never worked in that project ----------
          Button {
            visible: root.projectFilter !== ""
            width: parent.width
            text: root.tr("Project: %1 · click to clear").arg(root.projectName(root.projectFilter))
            tooltipText: root.projectFilter
            selected: true
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            verticalPadding: Style.spacing.controlPaddingY
            onClicked: root.projectFilter = ""
          }

          // ---------- Sections, in the order the settings list them ----------
          Repeater {
            model: root.sectionOrder

            Loader {
              required property string modelData
              width: column.width
              sourceComponent: root.sectionComponent(modelData)
              // A section with nothing to say steps out of the column entirely.
              visible: item ? item.shown : false
            }
          }

          // ---------- Customize: reorder and hide sections ----------
          PanelSeparator {
            visible: root.providers.length > 0
            foreground: root.foreground
          }

          Column {
            id: editList
            visible: root.editing
            width: parent.width
            spacing: Style.spacing.sm

            Repeater {
              model: root.editRows

              Item {
                id: editRow
                required property var modelData
                required property int index

                width: editList.width
                implicitHeight: editToggle.implicitHeight

                Text {
                  text: root.sectionTitles[editRow.modelData.name]
                  color: editRow.modelData.on ? root.foreground : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                  anchors.right: parent.right
                  spacing: Style.spacing.sm

                  Button {
                    visible: editRow.modelData.on
                    width: Style.space(30)
                    text: "↑"
                    bordered: true
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    fontSize: Style.font.bodySmall
                    verticalPadding: Style.spacing.controlPaddingY
                    onClicked: root.moveSection(editRow.modelData.name, -1)
                  }

                  Button {
                    visible: editRow.modelData.on
                    width: Style.space(30)
                    text: "↓"
                    bordered: true
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    fontSize: Style.font.bodySmall
                    verticalPadding: Style.spacing.controlPaddingY
                    onClicked: root.moveSection(editRow.modelData.name, 1)
                  }

                  Button {
                    id: editToggle
                    width: Style.space(56)
                    text: editRow.modelData.on ? root.tr("Hide") : root.tr("Show")
                    bordered: true
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    fontSize: Style.font.bodySmall
                    verticalPadding: Style.spacing.controlPaddingY
                    onClicked: root.toggleSection(editRow.modelData.name)
                  }
                }
              }
            }
          }

          Button {
            visible: root.providers.length > 0
            width: parent.width
            text: root.editing ? root.tr("Done") : root.tr("Customize sections")
            selected: root.editing
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            verticalPadding: Style.spacing.controlPaddingY
            onClicked: root.setEditing(!root.editing)
          }

          Text {
            visible: text !== ""
            width: parent.width
            topPadding: Style.space(2)
            text: root.footerText()
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- sections
  //
  // Each section is a Column that brings its own separator and reports
  // `shown`, so the page can reorder or drop it without knowing what it holds.

  Component {
    id: summarySection

    Column {
      id: summaryColumn
      readonly property bool shown: root.shown.length > 0
      spacing: Style.spacing.md

      PanelSeparator { foreground: root.foreground }

      SectionHead {
        width: parent.width
        title: root.tr("SUMMARY")
        note: root.rangeText()
      }

      Grid {
        id: tileGrid
        width: parent.width
        columns: 3
        columnSpacing: Style.spacing.md
        rowSpacing: Style.spacing.md

        Repeater {
          model: root.tiles

          StatTile {
            required property var modelData
            width: (tileGrid.width - tileGrid.columnSpacing * 2) / 3
            tile: modelData
          }
        }
      }
    }
  }

  Component {
    id: heatmapSection

    Column {
      readonly property bool shown: root.shown.length > 0
      spacing: Style.spacing.md

      PanelSeparator { foreground: root.foreground }

      SectionHead {
        width: parent.width
        title: root.tr("ACTIVITY")
        note: root.activityHeadline()
      }

      Heatmap {
        id: heat
        width: parent.width
        values: root.view.year
        faint: root.faintDates
        weeks: root.heatmapWeeks
        nowMs: root.nowMs
        picked: root.pickedDay
        monthNames: root.monthNames
        dayLabels: root.weekdayLetters
        foreground: root.foreground
        tint: root.heatmapTint
        fontFamily: root.fontFamily
        fontSize: Math.round(Style.font.caption * 0.85)
        onDayClicked: function(date) { root.pickedDay = root.pickedDay === date ? "" : date }

        PanelToolTip {
          visible: heat.hoveredDate !== ""
          delay: 0
          text: root.heatmapTooltip(heat.hoveredDate)
          fontFamily: root.fontFamily
        }
      }

      Text {
        width: parent.width
        text: root.activityFooter()
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }

  Component {
    id: limitsSection

    Column {
      id: limitsColumn
      readonly property bool shown: root.limitRows.length > 0 || root.statusRows.length > 0
      spacing: Style.spacing.md

      PanelSeparator { foreground: root.foreground }

      PanelSectionHeader {
        text: root.tr("LIMITS")
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: root.limitRows

        LimitRow {
          required property var modelData
          width: limitsColumn.width
          entry: modelData
        }
      }

      // Auth and endpoint problems: which agent, what is wrong, how to fix it.
      Repeater {
        model: root.statusRows

        BorderSurface {
          id: statusCard
          required property string modelData
          width: limitsColumn.width
          implicitHeight: statusText.implicitHeight + Style.spacing.xl * 2
          color: root.alpha(root.urgent, 0.10)
          borderSpec: Border.flat(root.alpha(root.urgent, 0.35), 1)
          radius: Style.cornerRadius

          Text {
            id: statusText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            textFormat: Text.PlainText
            text: statusCard.modelData
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  Component {
    id: capacitySection

    Column {
      id: capacityColumn
      readonly property bool shown: root.capacityRows.length > 0
      spacing: Style.spacing.md

      PanelSeparator { foreground: root.foreground }

      SectionHead {
        width: parent.width
        title: root.tr("PLAN CAPACITY")
        note: root.tr("full window ≈ used ÷ share used")
      }

      Repeater {
        model: root.capacityRows

        BarRow {
          required property var modelData
          width: capacityColumn.width
          label: modelData.label
          figure: root.capacityFigure(modelData)
          // The fill is how much of that allowance is already spent.
          share: modelData.share
          tip: root.capacityTooltip(modelData)
        }
      }
    }
  }

  Component {
    id: trendSection

    Column {
      readonly property bool shown: root.view.trend.peak > 0
      spacing: Style.spacing.md

      PanelSeparator { foreground: root.foreground }

      SectionHead {
        width: parent.width
        title: root.tr("TREND")
        note: root.view.trend.unit + " · " + root.tr("peak %1").arg(root.tokens(root.view.trend.peak))
      }

      TrendChart {
        width: parent.width
        buckets: root.view.trend.buckets
        peak: root.view.trend.peak
      }

      // Which strength is which agent; one series needs no key.
      Flow {
        visible: root.shown.length > 1
        width: parent.width
        spacing: Style.spacing.lg

        Repeater {
          model: root.shown

          Row {
            required property var modelData
            required property int index
            spacing: Style.spacing.sm

            Rectangle {
              width: Style.space(8)
              height: Style.space(8)
              radius: 2
              color: root.shade(index)
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: root.shortName(modelData)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }

  Component {
    id: agentsSection

    Column {
      id: agentsColumn
      // With one agent on the page this would only repeat the summary.
      readonly property bool shown: root.view.agentRows.length > 1
      spacing: Style.spacing.md

      PanelSeparator { foreground: root.foreground }

      SectionHead {
        width: parent.width
        title: root.tr("TOKENS BY AGENT")
        note: root.rangeText()
      }

      Repeater {
        model: root.view.agentRows

        BarRow {
          required property var modelData
          width: agentsColumn.width
          label: modelData.label
          figure: root.tokens(modelData.total)
          share: root.share(modelData.total, root.view.agentRows[0].total)
          tip: modelData.tip + " · " + root.tr("click to focus")
          clickable: true
          onClicked: root.focusId = modelData.key
        }
      }
    }
  }

  Component {
    id: modelsSection

    Column {
      id: modelsColumn
      readonly property bool shown: root.view.modelRows.length > 0
      spacing: Style.spacing.md

      PanelSeparator { foreground: root.foreground }

      SectionHead {
        width: parent.width
        title: root.tr("TOKENS BY MODEL")
        note: root.view.modelRows.length > root.listRows ? root.tr("top %1 of %2").arg(root.listRows).arg(root.view.modelRows.length) : ""
      }

      Repeater {
        model: root.view.modelRows.slice(0, root.listRows)

        BarRow {
          required property var modelData
          width: modelsColumn.width
          label: modelData.label
          figure: root.tokens(modelData.total)
          // Scaled to the heaviest model, so the top row is always full.
          share: root.share(modelData.total, root.view.modelRows[0].total)
          tip: root.modelTooltip(modelData)
        }
      }
    }
  }

  Component {
    id: projectsSection

    Column {
      id: projectsColumn
      readonly property bool shown: root.view.projectRows.length > 0
      spacing: Style.spacing.md

      PanelSeparator { foreground: root.foreground }

      SectionHead {
        width: parent.width
        title: root.tr("TOKENS BY PROJECT")
        note: root.projectFilter !== "" ? root.tr("filtered · click the row to clear")
          : root.view.projectRows.length > root.listRows ? root.tr("top %1 of %2").arg(root.listRows).arg(root.view.projectRows.length) : ""
      }

      Repeater {
        model: root.view.projectRows.slice(0, root.listRows)

        BarRow {
          required property var modelData
          width: projectsColumn.width
          label: modelData.label
          figure: root.tokens(modelData.total)
          share: root.share(modelData.total, root.view.projectRows[0].total)
          tip: modelData.key + "\n" + (root.projectFilter === modelData.key ? root.tr("Click to clear the filter") : root.tr("Click to show only this project"))
          clickable: true
          active: root.projectFilter === modelData.key
          onClicked: root.projectFilter = root.projectFilter === modelData.key ? "" : modelData.key
        }
      }
    }
  }

  Component {
    id: breakdownSection

    Column {
      id: breakdownColumn
      readonly property real whole: root.view.input + root.view.cacheRead + root.view.cacheWrite + root.view.output
      readonly property bool shown: whole > 0
      readonly property real peak: {
        var peak = 0
        for (var i = 0; i < root.view.parts.length; i++) peak = Math.max(peak, root.view.parts[i].total)
        return peak
      }
      spacing: Style.spacing.md

      PanelSeparator { foreground: root.foreground }

      SectionHead {
        width: parent.width
        title: root.tr("TOKEN BREAKDOWN")
        note: root.tr("cache hit %1").arg(root.percent(root.view.cacheHit))
      }

      Repeater {
        model: root.view.parts

        BarRow {
          required property var modelData
          width: breakdownColumn.width
          label: modelData.label
          figure: root.tokens(modelData.total) + " · " + root.percent(modelData.total / breakdownColumn.whole)
          share: root.share(modelData.total, breakdownColumn.peak)
        }
      }
    }
  }

  Component {
    id: hoursSection

    Column {
      readonly property bool shown: root.view.requests > 0
      readonly property int busiest: {
        var best = -1
        for (var i = 0; i < root.view.hours.length; i++)
          if (root.view.hours[i] > 0 && (best < 0 || root.view.hours[i] > root.view.hours[best])) best = i
        return best
      }
      spacing: Style.spacing.md

      PanelSeparator { foreground: root.foreground }

      SectionHead {
        width: parent.width
        title: root.tr("HOURS OF THE WEEK")
        note: busiest >= 0 ? root.tr("busiest %1").arg(root.hourTooltip(busiest).split(" · ")[0]) : ""
      }

      HourGrid {
        id: hourGrid
        width: parent.width
        values: root.view.hours
        dayLabels: root.weekdayLetters
        foreground: root.foreground
        tint: root.heatmapTint
        fontFamily: root.fontFamily
        fontSize: Math.round(Style.font.caption * 0.85)

        PanelToolTip {
          visible: hourGrid.hoveredSlot >= 0
          delay: 0
          text: root.hourTooltip(hourGrid.hoveredSlot)
          fontFamily: root.fontFamily
        }
      }
    }
  }

  Component {
    id: sessionsSection

    Column {
      id: sessionsColumn
      readonly property bool shown: root.view.sessionRows.length > 0
      spacing: Style.spacing.md

      PanelSeparator { foreground: root.foreground }

      SectionHead {
        width: parent.width
        title: root.tr("TOP SESSIONS")
        note: root.tr("top %1 of %2").arg(Math.min(root.listRows, root.view.sessionRows.length)).arg(root.view.sessionRows.length)
      }

      Repeater {
        model: root.view.sessionRows.slice(0, root.listRows)

        BarRow {
          required property var modelData
          width: sessionsColumn.width
          label: modelData.label
          figure: root.tokens(modelData.total)
          share: root.share(modelData.total, root.view.sessionRows[0].total)
          tip: root.sessionTooltip(modelData)
        }
      }
    }
  }

  // ---------------------------------------------------------------- rows

  // One allowance on one line: whose it is, how full, and what is left of it.
  component LimitRow: Item {
    id: limitRow
    property var entry: null

    readonly property bool alarming: !!entry && entry.alarming === true

    implicitHeight: Math.max(limitLabel.implicitHeight, limitValue.implicitHeight) + Style.spacing.sm

    Text {
      id: limitLabel
      // A model-scoped window is titled after its model, and those names run
      // long, so the label gives way before the numbers do.
      text: limitRow.entry ? limitRow.entry.label : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(124)
    }

    Meter {
      anchors.left: limitLabel.right
      anchors.right: limitValue.left
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      value: limitRow.entry ? limitRow.entry.value : -1
      alarming: limitRow.alarming
    }

    Text {
      id: limitValue
      text: limitRow.entry ? limitRow.entry.text : ""
      color: limitRow.alarming ? root.urgent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignRight
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(108)
    }

    MouseArea {
      id: limitHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    PanelToolTip {
      visible: limitHover.containsMouse && text !== ""
      text: limitRow.entry ? String(limitRow.entry.tip || "") : ""
      fontFamily: root.fontFamily
    }
  }

  // A section's title, with a quiet note opposite it.
  component SectionHead: Item {
    id: sectionHead
    property string title: ""
    property string note: ""

    implicitHeight: Math.max(headTitle.implicitHeight, headNote.implicitHeight)

    PanelSectionHeader {
      id: headTitle
      text: sectionHead.title
      foreground: root.foreground
      fontFamily: root.fontFamily
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: headNote
      text: sectionHead.note
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignRight
      anchors.left: headTitle.right
      anchors.leftMargin: Style.space(12)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // One headline number: what it is, the figure, and how it moved.
  component StatTile: Item {
    id: statTile
    property var tile: null

    implicitHeight: tileColumn.implicitHeight

    Column {
      id: tileColumn
      width: parent.width

      Text {
        width: parent.width
        text: statTile.tile ? statTile.tile.label : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        text: statTile.tile ? statTile.tile.value : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Math.round(Style.font.body * 1.45)
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        // Always a line tall, so tiles with and without a delta stay aligned.
        text: statTile.tile && statTile.tile.sub !== "" ? statTile.tile.sub : " "
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: tileHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    PanelToolTip {
      visible: tileHover.containsMouse && text !== ""
      text: statTile.tile ? String(statTile.tile.tip || "") : ""
      fontFamily: root.fontFamily
    }
  }

  // A table row whose bar fills in behind the text: label on the left, figure
  // on the right, and the row's share of the list's largest value as the fill.
  component BarRow: Item {
    id: barRow
    property string label: ""
    property string figure: ""
    property real share: 0
    property string tip: ""
    property bool clickable: false
    property bool active: false
    signal clicked()

    implicitHeight: barLabel.implicitHeight + Style.spacing.lg

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, barRow.active ? 0.2 : barRow.clickable && barHover.containsMouse ? 0.09 : 0.05)
    }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * root.clamp(barRow.share, 0, 1)
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, 0.14)

      Behavior on width {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
    }

    Text {
      id: barLabel
      // Session titles and paths come straight from logs.
      textFormat: Text.PlainText
      text: barRow.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: barRow.active
      elide: Text.ElideRight
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.right: barFigure.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: barFigure
      text: barRow.figure
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
      id: barHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: barRow.clickable ? Qt.LeftButton : Qt.NoButton
      cursorShape: barRow.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: barRow.clicked()
    }

    PanelToolTip {
      visible: barHover.containsMouse && barRow.tip !== ""
      text: barRow.tip
      fontFamily: root.fontFamily
    }
  }

  // Stacked columns over time, one segment per agent on the page.
  component TrendChart: Item {
    id: trend
    property var buckets: []
    property real peak: 0
    property int hovered: -1

    readonly property real plotHeight: Style.space(84)
    readonly property real band: buckets.length > 0 ? width / buckets.length : 0
    readonly property real barWidth: Math.max(1, Math.min(Style.space(22), Math.floor(band * 0.7)))
    readonly property real pixelsPerToken: peak > 0 ? plotHeight / peak : 0

    implicitHeight: plotHeight + firstLabel.implicitHeight + Style.space(4)

    // Where the stack stands once `count` of its segments are in, in pixels.
    function stackTop(values, count) {
      var sum = 0
      for (var i = 0; i < count; i++) sum += values[i]
      return Math.round(sum * pixelsPerToken)
    }

    Repeater {
      model: trend.buckets

      Item {
        id: stack
        required property var modelData
        required property int index

        x: index * trend.band
        width: trend.band
        height: trend.plotHeight

        Rectangle {
          anchors.fill: parent
          color: root.alpha(root.foreground, trend.hovered === stack.index ? 0.08 : 0)
        }

        Repeater {
          model: stack.modelData.values

          Rectangle {
            required property real modelData
            required property int index

            readonly property real upper: trend.stackTop(stack.modelData.values, index + 1)
            readonly property real lower: trend.stackTop(stack.modelData.values, index)

            x: (stack.width - width) / 2
            y: trend.plotHeight - upper
            width: trend.barWidth
            // Anything above zero keeps at least a pixel.
            height: Math.max(modelData > 0 ? 1 : 0, upper - lower)
            color: root.shade(index)
          }
        }
      }
    }

    Rectangle {
      y: trend.plotHeight
      width: parent.width
      height: 1
      color: root.alpha(root.foreground, 0.2)
    }

    Text {
      id: firstLabel
      y: trend.plotHeight + Style.space(4)
      text: trend.buckets.length > 0 ? trend.buckets[0].label : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      y: firstLabel.y
      anchors.right: parent.right
      text: trend.buckets.length > 1 ? trend.buckets[trend.buckets.length - 1].label : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    // The whole band is the target, so thin and empty columns stay reachable.
    MouseArea {
      width: parent.width
      height: trend.plotHeight
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      onPositionChanged: function(mouse) {
        if (trend.band > 0) trend.hovered = root.clamp(Math.floor(mouse.x / trend.band), 0, trend.buckets.length - 1)
      }
      onExited: trend.hovered = -1
    }

    PanelToolTip {
      visible: trend.hovered >= 0
      delay: 0
      text: trend.hovered >= 0 ? root.trendTooltip(trend.buckets[trend.hovered]) : ""
      fontFamily: root.fontFamily
    }
  }

  // Rounded track showing the percentage of the allowance used.
  component Meter: Item {
    id: meter
    property real value: -1
    property bool alarming: false
    property real thickness: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

    implicitHeight: thickness

    Rectangle {
      id: meterTrack
      anchors.fill: parent
      radius: height / 2
      color: root.track
    }

    Rectangle {
      anchors.left: meterTrack.left
      anchors.verticalCenter: meterTrack.verticalCenter
      height: meterTrack.height
      radius: meterTrack.radius
      width: meterTrack.width * root.clamp(meter.value, 0, 1)
      color: meter.alarming ? root.urgent : root.foreground

      Behavior on width {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
    }

  }
}
