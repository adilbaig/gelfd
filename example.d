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
    
    writeln(m); // {"version":1.1, "host:"localhost", "short_message":"HUGE ERROR!", "timestamp":1447275799, "level":3, "_a_number":7, "_PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games", ...}
    
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
    
    // Start netcat to watch the output : `nc -lu 11200`
    
    foreach(c; Chunks(m, 500)) // Chunk if message is larger than 500 bytes 
        s.send(c); 
    
    import std.zlib : compress;
    foreach(c; Chunks(compress(m.toBytes), 500)) // Same as above, but compresses the message (using zlib) before chunking
        s.send(c);
}