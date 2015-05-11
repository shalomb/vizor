# Debugging vizor scripts

> This section is a work-in-progress.

Most vizor scripts make use of the CLI components to interface with the REST APIs
of razor, apache, couchdb, etc and use bash as the interpreter to tie interactions
together.

As it may be necessary to debug scripts on failure or unexpected behaviour,
the following tips are provided to better expose the tracing in a script and
so faciliate debugging.

# Debugging bash script

## Enabling extended tracing.

Often it is useful to have a bash script emit extra information about
commands being executed, the state of variables, the sections of a script
where errors are emitted, etc as the script is being evaluated by the interpreter.

Some vizor scripts honour the DEBUG environment variable, so setting this before
running a vizor command may generate additional verbose/tracing output

    DEBUG=1 vizor box build ...

It may be necessary to have tracing explicitly enabled for the scripts execution,
this is done by placing the following commands before appropriate sections of a
script (or at the top of the script as a catch-all).

    set -x      # Enable xtrace (extended tracing)
    set -v      # Enable verbose output

## Stepping through a bash script

It may be necessary to step through a bash script and have it pause while
other parts of the system/infrastructure can be examined.

As per [How to execute a bash script line by line?](http://stackoverflow.com/a/9080645/742600),
place the following before an appropriate section in the script (or at the very
top as a catch-all).

    set -xv          # enable xtrace and verbose output
    trap read debug

This casues bash to evaluate every line, emitting extended output about evaluations
and then pausing exeuction until the ``return`` key is pressed.

## Additional extended debugging tips

* [BashGuide/Practices#Debugging - Greg's Wiki](http://mywiki.wooledge.org/BashGuide/Practices#Debugging)
* [Debugging Bash Tips - Bash Hackers Wiki](http://wiki.bash-hackers.org/scripting/debuggingtips)
* [Debugging Bash scripts - TLDP Bash Beginners Guide](http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_02_03.html)

# Debugging razor-server

vizor's razor-server interaction is done through the razor-client which uses
HTTP as a transport.

    razor -d nodes   # as an example of debugging HTTP interactions

Alternatively, curl can be used to work with razor-server at its API end-point,
and the returned JSON can be passed to ``jq(1)`` to prettify/validate the output.

    curl -v -XGET 'http://localhost:8080/api/collections/nodes/node14' | jq -S '.'

vizor's implementation of razor-server stores its logs under 
``/var/log/torquebox/razor-server.log`` and so this can be tailed.

    tail -f /var/log/torquebox/razor-server.log

## References

* [razor-server/api.md at master · puppetlabs/razor-server](https://github.com/puppetlabs/razor-server/blob/master/doc/api.md)
* [puppetlabs/razor-server Wiki](https://github.com/puppetlabs/razor-server/wiki)
* [Installing windows · puppetlabs/razor-server Wiki](https://github.com/puppetlabs/razor-server/wiki/Installing-windows)

# Debugging couchdb

vizor's CouchDB interaction is done through curl and HTTP as a transport.
Data is stored in CouchDB documents under named indexes at known HTTP URLs
and so curl can be used to interrogate CouchDB and jq used to validate/prettify
the returned JSON for readable output.

e.g.

    curl -vfsSL -X GET 'http://vizor.example.com:5984/box/document' | jq -S '.'

CouchDB's logs are stored in ``/var/log/couchdb/*.log`` and so these can be tailed.

    tail -f /var/log/couchdb/*.log

## References
* [1.8. curl: Your Command Line Friend — Apache CouchDB 2.0.0 Documentation](http://docs.couchdb.org/en/latest/intro/curl.html)
* [jwood/couchdb_demo](https://github.com/jwood/couchdb_demo)
  

# Debugging elasticsearch

vizor's elasticsearch interaction is done through curl using HTTP as a transport.
Querying elasticsearch is done by formulating a query in the GET query-string and then
requesting elasticsearch end-point.

elasticsearch's logs are storef in ``/var/log/elasticsearch/*.log`` and so these can
be tailed.

    tail -f /var/log/elasticsearch/*.log

## References
* [elasticsearch Search API](http://www.elastic.co/guide/en/elasticsearch/reference/1.x/search-search.html)
* [Query String Query](http://www.elastic.co/guide/en/elasticsearch/reference/1.x/query-dsl-query-string-query.html)
* [Exploring Elasticsearch](http://exploringelasticsearch.com/searching_data.html)

