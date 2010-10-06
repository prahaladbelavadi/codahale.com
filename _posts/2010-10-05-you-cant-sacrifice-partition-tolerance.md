---
title: You Can't Sacrifice Partition Tolerance
layout: post
---

I've seen a number of distributed databases recently
[describe](http://danweinreb.org/blog/voltdb-versus-nosql) themselves as
[being "CA"](http://en.wikipedia.org/wiki/Membase)--that is, providing both
consistency and availability while not providing partition-tolerance. To me,
this indicates that the developers of these systems do not understand the
implications of the CAP theorem.


A Quick Refresher
-----------------

In 2000, Dr. Eric Brewer gave a keynote at the *Proceedings of the Annual ACM
Symposium on Principles of Distributed Computing*[<sup>1</sup>](#ft1) in which
he laid out his famous CAP Theorem: *a shared-data system can have at most two
of the three following properties: **C**onsistency, **A**vailability, and
tolerance to network **P**artitions.* In 2002, Gilbert and
Lynch[<sup>2</sup>](#ft2) converted "Brewer's conjecture" into a formal
definition with a formal proof. As far as I can tell, it's been misunderstood
ever since.

So let's be clear on the terms we're using.


On Consistency
--------------

From Gilbert and Lynch[<sup>2</sup>](#ft2):

> Atomic, or linearizable, consistency is the condition expected by most web
> services today. Under this consistency guarantee, there must exist a total 
> order on all operations such that each operation looks as if it were completed
> at a single instant. This is equivalent to requiring requests of the
> distributed shared memory to act as if they were executing on a single node,
> responding to operations one at a time.

Most people seem to understand this.


On Availability
---------------

Again from Gilbert and Lynch[<sup>2</sup>](#ft2):

> For a distributed system to be continuously available, every request received
> by a non-failing node in the system must result in a response. That is, any
> algorithm used by the service must eventually terminate. … [When] qualified by
> the need for partition tolerance, this can be seen as a strong definition of
> availability: even when severe network failures occur, every request must
> terminate.

It should be noted that a `500 Everything's On Fire` response does not count as
an actual response any more than a network timeout does. A response contains the
results of the requested work.


On Partition Tolerance
----------------------

Once more, Gilbert and Lynch[<sup>2</sup>](#ft2):

> In order to model partition tolerance, the network will be allowed to lose
> arbitrarily many messages sent from one node to another. When a network is
> partitioned, all messages send from nodes in one component of the partition to
> nodes in another component are lost. (And any pattern of message loss can be
> modeled as a temporary partition separating the communicating nodes at the
> exact instant the message is lost.)

This seems to be the part that most people gloss over.

Some systems, it's true, cannot partition. Single-node systems (e.g., one of
those huge Oracle boxes with no replication enabled) are incapable of
experiencing a network partition. It should be noted, however, that the
single-node system combined with one or more clients is now a distributed system
and can experience a network partition (e.g., your single database server dies).
It should also be noted that a failed node can be modeled as a network
partition: the down node is its own, lonely partition and all messages to it are
"lost" (i.e., they are not processed by the node due to its failure).

For a distributed (i.e., multi-node) system to not *require* partition-tolerance
it would have to run on a network which is *guaranteed* to *never* drop messages
and whose nodes are *guaranteed* to *never* die. Oh, plus the network would need
to be *guaranteed* to *never* deliver messages "late" and the nodes would have
to be *guaranteed* to *never* be slow in responding, since then it'd be
impossible to build a perfect failure detector[<sup>3</sup>](#ft3). You and I do
not work with these types of systems because *they don't exist.*


Given A System In Which Failure Is An Option
--------------------------------------------

[Michael Stonebraker's assertions](http://voltdb.com/voltdb-webinar-sql-urban-myths)
aside, partitions (read: failures) do happen, and the chances that any one of
your nodes will fail jumps exponentially as the number of nodes increases:

*P(any failure) = 1 - P(individual node not failing)<sup>number of nodes</sup>*

In a distributed system of any reasonable size, it is impossible to escape the
requirement of failure recovery.

Therefore, the question you should be asking yourself is:

> **In the event of failures, what do I sacrifice? Consistency? Or Availability?**


Choosing Consistency Over Availability
--------------------------------------

If a system chooses to provide Consistency over Availability in the presence of
partitions (again, read: failures), it will preserve the guarantees of its
atomic reads and writes by refusing to respond to some requests. It may decide
to shut down entirely (like the clients of a single-node data store), refuse
writes (like Two-Phase Commit), or only respond to reads and writes for pieces
of data whose "master" node is inside the partition component (like Membase).

*This is perfectly reasonable.* There are plenty of things (atomic counters, for
one) which are made much easier by strongly consistent systems. They are a
perfectly valid type of tool for satisfying a particular set of business
requirements.


Choosing Availability Over Consistency
--------------------------------------

If the system chooses to provide Availability over Consistency in the presence
of partitions (all together now: failures), it will respond to all requests,
potentially returning stale data on reads and potentially accepting conflicting
writes. These inconsistencies are often resolved via causal ordering mechanisms
like vector clocks and by application-specific conflict resolution procedures.
(Dynamo systems usually offer both of these; Cassandra's timestamped
Last-Writer-Wins conflict resolution being the main exception.)

Again, *this is perfectly reasonable.* There are plenty of data models which are
amenable to conflict resolution and for which stale reads are acceptable
(ironically, many of these data models are in the financial industry) and for
which unavailability results in massive bottom-line losses. (Amazon's shopping
cart system is the canonical example of a Dynamo model[<sup>4</sup>](#ft4)).


But Never Both
--------------

**You cannot, however, choose both consistency and availability in a distributed
system.**

To claim to do so is claiming either that the system operates on a single node
(and is therefore not distributed) or that an update applied to a node in one
component of a network partition will also be applied to another node in a
different partition component *without using the network* (and is therefore
magical).


A Readjustment In Focus
----------------------------------

I think part of the problem with practical interpretations of the CAP theorem is
the rather nuanced read on partition tolerance. It's useful from the perspective
of Gilbert and Lynch's proof, but in terms of building reliable systems it's far
more helpful to stop focusing on *whether* things will go bad and instead focus
on *what the system gives up* when things go bad. Because they will
[go bad](blog.foursquare.com/2010/10/05/so-that-was-a-bummer/).

So instead of CAP, I think we should focus on an earlier bit of Brewer wisdom:
**yield** and **harvest**, which come from Fox and Brewer's "Harvest, Yield, and
Scalable Tolerant Systems"[<sup>5</sup>](#ft5).

> We assume that clients make queries to servers, in which case there are at
> least two metrics for correct behavior: yield, which is the probability of
> completing a request, and harvest, which measures the fraction of the data
> reflected in the response, i.e. the completeness of the answer to the query.

In a later article[<sup>6</sup>](#ft6), Brewer expands on **yield** and its
uses:

> Numerically, this is typically very close to uptime, but it is more useful in
> practice because it directly maps to user experience and because it correctly
> reflects that not all seconds have equal value. Being down for a second when
> there are no queries has no impact on users or yield, but reduces uptime.
> Similarly, being down for one second at peak and off-peak times generates the
> same uptime, but vastly different yields because there might be an
> order-of-magnitude difference in load between the peak second and the
> minimum-load second. Thus we focus on yield rather than uptime.

**Harvest** is a far more overlooked metric, especially in the age of the
relational database. If we imagine working on a search engine, however, we can
imagine there being separate indexes for each word. The index of web pages which
use the word "cute" is on node A, the index of web pages which use the word
"baby" is on node B, and the index for the word "animals" is on machine C. A
search, then, for "cute baby animals" which combined results from nodes A, B,
and C would have a 100% harvest. If node B was unavailable, however, we might
return a result for just "cute animals," which would be a harvest of 66%. In
other words:

*harvest = data available/complete data*

As Brewer puts it[<sup>6</sup>](#ft6):

> The key insight is that we can influence whether faults impact yield, harvest,
> or both. Replicated systems tend to map faults to reduced capacity (and to
> yield at high utilizations), while partitioned systems tend to map faults to
> reduced harvest, as parts of the database temporarily disappear, but the
> capacity in queries per second remains the same.


A Better Heuristic
------------------

In terms of general advice to people building distributed systems (and really,
who isn't these days?), I think the following is far more effective:

> **In the presence of faults, at some point you will need to either reduce
> yield (i.e., stop answering requests) or reduce harvest (i.e., give incomplete
> answers). Which strategy you choose should be about your business
> requirements.**

Of course, any decent system should also be fault-tolerant. Both strongly
consistent models like Paxos and highly available models like Dynamo can
withstand the loss of a small number of nodes before having to choose between
yield and harvest.


Well Now What
-------------

It's incredibly unlikely this will change the way people will build distributed
systems—far more of our motivation comes from business concerns ("our shopping
carts *cannot* go down" or "there would be no way for us to reconcile this
later"). What I'd like to see, though, is far fewer people unknowingly
describing their systems as logical impossibilities.


tl;dr
-----

Of the CAP theorem's Consistency, Availability, and Partition Tolerance, 
Partition Tolerance is mandatory. You cannot **not** choose it. It is suggested
that you think about your availability in terms of *yield* (percent of requests
answered successfully) and *harvest* (percent of required data actually
included in the responses). Given sufficient failures, your system will have to
sacrifice one of these two things.


References (i.e., Things You Should Read)
-----------------------------------------


1. Brewer. [Towards robust distributed systems.](http://www.cs.berkeley.edu/~brewer/cs262b-2004/PODC-keynote.pdf)
   Proceedings of the Annual ACM Symposium on Principles of Distributed
   Computing (2000) vol. 19 pp. 7-10 <a id="ft1" />

2. Gilbert and Lynch. [Brewer's conjecture and the feasibility of consistent, available, partition-tolerant web services.](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.67.6951&rep=rep1&type=pdf)
   ACM SIGACT News (2002) vol. 33 (2) pp. 59 <a id="ft2" />

3. Fischer et al. [Impossibility of distributed consensus with one faulty process.](http://groups.csail.mit.edu/tds/papers/Lynch/pods83-flp.pdf)
   Journal of the ACM (1985) vol. 32 (2) <a id="ft3" />

4. DeCandia et al. [Dynamo: Amazon's highly available key-value store.](http://s3.amazonaws.com/AllThingsDistributed/sosp/amazon-dynamo-sosp2007.pdf)
   SOSP '07: Proceedings of twenty-first ACM SIGOPS symposium on Operating
   systems principles (2007) <a id="ft4" />

5. Fox and Brewer. [Harvest, yield, and scalable tolerant systems.](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.24.3690&rep=rep1&type=pdf)
   Hot Topics in Operating Systems, 1999. Proceedings of the Seventh Workshop on
   (1999) pp. 174 - 178 <a id="ft5" />

6. Brewer. [Lessons from giant-scale services.](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.83.4274&rep=rep1&type=pdf)
   Internet Computing, IEEE (2001) vol. 5 (4) pp. 46 - 55 <a id="ft6" />

(As a sad postscript: all of the theoretical papers I've referenced are about a
decade old and freely available. The cutting edge of blogs is arguing about
topics which bore the tits off the actual researchers involved.)