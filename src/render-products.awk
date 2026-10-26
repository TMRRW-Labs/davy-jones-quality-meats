# Renders a product data file (src/data/*.txt) into HTML.
#
# Data format
#   ## Section Title | slug [| compact]
#   > optional intro paragraph
#   - Product Name | optional description | optional tag | optional photo file
#   ! note shown as a callout inside the section
#
# Within a section the products are split into two grids: the ones with a
# photograph first, then the ones without, smaller, underneath. Mixing them in
# one grid left photo cards sitting beside tall empty text cards, which read as
# a mistake rather than a choice.
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

# Builds one card. A product with no photo file renders as a text card: no
# image block, and it sits in the smaller grid below the photographed ones.
function cardHTML(name, desc, tag, img, compact,   s) {
  s = "          <article class=\"product" (compact ? " product--compact" : "") (img == "" ? " product--text" : "") "\">\n"
  if (img != "")
    s = s "            <div class=\"photo photo--card\"><img src=\"{{BASE}}assets/img/products/" img "\" alt=\"" esc(name) "\" loading=\"lazy\"></div>\n"
  s = s "            <div class=\"product__body\">\n"
  s = s "              <h3 class=\"product__name\">" esc(name) "</h3>\n"
  if (desc != "" && !compact) s = s "              <p class=\"product__desc\">" esc(desc) "</p>\n"
  if (tag != "")              s = s "              <span class=\"product__tag\">" esc(tag) "</span>\n"
  s = s "            </div>\n"
  s = s "          </article>"
  return s
}

function headClose() {
  if (pendingHead) { print "        </div>"; pendingHead = 0 }
}

# Emits the photographed grid, then the text-only grid, and resets both.
function flushGrids(   i, cls) {
  if (pn == 0 && tn == 0) return
  headClose()
  if (pn > 0) {
    cls = "product-grid" (curCompact ? " product-grid--compact" : "")
    # Two photographed products should span the row rather than leave an
    # empty track beside them. Three or more already fill it.
    if (pn == 2) cls = cls " product-grid--n2"
    print "        <div class=\"" cls "\">"
    for (i = 1; i <= pn; i++) print pBuf[i]
    print "        </div>"
  }
  if (tn > 0) {
    print "        <div class=\"product-grid product-grid--text\">"
    for (i = 1; i <= tn; i++) print tBuf[i]
    print "        </div>"
  }
  pn = 0; tn = 0
}

function closeSection() {
  flushGrids()
  if (inSection) { headClose(); print "      </section>"; inSection = 0 }
}

BEGIN { FS = "|"; inSection = 0; n = 0; pn = 0; tn = 0 }

/^[ \t]*$/     { next }
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
  curCompact = (flag == "compact") ? 1 : 0
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
  flushGrids()
  headClose()
  print "        <div class=\"callout\"><p>" esc(line) "</p></div>"
  next
}

# -------------------------------------------------------------------- product
/^[ \t]*-/ {
  line = $0; sub(/^[ \t]*-[ \t]*/, "", line)
  split(line, p, "|")
  name = trim(p[1]); desc = trim(p[2]); tag = trim(p[3]); img = trim(p[4])

  if (mode != "sections") next

  if (img == "") tBuf[++tn] = cardHTML(name, desc, tag, "",  curCompact)
  else           pBuf[++pn] = cardHTML(name, desc, tag, img, curCompact)
  next
}

END {
  if (mode == "sections") closeSection()
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
