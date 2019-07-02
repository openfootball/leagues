# Major League Soccer (MLS) / United States n Canada


## What's `soccer.db`?

A free open public domain soccer (football) database & schema
for use in any (programming) language
(e.g. uses plain text fixtures/data sets).
More [`football.db` Project Site »](http://openfootball.github.io)


## Intro

Free open public domain soccer data for major league soccer (MLS)
for the United States n Canada.


Example:

```
Key,      Name,                Code
galaxy,   Los Angeles Galaxy,  LA
seattle,  Seattle Sounders,    SEA
houston,  Houston Dynamo,      HOU
saltlake, Real Salt Lake,      RSL
...
```

or

```
Week 1

[Sat Mar 8]
Seattle Sounders FC    1-0   Sporting Kansas City

[Sun Mar 9]
D.C. United            0-3   Columbus Crew
Vancouver Whitecaps    4-1   New York Red Bulls
FC Dallas              3-2   Montreal Impact
Houston Dynamo         4-0   New England Revolution
Portland Timbers       1-1   Philadelphia Union
Los Angeles Galaxy     0-1   Real Salt Lake City
CD Chivas USA          3-2   Chicago Fire
```


## Build Your Own `soccer.db` Copy

Use the `sportdb` command line tool to build your own `soccer.db` copy
from the plain text fixtures. [More »](http://openfootball.github.io/build.html)

Prerequisites:

* [world.db](https://github.com/openmundi/world.db.git)

```
git clone https://github.com/openmundi/world.db.git
```

* [sportdb](https://github.com/sportdb/sport.db.ruby)

```
gem install sportdb
```

Example:

To create a database from scratch, use the following command, substituting the appropriate paths to major-league-soccer and world.db as necessary.

```
sportdb -n mls.db setup --include major-league-soccer --worldinclude world.db
```

Once you have an initialized database, you can load data on top of it as follows.

```
sportdb -n mls.db load major-league-soccer/2014/mls
```

See the sportdb help and git page for more information.


## License

![](https://publicdomainworks.github.io/buttons/zero88x31.png)

The football.db schema, data and scripts are dedicated to the public domain. Use it as you please with no restrictions whatsoever.

## Questions? Comments?

Send them along to the
[Open Sports & Friends Forum/Mailing List](http://groups.google.com/group/opensport).
Thanks!
