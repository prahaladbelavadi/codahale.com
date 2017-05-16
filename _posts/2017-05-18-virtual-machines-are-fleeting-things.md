---
title: "Virtual Machines Are Fleeting Things"
layout: post
summary: In which the pain of attachment is avoided.
---

**(This article was originally posted on blog.skyliner.io on Feb 23, 2017.)**

![Fine weather, isn't it?](/images/mono-no-aware.jpg "Fine weather, isn't it?")

Last month, AWS sent us an email regretfully informing us that the hardware running one of our
instances had begun to fail. They gave us two weeks to move our data, if we could, to a new
instance. I smiled, hit the archive button, and confidently went about the rest of my day. We’d long
since terminated that instance, and our software had already moved on. At other companies, an
instance retirement email means a day’s work for someone. My happy indifference to the loss of
instance `i-0b3baeac82b2b8461` was a direct result of a key design decision we made when building
Skyliner: Skyliner performs everything — builds and deploys — by launching new, impermanent EC2
instances. The result is a dramatically simpler system, and thus a more reliable and operable
system.

At the lowest level, deploying with fresh, purpose-specific instances means there is zero risk of
accidental state from the last deploy: no conflicting system packages, no mangled symlinks, no
zombie processes, no old configuration files. This radically reduces the path dependence of builds
and deploys, which in turn increases their reliability and operability. When a deploy fails, you
don’t need to consider the entire history of a server—you can be confident that the failure is
scoped to that deploy’s (hopefully small) diff.

The cumulative effect of this elimination of accidental state is a radically reduced divergence from
an ideal state over time. If an engineer manually logs into one of the servers to debug something,
whatever changes they may make—installing a package, modifying a configuration file, taking a heap
dump—automatically disappear after the next deploy, instead of when said engineer diligently
remembers to roll back all of the changes they made when trying to diagnose an outage at 3am. If a
developer forgets to delete their temporary files or debug logging is accidentally enabled for
everything, those files vanish after the next deploy. Like
[apoptosis](https://en.wikipedia.org/wiki/Apoptosis), continuously destroying and creating instances
makes it nearly impossible to accumulate error.

Instance impermanence is also a helpful invariant for steering applications themselves towards more
reliable architectures. The ability to depend on local storage as long-term persistence is a kind of
[false affordance](https://en.wikipedia.org/wiki/Affordance): it implicitly makes the promise to
application developers that `/tmp` is not, despite the name, actually temporary. A classic example
of this are web applications which store session data as temporary files (_e.g. Rails circa 2006_).
When working on and deploying to permanent servers, it’s easy for a developer (_e.g. me circa early
2006_) to build software on top of that false affordance of permanence (_e.g. authentication circa
early 2006_) with significant reliability and operability problems (_e.g. inode exhaustion from old
session files, logging out all users from cleaning up what I thought were old session files, kernel
locks and corrupted data from trying to store the sessions on an NFS server circa mid-2006_) which
would not have happened with an alternate architecture (_e.g. storing sessions in memcached circa
late 2006_). (It was a different time.)

Unsurprisingly, this invariant is also helpful in guiding infrastructure applications like Skyliner
towards simpler, more reliable architectures. In particular, it collapses provisioning, deployment,
and configuration management into a single, highly reliable pathway. Need more capacity? Launch new
instances. Want to deploy your changes? Launch new instances. Want to change the configuration?
Launch new instances. In systems with separate provisioning, deployment, and configuration
management processes, it’s common for the less frequently used processes to be slow, complex, and
unreliable: deploys are pleasant, installing a new package for an application takes half a day
wrestling with Puppet, and provisioning additional capacity is a full-on devops adaptation of
Voltaire’s _Candide_. By combining those pathways, we ensure that an improvement for one is an
improvement for all, and its constant operation gives us confidence in our ability to perform more
infrequent tasks like provisioning and configuration.

Finally, a focus on new instances means being able to take advantage of key AWS technologies like
autoscaling groups. Every Skyliner application is deployed in an autoscaling group, which makes
recovering from instance crashes or retirement automatic. Skyliner is itself a Skyliner application,
so when I read that email about poor instance `i-0b3baeac82b2b8461`, I could simply smile and get
back to work.