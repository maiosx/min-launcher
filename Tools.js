// Helpers for native-only app listing (Omarchy AppLibrary rows).
// No web URLs — only installed .desktop applications.

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

// Build a flat list of { appId, name, subtext, icon } from AppLibrary.
function buildAppList(appLibrary) {
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
    out.push({
      appId: appId,
      name: entryName(appLibrary, entry),
      subtext: entrySubtext(appLibrary, entry),
      icon: entryIcon(entry)
    })
  }
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
    var hay = (String(a.name || "") + " " + String(a.subtext || "") + " " + String(a.appId || "")).toLowerCase()
    var ok = true
    for (var t = 0; t < tokens.length; t++) {
      if (hay.indexOf(tokens[t]) < 0) { ok = false; break }
    }
    if (ok) matched.push(a)
  }
  return matched
}
