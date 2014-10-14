#!/bin/bash

function patch_yaml {
  local file="$1";  shift;
  local key="$1";   shift;

  cp -a "$file" "$file.$$.$(date +%s)"

  perl -le '
    use strict;
    use warnings;
    use autodie;
    use YAML qw[Load DumpFile];

    print join "|", 
    my ($file, $key, @values) = (@ARGV);

    my $yaml = do { 
      local $/ = undef;
      open my $fh, "<", $file; 
      my $yaml = Load(<$fh>); 
    };
    my $ptr = \$yaml;
    for my $iter (split m{/}, $key) { 
      $ptr = \$$ptr->{$iter}; 
    }
    $$ptr = [ @values ];
    eval { DumpFile($file, $yaml) };
    die "$@" if $@;
  ' "$file" "$key" "$@"

}

export -f patch_yaml
