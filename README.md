# gelfd
D module for the GELF protocol.

## What is GELF?
GELF stands for the [Graylog Extended Logging Format](https://www.graylog.org/resources/gelf/).

It is an open standard logging format based on JSON. It is primarily used to pipe messages to [Graylog](www.graylog.org/overview/), the open source log management and analysis platform.

Using GELF avoids the shortcomings of logging to plain syslog, most importantly the lack of a structured payload along with messages (stack traces, timeouts etc).

GELF is a pure JSON format. It describes how log messages should be structured. In addition, it also describes compression of messages and chunking of large messages over UDP.

This module aims to provide a simple, yet structured, way of generating log messages in the GELF format. You can combine messages with arbitrary payload data and construct messages in multiple parts. Message contents are also queryable. See examples below.

## Usage

The simplest way to create a GELF message is as follows :
````d
import gelf;

writeln(Message("localhost", "An alert message"));
````

GELF messages are composed in a `Message` struct. The struct supports :
- `opString` - writing or casting to a string generates the GELF message.
- `opDispatch` - payload data can be added using user-defined functions or properties. It can also be read as properties.
- `opIndexAssign` - payload data can also be assigned like an associative array.

````d
import std.stdio;
import std.datetime;
import std.socket;
import std.process;

import gelf;

void main() {
    writeln(Message("localhost","An alert message")); // {"version":1.1, "host":"localhost", "short_message":"An alert message", "level":1}
    writeln(Message("localhost","HUGE ERROR!", Level.ERROR)); //{"version":1.1, "host":"localhost", "short_message":"HUGE ERROR!", "level":3}
    
    // Let's create a GELF message using a number of user-defined properties
    auto m = Message("localhost","HUGE ERROR!");
    m.level = Level.ERROR;
    m.timestamp = Clock.currTime();
    m.a_number = 7;
    
    // Now let's add some environment variables ..
    foreach(v, k; environment.toAA())
    	m[k] = v; // .. using a associative array syntax
    
    writeln(m); // {"version":1.1, "host:"localhost", "short_message":"HUGE ERROR!", "timestamp":1447275799, "level":3, "_a_number":7, "_PATH":"/usr/local/sbin:..."}
    
    auto s = new UdpSocket();
    s.connect(new InternetAddress("localhost", 11200));
    	
    // You can also generate a message using a fluent interface
    auto m1 = Message("localhost", "Divide by zero error")
        .level(Level.ERROR)
        .timestamp(Clock.currTime())
        .numerator(1000)
    ;
    
    // Values are readable. Here, we only send messages of Level.ERROR or more severity to Graylog 
    if(m1.level <= Level.ERROR)
    	s.send(m1.toString());
    
    // Start netcat to watch the output : `nc -lu 12200`
    
    foreach(c; Chunks(m, 500)) // Chunk if message is larger than 500 bytes 
        s.send(c); 
    
    import std.zlib : compress;
    foreach(c; Chunks(compress(m.toBytes), 500)) // Same as above, but compresses the message before chunking
        s.send(c);
}
````

## Chunking and Compression

Chunking and compression are supported automatically using the `sendChunked` function.

````d
import gelf;
import std.socket;

auto s = new UdpSocket();
s.connect(new InternetAddress("localhost", 12200));

// Start netcat to watch the output : `nc -lu 12200`

auto m = Message("localhost","HUGE ERROR!");
s.sendChunked(m, 500); // Chunk if message is larger than 500 bytes
s.sendChunked(m, 500, true); // Same as above, but compresses the message (zlib) before chunking
````

This is simple, but not very flexible. `sendChunked` is a convenience function. 

Chunking support is now provided with the `Chunks` struct. This is an InputRange that takes a `Message` or a compressed message and generates chunks from it.

Using `Chunks` gives you the flexibility to :
- Use blocking or non-blocking sockets as chunking is not tied to sockets anymore
- Use zlib or gzip with user-defined levels of compression 

````d
import gelf;
import std.socket;

auto s = new UdpSocket();
s.connect(new InternetAddress("localhost", 12200));

// Start netcat to watch the output : `nc -lu 12200`

auto m = Message("localhost","HUGE ERROR!");
foreach(c; Chunks(m, 500)) // Chunk if message is larger than 500 bytes 
    s.send(c); 
    
import std.zlib : compress;
foreach(c; Chunks(compress(m.toBytes), 500)) // Same as above, but compresses the message (using zlib) before chunking
    s.send(c);
````

## Installation

You can install this package using dub, or download the source and compile it into your program.

### Using DUB

The **recommended** way. To include gelfd in your project follow the instructions on the [project dub page](http://code.dlang.org/packages/gelfd)

If you want to just download the source into your project directory, do this :

````bash
dub fetch gelfd --cache=local
````

### Using DMD/LDC/GDC

- Clone this repo
- Compile your source with the gelf sources. `dmd MYFILE.d source/gelf/*`

## Unittests

Run unittests like so :

````
dub test
````

## Run the Example script

This script contains various examples of how to generate GELF messages. You don't need Graylog installed to check this, although it is recommended to atleast run `netcat` to see the output of chunked (and compressed) messages. To run `example.d`, do :

````
dub run --config=example;
````

or

````bash
dmd example.d source/gelf/* -ofexample && ./example;
````


## Licence
MIT License

Adil Baig
