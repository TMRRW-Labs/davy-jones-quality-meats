# Renders a page-specific "Why Davy Jones" section from src/data/why/*.txt
#
# Data format
#   EYEBROW: WHY DAVY JONES CHICKEN
#   HEADING: Fresh Chicken. Better Prepared.
#   - Value Point Title | body copy
#
# Usage
#   awk -f render-why.awk data/why/chicken.txt

function esc(s) {
  gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s)
  return s
}
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

BEGIN {
  n = 0
  # A rotating set of line icons, reused across pages so the boxes stay
  # visually consistent with the rest of the design system.
  ico[1] = "<path d=\"M12 3l2.2 6.2H21l-5.4 4 2 6.4L12 15.8 6.4 19.6l2-6.4L3 9.2h6.8z\"/>"
  ico[2] = "<path d=\"M8 21v-2a4 4 0 0 1 8 0v2\"/><circle cx=\"12\" cy=\"8\" r=\"3.5\"/><path d=\"M3 21v-1.5a3 3 0 0 1 3-3\"/><path d=\"M21 21v-1.5a3 3 0 0 0-3-3\"/>"
  ico[3] = "<path d=\"M4 17 15 6\"/><path d=\"M15 6l3-3 3 3-3 3z\"/><path d=\"M4 17v3h3\"/>"
  ico[4] = "<path d=\"M4 6h16v14H4z\"/><path d=\"M4 10h16\"/><path d=\"M9 3v4\"/><path d=\"M15 3v4\"/><path d=\"M9 15h6\"/>"
  ico[5] = "<path d=\"M3 18h18\"/><path d=\"M5 18a7 7 0 0 1 14 0\"/><path d=\"M12 4v3\"/>"
  ico[6] = "<path d=\"M5 8c6 0 4 8 10 8\"/><path d=\"M5 8a3 3 0 0 1 0 6\"/><path d=\"M15 16a3 3 0 0 0 0-6\"/>"
}

/^[ \t]*#/    { next }
/^[ \t]*$/    { next }

/^EYEBROW:/ { eyebrow = trim(substr($0, 9)); next }
/^HEADING:/ { heading = trim(substr($0, 9)); next }

/^[ \t]*-/ {
  line = $0; sub(/^[ \t]*-[ \t]*/, "", line)
  split(line, p, "|")
  n++
  titles[n] = trim(p[1])
  bodies[n] = trim(p[2])
  next
}

END {
  if (n == 0) exit
  print "<section class=\"section section--bone\">"
  print "  <div class=\"shell\">"
  print "    <p class=\"eyebrow\">" esc(eyebrow) "</p>"
  print "    <h2 class=\"h2 u-max-780\">" esc(heading) "</h2>"
  print ""
  # Three across reads best for 3 or 6 boxes; two across suits 4. Five gets its
  # own modifier so the last row widens to fill instead of leaving a hole.
  cls = (n == 4) ? "box-grid" : "box-grid box-grid--3"
  if (n == 5) cls = cls " box-grid--5"
  print "    <div class=\"" cls " u-mt-l\">"
  for (i = 1; i <= n; i++) {
    k = ((i - 1) % 6) + 1
    print "      <div class=\"box\">"
    print "        <div class=\"box__icon\"><svg width=\"30\" height=\"30\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.25\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">" ico[k] "</svg></div>"
    print "        <h3 class=\"h3\">" esc(titles[i]) "</h3>"
    print "        <p>" esc(bodies[i]) "</p>"
    print "      </div>"
  }
  print "    </div>"
  print "  </div>"
  print "</section>"
}
