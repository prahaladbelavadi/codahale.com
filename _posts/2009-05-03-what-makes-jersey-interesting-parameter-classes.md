--- 
title: "What Makes Jersey Interesting: Parameter Classes"
layout: post
---

For folks who have known me for a while, this may come as a bit of a shock: 
these days I'm spending a *lot* of time working with Java these days. And I'm
having a *lot* of fun.


Wait What
---------

Seriously.

This is due in no small part to the fact that I'm working on writing RESTful
web services using a really neat framework: 
[Jersey](https://jersey.dev.java.net/).

Jersey is unfortunately kind of buried in the usual Java community muck of tight
suits and acronyms and corporate nonsense. But here's the deal:

> If it's a good tool -- if it helps you solve problems -- then it doesn't 
> matter how cool the people are who use it. Take the tool; solve the problem.


Tell Me About This Jersey You Speak Of
--------------------------------------

Jersey is the reference implementation of 
[JSR311](https://jsr311.dev.java.net/), which is the Java community's incredibly
bureaucratic way of coming up with a decent API for writing RESTful web 
services. Despite the gray-flannel-suit feel to it, they actually hit a home 
run: Jersey is awesome. A Jersey application maps RESTful resources to classes, 
and requests for those resources to particular methods.

The resource I'm going to write today is a weekday calculator. You give it a 
date, and it tells you what day of the week the day was (or will be) on.

Round One: The Simplest Thing Possible
--------------------------------------

The first thing I'll do is sketch out an interface. Here's a first swing:

{% highlight java %}
@Path("/v1/weekday/{date}")
@Produces(MediaType.TEXT_PLAIN)
public class SkeletonWeekdayResource {
  @GET
  public String getWeekday(@PathParam("date") String date) {
    return date + " is on a ???.";
  }
}
{% endhighlight %}

Here's a sample request/response:

    GET /v1/weekday/20060714 HTTP/1.1
    Host: localhost:8080
    Accept: */*

And our resource class responds with:

    HTTP/1.1 200 OK
    Content-Type: text/plain
    
    20060714 is on a ???.

So far this is pretty plain -- it's not much more verbose than cooler 
frameworks, like Rails. But the kicker comes when we start to implement the code
that parses the date and does the work. Because Java's `Calendar` and `Date`
classes are hilariously bad, I'm going to use 
[Joda Time](http://joda-time.sourceforge.net/). It is awesome.

Round Two: Now Make It Work
---------------------------

So let's add some date parsing to our resource class.

{% highlight java %}
@Path("/v2/weekday/{date}")
@Produces(MediaType.TEXT_PLAIN)
public class NaiveWeekdayResource {
  private static final DateTimeFormatter ISO_BASIC = ISODateTimeFormat.basicDate();
  
  @GET
  public String getWeekday(@PathParam("date") String dateAsString) {
    final DateTime date = ISO_BASIC.parseDateTime(dateAsString);
    return dateAsString + " is on a " + date.dayOfWeek().getAsText() + ".";
  }
}
{% endhighlight %}

Ok, rad. Now it does what we want:

    GET /v2/weekday/20060714 HTTP/1.1
    Host: localhost:8080
    Accept: */*

And then:

    HTTP/1.1 200 OK
    Content-Type: text/plain
    
    20060714 is on a Friday.

Round Three: Oh Yeah, Error Handling
------------------------------------

So what happens when someone asks for an invalid date?

    GET /v2/weekday/200607f14 HTTP/1.1
    Host: localhost:8080
    Accept: */*

Oh geez:
    
    HTTP/1.1 500 Invalid format: "200607f14" is malformed at "f14"
    Content-Type: text/html; charset=iso-8859-1
    
    <big-ass stack trace complaining about the date>

That's not good for a few reasons. First, `500 Internal Server Error` is the
wrong response. It's a bad request -- one you can never handle, regardless of 
the server's date. A `400 Bad Request`, then, is the only humane response, with
a description of why you can't parse that date. Second, stack traces are like
Dad's stories of living in a commune in the 60s: best limited to friends and
family.

So let's add some error handling:

{% highlight java %}
@Path("/v3/weekday/{date}")
@Produces(MediaType.TEXT_PLAIN)
public class BetterWeekdayResource {
  private static final DateTimeFormatter ISO_BASIC = ISODateTimeFormat.basicDate();
  
  @GET
  public String getWeekday(@PathParam("date") String dateAsString) {
    try {
      final DateTime date = ISO_BASIC.parseDateTime(dateAsString);
      return dateAsString + " is on a " + date.dayOfWeek().getAsText() + ".";
    } catch (IllegalArgumentException e) {
      throw new WebApplicationException(
        Response
          .status(Status.BAD_REQUEST)
          .entity("Couldn't parse date: " + dateAsString + " (" + e.getMessage() + ")")
          .build()
      );
    }
  }
}
{% endhighlight %}

Let's try that again:

    GET /v2/weekday/200607f14 HTTP/1.1
    Host: localhost:8080
    Accept: */*

Yay!

    HTTP/1.1 400 Bad Request
    Content-Type: text/plain

    Couldn't parse date: 200607f14 (Invalid format: "200607f14" is malformed at "f14")

That's a much better response, but now the code looks like ass. Also, if we're
doing any date parsing in other resources, we'll have this code there, too.
It also means we have to test the error handling of all the resources which
parse dates.

Round Four: Time To Clean
-------------------------

There's a better way, though, and it has to do with the way that Jersey handles
the `@PathParam` annotation. From the Jersey docs:

> The type of the annotated parameter, field or property must either:
> 
> * ...
> * Be a primitive type.
> * Have a constructor that accepts a single `String` argument.
> * Have a static method named `valueOf` that accepts a single `String`
>   argument (see, for example, `Integer#valueOf(String)`).

So we can just write a class which takes a single `String` argument, eh?

Like this:

{% highlight java %}
public class SimpleDateParam {
  private static final DateTimeFormatter ISO_BASIC = ISODateTimeFormat.basicDate();
  private final DateTime date;
  private final String originalValue;
  
  public SimpleDateParam(String date) throws WebApplicationException {
    try {
      this.originalValue = date;
      this.date = ISO_BASIC.parseDateTime(date);
    } catch (IllegalArgumentException e) {
      throw new WebApplicationException(
        Response
          .status(Status.BAD_REQUEST)
          .entity("Couldn't parse date: " + date + " (" + e.getMessage() + ")")
          .build()
      );
    }
  }
  
  public DateTime getDate() {
    return date;
  }
  
  public String getOriginalValue() {
    return originalValue;
  }
}
{% endhighlight %}

And then our resource class looks like this:

{% highlight java %}
@Path("/v4/weekday/{date}")
@Produces(MediaType.TEXT_PLAIN)
public class AwesomeWeekdayResource {
  @GET
  public String getWeekday(@PathParam("date") SimpleDateParam dateParam) {
    return dateParam.getOriginalValue()
        + " is on a "
        + dateParam.getDate().dayOfWeek().getAsText()
        + ".";
  }
}
{% endhighlight %}

Now that's nice.

We've done a few things here:

* DRYed up our date parsing and error handling into a single, testable, reusable
  class: `SimpleDateParam`.
* Made our resource classes more testable and easier to write. Instead of
  passing them raw date params, we can pass them `SimpleDateParam` instances (or
  mocks). Because error handling is no longer their responsibility, we can focus
  on the resource logic.
* Made our web service a better HTTP citizen. A lot of web services respond with
  `200 OK`, `302 Temporary Redirect` and `500 THE BEES THEY'RE IN MY EYES`.
  Writing clients for those services is goddamn horrible, and there's no reason
  to make strangers suffer.

But wait! We're not done yet!

Round Five: The Mythbusters Get To Take It Too Far; Why Can't I?
----------------------------------------------------------------

We can safely assume we'll be writing a *lot* of these param classes for any
given project -- in fact, the more we write, the cleaner and more testable our
resources are. So it behooves us to streamline the param-writing process as much
as possible.

Thus:

{% highlight java %}
public abstract class AbstractParam<V> {
  private final V value;
  private final String originalParam;
  
  public AbstractParam(String param) throws WebApplicationException {
    this.originalParam = param;
    try {
      this.value = parse(param);
    } catch (Throwable e) {
      throw new WebApplicationException(onError(param, e));
    }
  }
  
  public V getValue() {
    return value;
  }
  
  public String getOriginalParam() {
    return originalParam;
  }
  
  @Override
  public String toString() {
    return value.toString();
  }
  
  protected abstract V parse(String param) throws Throwable;
  
  protected Response onError(String param, Throwable e) {
    return Response
        .status(Status.BAD_REQUEST)
        .entity(getErrorMessage(param, e))
        .build();
  }
  
  protected String getErrorMessage(String param, Throwable e) {
    return "Invalid parameter: " + param + " (" + e.getMessage() + ")";
  }
}
{% endhighlight %}

Which means our param class can look like this:

{% highlight java %}
public class DateParam extends AbstractParam<DateTime> {
  private static final DateTimeFormatter ISO_BASIC = ISODateTimeFormat.basicDate();
  
  public DateParam(String param) throws WebApplicationException {
    super(param);
  }

  @Override
  protected DateTime parse(String param) throws Throwable {
    return ISO_BASIC.parseDateTime(param);
  }
}
{% endhighlight %}

And our resource class looks like this:

{% highlight java %}
@Path("/v5/weekday/{date}")
@Produces(MediaType.TEXT_PLAIN)
public class FinalWeekdayResource {
  @GET
  public String getWeekday(@PathParam("date") DateParam dateParam) {
    return dateParam.getOriginalParam()
        + " is on a "
        + dateParam.getValue().dayOfWeek().getAsText()
        + ".";
  }
}
{% endhighlight %}

