#!/usr/bin/perl
# Checks a crawl of the old site against the new one: every URL that currently
# returns 200 must land somewhere real after the switch, or its ranking is
# thrown away.
#
#   perl tools/migration-check.pl <crawl.tsv> <new-site-base-url>
#
# For each old URL it reports one of:
#   SAME      the new site serves the same path directly (best; no hop)
#   REDIRECT  a 301 in the redirect map points it at a live page
#   GONE      nothing handles it - this is what loses rankings
use strict;
use warnings;
use utf8;
binmode(STDOUT, ':encoding(UTF-8)');

my $tsv  = shift or die "usage: $0 <crawl.tsv> <new-base>\n";
my $base = shift or die "usage: $0 <crawl.tsv> <new-base>\n";
$base =~ s{/$}{};

open my $fh, '<:encoding(UTF-8)', $tsv or die "$tsv: $!";
my $hdr = <$fh>;
my (@rows);
while (my $l = <$fh>) {
  chomp $l;
  my @f = split /\t/, $l, -1;
  push @rows, { path => $f[0], status => $f[1], ctype => $f[2], redirect => $f[3],
                canon => $f[4], robots => $f[5], title => $f[6], desc => $f[7] };
}
close $fh;

my (@same, @redir, @gone, @skip);

for my $r (@rows) {
  next unless ($r->{status} // '') eq '200';
  # Only pages matter for rankings; feeds/JSON/XML are infrastructure.
  unless (($r->{ctype} // '') =~ m{text/html}) { push @skip, $r; next }
  # A page the old site itself marks noindex was never in the index.
  if (($r->{robots} // '') =~ /noindex/i) { push @skip, $r; next }

  my $p = $r->{path};
  my $code = `curl -s -o /dev/null -w "%{http_code}" --max-time 20 "$base$p" 2>/dev/null` // '';
  my $loc  = '';
  if ($code =~ /^3/) {
    $loc = `curl -s -o /dev/null -w "%{redirect_url}" --max-time 20 "$base$p" 2>/dev/null` // '';
    my $final = `curl -sL -o /dev/null -w "%{http_code}" --max-time 20 "$base$p" 2>/dev/null` // '';
    $r->{to} = $loc; $r->{final} = $final;
    if ($final eq '200') { push @redir, $r } else { push @gone, $r }
  }
  elsif ($code eq '200') { push @same, $r }
  else { $r->{final} = $code; push @gone, $r }
}

printf "Old URLs returning 200 (HTML): %d\n\n", scalar(@same) + scalar(@redir) + scalar(@gone);

printf "SAME PATH, no redirect needed (%d)\n", scalar @same;
printf "  %s\n", $_->{path} for sort { $a->{path} cmp $b->{path} } @same;

printf "\n301 REDIRECT to a live page (%d)\n", scalar @redir;
for my $r (sort { $a->{path} cmp $b->{path} } @redir) {
  (my $to = $r->{to}) =~ s{^\Q$base\E}{};
  printf "  %-30s -> %s\n", $r->{path}, $to;
}

printf "\n*** NOT HANDLED - would lose its ranking (%d)\n", scalar @gone;
for my $r (sort { $a->{path} cmp $b->{path} } @gone) {
  printf "  %-30s new site returns %s   [old title: %s]\n",
    $r->{path}, ($r->{final} // '?'), substr($r->{title} // '', 0, 60);
}

printf "\nNot page content, ignored for rankings (%d)\n", scalar @skip;
printf "  %-34s %s\n", $_->{path}, $_->{ctype} for sort { $a->{path} cmp $b->{path} } @skip;
