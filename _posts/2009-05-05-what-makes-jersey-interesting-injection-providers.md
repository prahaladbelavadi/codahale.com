--- 
title: "What Makes Jersey Interesting: Injection Providers"
layout: post
---

Another interesting thing about Jersey (in addition to 
[parameter classes](http://codahale.com/what-makes-jersey-interesting-parameter-classes))
is the way it uses dependency injection.

You can write a resource method like this:

{% highlight java %}
public String show(@Context UriInfo uriInfo) {
  return "You asked for " + uriInfo.getAbsolutePath();
}
{% endhighlight %}

Jersey detects the `@Context` annotation and automatically injects a `UriInfo`
with the current request's data into the method. You can do this for 
`HttpHeaders`, `SecurityContext`, and a few other Jersey classes.


Why is that cool?
-----------------

Having these objects as method parameters (or as immutable instance variables 
injected via the constructor) makes for startlingly testable code:

{% highlight java %}
@Setup
public void setup() {
    this.uri = new URI("http://example.com/booger");
    this.uriInfo = mock(UriInfo.class);
    this.resource = new MyResource();
}

@Test
public void itReturnsTheAbsolutePath() {
    assertThat(
        resource.show(uriInfo),
        is("You asked for http://example.com/booger")
    );
}
{% endhighlight %}

Because the resource class doesn't go out and get the `UriInfo`, it's much 
easier to test.

What's nice about Jersey is that it opens up this infrastructure to you: it's
easy to write your own injection providers to peel arbitrary bits of an HTTP
request off and inject them into your resources.


1.. 2.. 3.. Example time!
-------------------------

As an easy example, let's take the request's locale, as determined by its
`Accept-Language` header. Out of the box, Jersey gives us access to this via
`HttpHeaders#getAcceptableLanguages()`, which returns a list of `Locale` 
instances in order of preference.

But it's a tedious thing to have our resource class have an `HttpHeaders` 
instance injected and then get the first item from the 
`getAcceptableLanguages()` results:

{% highlight java %}
public String uppercase(@Context HttpHeaders headers) {
    return "this is lowercase".toUppercase(headers.getAcceptableLanguages().get(0));
}
{% endhighlight %}

In order to test that, we'll have to come up with an `HttpHeaders` mock and stub
its `getAcceptableLanguages()` to return a list of locales. Bleagh.


Now make it uglier
------------------

In keeping with my "so what if it looks good on a slide" motif here, I'm also
going to throw in error handling: what if the user doesn't specify a locale?

{% highlight java %}
public String uppercase(@Context HttpHeaders headers) {
    final List<Locale> locales = headers.getAcceptableLanguages();
    final Locale selectedLocale;
    if (locales.isEmpty()) {
        selectedLocale = Locale.US;
    } else {
        selectedLocale = locales.get(0);
    }
    return "this is lowercase".toUppercase(selectedLocale);
}
{% endhighlight %}

That's goddamn horrible -- we'll have to test that logic all over the place, 
lest we end up throwing an `IndexOutOfBoundsException` because someone's HTTP
client has funny ideas about valid locales are.

It would be nice to have the locale-selecting code in its own class, and to do
that in the same way that our `HttpHeaders` instance was injected.

I assume you have some kind of plan
-----------------------------------

In order to do that we'll need to write two things:

1. A class implementing `Injectable<Locale>`, which will be responsible for
   extracting a `Locale` from an HTTP request context.
2. A class implementing `InjectableProvider<Locale>`, which will be responsible
   for injecting instances of #1.

With Jersey, those responsibilities belong to `AbstractHttpContextInjectable` 
and `InjectableProvider`, respectively.


Ok, let's do it
---------------

Luckily for us, we can kill two birds with one stone and implement both
complimentary responsibilities in a single class:

{% highlight java %}
@Provider
public class LocaleProvider
      extends AbstractHttpContextInjectable<Locale>
      implements InjectableProvider<Context, Type> {
    
    @Override
    public Injectable<E> getInjectable(ComponentContext ic, Context a, Type c) {
        if (c.equals(Locale.class)) {
            return this;
        }

        return null;
    }

    @Override
    public ComponentScope getScope() {
        return ComponentScope.PerRequest;
    }
    
    @Override
    public Locale getValue(HttpContext c) {
        final Locales locales = c.getRequest().getAcceptableLanguages();
        if (locales.isEmpty()) {
          return Locale.US;
        }
        return locales.get(0);
    }
}
{% endhighlight %}

This is kind of a complicated class. Let's cover a few things.

* The `@Provider` annotation marks it so that Jersey will add it as an injection
  provider.
* The `getInjectable` method checks to see that `c` is `Locale` -- that is, if
    Jersey is asking this provider if it can  inject a `Locale`. If so, it
    returns itself to do the injection.  Otherwise, it returns `null` to
    indicate there's nothing it can inject.
* The `getScope` method indicates that the returned injectable is only
  meaningful on a per-request basis.
* The `getValue` method is where the real logic happens. Once the
  `LocaleProvider` instance has been returned from `getInjectable`, Jersey 
  passes it an `HttpContext`, which contains all the relevant information about 
  the HTTP  request. It returns the most-preferred locale, including error 
  handling.

When we put `LocaleProvider` in a package that Jersey's configured to scan, we 
can reduce our resource class logic to this:

{% highlight java %}
public String uppercase(@Context Locale locale) {
    return "this is lowercase".toUppercase(locale);
}
{% endhighlight %}

Then our test looks like this:

{% highlight java %}
@Test
public void itReturnsAnUppercaseString() {
    final MyResource resource = new MyResource();
    
    assertThat(
        resource.uppercase(Locale.CANADA),
        is("THIS IS LOWERCASE")
    );
}
{% endhighlight %}

But I don't think we're done yet.


How many times you wanna write this thing
-----------------------------------------

Much like [parameter classes](http://codahale.com/what-makes-jersey-interesting-parameter-classes),
our code gets cleaner the more injection providers we write, so we need to 
extract out the guts into a base class:

{% highlight java %}
public abstract class AbstractInjectableProvider<E>
      extends AbstractHttpContextInjectable<E>
      implements InjectableProvider<Context, Type> {

    private final Type t;

    public AbstractInjectableProvider(Type t) {
        this.t = t;
    }

    @Override
    public Injectable<E> getInjectable(ComponentContext ic, Context a, Type c) {
        if (c.equals(t)) {
            return getInjectable(ic, a);
        }

        return null;
    }

    public Injectable<E> getInjectable(ComponentContext ic, Context a) {
        return this;
    }

    @Override
    public ComponentScope getScope() {
        return ComponentScope.PerRequest;
    }
}
{% endhighlight %}

Now our provider is sleek and shiny:

{% highlight java %}
@Provider
public class LocaleProvider extends AbstractInjectableProvider<Locale> {
    public LocaleProvider() {
        super(Locale.class);
    }

    @Override
    public Locale getValue(HttpContext c) {
        final Locales locales = c.getRequest().getAcceptableLanguages();
        if (locales.isEmpty()) {
          return Locale.US;
        }
        return locales.get(0);
    }
}
{% endhighlight %}


tl;dr
-----

Jersey has an internal dependency injection system which allows you to write
small, focused classes to extract aspects of an HTTP request -- in our case, the
request's locale -- and inject them into your resource classes as an object of 
an appropriate type. This makes for smaller, more composed, more testable 
resource classes, which in turn makes for an application which is easier to
change.
