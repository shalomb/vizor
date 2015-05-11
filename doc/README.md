# Vizor Documentation

vizor documentation is written in the 
[Pandoc flavour of markdown](http://pandoc.org/demo/example9/pandocs-markdown.html)
with the .md files being the source and all subsequent compiled documentation
derived from these.

To make edits and regenerate the documentation

    pandoc -c pandoc.css --toc section.md -o section.html

Refer to [Pandoc - About pandoc](http://pandoc.org/) for information on
usage and converting to other compiled formats.
