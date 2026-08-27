# PeaversSplitsData

Benchmark **keystone boss splits**, as a data library other addons read. Ships
no UI; [PeaversSplits](https://github.com/peavers-warcraft/PeaversSplits) is the
consumer.

A **split** is the time from the start of a Mythic+ run to a boss dying - the
number a group is judged by while the key is being run, rather than the single
deadline at the end that arrives too late to act on.

For every dungeon in the current season, at every exact keystone level with
enough runs behind it, this holds the pool's median split per boss along with
its interquartile range and the sample size.

See the [README](https://github.com/peavers-warcraft/PeaversSplitsData#readme)
for the API and for the two rules the shape enforces - exact keystone levels,
and one season only.
