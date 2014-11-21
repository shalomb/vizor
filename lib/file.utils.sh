#!/bin/bash

function pstat {
  local file="$1"
  perl -le '
    use strict; 
    use warnings;
    use Time::Piece;
    use POSIX;

    my $f=pop; 
    my %f; @f{qw[dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks]} = stat $f;
    for (keys %f) { 
      if ($_ =~ /time/ and defined $f{$_}) {
        $f{$_} = strftime "%FT%TZ", gmtime $f{$_}
      }
      printf "%8s : %s\n", $_, $f{$_}
    } ' "$file"
}

