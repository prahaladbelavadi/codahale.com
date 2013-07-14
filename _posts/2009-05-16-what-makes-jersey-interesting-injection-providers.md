--- 
title: "What Makes Jersey Interesting: Injection Providers"
layout: post
---

*Ok, let's get back to the geeky stuff.*

Another interesting thing about Jersey (in addition to 
[parameter classes](http://codahale.com/what-makes-jersey-interesting-parameter-classes))
is the way it uses dependency injection.

Jersey doesn't have an abstract base class for resources, like Rails' 
`ActionController::Base` or Restlet's `Resource`. This removes the obvious way
of retrieving information about the incoming request: from the base class.

Take this Rails controller action, for example:

{% highlight ruby %}
def show
  render(:text => "You asked for #{request.url}")
end
{% endhighlight %}

`request` is a method defined on `ActionController::Base` which returns an 
object encapsulating the information about the current HTTP request.

But how would you test this action in isolation? Hopefully the base class 
provides an easy way of passing in a mock request object, or else you're stuck
modifying instance variables or partially mocking the class you're trying to 
test.

### So what's a better way of doing that?

Jersey avoids this situation by injecting the required information into the 
resource class:

{% highlight java %}
public String show(@Context UriInfo uriInfo) {
  return "You asked for " + uriInfo.getAbsolutePath();
}
{% endhighlight %}

Jersey detects the `@Context` annotation and automatically injects a `UriInfo`
with the current request's data into the method. You can do this for 
`HttpHeaders`, `SecurityContext`, and a few other Jersey classes.

When it comes time to test this class, it's a simple matter of making a mock
`UriInfo` and passing it in:

{% highlight java %}
@Test
public void itReturnsTheRequestURI() throws Exception {
    final MyResource resource = new MyResource();
    
    final UriInfo uriInfo = mock(UriInfo.class);
    when(uriInfo.getAbsolutePath()).thenReturn("/wooooo");
    
    assertThat(resource.show(uriInfo), is("You asked for /wooooo"));
}
{% endhighlight %}

Because the resource class doesn't go out and get the `UriInfo` itself, it's 
much easier to test.

What takes this feature from Neat to Indispensable is the fact that Jersey opens
this infrastructure to you: it's easy to write your own injection providers to 
peel arbitrary bits of an HTTP request off and inject them into your resources.

### 1.. 2.. 3.. Example time!

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

<ins>
**Update:** If you're wondering why you'd need a `Locale` to convert a string to
uppercase, check out the Turkish language. The uppercase version of **i** 
(U+0069) is **İ** (U+0130), and the lowercase version of **I** (U+0049) is **ı** 
(U+0131). It matters.
</ins>

### Now make it uglier

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

That's goddamn horrible--we'll have to test that logic all over the place, 
lest we end up throwing an `IndexOutOfBoundsException` because someone's HTTP
client has funny ideas about valid locales are.

It would be nice to have the locale-selecting code in its own class, and to do
that in the same way that our `HttpHeaders` instance was injected.

### I assume you have some kind of plan

In order to do that we'll need to write two things:

1. A class implementing `Injectable<Locale>`, which will be responsible for
   extracting a `Locale` from an HTTP request context.
2. A class implementing `InjectableProvider<Locale>`, which will be responsible
   for injecting instances of #1.

Jersey has a specific class to handle the first responsibility: 
`AbstractHttpContextInjectable` which is used to inject information from the
HTTP context into resource classes. The second responsibility is simple enough 
to not require a template base class.

### Ok, let's do it

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
* The `getInjectable` method checks to see that `c` is `Locale`--that is, if
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

### How many times you wanna write this thing

Much like [parameter classes](/what-makes-jersey-interesting-parameter-classes),
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

Now both our resource class and our `LocaleProvider` are composed and testable.

I love it when a plan comes together.

### tl;dr

Jersey has an internal dependency injection system which allows you to write
small, focused classes to extract aspects of an HTTP request--in our case, the
request's locale--and inject them into your resource classes as an object of 
an appropriate type. This makes for smaller, more composed, more testable 
resource classes, which in turn makes for an application which is easier to
change.
