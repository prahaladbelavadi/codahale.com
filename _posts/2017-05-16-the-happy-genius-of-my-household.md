---
title: "The Happy Genius Of My Household"
layout: post
summary: In which clouds are considered.
---

**(This article was originally posted on blog.skyliner.io on Aug 29, 2016.)**

When viewed from one angle, we’re in the middle of an infrastructure software renaissance: a
cornucopia of distributed databases, self-healing meshes, and software-defined anythings, all
radiating with potential to help you get your own applications up and running. From a different
angle however, the average software developer resembles a modern Tantalus, ever-grasping at an
ever-retreating image of operability and reliability.

When we started work on Skyliner, we knew that in building a product that helps people quickly get
their applications up and running in the cloud we would have to make a number of hard architectural
decisions not just for ourselves but also for our customers. One of the biggest of these—and one I
remain very confident about—was the decision to avoid container platforms like Swarm and Kubernetes
entirely. We believe that by focusing on a single cloud provider—in our case, AWS—and tapping into
the economies of scale which make cloud computing so attractive, we can deliver a better application
platform for our customers. Here’s why.

### Pick a cloud. Any cloud.

To start, a bit of devops apostasy: the idea of multi-cloud architectures is, for the vast majority
of companies, a complete and total boondoggle.

The idea of jumping from Amazon to Microsoft to Google all nimbly-pimbly is an attractive one, and
for some very constrained workloads the financial upside of pricing arbitrage might even be worth
it. For the other 99% of the market, however, the reality of the situation is that a truly
multi-cloud architecture must either limit itself to the lowest common denominator of the supported
providers’ functionality or else foist on its users the responsibility for resolving the
inconsistencies in feature sets and behaviors (probably at 4am during an outage).

Historically, most companies have settled on a single provider, but with the rising hype about
containers some companies have decided to invest in systems which limit their requirements to the
multi-cloud lowest common denominator but provide a platform on top of that which is so universal
that the affordances and amenities that customers require could be built on top of it. In essence:
_what if the cloud was built on top of us_?

The potential upside of these container platforms is well-marketed but the costs are far less widely
acknowledged.

### You only get one hill to die on, so choose wisely.

A viable production install of a container platform usually looks something like this. First, you
set up a clustered configuration service (e.g. Consul, Etcd, ZooKeeper). Second, you set up a
clustered scheduler service (e.g. Kubernetes, Swarm, etc.). Third, you set up a set of workers which
actually run your software. At every step of the process, you alone are responsible for all
operational tasks associated with keeping these systems running 24/7.

Once you manage to set all that up, you’ll only have a blank slate upon which you can begin the work
of building your own application platform. Log aggregation? Metrics collection? Databases? Backups?
Storage? Alerting? Load balancing? Key management? Service discovery? Authentication? You’ll need to
find solutions for all of these problems, set them up, integrate them, and then keep them running
for the rest of your business’s natural life. (Not that you need it all for the business, but once
you get locked into a serious container platform, the tendency is to push it as far as you can.)

Even if you cobble together a suitable application platform, you’ll still be on the wrong side of
the economic dynamics which make cloud computing so appealing. To wit: there is a large team of
people at Amazon whose job it is to keep the load balancers working 24/7, and because they operate
at a vast scale, they can offer this service for $16 a month per load balancer. That’s about 12
minutes per month of a software developer’s time. It’s unlikely that a jerry-built ball of Nginx and
HAProxy can beat that value proposition.

Unless you’re in the business of building platforms, it’s wise to consider the set of
responsibilities you already have—the features you need to ship, the bugs you need to fix, the
markets you need to address, the customers you need to help—and ask yourself if just participating
in your cloud provider’s economies of scale wouldn’t make more sense.

At Skyliner, we came to the conclusion that the point of running our software in the cloud was to
make life easier—not more exciting—and we think we’ve hit a fine balance in how to accomplish this.

### Use containers. Not too much. Mostly for packaging.

Skyliner uses containers purely as an application packaging system, allowing you to build a
container image on your laptop, build server, etc. and have a high degree of confidence that it can
be successfully deployed. Skyliner doesn’t use registries, scheduling, service discovery,
virtualized networking, or any other advanced features. Instead, we use AWS services with proven
reliability like S3, Autoscaling, and Elastic Load Balancing — services which have seen almost a
[decade](https://aws.amazon.com/blogs/aws/amazon_ec2_beta/) of continuous use and improvement. Each
instance in your application’s autoscaling group downloads the container image from S3, loads it,
and runs it locally. It’s simple, it’s reliable, and it’s managed entirely by AWS.

While there’s a lot of interesting technology on the horizon, the point of Skyliner is to help you
run your applications today. Even if you’re excited by the potential of containers, you already have
software you need to run—your own—and you probably won’t be helped in that by adding additional
operational tasks to your long list of responsibilities.

### If you lived here, you’d be home by now.

As part of building Skyliner, we actively sought out economies of scale and technical advantages in
AWS—places where Amazon teams provide far better value than a small company could on their own. For
example:

* Elastic Load Balancing can offer superior service by virtue of the fact that Amazon controls the 
  networking fabric in ways that Amazon customers cannot;
* Key Management Service is backed by cryptographic hardware but is orders of magnitude cheaper than 
  going it alone;
* S3’s storage pricing was industry-changing when it launched a decade ago and it’s only gotten
  cheaper;
* a t2.medium instance on EC2 is about half the cost of a c4.8xlarge instance when normalized for 
  CPU and memory.
  
With Skyliner, you can leverage the best parts of the existing AWS ecosystem without having to be an
expert. We do the curation for you. It’s our job to do the work of researching each service,
weighing its value proposition, selecting the winners, and connecting it all together. As a
customer, you get some amazing functionality directly out of the box:

* A full, tamper-proof audit log of all AWS operations performed on your account via CloudTrail.
* Load balancers with HTTP/2, WebSockets, and a modern, managed TLS stack via ELB’s Application Load 
  Balancers.
* Scalable log aggregation with search and alerting via CloudWatch Logs.
* Free SSL certificates which renew automatically via Amazon Certificate Manager.
* Secure configuration parameter storage via Key Management Service.
* Metric aggregation and alerting with CloudWatch.
* Resilience to data center outages via Autoscaling Groups and multi-availability zone Virtual 
  Private Clouds.

The core component of what we do at Skyliner is turn our expertise with AWS into integrated,
reliable features for you, and because Skyliner runs everything on your own AWS account, you’re not
limited to what we can do. Want to set up a managed database server with RDS? Want to use Kinesis
for stream processing? Redshift for big data analytics? SQS for background jobs? CloudFront for
faster web pages? Go ahead and set it up. Where possible, we add things like subnet and security
groups to make it easy for you to set things up yourself, even if we don’t automate their management
yet.

As software developers, we understand the allure of shiny new technologies, but ultimately we
decided that we prefer the quiet satisfaction of sleeping through a night while on call. After all,
we’re not just building a platform for our customers—we run our applications on Skyliner, too.
