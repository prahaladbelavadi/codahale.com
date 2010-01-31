---
title: How To Safely Store A Password
layout: post
---

Use `bcrypt`
------------

Use [bcrypt](http://www.usenix.org/events/usenix99/provos.html).
Use [bcrypt](http://github.com/codahale/bcrypt-ruby).
Use [bcrypt](http://pypi.python.org/pypi/bcrypt/).
Use [bcrypt](http://derekslager.com/blog/posts/2007/10/bcrypt-dotnet-strong-password-hashing-for-dotnet-and-mono.ashx).
Use [bcrypt](http://www.mindrot.org/projects/jBCrypt/).
Use [bcrypt](http://search.cpan.org/~zefram/Crypt-Eksblowfish-0.007/lib/Crypt/Eksblowfish/Bcrypt.pm).
Use [bcrypt](http://www.openwall.com/crypt/).
Use [bcrypt](http://www.openwall.com/phpass/).
Use [bcrypt](http://github.com/skarab/erlang-bcrypt).


Why Not {`MD5`, `SHA1`, `SHA256`, `SHA512`, `SHA-3`, etc}?
----------------------------------------------------------

These are all *general purpose* hash functions, designed to calculate a digest
of huge amounts of data in as short a time as possible. This means that they are
fantastic for ensuring the integrity of data and utterly rubbish for storing
passwords.

A modern server can calculate the MD5 hash of about
[330MB every second](http://www.cryptopp.com/benchmarks-amd64.html). If your
users have passwords which are lowercase, alphanumeric, and 6 characters long,
you can try *every single possible password of that size* in around
**40 seconds**.

And that's without investing anything.

If you're willing to spend about 2,000 USD and a week or two picking up
[CUDA](http://www.nvidia.com/object/cuda_home.html), you can put together your
own little supercomputer cluster which will let you
[try around 700,000,000 passwords a second](http://www.win.tue.nl/cccc/sha-1-challenge.html).
And that rate you'll be cracking those passwords at the rate of more than **one
per second.**


Salts Will Not Help You
-----------------------

It's important to note that **salts are useless for preventing dictionary
attacks or brute force attacks.** You can use huge salts or many salts or
hand-harvested, shade-grown, organic [Himalayan pink salt](http://en.wikipedia.org/wiki/Himalayan_salt).
It doesn't affect how fast an attacker can try a candidate password, given the
hash and the salt from your database.

Salt or no, if you're using a general-purpose hash function designed for speed
you're well and truly effed.


`bcrypt` Solves These Problems
------------------------------

How? Basically, it's slow as hell. It uses a variant of the Blowfish
encryption algorithm's keying schedule, and introduces a *work factor*, which
allows you to determine how expensive the hash function will be. Because of
this, `bcrypt` can keep up with Moore's law. As computers get faster you can
increase the work factor and the hash will get slower.

How much slower is `bcrypt` than, say, `MD5`? Depends on the work factor. Using
a work factor of 12, `bcrypt` hashes the password `yaaa` in about 0.3 seconds on
my laptop. `MD5`, on the other hand, takes less than a microsecond.

So we're talking about **5 or so orders of magnitude**. Instead of cracking a
password every 40 seconds, I'd be cracking them every **12 years** or so. Your
passwords might not need that kind of security and you might need a faster
comparison algorithm, but `bcrypt` allows you to choose your balance of speed
and security. Use it.


tl;dr
-----

**Use `bcrypt`.**