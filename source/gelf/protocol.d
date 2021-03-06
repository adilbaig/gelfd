/**

D module for GELF format.

Graylog Extended Logging Format (https://www.graylog.org/resources/gelf/)
The Graylog Extended Log Format (GELF) is a log format that avoids the shortcomings of classic plain syslog, when logging to Graylog (graylog.org)

GELF is a pure JSON format.
This module aims to provide a very simple way of generating log messages in GELF format.

Author:   Adil Baig
*/

module gelf.protocol;

import std.conv : to;
import std.datetime : SysTime;

public :

    enum Level {
        EMERGENCY = 0,
        ALERT = 1,
        CRITICAL = 2,
        ERROR = 3,
        WARNING = 4,
        NOTICE = 5,
        INFO = 6,
        DEBUG = 7,
    }

    /**

    This struct provides a convenient way to create and inspect a GELF message.

    Example:
    -------------------------
    writeln(Message("localhost","HUGE ERROR!")); //This creates a bare minimum GELF message
    writeln(Message("localhost","HUGE ERROR!", Level.ERROR)); //This example uses the overloaded contructor to report an error
    -------------------------

    GELF messages can also be created in multiple steps. This allows you to add in custom values using loops or other code

    Example:
    -------------------------
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
    -------------------------

    A simpler method is to use a fluent interface. This example also shows how values from a Message can be read and used in a conditional statement.

    Example:
    -------------------------
    // Use the fluent interface ..
    auto m1 = Message("localhost", "Divide by zero error").level(Level.ERROR).timestamp(Clock.currTime()).numerator(1000).PATH("/usr/bin/");

    // Values can be checked for conditions. Here we only send messages of Level.ERROR or more severity to Graylog
    if(m1.level <= Level.ERROR) {
        auto s = new UdpSocket();
        s.connect(new InternetAddress("localhost", 11200));
        s.send(m1.toString());
    }

    writeln(m1); //{"version":1.1, "host:"localhost", "short_message":"Divide by zero error", "timestamp":1447274923, "level":3, "_numerator":1000, "_PATH":"/usr/bin/"}
    -------------------------

    */
    struct Message
    {
        const string host;
        const string short_message;
        string full_message;

        private Level lvl = Level.ALERT;
        private Field[string] fields;
        private string ts; // The timestamp

        this(string host, string short_message) @safe nothrow @nogc
        {
            this.host = host;
            this.short_message = short_message;
        }

        this(string host, string short_message, Level level) @safe nothrow @nogc
        {
            this(host, short_message).level(level);
        }

        auto level() { return lvl; }
        auto level(Level l) { lvl = l; return this; }

        auto fullMessage() { return full_message; }
        auto fullMessage(string msg) { full_message = msg; return this; }

        auto timestamp(SysTime sysTime)
        {
            ts = to!string(sysTime.toUnixTime());
            return this;
        }

        auto timestamp(size_t timestamp)
        {
            ts = to!string(timestamp);
            return this;
        }

        auto timestamp(double timestamp)
        {
            ts = to!string(timestamp);
            return this;
        }

        auto opDispatch(string s, T)(T i)
        {
            fields[s] = Field(i);
            return this;
        }

        string opDispatch(string s)()
        {
            return fields[s].val;
        }

        void opIndexAssign(string key, string value) @safe
        {
            fields[key] = Field(value);
        }

        string toString() @safe
        {
            import std.array : appender;

            auto app = appender!string();
            toString((const(char)[] s) { app.put(s); });

            return app.data;
        }
        
        immutable(ubyte[]) toBytes() @safe
        {
            return cast(typeof(return))this.toString();
        }

        void toString(Dg)(scope Dg sink) const
        if (__traits(compiles, sink(['a'])))
        {
            import std.string : replace;

            sink("{\"version\":1.1, \"host\":\"" ~ host ~ "\", \"short_message\":\"" ~ replace(short_message,"\"", "\\\"") ~ "\"");

            if (full_message)
                sink(", \"full_message\":\"" ~ replace(full_message, "\"", "\\\"") ~ "\"");

            if (ts)
                sink(", \"timestamp\":" ~ ts);

            sink(", \"level\":" ~ to!string(cast(int)lvl));

            foreach(k, v; fields) {
                sink(", \"_"~k~"\":");
                sink((v.enclose == 0) ? v.val : "\"" ~ replace(v.val,"\"", "\\\"") ~ "\"");
            }

            sink("}");
        }
    }

private:

    struct Field
    {
        bool enclose = false;
        string val;

        this(V)(V val)
        {
            static if (!is(V : size_t) || is(V == enum))
                enclose = true;

            this.val = to!string(val);
        }
    }

@safe unittest
{
    auto s = Message("localhost","SOME ERROR!").toString();
    auto s1 = "{\"version\":1.1, \"host\":\"localhost\", \"short_message\":\"SOME ERROR!\", \"level\":1}";

    s = Message("localhost","SOME ERROR!", Level.ERROR).toString();
    s1 = "{\"version\":1.1, \"host\":\"localhost\", \"short_message\":\"SOME ERROR!\", \"level\":3}";
    assert(s == s1);

    auto m = Message("localhost","SOME ERROR!").PATH("/usr/bin/").Timeout(3000).level(Level.ERROR);
    assert(m.PATH == "/usr/bin/");
    assert(m.Timeout == "3000"); //NOTE : Numbers are converted to strings and stored
    assert(m.level == Level.ERROR);
    
    // Test if serialization of Enums is correct
    enum {
    	blah
    }
    
    enum SomeEnum {
		SE_A,
		SE_B,
		SE_C
	}
    
    s = Message("localhost","SOME ERROR!").blah(blah).aenum(SomeEnum.SE_A).toString();
    s1 = "{\"version\":1.1, \"host\":\"localhost\", \"short_message\":\"SOME ERROR!\", \"level\":1, \"_aenum\":\"SE_A\", \"_blah\":0}";
    assert(s == s1);
    
    // Strings are automatically escaped.
    s = Message("localhost", "SOME ERROR!").fullMessage("{\"name\" : \"Adil\"}").toString();
    s1 = "{\"version\":1.1, \"host\":\"localhost\", \"short_message\":\"SOME ERROR!\", \"full_message\":\"{\\\"name\\\" : \\\"Adil\\\"}\", \"level\":1}";
    assert(s == s1);
    
    //Check toBytes
    assert(m.toBytes() == [123, 34, 118, 101, 114, 115, 105, 111, 110, 34, 58, 49, 46, 49, 44, 32, 34, 104, 111, 115, 116, 34, 58, 34, 108, 111, 99, 97, 108, 104, 111, 115, 116, 34, 44, 32, 34, 115, 104, 111, 114, 116, 95, 109, 101, 115, 115, 97, 103, 101, 34, 58, 34, 83, 79, 77, 69, 32, 69, 82, 82, 79, 82, 33, 34, 44, 32, 34, 108, 101, 118, 101, 108, 34, 58, 51, 44, 32, 34, 95, 84, 105, 109, 101, 111, 117, 116, 34, 58, 51, 48, 48, 48, 44, 32, 34, 95, 80, 65, 84, 72, 34, 58, 34, 47, 117, 115, 114, 47, 98, 105, 110, 47, 34, 125]);
}
