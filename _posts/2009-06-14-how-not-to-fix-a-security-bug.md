--- 
title: "How Not To Fix A Security Bug"
layout: post
---

## November 25th, 2008

* Tadayoshi Funaba opens [Bug #794](http://redmine.ruby-lang.org/issues/show/794)
  in the Ruby Issue Tracking System describing a segmentation fault when huge 
  decimal strings are converted into `BigDecimal` instances.


## November 26th, 2008

* Matz closes Bug #794 with [r20359](http://redmine.ruby-lang.org/repositories/revision/ruby-19?rev=20359)
  to Ruby 1.9's trunk.


## November 27th, 2008 to June 2nd, 2009

* Every site running Ruby 1.8.x which creates BigDecimal instances from
  client-provided data is vulnerable to a Denial-of-Service attack which Ruby
  Core developers have already fixed but not backported.


## June 3rd, 2009

* [CVE-2009-1904](http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2009-1904)
  is assigned.


## June 7th, 2009

* ruby-core notifies the [vendor-sec](http://en.wikipedia.org/wiki/Vendor-sec) 
  mailing list of the vulnerability.

## June 8th, 2009

* [Bug 273213](http://bugs.gentoo.org/show_bug.cgi?id=273213) is created in
  the Gentoo bug tracker to address CVE-2009-1904. Like most tickets for
  as-yet-undisclosed security vulnerabilities, the ticket was marked
  confidential and that "no information should be disclosed until [the 
  vulnerability] is made public."
* Michael Koziarski creates a private GitHub project, [bigdecimal-segfault-fix](http://github.com/NZKoz/bigdecimal-segfault-fix/tree/master)
  with a workaround for the bug.
* Kirk Haines [commits a change](http://github.com/rubyspec/rubyspec/commit/95c0abbe07bf350f83d2454eb080b0bd315d59d4)
  to the RubySpec project which adds a test to ensure Ruby implementations 
  don't "segfault when using a very large string to build [a BigDecimal]."


## June 9th, 2009

* The vulnerability [is announced](http://www.ruby-lang.org/en/news/2009/06/09/dos-vulnerability-in-bigdecimal/) as well as the release of Ruby 1.8.7-p173.
* [A ticket is added](http://www.vuxml.org/freebsd/62e0fbe5-5798-11de-bb78-001cc0377035.html)
to FreeBSD's security bug tracker to address CVE-2009-1904.
* Michael Koziarski [announces the vulnerability](http://groups.google.com/group/rubyonrails-security/msg/fad60751e2b9b4f6?)
  to the rails-security mailing list.
* Kirk Haines [adds Backport #1589](http://redmine.ruby-lang.org/issues/show/1589)
  to the Ruby Issue Tracking System describing a patch which "eliminate[s] some
  BigDecimal bugs."
* Kirk Haines [announces the release of Ruby 1.8.6-p369](http://groups.google.com/group/comp.lang.ruby/browse_thread/thread/3106062ee1df078a/0625d1bd36da13db?lnk=raot&fwc=2), which includes a fix for CVE-2009-1904.
* Michael Koziarski makes the bigdecimal-segfault-fix project public on GitHub.


## June 10th, 2009

* Barry Hess finds a bug introduced in 1.8.7-p173 [breaks BigDecimal#to_f](http://www.getharvest.com/blog/2009/06/ruby-denial-of-service-patch-breaks-bigdecimal-to_f-method/).
* [A ticket is added](https://bugzilla.redhat.com/show_bug.cgi?id=504958) to
  the Red Hat bug tracker to address CVE-2009-1904.
* The vulnerability [is announced](http://weblog.rubyonrails.org/2009/6/10/dos-vulnerability-in-ruby/)
  on the Ruby On Rails blog.
* [A ticket is added](https://bugs.launchpad.net/ubuntu/+source/ruby1.8/+bug/385436) to
  the Ubuntu bug tracker to address CVE-2009-1904.
* [A ticket is added](http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=532689)
  to the Debian bug tracker to address CVE-2009-1904.


## June 12th, 2009

* [A fix is released](http://www.freshports.org/commit.php?category=lang&port=ruby18&files=yes&message_id=200906122244.n5CMiug0080745@repoman.freebsd.org) for FreeBSD.


## June 13th, 2009

* [A fix is released](http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=532689#20) for Debian Unstable. This fix contains the bug that Barry Hess found.


## June 14th, 2009

* No fix has been released for Ubuntu.
* No fix has been released for Red Hat.
* No fix has been released for Fedora Core.
* No fix has been released for Gentoo.


## June 15th, 2009
* Ruby 1.8.7-p174 [is released](http://www.ruby-forum.com/topic/189053#827091)
  without the `BigDecimal#to_f` bug.


## tl;dr

This is not a coordinated disclosure. This is a clusterfuck. If you are 
responsible for running a secure MRI/Ruby installation, your only hope is to pay
attention to all changes made to Ruby's trunk and backport any fixes yourself.
Depending on your operating system vendor is not a viable strategy, as 
downstream vendors are not given sufficient advance warning and are presented 
with fixes which introduce other bugs or do not apply cleanly to the last 
released version.


## Updated June 16th, 2009

* [Michael Koziarski](http://www.koziarski.net/) dropped me a note to clarify a 
  few things. First, his GitHub project was private and was only opened to the
  public *after* the vulnerability was announced. Second, ruby-core sent an 
  email to the [vendor-sec](http://en.wikipedia.org/wiki/Vendor-sec) mailing 
  list 48 hours before the disclosure. I've updated the timeline to reflect 
  these changes.
* [James Ludlow](http://twitter.com/jdludlow) [let me know about](http://twitter.com/jdludlow/status/2166873415)
  a bug introduced in 1.8.7-p173 and fixed in 1.8.7-p174.
* Updated my conclusions based on the new information. Still not happy, but more
  accurate in what I'm unhappy about.
