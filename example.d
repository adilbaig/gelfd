import std.stdio;
import std.datetime;
import std.socket;

import gelf;

void main() {
	
	writeln(Message("localhost","HUGE ERROR!")); //This creates a bare minimum GELF message
	writeln(Message("localhost","HUGE ERROR!", Level.ERROR)); //This example uses the overloaded contructor to report an error
	
	// Let's create a GELF message using properties
	auto m = Message("localhost","HUGE ERROR!");
	m.level = Level.ERROR;
	m.timestamp = Clock.currTime();
	m.a_number = 7;
	
	// Now let's add some environment variables in
	import std.process;
	foreach(v, k; environment.toAA())
		m[k] = v;
	
	writeln(m); // {"version":1.1, "host:"localhost", "short_message":"HUGE ERROR!", "timestamp":1447275799, "level":3, "_a_number":7, "_PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games", ...}
	
	// OR, use the fluent interface ..
	auto m1 = Message("localhost", "Divide by zero error").level(Level.ERROR).timestamp(Clock.currTime()).numerator(1000).PATH("/usr/bin/");
	
	// Values can be checked for conditions. Here we only send messages of Level.ERROR or more severity to Graylog 
	if(m1.level <= Level.ERROR) {
		auto s = new UdpSocket();
		s.connect(new InternetAddress("localhost", 11200));
		s.send(m1.toString());
	}
	
	writeln(m1); //{"version":1.1, "host:"localhost", "short_message":"Divide by zero error", "timestamp":1447274923, "level":3, "_numerator":1000, "_PATH":"/usr/bin/"}

	
	import std.socket;
	
	auto s = new UdpSocket();
	s.connect(new InternetAddress("localhost", 12200));
	
	// Start netcat to watch the output : `nc -lu 12200`
	
	s.sendChunked(m, 500); // Chunk if message is larger than 500 bytes
	s.sendChunked(m, 500, true); // Same as above, but compresses the message (zlib) before chunking
}