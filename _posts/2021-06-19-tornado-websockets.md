---
title: Streaming Data with Tornado and WebSockets
excerpt: "WebSockets with the Tornado web framework is a simple, robust way to
handle streaming data. I walk through a minimal example and discuss why these
tools are good for the job."
tags:
  - streaming
  - tornado
  - websocket
header:
  overlay_image: /assets/images/cool-backgrounds/cool-background8.png
  caption: 'Photo credit: [coolbackgrounds.io](https://coolbackgrounds.io/)'
last_modified_at: 2021-06-19
---

A lot of data science and machine learning practice assumes a static dataset,
maybe with some MLOps tooling for rerunning a model pipeline with the freshest
version of the dataset.

Working with streaming data is an entirely different ball game, and it wasn't
clear to me what tools a data scientist might reach for when dealing with
streaming data[^1].

I recently came across a pretty straightforward and robust solution:
[WebSockets](https://datatracker.ietf.org/doc/html/rfc6455) and
[Tornado](https://www.tornadoweb.org/en/stable/). Tornado is a Python web
framework with strong support for asynchronous networking.  WebSockets are a
way for two processes (or apps) to communicate with each other (similar to HTTP
requests with REST endpoints). Of course, Tornado has pretty good support for
WebSockets as well.

In this blog post I'll give a minimal example of using Tornado and WebSockets
to handle streaming data. The toy example I have is one app (`transmitter.py`)
writing samples of a Bernoulli to a WebSocket, and another app (`receiver.py`)
listening to the WebSocket and keeping track of the posterior distribution for
a [Beta-Binomial conjugate model](https://eigenfoo.xyz/bayesian-bandits/).
After walking through the code, I'll discuss these tools, and why they're good
choices for working with streaming data.

For another good tutorial on this same topic, you can check out [`proft`'s blog
post](https://en.proft.me/2014/05/16/realtime-web-application-tornado-and-websocket/).

## Transmitter

- When `WebSocketHandler` is registered to a REST endpoint (on line 44), it
  keeps track of any processes who are listening to that endpoint, and pushes
  messages to them when `send_message` is called.
  * Note that `clients` is a class variable, so `send_message` is a class
    method.
  * This class could be extended to also listen to the endpoint, instead of
    just blindly pushing messages out - after all, WebSockets allow for
    bidirectional data flow.
- The `RandomBernoulli` and `PeriodicCallback` make a pretty crude example, but
  you could write a class that transmits data in real-time to suit your use
  case. For example, you could watch a file for any modifications using
  [`watchdog`](https://pythonhosted.org/watchdog/), and dump the changes into
  the WebSocket.

<script src="https://gist.github.com/eigenfoo/cb07fe6f026d544b013b29143e125a38.js"></script>

## Receiver

- `WebSocketReceiver` is a class that:
  1. Can be `start`ed and `stop`ped to connect/disconnect to the WebSocket and
     start/stop listening to it in a separate thread
  2. Can process every message (`on_message`) it hears from the WebSocket: in
     this case it simply maintains [a count of the number of trials and
     successes](https://eigenfoo.xyz/bayesian-bandits/#stochastic-aka-stationary-bandits),
     but this processing could theoretically be anything. For example, you
     could do some further processing of the message and then dump that into a
     separate WebSocket for other apps (or even users!) to subscribe to.
- To connect to the WebSocket, we need to use a WebSocket client, such as the
  creatively named
  [`websocket-client`](https://github.com/websocket-client/websocket-client).
- Note that we run `read` is a separate thread, so as not to block the main
  thread (where the `on_message` processing happens).
- The `io_loop` instantiated on line 50 (as well as in `transmitter.py`) is
  important - it's how Tornado schedules tasks (a.k.a. _callbacks_) for delayed
  (a.k.a. _asynchronous_) execution. To add a callback, we simply call
  `io_loop.add_callback()`.

<script src="https://gist.github.com/eigenfoo/a693b67167c775f7fe67329f3797595d.js"></script>

## Why Tornado?

Tornado is a Python web framework, but unlike the more popular Python web
frameworks like [Flask](https://flask.palletsprojects.com/) or
[Django](https://www.djangoproject.com/), it has strong support for
[asynchronous networking and non-blocking
calls](https://www.tornadoweb.org/en/stable/guide/async.html#blocking) -
essentially, Tornado apps have one (single-threaded) event loop
(`tornado.ioloop.IOLoop`), which handles all requests asynchronously,
dispatching incoming requests to the relevant non-blocking function as the
request comes in. As far as I know, Tornado is the only Python web framework
that does this.

As an aside, Tornado seems to be [more popular in
finance](https://thehftguy.com/2020/10/27/my-experience-in-production-with-flask-bottle-tornado-and-twisted/),
where streaming real-time data (e.g. market data) is very common.

## Why WebSockets?

A sharper question might be, why WebSockets over HTTP requests to a REST
endpoint? After all, both theoretically allow a client to stream data in
real-time from a server.

[A lot can be said](https://stackoverflow.com/a/45464306) when comparing
WebSockets and RESTful services, but I think the main points are accurately
summarized by [Kumar Chandrakant on
Baeldung](https://www.baeldung.com/rest-vs-websockets#usage):

> [A] WebSocket is more suitable for cases where a push-based and real-time
> communication defines the requirement more appropriately. Additionally,
> WebSocket works well for scenarios where a message needs to be pushed to
> multiple clients simultaneously. These are the cases where client and server
> communication over RESTful services will find it difficult if not prohibitive.

Tangentially, there's one alternative that seems to be better than WebSockets
from a protocol standpoint, but unfortunately doesn't seem to have support from
many Python web frameworks, and that is [Server-Sent Events (a.k.a.
SSE)](https://www.smashingmagazine.com/2018/02/sse-websockets-data-flow-http2/):
it seems to be a cleaner protocol for unidirectional data flow, which is really
all that we need.

---

[^1]: There is [technically a difference](https://sqlstream.com/real-time-vs-streaming-a-short-explanation/) between "real-time" and "streaming": "real-time" refers to data that comes in as it is created, whereas "streaming" refers to a system that processes data continuously. You stream your TV show from Netflix, but since the show was created long before you watched it, you aren't viewing it in real-time.
