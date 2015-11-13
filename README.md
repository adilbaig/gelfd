# gelfd
D module for the GELF protocol.

## What is GELF?
GELF stands for the [Graylog Extended Logging Format](https://www.graylog.org/resources/gelf/).

It is an open standard logging format based on JSON. It is primarily used to pipe messages to [Graylog](www.graylog.org/overview/), the open source log management and analysis platform. 

Using GELF avoids the shortcomings of logging to plain syslog, most importantly the lack of a structured payload along with messages (stack traces, timeouts etc).

GELF is a pure JSON format. It describes how log messages should be structured. In addition, it also describes compression of messages and chunking of large messages over UDP.

This module aims to provide a simple, yet structured, way of generating log messages in GELF format. You can combine messages with arbitrary payload data and construct messages in multiple parts. Message contents are queryable as well. See examples below.

## Installation

### Using DUB

See documentation on the [project dub page](http://code.dlang.org/packages/gelfd)

### Using DMD/LDC/GDC

- Download `src/gelf.d`. This contains all source and unittests
- Include it in your compile. `dmd MYFILE.d gelf.d`

## Unittests

Run unittests like so :

````
rdmd -main -unittest src/gelf.d
````

## Usage

This is the simplest way to create a GELF message.
````
import stdx.protocol.gelf;

// A simple way of creating a GELF message
writeln(gelf("localhost", "The error message"));
````

GELF messages are composed in a `gelf` struct. The struct supports :
- `opString` - writing to a string generates a JSON string.
- `opDispatch` - payload data can be added as functions or properties. It can also be read as properties.
- `opIndexAssign` - payload data can be assigned like an associative array.

````
import std.stdio;
import std.datetime;
import std.socket;

import stdx.protocol.gelf;

void main() {
	
	writeln(gelf("localhost","HUGE ERROR!")); //This creates a bare minimum GELF message
	writeln(gelf("localhost","HUGE ERROR!", Level.ERROR)); //This example uses the overloaded contructor to report an error
	
	// Let's create a GELF message using properties
	auto m = gelf("localhost","HUGE ERROR!");
	m.level = Level.ERROR;
	m.timestamp = Clock.currTime();
	m.a_number = 7;
	
	// Now let's add some environment variables in
	import std.process;
	foreach(v, k; environment.toAA())
		m[k] = v;
	
	writeln(m); // {"version":1.1, "host:"localhost", "short_message":"HUGE ERROR!", "timestamp":1447275799, "level":3, "_a_number":7, "_PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games", ...}
	
	// OR, use the fluent interface ..
	auto m1 = gelf("localhost", "Divide by zero error").level(Level.ERROR).timestamp(Clock.currTime()).numerator(1000).PATH("/usr/bin/");
	
	// Values can be checked for conditions. Here we only send messages of Level.ERROR or more severity to Graylog 
	if(m1.level <= Level.ERROR) {
		auto s = new UdpSocket();
		s.connect(new InternetAddress("localhost", 11200));
		s.send(m1.toString());
	}
	
	writeln(m1); //{"version":1.1, "host:"localhost", "short_message":"Divide by zero error", "timestamp":1447274923, "level":3, "_numerator":1000, "_PATH":"/usr/bin/"}

}
````


## TODO
- Chunking
- Compression
