// ISO-8601 week number math, ported from Omarchy's own
// shell/plugins/panels/clock/Model.js (isoWeek/isoWeekLiteral/pad2) so this
// widget computes the "WWnn" label the same way the built-in clock's format
// ring would, without re-deriving the algorithm.

function pad2(value) {
  var n = Number(value)
  return (n < 10 ? "0" : "") + n
}

function isoWeek(year, month, day) {
  var MS_PER_DAY = 86400000
  var date = new Date(Date.UTC(year, month, day))
  var weekday = date.getUTCDay() || 7
  date.setUTCDate(date.getUTCDate() + 4 - weekday)
  var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
  return Math.ceil(((date.getTime() - yearStart.getTime()) / MS_PER_DAY + 1) / 7)
}

function isoWeekLabel(date) {
  return "WW" + pad2(isoWeek(date.getFullYear(), date.getMonth(), date.getDate()))
}

if (typeof module !== "undefined") {
  module.exports = { pad2: pad2, isoWeek: isoWeek, isoWeekLabel: isoWeekLabel }
}
