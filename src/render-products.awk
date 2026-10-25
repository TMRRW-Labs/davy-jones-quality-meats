# Renders a product data file (src/data/*.txt) into HTML.
#
# Data format
#   ## Section Title | slug [| compact]
#   > optional intro paragraph
#   - Product Name | optional description | optional tag
#   ! note shown as a callout inside the section
#
# Usage
#   awk -f render-products.awk -v mode=sections data/beef.txt
#   awk -f render-products.awk -v mode=jumpnav  data/beef.txt
#   awk -f render-products.awk -v mode=count    data/beef.txt

function esc(s) {
  gsub(/&/, "\\&amp;", s)
  gsub(/</, "\\&lt;", s)
  gsub(/>/, "\\&gt;", s)
  return s
}

function trim(s) {
  sub(/^[ \t]+/, "", s)
  sub(/[ \t]+$/, "", s)
  return s
}

function closeGrid() {
  if (inGrid) { print "        </div>"; inGrid = 0 }
}

function closeSection() {
  closeGrid()
  if (inSection) { print "      </section>"; inSection = 0 }
}

BEGIN { FS = "|"; inSection = 0; inGrid = 0; n = 0 }

/^[ \t]*$/  { next }
/^[ \t]*#[^#]/ { next }              # comment line
/^[ \t]*###/   { next }

# ---------------------------------------------------------------- section head
/^[ \t]*##/ {
  line = $0
  sub(/^[ \t]*##[ \t]*/, "", line)
  split(line, part, "|")
  title = trim(part[1]); slug = trim(part[2]); flag = trim(part[3])
  n++
  slugs[n] = slug; titles[n] = title

  if (mode != "sections") next

  closeSection()
  inSection = 1
  compact[n] = (flag == "compact") ? 1 : 0
  curCompact = compact[n]
  print "      <section class=\"product-section\" id=\"" slug "\">"
  print "        <div class=\"product-section__head\">"
  print "          <h2>" esc(title) "</h2>"
  pendingHead = 1
  next
}

# ---------------------------------------------------------------- intro copy
/^[ \t]*>/ {
  if (mode != "sections") next
  line = $0; sub(/^[ \t]*>[ \t]*/, "", line)
  print "          <p>" esc(line) "</p>"
  next
}

# ---------------------------------------------------------------- inline note
/^[ \t]*!/ {
  if (mode != "sections") next
  line = $0; sub(/^[ \t]*![ \t]*/, "", line)
  if (pendingHead) { print "        </div>"; pendingHead = 0 }
  closeGrid()
  print "        <div class=\"callout\"><p>" esc(line) "</p></div>"
  next
}

# -------------------------------------------------------------------- product
/^[ \t]*-/ {
  line = $0; sub(/^[ \t]*-[ \t]*/, "", line)
  split(line, p, "|")
  name = trim(p[1]); desc = trim(p[2]); tag = trim(p[3]); img = trim(p[4])

  if (mode != "sections") next

  if (pendingHead) { print "        </div>"; pendingHead = 0 }
  if (!inGrid) {
    print "        <div class=\"product-grid" (curCompact ? " product-grid--compact" : "") "\">"
    inGrid = 1
  }
  # Fourth field is a filename in assets/img/products/. A product without one
  # renders as a text card: no image block, but it stretches to the same height
  # as its neighbours so the grid row stays even.
  textcard = (img == "") ? " product--text" : ""
  print "          <article class=\"product" (curCompact ? " product--compact" : "") textcard "\">"
  if (img != "")
    print "            <div class=\"photo photo--card\"><img src=\"{{BASE}}assets/img/products/" img "\" alt=\"" esc(name) "\" loading=\"lazy\"></div>"
  print "            <div class=\"product__body\">"
  print "              <h3 class=\"product__name\">" esc(name) "</h3>"
  if (desc != "" && !curCompact) print "              <p class=\"product__desc\">" esc(desc) "</p>"
  if (tag != "")  print "              <span class=\"product__tag\">" esc(tag) "</span>"
  print "            </div>"
  print "          </article>"
  next
}

END {
  if (mode == "sections") {
    if (pendingHead) print "        </div>"
    closeSection()
  }
  else if (mode == "count") { print n }
  else if (mode == "jumpnav") {
    # Jump links only earn their place on pages with three or more sections.
    if (n >= 3) {
      print "  <nav class=\"jumpnav\" aria-label=\"Jump to a section\">"
      print "    <div class=\"jumpnav__inner\">"
      for (i = 1; i <= n; i++)
        print "      <a href=\"#" slugs[i] "\">" esc(titles[i]) "</a>"
      print "    </div>"
      print "  </nav>"
    }
  }
}
