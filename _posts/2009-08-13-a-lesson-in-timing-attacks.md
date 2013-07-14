---
title: "A Lesson In Timing Attacks (or, Don’t use MessageDigest.isEquals)"
layout: post
---

[Timing attacks](http://crypto.stanford.edu/~dabo/papers/ssl-timing.pdf)
are pretty horrible from the perspective of someone trying to write a secure
cryptosystem. They work against a programmer's best instincts—don't do extra
work—to give an attacker with access to a Statistics 101 textbook a good solid
grip on your application's guts.

### How the hell does that work?

In short, a timing attack uses statistical analysis of how long it takes your
application to do something in order to learn something about the data it's
operating on. For [HMACs](http://en.wikipedia.org/wiki/HMAC), this means using
the amount of time your application takes to compare a given value with a
calculated value to learn information about the calculated value.

Take [the recent Keyczar vulnerability that Nate Lawson found](http://rdist.root.org/2009/05/28/timing-attack-in-google-keyczar-library/).
He was able to take the fact that Keyczar used a simple break-on-inequality
algorithm to compare a candidate HMAC digest with the calculated digest.

This is the offending code in Python:

{% highlight python %}
return self.Sign(msg) == sig_bytes
{% endhighlight %}

and in Java:

{% highlight java %}
return Arrays.equals(hmac.doFinal(), sigBytes);
{% endhighlight %}

A value which shares no bytes in common with the secret digest will return
immediately; a value which shares the first 15 bytes will return 15 compares
later. That's a difference of perhaps microseconds, but given enough
attempts—which is usually easy to arrange in web applications (how many of you
throttle requests with bad session cookies?)—the random noise becomes a very
predictable, normally distributed skew, leaving only the signal.

### Well that doesn't seem that bad

Oh, but it is.

I can choose what message I want to be authenticated—let's say a session cookie
with a specific user ID—and then calculate 256 possible values:

    0000000000000000000000000000000000000000
    0100000000000000000000000000000000000000
    0200000000000000000000000000000000000000
    ... snip 250 ...
    FD00000000000000000000000000000000000000
    FE00000000000000000000000000000000000000
    FF00000000000000000000000000000000000000

I go through each of these values until I find one—
`A100000000000000000000000000000000000000`—that takes a fraction of a
millisecond *longer* than the others. I now know that the first byte of what the
HMAC for that message *should be* is `A1`. Repeat the process for the remaining
19 bytes, and all of a sudden I'm logged in as you.

### You can't possibly measure that, can you?

Right about now, most people are thinking about the improbability of measuring
the difference between two array comparisons in a web application, given all the
routers, parsers, servers, proxies, etc. in the way.

According to Crosby et al.'s [Opportunities And Limits Of Remote Timing Attacks](http://www.cs.rice.edu/~dwallach/pub/crosby-timing2009.pdf):
> We have shown that, even though the Internet induces significant timing
> jitter, we can reliably distinguish remote timing differences as low as 20µs.
> A LAN environment has lower timing jitter, allowing us to reliably distinguish
> remote timing differences as small as 100ns (possibly even smaller). These
> precise timing differences can be distinguished with only hundreds or possibly
> thousands of measurements.

So. Almost microsecond resolution with hundreds to thousands of measurements.
Who wants to bet that network jitter compensation models get worse instead of
better?

A worst-case scenario for guessing an HMAC would require `\(20 \times 256 \times n\)`
measurements, where `\(n\)` is the number of measurements required to pin down a
single byte. So—around 5,000,000 requests. You could do that in less than a week
at a barely-perceptible 10 req/s.

It's an attack which takes some planning and analysis, but it's viable.

### Well crap. Now what?

Instead of using a variable-time algorithm for comparing secrets, you should be
using constant-time algorithms. Lawson recommends something like the following
in Python:

{% highlight python %}
def is_equal(a, b):
    if len(a) != len(b):
        return False

    result = 0
    for x, y in zip(a, b):
        result |= x ^ y
    return result == 0
{% endhighlight %}

In Java, that would look like this:

{% highlight java %}
public static boolean isEqual(byte[] a, byte[] b) {
    if (a.length != b.length) {
        return false;
    }

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i]
    }
    return result == 0;
}
{% endhighlight %}

### Yay! Problem solved, right?

Oh, if only.

Check out what's inside of `java.security.MessageDigest` as recently as Java
6.0 Update 15:

{% highlight java %}
/**
  * Compares two digests for equality. Does a simple byte compare.
  *
  * @param digesta one of the digests to compare.
  *
  * @param digestb the other digest to compare.
  *
  * @return true if the digests are equal, false otherwise.
  */
public static boolean isEqual(byte digesta[], byte digestb[]) {
    if (digesta.length != digestb.length)
        return false;

    for (int i = 0; i < digesta.length; i++) {
        if (digesta[i] != digestb[i]) {
            return false;
        }
    }
    return true;
}
{% endhighlight %}

### Wait What

Yep. Byte-by-byte comparison; returns on first inequality. Just what we don't
need.

I'll be blunt here: **any Java application which compares client-provided data
to a secret value using `MessageDigest.isEqual` is vulnerable to timing
attacks**. This includes HMACs, decryption results, etc.

I reported this to Sun on July 22nd, 2009. It's
[Bug # 6863503](http://bugs.sun.com/bugdatabase/view_bug.do?bug_id=6863503),
which isn't publicly viewable due to the security concerns. Besides the
automated email with the ticket number, I haven't heard anything from Sun since
then. In my bug report, I was explicit about my intent to follow through
according to the [RFPolicy](http://www.wiretrip.net/rfp/policy.html), which says

> D. If the MAINTAINER goes beyond 5 working days without any communication to
> the ORIGINATOR, the ORIGINATOR may choose to disclose the ISSUE. The
> MAINTAINER is responsible for providing regular status updates (regarding the
> resolution of the ISSUE) at least once every 5 working days.

So here I am, fully disclosing a rather large cryptographic vulnerability in one
of the largest programming platforms there is. I can't tell if that's terrible
or awesome.

### tl;dr

Replace your usage of `MessageDigest.isEqual` with a constant-time algorithm,
like the one above.

**Every time you compare two values, ask yourself: what could someone do if
they knew either of these values?** If the answer is at all meaningful, use a
constant-time algorithm to compare them.

### A Side Note

This would be substantially less of an issue if more cryptographic libraries had
better encapsulation. An HMAC is *not* just a series of characters or bytes—why
treat it as such? Why have such a crucial piece of cryptography squirt out its
state for others to man-handle?

### Thanks

[Nate Lawson](http://www.root.org/~nate/)'s Keyczar find got me thinking about
timing attacks in my own code. His
[When Crypto Attacks](http://www.youtube.com/watch?v=ySQl0NhW1J0) talk should be
required watching for everyone with access to a compiler.

### Updated August 13, 2009

As [sophacles on Hacker News](http://news.ycombinator.com/item?id=761059)
pointed out, I had overly refactored the suggested constant-time algorithms and
introduced a more subtle timing attack vulnerability via the return
statement's boolean expression short-circuit. The algorithm has been updated to
fix this.

### Updated December 3, 2009

The timing attack vulnerability in `MessageDigest` was fixed in
[Java SE 6 Update 17](http://java.sun.com/javase/6/webnotes/6u17.html).
