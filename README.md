# Davy Jones Quality Meats — website

Static site built from the Homepage V1 design (Claude Design canvas) and the
project master doc. No framework, no build dependencies beyond bash and awk —
`dist/` is plain HTML you can drop on any host.

**Client:** Davy Jones Quality Meats — Kyle Deloof, President
**Built by:** TMRRW

---

## Build and preview

```bash
bash build.sh
```

Output lands in `dist/`. Then preview it:

```bash
powershell -ExecutionPolicy Bypass -File serve.ps1
```

That serves `dist/` at http://localhost:8181. (There's no Node or Python on this
machine, which is why the build is bash and the server is PowerShell.)

To check the dormant city template still renders:

```bash
bash build.sh --with-demo-market
```

That generates one city page with London filled in. A normal `bash build.sh`
leaves it out — see *City pages* below.

---

## What's in here

```
build.sh                 the whole build
serve.ps1                local preview server
src/
  partials/              head, header, footer, and the sections repeated
                         across pages (reviews, final CTA, why-choose, FAQ)
  pages/                 one file per page, with front matter at the top
  pages/_template/       the dormant city page (never built by default)
  data/                  the product lists, one file per category
  redirects/             301 maps for the old WordPress URLs
  render-products.awk    turns a data file into product cards + jump links
assets/                  css, js, images — copied to dist as-is
docs/
  master-doc.md          the project master doc, as supplied
  open-items.md          what still needs a decision, and what the build assumed
  integrations.md        pixel, reviews widget, forms, Shopify
  homepage-design-v1.dc.html   the original design canvas source
dist/                    build output (throwaway — regenerate any time)
```

### Pages

22 pages, exactly the sitemap in section 3 of the master doc:

Home · Products (index + Beef, Premium Dry Aged, Chicken, Pork, Sausage,
Butcher Crafted, Appetizers, Gluten Free & No Gluten Added, Pantry & Rubs) ·
Freezer Packs · Custom Cutting · Our Story · Locations (index + Sarnia +
Point Edward) · Loyalty · Contact Us · FAQ · Privacy · Terms.

Plus the city template, built but not published.

---

## Editing

### Product lists

This is the part Kyle will change most, so it lives in plain text files in
`src/data/`. One file per category:

```
## Section Title | section-slug [| compact]
> Optional intro paragraph for the section
- Product Name | optional one-line description | optional tag
! A callout box, for copy that needs to sit inside the section
# lines starting with a hash are internal notes and never reach the page
```

Rules the renderer follows on its own:

- Jump links appear only on pages with **three or more sections** — that's the
  fix for not being able to find the T-bone without scrolling.
- `compact` gives you the smaller card and drops the per-product copy. Used for
  the sausage and fries lists.
- Every product card gets a photo placeholder captioned with its own name.

### Copy and layout

Page bodies are in `src/pages/`. Front matter at the top of each file:

```
title:      the <title> and og:title
desc:       meta description
active:     which nav item gets aria-current
noindex:    true to keep it out of the sitemap and add a robots meta
head_extra: anything extra to drop in <head>
---
```

Then the body. `{{BASE}}` is the relative path back to the site root, so pages
work in subdirectories and straight off the filesystem. `{{> name}}` pulls in
`src/partials/name.html`. `{{PRODUCTS:beef}}` and `{{JUMPNAV:beef}}` render
`src/data/beef.txt`.

### Photography

Every image on the site is currently a captioned grey placeholder — Kyle uses
real photography, never AI images, and the shoot hasn't happened yet. Each
placeholder says what shot belongs there. To swap one in:

```html
<!-- before -->
<div class="photo photo--tall"><span class="photo__note">Photo — Kyle behind the counter, portrait</span></div>

<!-- after -->
<div class="photo photo--tall"><img src="{{BASE}}assets/img/kyle-counter.webp" alt="Kyle Deloof behind the counter at the Confederation Street shop"></div>
```

Keep the wrapper and its modifier class — that's what holds the aspect ratio.
`--tall` is 4:5, `--wide` is 16:9, `--card` is 3:2, `--band` fills a full-height
band.

### City pages (built, not published)

Section 7 of the master doc: build it, don't publish it. The `MARKETS` list near
the bottom of `build.sh` ships empty, so no city pages exist — nothing links to
them, nothing is in the sitemap, nothing for Google to find. The layout stays in
the build.

When Kyle opens a market, add a line:

```bash
MARKETS=("London|London|Sarnia|1030 Confederation St|(519) 383-8837|about an hour east on the 402")
#         slug  |city  |shop  |address                |phone          |drive-time phrase
```

And when one does go live, replace the generic copy in
`src/pages/_template/city.html` with real content for that town — actual drive
times, local landmarks, answers specific to that area. Two real pages beat eight
thin ones.

---

## Deploying

`dist/` is the whole site. Upload it, or point a static host at the repo with
`bash build.sh` as the build command and `dist` as the publish directory.

The build emits `_redirects` (Netlify / Cloudflare Pages) and `.htaccess`
(Apache / cPanel) with 301s from the old WordPress URLs. **Both need verifying
against the real URL list in Google Search Console before launch** — the paths
in there are what the audit found, and there are probably more.

Also before launch:

- Confirm the live domain (`SITE_URL`, used for canonicals and the sitemap).
- Add the Meta pixel, the Google Reviews widget and the form endpoint — see
  `docs/integrations.md`.
- Check the addresses match the Google Business Profile word for word.
- Read `docs/open-items.md`. Several things on the site are placeholders waiting
  on a decision from Kyle.

---

## House style

Rules the copy follows throughout. Worth keeping to when anyone edits it.

- **No em dashes.** Sentences are punctuated with full stops, commas and the
  occasional colon instead. En dashes are still used inside numeric and day
  ranges, where they are the correct character (`10 AM – 6 PM`).
- **Every product claim is sourced.** A description is either drawn from the
  master doc, taken from the client's own live copy, or a plain restatement of
  the product name. Where nothing could be sourced, the product is listed by
  name alone rather than given invented flavour copy. Each data file names its
  sources at the top.
- **Confident, not cocky.** The comparison with the grocery store is framed as a
  difference in what each place is set up to do, never as an attack. Nothing
  claims to be the best.
- **FUEL applied where it fits.** Heroes lead with the specific claim rather
  than a company introduction, calls to action describe the real next action
  (`Get Directions`, `Call to Reserve`, `Claim Your 10% Off`), the process
  sections run three steps ending at the customer's outcome, and the FAQs answer
  real hesitations. It is not forced onto pages that are simply lists of
  products.

## Notes on how the copy behaves

Things the master doc was explicit about, and which the build honours:

- **Never "grass-fed."** Grain-fed on purpose, and the site says why.
- **No sausage count anywhere.** The old site claimed "over 25 kinds" and Kyle
  supplied 19, so no number is published.
- **No "safe to consume."** No Gluten Added items are described by how they're
  made, and the page tells anyone with celiac disease to talk to a butcher.
- **No dry-aging duration.** The number isn't confirmed, so it isn't published.
- **No loyalty member count.** "7,600+ members" is left out until Kyle confirms
  we can use it.
- **No sale banners.** Premium butcher at a fair price; the loyalty program is
  where the value sits.
- **No video testimonials section.** Designed but left out of the build until
  the videos exist, per the doc.
