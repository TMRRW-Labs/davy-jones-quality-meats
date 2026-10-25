#!/usr/bin/perl
# Post-build pass over dist/. Adds two kinds of JSON-LD that can only be
# derived once a page is rendered:
#
#   BreadcrumbList  from the visible <nav class="breadcrumb"> on every page
#                   that has one, so the markup and the data can never drift.
#   FAQPage         from the <details>/<summary> accordion on faq.html.
#
# Run:  perl tools/add-structured-data.pl dist https://www.davyjonesqualitymeats.ca
use strict; use warnings; use utf8;
use File::Find;
use File::Basename;
binmode(STDOUT, ':encoding(UTF-8)');

my $root = shift or die "usage: $0 <dist-dir> <site-url>\n";
my $site = shift or die "usage: $0 <dist-dir> <site-url>\n";
$site =~ s{/$}{};

my @pages;
find(sub { push @pages, $File::Find::name if /\.html$/ }, $root);
@pages = sort @pages;

# ---------------------------------------------------------------- helpers
sub unent {           # the small set of entities this build actually emits
  my $s = shift;
  $s =~ s/&amp;/&/g;  $s =~ s/&lt;/</g;   $s =~ s/&gt;/>/g;
  $s =~ s/&rsquo;/\x{2019}/g; $s =~ s/&lsquo;/\x{2018}/g;
  $s =~ s/&ldquo;/\x{201C}/g; $s =~ s/&rdquo;/\x{201D}/g;
  $s =~ s/&ndash;/\x{2013}/g; $s =~ s/&mdash;/\x{2014}/g;
  $s =~ s/&nbsp;/ /g; $s =~ s/&quot;/"/g; $s =~ s/&#39;/'/g;
  return $s;
}
sub jsonstr {
  my $s = shift;
  $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g;
  $s =~ s/\r//g; $s =~ s/\n/ /g; $s =~ s/\t/ /g;
  $s =~ s/\s+/ /g; $s =~ s/^ | $//g;
  return $s;
}
sub strip_tags { my $s = shift; $s =~ s/<[^>]*>//g; return $s }

# Resolve a page-relative href to an absolute site URL.
sub abs_url {
  my ($page, $href) = @_;
  return undef if $href =~ m{^(https?:|tel:|mailto:|#)};
  $href =~ s/#.*//;
  my $dir = dirname($page);                 # e.g. dist/products
  my $p   = ($href =~ m{^/}) ? "$root$href" : "$dir/$href";
  $p =~ s{/\./}{/}g;
  1 while $p =~ s{[^/]+/\.\./}{};
  $p =~ s{//+}{/}g;
  $p =~ s{^\Q$root\E/?}{};                  # -> products/beef.html
  $p =~ s{(^|/)index\.html$}{$1};           # -> products/  and  ""
  return "$site/$p";
}

# ---------------------------------------------------------------- the pass
my ($bc, $faq) = (0, 0);

for my $f (@pages) {
  open my $in, '<:encoding(UTF-8)', $f or die "$f: $!";
  local $/; my $html = <$in>; close $in;
  my $add = '';

  # ---- BreadcrumbList ---------------------------------------------------
  if (my ($nav) = $html =~ m{<nav class="breadcrumb"[^>]*>(.*?)</nav>}s) {
    my @items;
    # Linked crumbs, in document order.
    while ($nav =~ m{<a\s+href="([^"]+)"[^>]*>(.*?)</a>}gs) {
      my ($href, $label) = ($1, unent(strip_tags($2)));
      my $url = abs_url($f, $href);
      push @items, { name => $label, url => $url } if $url;
    }
    # The final crumb is bare text after the last </a> and its separator.
    my ($tail) = $nav =~ m{</a>\s*<span[^>]*>[^<]*</span>\s*([^<]+)}s;
    $tail = defined $tail ? unent($tail) : '';
    $tail =~ s/^\s+|\s+$//g;
    push @items, { name => $tail } if length $tail;

    if (@items > 1) {
      my @el;
      for my $i (0 .. $#items) {
        my $it = $items[$i];
        my $line = sprintf('{"@type":"ListItem","position":%d,"name":"%s"',
                           $i + 1, jsonstr($it->{name}));
        $line .= sprintf(',"item":"%s"', $it->{url}) if $it->{url};
        $line .= '}';
        push @el, $line;
      }
      $add .= '<script type="application/ld+json">' . "\n"
            . '{"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[' . "\n  "
            . join(",\n  ", @el) . "\n]}\n" . '</script>' . "\n";
      $bc++;
    }
  }

  # ---- FAQPage ----------------------------------------------------------
  if ($f =~ m{faq\.html$}) {
    my @qa;
    while ($html =~ m{<details>\s*<summary>(.*?)</summary>\s*<div class="accordion__body">(.*?)</div>\s*</details>}gs) {
      my ($q, $abody) = ($1, $2);
      my @paras = $abody =~ m{<p>(.*?)</p>}gs;
      next unless @paras;
      my $a = join ' ', map { unent(strip_tags($_)) } @paras;
      push @qa, [ unent(strip_tags($q)), $a ];
    }
    if (@qa) {
      my @el = map {
        sprintf('{"@type":"Question","name":"%s","acceptedAnswer":{"@type":"Answer","text":"%s"}}',
                jsonstr($_->[0]), jsonstr($_->[1]))
      } @qa;
      $add .= '<script type="application/ld+json">' . "\n"
            . '{"@context":"https://schema.org","@type":"FAQPage","mainEntity":[' . "\n  "
            . join(",\n  ", @el) . "\n]}\n" . '</script>' . "\n";
      $faq = scalar @qa;
    }
  }

  next unless length $add;
  $html =~ s{</head>}{$add</head>} or do { warn "  no </head> in $f\n"; next };
  open my $out, '>:encoding(UTF-8)', $f or die $!;
  print $out $html; close $out;
}

print "  BreadcrumbList on $bc pages\n";
print "  FAQPage with $faq questions\n";
