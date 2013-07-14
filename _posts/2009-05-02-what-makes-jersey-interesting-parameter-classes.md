--- 
title: "What Makes Jersey Interesting: Parameter Classes"
layout: post
---

For folks who have known me for a while, this may come as a bit of a shock: 
these days I'm spending a *lot* of time working with Java. And I'm having a 
*lot* of fun.

### lol wut

No really.

This is due in no small part to the fact that I'm working on writing RESTful
web services using a really neat framework: 
[Jersey](https://jersey.dev.java.net/).

### What Is This Jersey You Speak Of

Jersey is the reference implementation  of 
[JSR311](https://jsr311.dev.java.net/), which is the Java community's incredibly 
bureaucratic way of coming up with a decent API for writing RESTful web 
services. Despite the gray-flannel-suit feel to it, it's actually a delight to
work with.

Broadly speaking, Jersey maps resources to classes, and HTTP verbs to methods.

Here's an example resource class:

{% highlight java %}
@Path("/helloworld")
@Produces(MediaType.TEXT_PLAIN)
public class HelloWorldResource {
  @GET
  public String sayHello() {
    return "Hello, world!";
  }
}
{% endhighlight %}

The `@Path` annotation marks the class as a resource class and tells Jersey what
URIs the resource is responsible for. When a request comes in for `/helloworld`,
Jersey routes that to a `HelloWorldResource` instance.

The `@Produces` annotation allows Jersey to perform content negotiation. If a
request comes in with a `Accept: image/jpeg` header, Jersey will respond with a
`406 Not Acceptable`.

The `@GET` annotation tells Jersey that the `sayHello()` method is responsible
for handling `GET` requests. If a resource class doesn't have a method to handle
an HTTP verb, Jersey will respond with a `405 Method Not Allowed`.

When a `GET` request comes in, Jersey calls `sayHello()`. The `String` that's 
returned gets turned into an HTTP response entity, and you're off to the races.

There's a lot more to it, but that's Jersey and JSR311 in a nutshell.

What this article is about is how a Jersey application handles change--you can
find anything about a framework which will look good on a slide but end up
sucking horribly in real life (see: Rails' `respond_to`).

For this article, I'm going to write a weekday calculator. You give it a date, 
and it tells you what day of the week the day was (or will be) on. Not 
super-useful, sure, but my boss won't let me paste huge chunks of our source 
code here; you'll have to settle for a contrived example.

### Round One: The Simplest Thing Possible

The first thing I'll do is sketch out a skeleton resource class. Here's a first
swing:

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

You'll notice that the `getWeekday` method takes an argument, `date`, which is
annotated with `@PathParam`. The `@PathParam` annotation pulls the `date`
variable from the resource's URI template (`/v1/weekday/{date}`), turns it into
a `String`, and passes it to the `getWeekday` method.

Here's a sample request/response:

    GET /v1/weekday/20060714 HTTP/1.1
    Host: localhost:8080
    Accept: */*

And our resource class responds with:

    HTTP/1.1 200 OK
    Content-Type: text/plain
    
    20060714 is on a ???.

This isn't much more complicated than `HelloWorldResource`; we're still in
could-be-crap-but-looks-good-on-a-slide territory. So let's add the guts of the
resource--date parsing and weekday calculation. Because Java's `Calendar` and 
`Date` classes are *hilariously* bad, I'm going to use 
[Joda Time](http://joda-time.sourceforge.net/), which kicks ass.

### Round Two: Now Make It Work

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

The changes here are obvious: we use `ISO_BASIC`, a parser and formatter, to 
turn `dateAsString` into a `DateTime`, `date`. `date.dayOfWeek()` returns a 
property which we turn into text and send back to the client.

Now it does what we want:

    GET /v2/weekday/20060714 HTTP/1.1
    Host: localhost:8080
    Accept: */*

And then:

    HTTP/1.1 200 OK
    Content-Type: text/plain
    
    20060714 is on a Friday.

But this could still be a Potemkin application. So let's do something you 
rarely see in slide shows. Let's throw some bad input at it.

### Round Three: Oh Yeah, Error Handling

What happens when someone asks for an invalid date?

    GET /v2/weekday/200607f14 HTTP/1.1
    Host: localhost:8080
    Accept: */*

Oh geez:
    
    HTTP/1.1 500 Invalid format: "200607f14" is malformed at "f14"
    Content-Type: text/html; charset=iso-8859-1
    
    <big-ass stack trace complaining about the date>

That's not terrible, but it needs to change.

First, `500 Internal Server Error`is the wrong response. The problem isn't with 
the server's state, it's with the request. A better response would be `400 Bad 
Request`--that way the client knows not to retry the request, and we can add 
an explanation of what about the request needs to change before it will be
acceptable.

Second, unloading a stack trace on random passers-by is bad form. They don't 
care, and they probably shouldn't know what kind of magic is behind the scenes.

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

This is a pretty simple approach--catch the exception, and throw a 
`WebApplicationException` with an HTTP response explaining the problem. Jersey
catches the `WebApplicationException` and sends the attached `Response`.

Let's try that again:

    GET /v2/weekday/200607f14 HTTP/1.1
    Host: localhost:8080
    Accept: */*

Yay!

    HTTP/1.1 400 Bad Request
    Content-Type: text/plain

    Couldn't parse date: 200607f14 (Invalid format: "200607f14" is malformed at "f14")

Ok, so our code is now correct and handles errors, but its readability has 
suffered--for two lines of domain-specific code, we have nine lines of error
handling. *Ruh-roh.* If we continue with this approach, every date parsing
resource in the application will have its own error handling, which means a lot
of copying and pasting and testing the error handling and bugs, bugs, bugs.

Here's where Jersey starts to shine--separation of concerns.

### Round Four: Time To Clean

The trick here is to stop accepting `String`s and start dealing with 
domain-specific objects. We can do that easily due to the way that Jersey 
handles the `@PathParam` annotation.

From the Jersey docs:

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

This is a pretty straight-forward class which takes a string, parses it, and
either throws a `WebApplicationException` or returns an object with a `DateTime`
and the original parameter.

We can change our resource class to accept a `SimpleDateParam` argument instead
of a `String`, which ends up looking like this:

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

In between our first working resource and this one, we've done a few things 
worth noting:

* We extracted date parsing and HTTP-specific error handling into a simple,
  testable, reusable class.
* We made our resource classes more testable. Instead of banging `String`s 
  together and testing error handling, we can pass in `SimpleDateParam` stubs
  test the actual resource logic, safe in the knowledge that a malformed 
  `SimpleDateParam` **cannot exist**.
* We made our web service a better HTTP citizen. Instead of freaking out with a
  `500 THE BEES THEY'RE IN MY EYES` mystery response, we provide clients and 
  intermediaries with specific, usable information.

But wait! We're not done yet!

### Round Five: And *Stay* Solved, Damnit

We can safely assume we'll be writing a *lot* of these param classes for any
given project--in fact, the more of these we write, the cleaner and more 
testable our resources are.

Think about it--does your web service accept any of the following things?

* URIs
* Numbers
* Enums (e.g., `/posts?status=1` ends up being `PostStatus.ACTIVE`)
* Booleans
* Timestamps
* IDs with a specific format

Duh. Of course it does. Now how many times do want to write that code? Once. So 
it behooves us to streamline the param-writing process as much as possible.

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

Which means our param class ends up look like this:

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

### tl;dr

Jersey's approach to handling input is graceful in the face of ugly error 
handling and edge cases, allowing separation of concerns, encapsulation, and 
reuse. We started out with a simple resource class, added some functionality, 
added some ugly error handling, then extracted that into a small, composed, 
testable class. Any other resource class which needs to parse an ISO 8601 basic 
date? *Solved.* The end result is testable and readable.

All this despite the fact that it's in Java.

You can download all the source code for this project 
[here](/downloads/jersey-parameter-example.zip).
