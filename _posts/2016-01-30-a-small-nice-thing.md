---
title: "A Small, Nice Thing"
layout: post
summary: In which I stop and smell the roses.
---

Lately, I've been programming in [Clojure][clojure] and enjoying it quite a
bit. It's my first Lisp, a return to dynamic typing, and in many ways the first
truly functional language I've used in anger. One of the things I've been
enjoying about Clojure is its regularity and the effects that has on
composability.

[clojure]: http://clojure.org/

Consider taking two sequences of numbers and adding their elements together in a
pairwise fashion:

`\[
\left[\begin{array}{ccc}1 & 2 & 3\end{array}\right] +
\left[\begin{array}{ccc}4 & 5 & 6\end{array}\right] =
\left[\begin{array}{ccc}5 & 7 & 9\end{array}\right]
\]`

From a purely syntactic perspective, this is usually a simple task, but
syntactic complexity is often misleading. When learning a new programming
language, I often stop to consider how many concepts would need to be explained
to a novice familiar with the underlying domain.

### O, Complexity!

#### Scala

{% highlight scala %}
(a, b).zipped.map(_+_)
{% endhighlight %}

For Scala, you'd need to explain tuples, regular method notation, `zipped`,
dotless/parenless/infix method notation (e.g. `_ + _`), placeholder syntax
(i.e. `_` and why it's different than the `_` characters elsewhere) and
anonymous functions (which would probably include some talk about how they're
only contextually distinguishable from everything else).

(Or you'd need to explain Scalaz, semigroups, typeclasses, third-party
dependencies and management tools, imports, implicit methods, infix method
notation, &c. &c. There are a lot of ways to golf this in Scala, all of which
require a large number of concepts to explain.)

#### Ruby

{% highlight ruby %}
a.zip(b).map { |(x, y)| x + y }
{% endhighlight %}

Ruby would require an explanation of method invocation, `zip`, `map`, method
blocks, and parameter destructuring, and infix notation.

#### Python

{% highlight python %}
[(x + y) for (x, y) in zip(a, b)]
{% endhighlight %}

For Python you'd need to explain list comprehensions, tuples, function
invocation, and `zip`.

#### Javascript

{% highlight javascript %}
a.map(function(x, i) {
    return x + b[i];
});
{% endhighlight %}

Javascript requires method invocation, `map`, anonymous function notation, the
`return` keyword, infix operators, and array access.

#### Go

{% highlight go %}
s := make([]int, len(a))
for i, x := range a {
    s[i] = x + b[i];
}
{% endhighlight %}

Go is unsurprisingly a bit more verbose, as you need to explain `make`, slice
type notation, `len`, short variable declarations (i.e. `:=`), `range` loops,
and index expressions and assignment,

#### Clojure

{% highlight clojure %}
(map + a b)
{% endhighlight %}

For Clojure you need to explain s-expressions and `map`. That's
it. Literally. Clojure is a [Lisp-1][lisp1], so referring to the `+` function is
as simple as using the `+` symbol.

[lisp1]: http://ergoemacs.org/emacs/lisp1_vs_lisp2.html

### O, More Complexity!

What happens if we need to add a third list of numbers, `c`?

#### Scala

{% highlight scala %}
(a, b, c).zipped.map(_+_+_)
{% endhighlight %}

Scala handles this relatively gracefully, requiring only a 3-tuple receiver and
another infix operator in the anonymous function.

#### Python

{% highlight python %}
[(x + y + z) for (x, y, z) in zip(a, b, c)]
{% endhighlight %}

Python needs an additional parameter to `zip`, another tuple element, and
another addition.

#### Ruby

{% highlight ruby %}
a.zip(b).zip(c).map { |((x, y), z)| x + y + z }
{% endhighlight %}

Ruby extends the invocation chain and nests the tuples.

#### Javascript

{% highlight javascript %}
a.map(function(x, i) {
    return x + b[i] + c[i];
});
{% endhighlight %}

Javascript adds another array access and addition, which isn't too bad.

#### Go

{% highlight go %}
s := make([]int, len(a))
for i, x := range a {
    s[i] = x + b[i] + c[i];
}
{% endhighlight %}

Go handles the situation similarly.

#### Clojure

{% highlight clojure %}
(map + a b c)
{% endhighlight %}

Clojure, though, remains almost exactly the same as the original. We add `c` as
an additional parameter to `map`---that's it.

Like Python, `map` is variadic, which avoids the tuple nesting seen in Ruby and
Scala. Unlike all the others, though, `+` is neither infix (as Clojure has no
such thing) nor binary---like `map`, it's a variadic function:

{% highlight clojure %}
(+ 1 2 3) => 6
{% endhighlight %}

If either `map` or `+` were of fixed arity, this would not be possible.

### tl;dr

The regularity of Clojure as a programming language provides many opportunities
for composition compared with other programming languages, which in turn allows
for concise expressions of common bits of code. I think that's nice.

### Updated January 30, 2016

* Changed the Python example to use list comprehensions, which I'm assured are a
  more idiomatic way of doing things. Thanks,
  [@michalmigurski](https://twitter.com/michalmigurski)!
* Cleaned up a confusing sentence in the second paragraph. Thanks,
  [@colby](https://twitter.com/colby).
* Included infix notation in the Ruby concepts.
