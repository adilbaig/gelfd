# gelfd
D module for the GELF protocol.

## What is GELF?
GELF stands for the Graylog Extended Logging Format.

The Graylog Extended Log Format (GELF) is a log format that avoids the shortcomings of classic plain syslog, when logging to [Graylog](graylog.org). It is an open standard with implementations in several languages.

GELF is a pure JSON format. It merely describes how log messages should be structured. In addition it describes compression of messages and chunking of large messages over UDP.

The protocol is described at [graylog.org/resources/gelf](https://www.graylog.org/resources/gelf/)

This module aims to provide a very simple way of generating log messages in GELF format.

## Installation

### Using DUB

See documentation on the [project dub page](http://code.dlang.org/packages/gelfd)

### Using DMD/LDC/GDC

- Download `src/gelf.d`. This contains all source and unittests
- Include it in your compile. `dmd MYFILE.d gelf.d`

## Unittests

Run unittests like so :

````
rdmd -main -unittest gelf.d
````

## Usage

````
	import stdx.protocol.gelf;
	
	writeln(gelf("localhost", "The error message"));

````

## TODO
- Chunking
- Compression
