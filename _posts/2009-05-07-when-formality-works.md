---
title: When Formality Works
layout: post
summary: In which I argue that sometimes it takes a standard to improve things.
---

[On his blog, Yehuda Katz writes](http://yehudakatz.com/2009/05/02/incentivizing-innovation/):

> One of the things I love the most about the Ruby community is how easy it is
> to try out small mutations in practices, which leads to very rapid evolution
> in best practices. Rather than having the community look toward authority to
> design, plan, and implement "best practices" (a la the JSR model), members of
> the Ruby community try different things, and have rapidly made refinements to
> the practices over time.

In general, I agree with Yehuda about [Obie](http://obiefernandez.com)'s
[current advertising campaign](http://railsmaturitymodel.com/): playing
hot-or-not with the bullet points in a HashRocket sales brochure does not make
for a compelling discussion of what makes good software, nor does it actually
help the community. (But then, I don't think helping the community is the
intent behind RMM--I think it's about drumming up business by being
thoughtleaders.)

But I have an important nit to pick.

### That's not how the JSR model works.

Java programmers don't sit around feeling helpless waiting for *JSR-9918: Doing
That Thing You Get Paid To Do* to be finalized. Instead, they haul off and
implement [crazy experiments](http://functionaljava.org/) and
[solve their problems](http://www.thimbleware.com/projects/jrel) in new and
unique ways *just like every other programming community*.

In the [Java Community Process](http://jcp.org/en/procedures/jcp2), you write
a JSR proposal describing what you'd like to standardize and why. [Here's the original proposal for JSR-311, about RESTful web services for Java](http://www.jcp.org/en/jsr/detail?id=311#orig).
Then you assemble an expert group--a group of people who are both
knowledgeable and interested in the subject--and write a bunch of drafts, go
through a bunch of reviews, and finally end up with both a free reference
implementation of the standard and a test suite to verify API compliance with
the standard.

Horrible, I know.

It is incredibly bureaucratic, yes. But it's a standardization process. It's not
where innovation starts, it's where it ends. And that's as it should be.

The whole point of a standard is to describe a fixed set of practices that
people can take for granted. Once they can take it for granted, they can begin
to focus on other things.

### For example, Rack.

One of the more exciting things to have happened in the Ruby web development
community is [Rack](http://rack.rubyforge.org/). It's not a very sexy
project--one can't claim to be a web framework middleware ninja--but it has an
incredible amount of utility: it's standardized the interface between web
application containers--[Mongrel](http://mongrel.rubyforge.org/),
[Thin](http://code.macournoyer.com/thin/),
[Ebb](http://ebb.rubyforge.org/),
[Passenger](http://www.modrails.com/),
[Glassfish, Jetty, Tomcat, JBoss, SpringSource, Google App Engine](http://kenai.com/projects/jruby-rack/pages/Home),
[WEBrick](http://github.com/chneukirchen/rack/blob/d221938a6401d956ac6cfdc892f9b1c11b1fa31a/lib/rack/handler/webrick.rb),
[LiteSpeed](http://litespeedtech.com/),
[Fuzed](http://github.com/KirinDave/fuzed/tree/master),
[CGI](http://github.com/chneukirchen/rack/blob/d221938a6401d956ac6cfdc892f9b1c11b1fa31a/lib/rack/handler/cgi.rb),
[FastCGI](http://github.com/chneukirchen/rack/blob/d221938a6401d956ac6cfdc892f9b1c11b1fa31a/lib/rack/handler/fastcgi.rb),
[SCGI](http://github.com/chneukirchen/rack/blob/d221938a6401d956ac6cfdc892f9b1c11b1fa31a/lib/rack/handler/scgi.rb),
[EventedMongrel, SwiftipliedMongrel](http://swiftiply.swiftcore.org/mongrel.html)--and Ruby web applications.

Thanks to Rack's acceptance, you write a web application to work with a minimal
interface and deploy it on a wide variety of infrastructure without needing to
write your own adapter code. You no longer need to care about the glue code
between your web server and your web application. You can then spend time doing
other things, *like caring about your actual web application.*

### Why did Rack succeed?

Rack succeeded because it has a [spec](http://rack.rubyforge.org/doc/SPEC.html),
a [reference implementation](http://github.com/rack/rack/tree/master) and even
a [test suite](http://github.com/rack/rack/blob/815342a8e15db564b766f209ffb1e340233f064f/lib/rack/lint.rb)
to ensure spec compatibility.

It doesn't matter if Christian Neukirchen--not that he would--hauls off and
destroys Rack as a library; the spec still exists, and implementations of it can
be written again and again.

But a spec is not sufficient, obviously. You can't just crack open Word and
start writing fiction in order to make your project gain traction. You need to
extract from existing projects a common pattern, round off rough edges, and
resolve long-standing issues. Rack did that. It took the various Rails dispatch
glue code and other half-assed Ruby middleware implementations, looked at what
worked for the [Python community](http://www.python.org/dev/peps/pep-0333), came
up with some iterations, got an *astounding* amount of feedback from concerned,
knowledgeable people in the Ruby community, and ended up producing something
which has seen widespread adoption in a short period of time.

I'm not sure why Yehuda feels compelled to bring out the scare quotes when
referring to these as "best practices." It's a good process and it obviously
works.

### Ruby needs more of this.

The Ruby community has not had a great history of doing this.
[Ruby Change Requests](http://rcrchive.net/), a mechanism for proposed changes
to the Ruby language, were mothballed because ruby-core simply didn't want to
deal with it. It's much easier just making changes and having everyone else run
around fixing the ways in which the latest patch release of Ruby totally breaks
their code. It was discontent with this process which produced the
[RubySpec project](http://www.rubyspec.org) which, say, *looked toward authority
to design, plan, and implement "best practices"* regarding the Ruby language.

Why?

> %panel%
> Because trying to build a business on top of a Ruby interpreter in which
> ruby-core is constantly trying out "small mutations" is really goddamn
> annoying.

Not everything needs a spec--actually, *very few things need a spec.* But
trying to build the fundamentals of interoperability without a spec and an open
process is--like Ruby 1.8.7--bound to fail.

### tl;dr

The path to success for a Ruby library and a JSR are the same: pick a problem
where diversity of interface poses a problem, extract a common solution, get a
bunch of feedback from <del>stakeholders</del>interested people in the
community who are working in the area, build a solid reference implementation
which people can easily use, build a test suite so implementers can red/green
their projects, and write a well-defined, simple spec.

It worked for [servlets](http://jcp.org/en/jsr/detail?id=315),
it worked for [Hibernate](http://jcp.org/en/jsr/detail?id=220),
it's working for [Restlet](http://jcp.org/en/jsr/detail?id=311),
it's working for [Joda Time](http://jcp.org/en/jsr/detail?id=310),
it'll work for [Spring and Guice](http://docs.google.com/Doc?id=dd2fhx4z_13cw24s7dj),
and it worked for Rack.
