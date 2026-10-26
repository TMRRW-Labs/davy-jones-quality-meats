#!/usr/bin/perl
# Exhaustive crawl of the live WordPress site, so the migration can be checked
# against what actually exists rather than against what the sitemap advertises.
#
#   perl tools/crawl-old-site.pl <out-dir> [max-pages]
#
# Breadth-first over same-origin links, following redirects and recording the
# chain. Also probes the WordPress surfaces that never appear in a Yoast
# sitemap but can still be indexed: feeds, categories, tags, author archives,
# attachment pages, pagination, the REST API and the search endpoint.
use strict;
use warnings;
use utf8;
binmode(STDOUT, ':encoding(UTF-8)');

my $out = shift or die "usage: $0 <out-dir> [max-pages]\n";
my $max = shift // 400;
my $host = 'davyjonesqualitymeats.ca';
my $base = "https://$host";

mkdir $out unless -d $out;
mkdir "$out/pages" unless -d "$out/pages";

my (%seen, %status, %redirect, %title, %desc, %robots, %canon, %from, %ctype);
my @queue = ('/');
$seen{'/'} = 1;

# WordPress surfaces a Yoast sitemap will not list.
my @probes = qw(
  /feed/ /comments/feed/ /wp-sitemap.xml /sitemap.xml /sitemap_index.xml
  /page-sitemap.xml /post-sitemap.xml /category-sitemap.xml /product-sitemap.xml
  /author-sitemap.xml /wp-json/wp/v2/pages?per_page=100 /wp-json/wp/v2/posts?per_page=100
  /wp-json/wp/v2/media?per_page=100 /wp-json/
  /?s=beef /blog/ /news/ /category/uncategorized/ /tag/beef/ /author/admin/
  /shop/ /cart/ /checkout/ /my-account/ /wp-login.php /xmlrpc.php
  /page/2/ /recipes/ /specials/ /catering/ /gift-cards/ /careers/ /jobs/
  /privacy-policy/ /terms/ /terms-of-use/ /accessibility/ /faq/ /faqs/
  /locations/ /hours/ /about/ /about-us/ /our-story/ /loyalty/ /rewards/
  /weekly-specials/ /flyer/ /delivery/ /order/ /order-online/
);
for my $p (@probes) { next if $seen{$p}++; push @queue, $p }

sub fetch {
  my $path = shift;
  my $url  = $path =~ m{^https?://} ? $path : "$base$path";
  # -L follows redirects; write_out gives the final url and the whole chain.
  my $meta = `curl -sS -L --max-time 25 -A "Mozilla/5.0 (compatible; site-migration-audit)" -o "$out/.body" -w "%{http_code}|%{url_effective}|%{content_type}|%{num_redirects}" "$url" 2>/dev/null`;
  return (0, '', '', 0, '') unless defined $meta && length $meta;
  my ($code, $eff, $ct, $nred) = split /\|/, $meta, 4;
  my $body = '';
  if (open my $fh, '<:raw', "$out/.body") { local $/; $body = <$fh>; close $fh }
  return ($code // 0, $eff // '', $ct // '', $nred // 0, $body);
}

my $n = 0;
while (@queue && $n < $max) {
  my $path = shift @queue;
  $n++;
  my ($code, $eff, $ct, $nred, $body) = fetch($path);
  $status{$path}   = $code;
  $ctype{$path}    = $ct;
  $redirect{$path} = $eff if $nred && $nred > 0;

  next unless $code == 200;
  next unless $ct =~ m{text/html|xml|json};

  # Keep a copy for later inspection.
  (my $safe = $path) =~ s{[^A-Za-z0-9._-]}{_}g;
  $safe = 'root' if $safe eq '_';
  if (open my $o, '>:raw', "$out/pages/$safe") { print $o $body; close $o }

  if ($ct =~ m{text/html}) {
    $title{$path}  = $1 if $body =~ m{<title[^>]*>(.*?)</title>}si;
    $desc{$path}   = $1 if $body =~ m{<meta[^>]+name=["']description["'][^>]+content=["'](.*?)["']}si;
    $robots{$path} = $1 if $body =~ m{<meta[^>]+name=["']robots["'][^>]+content=["'](.*?)["']}si;
    $canon{$path}  = $1 if $body =~ m{<link[^>]+rel=["']canonical["'][^>]+href=["'](.*?)["']}si;
  }

  # Harvest links from HTML and <loc> from XML sitemaps alike.
  my @hrefs = ($body =~ /href=["']([^"']+)["']/gi);
  push @hrefs, ($body =~ m{<loc>([^<]+)</loc>}gi);
  for my $h (@hrefs) {
    next if $h =~ m{^(mailto:|tel:|javascript:|\#|data:)};
    $h =~ s/&amp;/&/g;
    my $p;
    if    ($h =~ m{^https?://\Q$host\E(/.*)?$}) { $p = $1 // '/' }
    elsif ($h =~ m{^https?://})                 { next }
    elsif ($h =~ m{^//})                        { next }
    elsif ($h =~ m{^/})                         { $p = $h }
    else                                        { next }
    $p =~ s/#.*//;
    next unless length $p;
    # Skip asset files; they are catalogued separately from the page copies.
    next if $p =~ m{\.(css|js|png|jpe?g|gif|svg|webp|woff2?|ttf|eot|ico|mp4|webm)(\?|$)}i;
    next if $seen{$p}++;
    $from{$p} //= $path;
    push @queue, $p;
  }
}

unlink "$out/.body";

open my $r, '>:encoding(UTF-8)', "$out/crawl.tsv" or die $!;
print $r join("\t", qw(path status content_type redirected_to canonical robots title description found_on)), "\n";
for my $p (sort keys %seen) {
  print $r join("\t",
    $p,
    $status{$p}   // '-',
    ($ctype{$p}   // '-') =~ s/;.*//r,
    $redirect{$p} // '',
    $canon{$p}    // '',
    $robots{$p}   // '',
    ($title{$p}   // '') =~ s/\s+/ /gr,
    ($desc{$p}    // '') =~ s/\s+/ /gr,
    $from{$p}     // '',
  ), "\n";
}
close $r;

my $ok = grep { ($status{$_} // 0) == 200 } keys %seen;
printf "crawled %d urls, %d returned 200, report: %s/crawl.tsv\n", scalar(keys %seen), $ok, $out;
