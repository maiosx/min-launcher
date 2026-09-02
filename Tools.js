// App list helpers: native AppLibrary apps + editable Web Apps section.
// Web Apps open in the browser; list is persisted under ~/.config/omarchy/.

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

// Default browser tools (used when no user file exists yet)
var DEFAULT_WEB_APPS = []
var MAX_CONFIG_BYTES = 64 * 1024
var MAX_WEB_ITEMS = 100
var MAX_NAME_LENGTH = 128
var MAX_URL_LENGTH = 2048

function slugify(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "item"
}

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

function normalizeWebItem(raw) {
  if (!raw || typeof raw !== "object") return null
  var rawName = String(raw.name || "")
  var rawUrl = String(raw.url || "")
  if (rawName.length > MAX_NAME_LENGTH || rawUrl.length > MAX_URL_LENGTH) return null
  var name = rawName.trim()
  var url = rawUrl.trim()
  if (!name || !url) return null
  if (url.indexOf("http://") !== 0 && url.indexOf("https://") !== 0)
    url = "https://" + url
  return {
    appId: "web." + slugify(name),
    name: name,
    subtext: "Web",
    icon: "",
    url: url,
    isWeb: true,
    section: "Web Apps"
  }
}

function defaultWebApps() {
  var out = []
  for (var i = 0; i < DEFAULT_WEB_APPS.length; i++) {
    var item = normalizeWebItem(DEFAULT_WEB_APPS[i])
    if (item) out.push(item)
  }
  return out
}

function parseWebAppsJson(raw) {
  var text = String(raw || "").trim()
  if (!text) return null
  if (text.length > MAX_CONFIG_BYTES) return null
  try {
    var parsed = JSON.parse(text)
    var source = Array.isArray(parsed) ? parsed
               : (parsed && Array.isArray(parsed.items) ? parsed.items : null)
    if (!source) return null
    if (source.length > MAX_WEB_ITEMS) return null
    var out = []
    var seen = ({})
    for (var i = 0; i < source.length; i++) {
      var item = normalizeWebItem(source[i])
      if (!item || seen[item.appId]) continue
      seen[item.appId] = true
      out.push(item)
    }
    return out
  } catch (e) {
    return null
  }
}

function serializeWebApps(list) {
  var items = []
  var arr = list || []
  for (var i = 0; i < arr.length && items.length < MAX_WEB_ITEMS; i++) {
    var a = arr[i]
    if (!a || !a.name || !a.url) continue
    items.push({ name: a.name, url: a.url })
  }
  return JSON.stringify({ items: items }, null, 2)
}

function webAppsConfigPath() {
  return "\"$HOME/.config/omarchy/min-launcher-web-apps.json\""
}

function buildNativeAppList(appLibrary) {
  var out = []
  if (!appLibrary || typeof appLibrary.sortedEntries !== "function")
    return out

  var rows = []
  try { rows = appLibrary.sortedEntries("") || [] } catch (e) { return out }

  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    var entry = row && row.entry ? row.entry : row
    if (!entry) continue
    var appId = entryId(entry)
    if (!appId) continue
    var cats = entryCategories(entry)
    out.push({
      appId: appId,
      name: entryName(appLibrary, entry).slice(0, MAX_NAME_LENGTH),
      subtext: entrySubtext(appLibrary, entry).slice(0, MAX_NAME_LENGTH),
      icon: entryIcon(entry),
      url: "",
      isWeb: false,
      section: sectionForCategories(cats)
    })
  }
  return out
}

function buildAppList(appLibrary, webApps) {
  var out = buildNativeAppList(appLibrary)
  var web = Array.isArray(webApps) ? webApps : defaultWebApps()
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

function removeWebApp(list, appId) {
  var out = []
  var arr = list || []
  for (var i = 0; i < arr.length; i++) {
    if (arr[i] && arr[i].appId !== appId)
      out.push(arr[i])
  }
  return out
}

function addWebApp(list, name, url) {
  var item = normalizeWebItem({ name: name, url: url })
  if (!item) return list || []
  var out = []
  var arr = list || []
  for (var i = 0; i < arr.length; i++) {
    if (arr[i] && arr[i].appId === item.appId) continue
    out.push(arr[i])
  }
  out.push(item)
  return out
}

function shellQuote(value) {
  return "'" + String(value || "").replace(/'/g, "'\\''") + "'"
}
