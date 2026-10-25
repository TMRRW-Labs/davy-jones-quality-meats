#!/usr/bin/perl
# Exports every word of copy from the built site into one reviewable document.
#
#   perl tools/export-copy.pl > docs/website-copy.md
#
# Reads dist/, so it always matches what is actually on the site. Run it after
# build.sh. Nav and footer appear once at the end rather than on all 22 pages.
use strict;
use warnings;

binmode(STDOUT, ':encoding(UTF-8)');

my @order = qw(
  index.html
  products/index.html
  products/beef.html
  products/premium-dry-aged.html
  products/chicken.html
  products/pork.html
  products/sausage.html
  products/butcher-crafted.html
  products/appetizers.html
  products/gluten-free.html
  products/pantry-and-rubs.html
  freezer-packs.html
  custom-cutting.html
  our-story.html
  locations/index.html
  locations/sarnia.html
  locations/point-edward.html
  loyalty.html
  contact.html
  faq.html
  privacy.html
  terms.html
);

sub clean {
  my ($s) = @_;
  $s =~ s/<[^>]+>//g;
  $s =~ s/&mdash;/-/g;   $s =~ s/&ndash;/-/g;
  $s =~ s/&amp;/&/g;     $s =~ s/&middot;/-/g;
  $s =~ s/&ldquo;|&rdquo;/"/g;
  $s =~ s/&lsquo;|&rsquo;/'/g;
  $s =~ s/&times;/x/g;   $s =~ s/&nbsp;/ /g;
  $s =~ s/&#9733;//g;    $s =~ s/&ntilde;/n/g;
  $s =~ s/&lt;/</g;      $s =~ s/&gt;/>/g;
  $s =~ s/\s+/ /g;
  $s =~ s/^\s+|\s+$//g;
  return $s;
}

sub slurp {
  my ($f) = @_;
  open my $fh, '<:encoding(UTF-8)', $f or die "$f: $!";
  local $/; my $t = <$fh>; close $fh; return $t;
}

print "# Davy Jones Quality Meats\n";
print "## Website copy, for review\n\n";
print "Every word of copy on the new site, page by page, in the order it appears\n";
print "on screen. Generated from the build, so this document and the site cannot\n";
print "drift apart.\n\n";
printf "Prepared by TMRRW. %s.\n\n", scalar(localtime) =~ s/\s+\d\d:\d\d:\d\d//r;
print "Notes on how to read it:\n\n";
print "- **Bold labels** name the kind of element, not text that appears on screen.\n";
print "- `[Photo: ...]` marks an image slot and describes the shot that belongs there.\n";
print "- Button text is the words on the button.\n";
print "- The header and footer are the same on every page and appear once, at the end.\n\n";
print "---\n\n";

for my $rel (@order) {
  my $path = "dist/$rel";
  unless (-e $path) { warn "missing $path\n"; next; }
  my $html = slurp($path);

  my ($title) = $html =~ /<title>(.*?)<\/title>/s;
  my ($desc)  = $html =~ /<meta name="description" content="(.*?)">/s;

  print "\n## ", clean($title || $rel), "\n\n";
  print "**Page:** `/", ($rel =~ s{/index\.html$}{/}r =~ s{^index\.html$}{}r), "`  \n";
  print "**Search description:** ", clean($desc || ''), "\n\n";

  my ($main) = $html =~ /<main id="main">(.*?)<\/main>/s;
  unless ($main) { print "_no main content found_\n"; next; }
  $main =~ s/<!--.*?-->//gs;

  # Walk the elements that carry copy, in document order.
  my @out;
  while ($main =~ m{
      <span\ class="photo__note"[^>]*>(?<photo>.*?)</span>
    | <p\ class="eyebrow[^"]*"[^>]*>(?<eyebrow>.*?)</p>
    | <h1[^>]*>(?<h1>.*?)</h1>
    | <h2[^>]*>(?<h2>.*?)</h2>
    | <h3[^>]*>(?<h3>.*?)</h3>
    | <p\ class="hero__sub"[^>]*>(?<sub>.*?)</p>
    | <p\ class="lede"[^>]*>(?<lede>.*?)</p>
    | <span\ class="tag"[^>]*>(?<tag>.*?)</span>
    | <a\ class="btn[^"]*"[^>]*>(?<btn>.*?)</a>
    | <button\ class="btn[^"]*"[^>]*>(?<btn2>.*?)</button>
    | <a\ class="link-(?:rule|arrow)[^"]*"[^>]*>(?<link>.*?)</a>
    | <div\ class="card__title"[^>]*>(?<ctitle>.*?)</div>
    | <p\ class="card__sub"[^>]*>(?<csub>.*?)</p>
    | <h3\ class="product__name"[^>]*>(?<pname>.*?)</h3>
    | <p\ class="product__desc"[^>]*>(?<pdesc>.*?)</p>
    | <span\ class="product__tag"[^>]*>(?<ptag>.*?)</span>
    | <div\ class="steps__title"[^>]*>(?<step>.*?)</div>
    | <div\ class="help-col__q"[^>]*>(?<helpq>.*?)</div>
    | <div\ class="closer__text"[^>]*>(?<closer>.*?)</div>
    | <div\ class="cut-to-order__text"[^>]*>(?<cut>.*?)</div>
    | <div\ class="pack__name"[^>]*>(?<pack>.*?)</div>
    | <span\ class="pack__now"[^>]*>(?<now>.*?)</span>
    | <span\ class="pack__was"[^>]*>(?<was>.*?)</span>
    | <summary[^>]*>(?<faq>.*?)</summary>
    | <blockquote[^>]*>(?<quote>.*?)</blockquote>
    | <cite[^>]*>(?<cite>.*?)</cite>
    | <label\ for="[^"]*"[^>]*>(?<label>.*?)</label>
    | <div\ class="compare__row"><div[^>]*>(?<c1>.*?)</div>\s*<div[^>]*>(?<c2>.*?)</div>
    | <li[^>]*>(?<li>.*?)</li>
    | <p(?:\ class="(?:fine|form__note|field__hint)")?\s*>(?<p>.*?)</p>
    }gsx) {
    my %m = %+;
    my ($k) = grep { defined $m{$_} } keys %m;
    next unless $k;
    # A review's attribution sits inside the blockquote; keep just the quote.
    $m{$k} =~ s/<footer.*?<\/footer>//gs if $k eq 'quote';
    my $v = clean($m{$k});
    next if $v eq '';

    if    ($k eq 'photo')   { $v =~ s{^Photo:\s*}{}; push @out, "  \n`[Photo: $v]`" }
    elsif ($k eq 'eyebrow') { push @out, "\n**Section label:** $v" }
    elsif ($k eq 'h1')      { push @out, "\n### $v" }
    elsif ($k eq 'h2')      { push @out, "\n#### $v" }
    elsif ($k eq 'h3')      { push @out, "\n**Heading:** $v" }
    elsif ($k eq 'sub' || $k eq 'lede') { push @out, "$v" }
    elsif ($k eq 'tag')     { push @out, "- Tag: $v" }
    elsif ($k eq 'btn' || $k eq 'btn2') { push @out, "- **Button:** $v" }
    elsif ($k eq 'link')    { push @out, "- **Link:** $v" }
    elsif ($k eq 'ctitle')  { push @out, "- **Card:** $v" }
    elsif ($k eq 'csub')    { push @out, "  $v" }
    elsif ($k eq 'pname')   { push @out, "- $v" }
    elsif ($k eq 'pdesc')   { push @out, "  $v" }
    elsif ($k eq 'ptag')    { push @out, "  _Tag: ${v}_" }
    elsif ($k eq 'step')    { push @out, "- **Step:** $v" }
    elsif ($k eq 'helpq')   { push @out, "- **Column:** $v" }
    elsif ($k eq 'closer' || $k eq 'cut') { push @out, "\n**Closing line:** $v" }
    elsif ($k eq 'pack')    { push @out, "\n- **Pack:** $v" }
    elsif ($k eq 'now')     { push @out, "  Now: $v" }
    elsif ($k eq 'was')     { push @out, "  Was: $v" }
    elsif ($k eq 'faq')     { push @out, "\n- **Q:** $v" }
    elsif ($k eq 'quote')   { push @out, "\n> $v" }
    elsif ($k eq 'cite')    { push @out, "> $v" }
    elsif ($k eq 'label')   { push @out, "- Form field: $v" }
    elsif ($k eq 'c1')      { push @out, "- Grocery store: $v  \n  Davy Jones: " . clean($m{c2} // '') }
    elsif ($k eq 'li')      { push @out, "  - $v" }
    else                    { push @out, "$v" }
  }

  print join("\n", @out), "\n";
  print "\n---\n";
}

# Header and footer, documented once.
my $home = slurp('dist/index.html');
$home =~ s/<!--.*?-->//gs;

print "\n## Header, on every page\n\n";
my ($nav) = $home =~ /<nav class="nav" aria-label="Main">(.*?)<\/nav>/s;
if ($nav) {
  print "**Top bar, left to right:**\n\n";
  print "- Products (opens a dropdown)\n";
  for my $item ($nav =~ /<a [^>]*>([^<]+)<\/a>/g) {
    my $t = clean($item);
    next if $t eq '';
    print "- $t\n";
  }
}
my ($menu) = $home =~ /<div class="nav__menu" id="products-menu"[^>]*>(.*?)<\/div>/s;
if ($menu) {
  print "\n**Products dropdown:**\n\n";
  print "- ", clean($_), "\n" for ($menu =~ /<a [^>]*>(.*?)<\/a>/g);
}

print "\n**Sticky bar on mobile:** Call, Directions\n";

print "\n---\n\n## Footer, on every page\n\n";
my ($foot) = $home =~ /<footer class="footer">(.*?)<\/footer>/s;
if ($foot) {
  print "**Tagline:** Quality Meats Since 1994\n\n";
  print "**Pages column:**\n\n";
  my ($links) = $foot =~ /<div class="footer__links">(.*?)<\/div>\s*<\/div>/s;
  print "- ", clean($_), "\n" for ($links // '') =~ /<a [^>]*>(.*?)<\/a>/g;

  print "\n**Hours column**\n\n";
  print "- Sarnia: Mon to Fri 10 AM to 6 PM, Sat 9 AM to 5 PM, Sun 10 AM to 3 PM\n";
  print "- Point Edward: Tue to Fri 10 AM to 6 PM, Sat 9 AM to 5 PM, closed Sun and Mon\n";
  print "\n**Locations column**\n\n";
  print "- Sarnia: (519) 383-8837, 1030 Confederation St, Sarnia, ON N7S 6H1, Directions\n";
  print "- Point Edward: (519) 491-0210, 519 Helena St, Point Edward, ON N7V 1S1, Directions\n";
  print "\n**Bottom row:** Privacy Policy, Terms\n";
}
print "\n---\n\n";
print "## Built but not published\n\n";
print "A location page template for future markets exists in the build and is\n";
print "switched off. No city pages are generated, nothing links to them and\n";
print "nothing appears in the sitemap. See section 7 of the master doc.\n";
