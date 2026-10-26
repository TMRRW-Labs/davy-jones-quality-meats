#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Davy Jones Quality Meats — static site build.
#
#   ./build.sh                       build the site into dist/
#   ./build.sh --with-demo-market    also render the dormant city template
#                                    with a real town filled in, so we can
#                                    confirm it isn't a broken template
#
# No toolchain: bash, awk and sed only. Output in dist/ is plain HTML and can
# be dropped on any host.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

SRC="src"
OUT="dist"
SITE_URL="https://www.davyjonesqualitymeats.ca"
STORE_URL="https://shop.davyjonesqualitymeats.ca/"
YEAR="$(date +%Y)"
BUILD_DATE="$(date +%Y-%m-%d)"

WITH_DEMO_MARKET=0
for arg in "$@"; do
  case "$arg" in
    --with-demo-market) WITH_DEMO_MARKET=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# Build into a staging directory and swap it into place at the end, so dist/
# is never half-empty. Deleting dist/ up front meant a browser refreshed during
# a rebuild got a 404.
STAGE="$OUT.new"
rm -rf "$STAGE"
mkdir -p "$STAGE"
OUT="$STAGE"

# ------------------------------------------------------------------ assets
cp -R assets "$OUT/assets"

# ------------------------------------------------------- template expansion

# Replace {{> name}} include markers with src/partials/name.html.
expand_includes() {
  awk -v partials="$SRC/partials" '
    {
      line = $0
      while (match(line, /\{\{>[ ]*[a-z0-9-]+[ ]*\}\}/)) {
        marker = substr(line, RSTART, RLENGTH)
        name = marker
        gsub(/[{}> ]/, "", name)
        pre = substr(line, 1, RSTART - 1)
        post = substr(line, RSTART + RLENGTH)
        print pre
        file = partials "/" name ".html"
        while ((getline part < file) > 0) print part
        close(file)
        line = post
      }
      print line
    }
  '
}

# Replace {{PRODUCTS:name}} / {{JUMPNAV:name}} with rendered product data.
expand_products() {
  awk -v datadir="$SRC/data" -v awkfile="$SRC/render-products.awk" -v whyfile="$SRC/render-why.awk" '
    /\{\{PRODUCTS:[a-z0-9-]+\}\}/ {
      name = $0
      sub(/^.*\{\{PRODUCTS:/, "", name); sub(/\}\}.*$/, "", name)
      cmd = "awk -f \"" awkfile "\" -v mode=sections \"" datadir "/" name ".txt\""
      while ((cmd | getline out) > 0) print out
      close(cmd)
      next
    }
    /\{\{JUMPNAV:[a-z0-9-]+\}\}/ {
      name = $0
      sub(/^.*\{\{JUMPNAV:/, "", name); sub(/\}\}.*$/, "", name)
      cmd = "awk -f \"" awkfile "\" -v mode=jumpnav \"" datadir "/" name ".txt\""
      while ((cmd | getline out) > 0) print out
      close(cmd)
      next
    }
    /\{\{WHY:[a-z0-9-]+\}\}/ {
      name = $0
      sub(/^.*\{\{WHY:/, "", name); sub(/\}\}.*$/, "", name)
      cmd = "awk -f \"" whyfile "\" \"" datadir "/why/" name ".txt\""
      while ((cmd | getline out) > 0) print out
      close(cmd)
      next
    }
    { print }
  '
}

# Substitute the scalar variables and the nav active-state markers.
substitute() {
  local base="$1" title="$2" desc="$3" path="$4" active="$5" extra="$6" home="$7"
  awk -v base="$base" -v title="$title" -v desc="$desc" -v path="$path" \
      -v active="$active" -v year="$YEAR" -v built="$BUILD_DATE" \
      -v siteurl="$SITE_URL" -v extra="$extra" -v storeurl="$STORE_URL" \
      -v home="$home" '
    function rep(line, key, val) {
      k = "{{" key "}}"
      while ((i = index(line, k)) > 0)
        line = substr(line, 1, i - 1) val substr(line, i + length(k))
      return line
    }
    {
      line = $0
      line = rep(line, "BASE", base)
      line = rep(line, "HOME", home)
      line = rep(line, "TITLE", title)
      line = rep(line, "DESC", desc)
      line = rep(line, "PATH", path)
      line = rep(line, "SITE_URL", siteurl)
      line = rep(line, "STORE_URL", storeurl)
      line = rep(line, "YEAR", year)
      line = rep(line, "BUILD_DATE", built)
      line = rep(line, "HEAD_EXTRA", extra)
      if (active != "") line = rep(line, "A_" toupper(active), "aria-current=\"page\"")
      # Any nav marker left over belongs to a page we are not on.
      while (match(line, /\{\{A_[A-Z_]+\}\}/))
        line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
      print line
    }
  '
}

# ------------------------------------------------------------- page assembly

SITEMAP_ENTRIES=()

front_matter() {  # front_matter <file> <key>
  sed -n '1,/^---$/p' "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1
}

build_page() {  # build_page <src file> <out path relative to dist>
  local src="$1" rel="$2"
  local title desc active noindex extra depth base
  title="$(front_matter "$src" title)"
  desc="$(front_matter "$src" desc)"
  active="$(front_matter "$src" active)"
  noindex="$(front_matter "$src" noindex)"
  extra="$(front_matter "$src" head_extra)"

  # Relative asset prefix, so the build also opens straight off the filesystem.
  depth="$(awk -v p="$rel" 'BEGIN { n = gsub(/\//, "/", p); print n }')"
  base=""
  for ((i = 0; i < depth; i++)); do base="../$base"; done

  # Home link: "./" at the root, "../" (and deeper) further in. Points at the
  # directory rather than index.html, and still opens off the filesystem.
  local home="${base:-./}"

  # Directory pages canonicalise to the trailing-slash form, which is what the
  # host actually serves. "/locations" 301s to "/locations/", so pointing the
  # canonical and the sitemap at the bare form aims them at a redirect.
  local path="/$rel"
  path="${path%index.html}"
  [[ "$path" == "" ]] && path="/"

  mkdir -p "$OUT/$(dirname "$rel")"

  {
    cat "$SRC/partials/head.html"
    cat "$SRC/partials/header.html"
    sed '1,/^---$/d' "$src"
    cat "$SRC/partials/footer.html"
  } | expand_includes | expand_includes | expand_products \
    | substitute "$base" "$title" "$desc" "$path" "$active" "$extra" "$home" \
    > "$OUT/$rel"

  if [[ "$noindex" != "true" ]]; then
    SITEMAP_ENTRIES+=("$path")
  fi

  printf '  %-46s %s\n' "$rel" "$title"
}

echo "Building Davy Jones Quality Meats -> $OUT/"
echo

while IFS= read -r file; do
  rel="${file#$SRC/pages/}"
  [[ "$rel" == _template/* ]] && continue
  build_page "$file" "$rel"
done < <(find "$SRC/pages" -name '*.html' | sort)

# --------------------------------------------------- dormant city template
# Section 7 of the master doc: build it, don't publish it. The market list
# below ships empty, so no city pages are generated, nothing links to them
# and nothing lands in the sitemap. Fill the list in to switch them on.
MARKETS=()

if ((WITH_DEMO_MARKET)); then
  MARKETS=("London|London|Sarnia|1030 Confederation St|(519) 383-8837|about an hour east on the 402")
fi

if ((${#MARKETS[@]})); then
  echo
  echo "City pages (from the market list):"
  for market in "${MARKETS[@]}"; do
    IFS='|' read -r slug city shop address phone drive <<< "$market"
    slug="$(echo "$slug" | tr '[:upper:] ' '[:lower:]-')"
    tmp="$(mktemp)"
    sed -e "s/{{CITY}}/$city/g" -e "s/{{SHOP}}/$shop/g" \
        -e "s/{{SHOP_ADDRESS}}/$address/g" -e "s/{{SHOP_PHONE}}/$phone/g" \
        -e "s/{{DRIVE}}/$drive/g" \
        "$SRC/pages/_template/city.html" > "$tmp"
    build_page "$tmp" "butcher-shop-serving-$slug.html"
    rm -f "$tmp"
  done
else
  echo
  echo "City template: dormant (market list is empty, as intended)."
fi

# ----------------------------------------------------------------- sitemap
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  for path in "${SITEMAP_ENTRIES[@]}"; do
    echo "  <url><loc>${SITE_URL}${path}</loc><lastmod>${BUILD_DATE}</lastmod></url>"
  done
  echo '</urlset>'
} > "$OUT/sitemap.xml"

cat > "$OUT/robots.txt" <<ROBOTS
User-agent: *
Allow: /

Sitemap: ${SITE_URL}/sitemap.xml
ROBOTS

# ----------------------------------------- redirects from the old WordPress
cp "$SRC/redirects/_redirects" "$OUT/_redirects"
cp "$SRC/redirects/.htaccess" "$OUT/.htaccess"
cp "$SRC/redirects/_headers" "$OUT/_headers"

# ------------------------------------- JSON-LD derived from rendered markup
# Breadcrumbs and the FAQ accordion only exist after the page is assembled,
# so their structured data is generated from the output rather than hand-kept.
if command -v perl > /dev/null 2>&1; then
  echo
  perl "$SRC/../tools/add-structured-data.pl" "$OUT" "$SITE_URL"
else
  echo "perl not found: skipped BreadcrumbList and FAQPage JSON-LD." >&2
fi

# ------------------------------------------------- swap the staged build in
# Keeps the live directory complete at all times apart from a brief rename.
FINAL="dist"
if [[ -d "$FINAL" ]]; then
  rm -rf "$FINAL.old"
  mv "$FINAL" "$FINAL.old"
fi
mv "$STAGE" "$FINAL"
rm -rf "$FINAL.old"

echo
echo "${#SITEMAP_ENTRIES[@]} pages in the sitemap."
echo "Done. Serve dist/ or open dist/index.html."
