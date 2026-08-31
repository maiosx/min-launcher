// App list helpers: native AppLibrary apps + curated Web Apps section.
// Web Apps open in the browser; everything else launches natively.

.pragma library

function entryId(entry) {
  if (!entry) return ""
  return String(entry.id || entry.desktopId || "")
}

function entryName(appLibrary, entry) {
  if (!entry) return ""
  if (appLibrary && typeof appLibrary.entryName === "function") {
    try { return String(appLibrary.entryName(entry) || "") } catch (e) {}
  }
  return String(entry.name || entry.id || "")
}

function entrySubtext(appLibrary, entry) {
  if (!entry) return ""
  if (appLibrary && typeof appLibrary.entrySubtext === "function") {
    try { return String(appLibrary.entrySubtext(entry) || "") } catch (e) {}
  }
  return String(entry.genericName || entry.comment || "")
}

function entryIcon(entry) {
  if (!entry) return ""
  return String(entry.icon || "")
}

function entryCategories(entry) {
  if (!entry) return []
  try {
    if (entry.categories && typeof entry.categories.join === "function")
      return entry.categories.map(function(c) { return String(c || "") }).filter(function(c) { return c.length > 0 })
    if (typeof entry.categories === "string" && entry.categories)
      return entry.categories.split(";").map(function(c) { return c.trim() }).filter(function(c) { return c.length > 0 })
  } catch (e) {}
  return []
}

// FreeDesktop category → section title
var CATEGORY_MAP = [
  { title: "Development", keys: ["Development", "IDE", "TextEditor", "Debugger", "GUIDesigner", "WebDevelopment"] },
  { title: "Graphics", keys: ["Graphics", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics", "Photography"] },
  { title: "Internet", keys: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging", "FileTransfer", "RemoteAccess"] },
  { title: "Office", keys: ["Office", "WordProcessor", "Spreadsheet", "Presentation", "Calendar", "ContactManagement"] },
  { title: "Multimedia", keys: ["AudioVideo", "Audio", "Video", "Player", "Recorder", "TV"] },
  { title: "System", keys: ["System", "Settings", "Monitor", "TerminalEmulator", "Filesystem", "Security"] },
  { title: "Utility", keys: ["Utility", "Accessibility", "Archiving", "Compression", "FileTools", "TextTools", "Calculator"] },
  { title: "Games", keys: ["Game", "ActionGame", "AdventureGame", "ArcadeGame", "BoardGame", "CardGame", "LogicGame", "RolePlaying", "Simulation", "SportsGame", "StrategyGame"] }
]

// Curated browser-based tools shown under "Web Apps"
var WEB_APPS = [
  { name: "60fps", url: "https://60fps.design/" },
  { name: "Awwwards", url: "https://www.awwwards.com/" },
  { name: "Bolt.new", url: "https://bolt.new/" },
  { name: "Claude", url: "https://claude.ai/" },
  { name: "Color.review", url: "https://color.review/" },
  { name: "Cosmos", url: "https://www.cosmos.so/" },
  { name: "Excalidraw", url: "https://excalidraw.com/" },
  { name: "FigJam", url: "https://www.figma.com/figjam/" },
  { name: "Godly", url: "https://godly.website/" },
  { name: "Mobbin", url: "https://mobbin.com/" },
  { name: "Miro", url: "https://miro.com/" },
  { name: "Motion Primitives", url: "https://motion-primitives.com/" },
  { name: "Pinterest", url: "https://www.pinterest.com/" },
  { name: "React Bits", url: "https://www.reactbits.dev/" },
  { name: "shadcn/ui", url: "https://ui.shadcn.com/" },
  { name: "v0 by Vercel", url: "https://v0.dev/" },
  { name: "21st.dev", url: "https://21st.dev/" },
  { name: "ChatGPT", url: "https://chatgpt.com/" },
  { name: "Linear", url: "https://linear.app/" },
  { name: "Notion", url: "https://www.notion.so/" }
]

function sectionForCategories(cats) {
  for (var i = 0; i < CATEGORY_MAP.length; i++) {
    var section = CATEGORY_MAP[i]
    for (var j = 0; j < cats.length; j++) {
      for (var k = 0; k < section.keys.length; k++) {
        if (cats[j] === section.keys[k]) return section.title
      }
    }
  }
  return "Apps"
}

function buildWebAppList() {
  var out = []
  for (var i = 0; i < WEB_APPS.length; i++) {
    var w = WEB_APPS[i]
    if (!w || !w.name || !w.url) continue
    out.push({
      appId: "web." + String(w.name).toLowerCase().replace(/[^a-z0-9]+/g, "-"),
      name: w.name,
      subtext: "Web",
      icon: "",
      url: w.url,
      isWeb: true,
      section: "Web Apps"
    })
  }
  return out
}

function buildAppList(appLibrary) {
  var out = []
  if (appLibrary && typeof appLibrary.sortedEntries === "function") {
    var rows = []
    try { rows = appLibrary.sortedEntries("") || [] } catch (e) { rows = [] }

    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      var entry = row && row.entry ? row.entry : row
      if (!entry) continue
      var appId = entryId(entry)
      if (!appId) continue
      var cats = entryCategories(entry)
      out.push({
        appId: appId,
        name: entryName(appLibrary, entry),
        subtext: entrySubtext(appLibrary, entry),
        icon: entryIcon(entry),
        url: "",
        isWeb: false,
        section: sectionForCategories(cats)
      })
    }
  }

  var web = buildWebAppList()
  for (var j = 0; j < web.length; j++)
    out.push(web[j])

  return out
}

function filterApps(apps, query) {
  var q = String(query || "").trim().toLowerCase()
  if (!q) return apps || []
  var tokens = q.split(/\s+/).filter(function(t) { return t.length > 0 })
  if (tokens.length === 0) return apps || []

  var list = apps || []
  var matched = []
  for (var i = 0; i < list.length; i++) {
    var a = list[i]
    var hay = (String(a.name || "") + " " + String(a.subtext || "") + " " + String(a.appId || "") + " " + String(a.section || "") + " " + String(a.url || "")).toLowerCase()
    var ok = true
    for (var t = 0; t < tokens.length; t++) {
      if (hay.indexOf(tokens[t]) < 0) { ok = false; break }
    }
    if (ok) matched.push(a)
  }
  return matched
}

function buildSections(apps) {
  var order = ["Development", "Graphics", "Internet", "Office", "Multimedia", "System", "Utility", "Games", "Apps", "Web Apps"]
  var buckets = ({})
  for (var o = 0; o < order.length; o++) buckets[order[o]] = []

  var list = apps || []
  for (var i = 0; i < list.length; i++) {
    var a = list[i]
    var sec = a.section || "Apps"
    if (!buckets[sec]) buckets[sec] = []
    buckets[sec].push(a)
  }

  var sections = []
  for (var j = 0; j < order.length; j++) {
    var title = order[j]
    if (buckets[title] && buckets[title].length > 0)
      sections.push({ title: title, tools: buckets[title] })
  }
  for (var key in buckets) {
    if (order.indexOf(key) >= 0) continue
    if (buckets[key].length > 0)
      sections.push({ title: key, tools: buckets[key] })
  }
  return sections
}
