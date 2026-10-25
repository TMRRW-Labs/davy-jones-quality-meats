#!/usr/bin/perl
# Turns docs/website-copy.md into three review-friendly formats.
#
#   perl tools/copy-to-formats.pl
#
#   website-copy.txt    plain text
#   website-copy.html   styled for reading, and for Print > Save as PDF
#   website-copy.doc    opens in Word, so Kyle can comment and track changes
use strict;
use warnings;

my $src = 'docs/website-copy.md';
open my $in, '<:encoding(UTF-8)', $src or die "$src: $!";
local $/; my $md = <$in>; close $in;

# ------------------------------------------------------------------ plain text
my $txt = $md;
$txt =~ s/^#\s+(.*)$/uc($1) . "\n" . ('=' x length($1))/gme;
$txt =~ s/^##\s+(.*)$/"\n" . uc($1) . "\n" . ('-' x length($1))/gme;
$txt =~ s/^###\s+(.*)$/"\n  " . $1/gme;
$txt =~ s/^####\s+(.*)$/"\n  " . $1/gme;
$txt =~ s/\*\*(.*?)\*\*/$1/g;
$txt =~ s/_(.*?)_/$1/g;
$txt =~ s/`(.*?)`/$1/g;
$txt =~ s/^---$/("-" x 74)/gme;
$txt =~ s/[ \t]+$//gm;
open my $t, '>:encoding(UTF-8)', 'docs/website-copy.txt' or die $!;
print $t $txt; close $t;

# --------------------------------------------------------- shared HTML rendering
sub esc { my $s = shift; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; return $s }

sub inline {
  my $s = esc(shift);
  $s =~ s/\*\*(.*?)\*\*/<strong>$1<\/strong>/g;
  $s =~ s/`(.*?)`/<span class="mono">$1<\/span>/g;
  $s =~ s/(?<![A-Za-z0-9])_(.*?)_(?![A-Za-z0-9])/<em>$1<\/em>/g;
  return $s;
}

sub render_body {
  my @lines = split /\n/, shift;
  my (@out, $inlist);
  for my $line (@lines) {
    if ($line =~ /^---\s*$/)          { push @out, "</ul>" if $inlist; $inlist = 0; push @out, '<hr>'; next }
    if ($line =~ /^#\s+(.*)/)         { push @out, "</ul>" if $inlist; $inlist = 0; push @out, '<h1>' . inline($1) . '</h1>'; next }
    if ($line =~ /^##\s+(.*)/)        { push @out, "</ul>" if $inlist; $inlist = 0; push @out, '<h2>' . inline($1) . '</h2>'; next }
    if ($line =~ /^###\s+(.*)/)       { push @out, "</ul>" if $inlist; $inlist = 0; push @out, '<h3>' . inline($1) . '</h3>'; next }
    if ($line =~ /^####\s+(.*)/)      { push @out, "</ul>" if $inlist; $inlist = 0; push @out, '<h4>' . inline($1) . '</h4>'; next }
    if ($line =~ /^>\s?(.*)/)         { push @out, "</ul>" if $inlist; $inlist = 0; push @out, '<blockquote>' . inline($1) . '</blockquote>'; next }
    if ($line =~ /^(\s*)-\s+(.*)/)    {
      my ($indent, $text) = (length($1), $2);
      push @out, '<ul>' unless $inlist; $inlist = 1;
      push @out, '<li' . ($indent ? ' class="sub"' : '') . '>' . inline($text) . '</li>';
      next;
    }
    if ($line =~ /^\s*$/)             { push @out, "</ul>" if $inlist; $inlist = 0; next }
    push @out, "</ul>" if $inlist; $inlist = 0;
    push @out, '<p>' . inline($line) . '</p>';
  }
  push @out, '</ul>' if $inlist;
  return join("\n", @out);
}

my $body = render_body($md);

my $css = <<'CSS';
  body { font-family: Georgia, "Times New Roman", serif; color: #1a1a1a; line-height: 1.55;
         max-width: 46em; margin: 0 auto; padding: 3em 2em 6em; font-size: 11.5pt; }
  h1 { font-family: Arial, Helvetica, sans-serif; font-size: 24pt; letter-spacing: -.02em;
       margin: 0 0 .2em; }
  h2 { font-family: Arial, Helvetica, sans-serif; font-size: 15pt; letter-spacing: -.01em;
       margin: 2.4em 0 .5em; padding-bottom: .3em; border-bottom: 2px solid #D8232A;
       page-break-after: avoid; }
  h3 { font-family: Arial, Helvetica, sans-serif; font-size: 13pt; margin: 1.6em 0 .3em;
       page-break-after: avoid; }
  h4 { font-family: Arial, Helvetica, sans-serif; font-size: 11.5pt; margin: 1.4em 0 .3em;
       page-break-after: avoid; }
  p { margin: .5em 0; }
  ul { margin: .4em 0 .8em; padding-left: 1.4em; }
  li { margin: .18em 0; }
  li.sub { list-style: none; color: #555; margin-left: -.4em; }
  blockquote { margin: .6em 0 .6em 1.2em; padding-left: 1em; border-left: 3px solid #ccc;
               color: #333; font-style: italic; }
  strong { font-family: Arial, Helvetica, sans-serif; font-size: 9.5pt; font-weight: bold;
           text-transform: none; color: #6b6b6b; letter-spacing: .02em; }
  .mono { font-family: Consolas, "Courier New", monospace; font-size: 9.5pt; color: #444;
          background: #f4f2ef; padding: .05em .3em; }
  hr { border: 0; border-top: 1px solid #ddd; margin: 2.4em 0; }
  @media print { body { padding: 0; font-size: 10.5pt; } h2 { page-break-before: auto; } }
CSS

open my $h, '>:encoding(UTF-8)', 'docs/website-copy.html' or die $!;
print $h "<!DOCTYPE html>\n<html lang=\"en-CA\">\n<head>\n<meta charset=\"utf-8\">\n";
print $h "<title>Davy Jones Quality Meats, website copy</title>\n<style>\n$css</style>\n</head>\n<body>\n";
print $h $body;
print $h "\n</body>\n</html>\n";
close $h;

# Word opens HTML saved with a .doc extension, which gives Kyle a commentable file
# without needing any converter installed.
open my $d, '>:encoding(UTF-8)', 'docs/website-copy.doc' or die $!;
print $d "<html xmlns:o=\"urn:schemas-microsoft-com:office:office\"\n";
print $d "      xmlns:w=\"urn:schemas-microsoft-com:office:word\"\n";
print $d "      xmlns=\"http://www.w3.org/TR/REC-html40\">\n<head>\n<meta charset=\"utf-8\">\n";
print $d "<title>Davy Jones Quality Meats, website copy</title>\n";
print $d "<!--[if gte mso 9]><xml><w:WordDocument><w:View>Print</w:View>\n";
print $d "<w:Zoom>100</w:Zoom></w:WordDocument></xml><![endif]-->\n";
print $d "<style>\n\@page { size: 8.5in 11in; margin: 1in; }\n$css</style>\n</head>\n<body>\n";
print $d $body;
print $d "\n</body>\n</html>\n";
close $d;

for my $f (qw(docs/website-copy.md docs/website-copy.txt docs/website-copy.html docs/website-copy.doc)) {
  printf "  %-30s %6.1f KB\n", $f, (-s $f) / 1024;
}
