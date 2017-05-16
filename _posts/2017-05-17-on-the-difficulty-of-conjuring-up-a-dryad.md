---
title: "On The Difficulty Of Conjuring Up A Dryad"
layout: post
summary: In which deploys are made boring.
---

**(This article was originally posted on blog.skyliner.io on Nov 29, 2016.)**

![Apollo & Daphne / Veronese](/images/apollo-and-daphne.jpg "Apollo & Daphne / Vernoese")

When we started building Skyliner, our goal was to make deploys on AWS safe, reliable, and easy. To
accomplish this at scale, we made some key design and implementation decisions. In this post, I’ll
tell you what those decisions were, why they work, and how we built a system which is reliable
enough to even deploy itself.

---

### Use A Finite-State Machine

Our earliest major design decision was to model the Skyliner deploy process as a [Finite-State
Machine](https://en.wikipedia.org/wiki/Finite-state_machine) (FSM), with transitions from one state
to another associated with specific conditions and actions. For example, a deploy in the
`rollout-wait` state will check the newly-launched instances of the deploy. If the instances are up
and running, the deploy is advanced via `rollout-ok` to the `evaluate-wait` state. If the instances
have failed to launch, the deploy is advanced via `rollout-failed` to the rollback state. If the
instances are still launching, the deploy is kept in the `rollout-wait` state via
`rollout-in-progress`.

![A Skyliner deploy](/images/skyliner-deploy.png "A Skyliner deploy.")

Using an FSM allows us not just to exhaustively determine that all possible states of a deploy are
handled, but also to decompose our own code into small, comprehensively-tested, state-specific
functions. It also allows us to extract state management as first-class concern; unlike many deploy
tools which keep this state in memory, we store an append-only history of deploy states. As a
result, our code is reentrant: it can be interrupted at any time and safely resumed later. If one of
our servers crashes another one can seamlessly take its place with no disruption in service.

### Use A Reliable Coordinator

Unlike some deploy tools which require a single “master” server to coordinate deploys, Skyliner uses
Amazon’s Simple Queue Service (SQS)—a highly-available, scalable, reliable message queue service—as
a distributed clock to advance each deploy’s state.

SQS has a very robust model for dealing with failures: when a consumer polls the server for a new
message, it specifies a visibility timeout — a period during which that message will not be visible
to other workers. If the consumer successfully processes the message, it deletes it from the queue.
If the consumer crashes, the visibility timeout elapses and the message becomes visible to another
consumer. Similarly, when sending a message to a queue, one can specify a delay — a period of time
during which that message will not be visible to any consumer. We use the delay and the visibility
timeouts to create “ticks” for deploys.

When a deploy is started, we send an SQS message with the deploy ID, environment, etc. using a delay
of e.g. 10 seconds. After 10 seconds, it becomes visible to a Skyliner background thread, which
receives it using a visibility timeout of e.g. 10 seconds. The thread looks up the deploy’s current
state and takes any appropriate action to advance it. If the deploy has finished, the thread deletes
the message from the queue. Otherwise, the message is left in the queue to reappear after another 10
seconds has passed.

If the instance handling the deploy crashes, the deploy’s message becomes visible after another 10
seconds, and another instance will receive it and advance the deploy.

### Use Blue-Green Deploys

Skyliner uses [blue-green deploys](http://martinfowler.com/bliki/BlueGreenDeployment.html). Instead
of modifying servers in-place and hoping nothing goes wrong, we leverage EC2’s elasticity and launch
an entirely new set of instances running the new version of your software. If the new version passes
healthchecks, we roll forward by terminating the old instances. If the new version doesn’t come up
cleanly, we roll back by terminating the new instances.

As a result, deploys on Skyliner are:

1. **Reliable.** Both rolling forward and backward requires only the termination of EC2 instances—no
   coordinating system package upgrades and downgrades, no modifying local Git checkouts or switching
   symlinks.
   
2. **Safe.** At no point in time is your application’s capacity reduced, so there’s no need to wait
   until a scheduled maintenance period to deploy.

3. **Fast.** Compared to other safe deploy strategies, Skyliner doesn’t have to reduce the rollout
    rate in order to maintain capacity. In a traditional data center, the set of servers an 
    application can run on is typically fixed, and in order to maintain a minimum capacity, deploys 
    are usually done in a “rolling” fashion, either making changes one server at a time or in small 
    batches. Consequently, rolling deploys take `\(O(\frac{N}{M})\)` time for `\(N\)` total servers 
    and batches of size `\(M\)`. Blue-green deploys, on the other hand, can perform all their 
    operations in parallel, and take `\(Ω(1)\)` time—only as long as the worst-case time of any 
    single instance. 
    
### Skyliner On Skyliner

The end result of these decisions is that several times a day, we can use Skyliner to deploy a new
version of itself. When a build is finished, we use the old version to start the deploy, which
launches EC2 instances with the new version of Skyliner. For a brief moment, both are running
simultaneously until a background thread rolls the deploy forward and begins the termination of the
EC2 instances running the old version. As those shut down, the instances running the new version
oversee the cleanup of the deploy which brought them into existence.
