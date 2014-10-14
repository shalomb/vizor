#!/usr/bin/perl -l

use strict;
use warnings;

use autodie;
use Getopt::Long;
use Data::Dumper;

our $key   ;
our $val   ;
our @fields;

GetOptions( 
  "key=s"      => \$key,
  "val=s"      => \$val,
  "fields=s"   => \@fields,
);

push @fields, @ARGV;

local $/ = "\n\n";

while (<STDIN>) {
  my ($m, %h) = (0);

  for (split /\n+/) {
    my ($k, $v) = /\s*([^:]+)\s*:\s*(.*)$/;
    $h{$k} = $v;
    if ($key and $val) {
      if ( ($k =~ /\b$key\b/i) and ($v =~ /$val/i) ) {
        $m = 1;
        next;
      }
    }
    elsif ($val) {
      do { $m = 1; next } if $v =~ /$val/i;
    }
    $m = 1;
  }

  next unless $m;

  do {print; next;} unless $fields[0];

  for my $k (keys %h) {
    for (map quotemeta, map { split /\s*,\s*/ } @fields) {
      if ($k =~ /\b$_\b/i) {
        if (not $key and not $val) {
          printf "%12s : %s\n", $k, $h{$k} 
        }
        else {
          printf "%s\n", $h{$k} 
        }
      }
    }
  }

}

# "$key" "$val" "${fields[@]-}"

__END__


function select_kvf {
  local infile=
  local val=
  local key=
  local fields=()

  while getopts ":k:v:f:i:" opt; do
    case $opt in
      k) key="$OPTARG"
      ;;
      v) val="$OPTARG"
      ;;
      f) fields+=( "$OPTARG" )
      ;;
      i) infile="$OPTARG"
      ;;
      \?)
        echo "Invalid option: -$OPTARG" >&2
      ;;
    esac
  done 

  # (( ${#fields[@]-} == 0 )) && fields=('.')

  perl -le '
    BEGIN {
      use autodie;
      our $file   = "'"$infile"'"; 
      our $key    = shift;
      our $val    = shift;
      our @fields = @ARGV;
    }
    local $/ = "\n\n";
    open my $fh, "<", $file;
    while (<$fh>) {
      my ($m, %h) = (0);

      for (split /\n+/) {
        my ($k, $v) = /\s*([^:]+)\s*:\s*(.*)$/;
        $h{$k} = $v;
        if ($key and $val) {
          if ( ($k =~ /\b$key\b/i) and ($v =~ /$val/i) ) {
            $m = 1;
            next;
          }
        }
        elsif ($val) {
          $m = 1 and next if $v =~ /$val/i;
        }
        $m = 1;
      }

      next unless $m;

      do {print; next;} unless $fields[0];

      for my $k (keys %h) {
        for (map quotemeta, map { split /\s*,\s*/ } @fields) {
          print $h{$k} if $k =~ /\b$_\b/i;
        }
      }

    }
  ' "$key" "$val" "${fields[@]-}"
}


