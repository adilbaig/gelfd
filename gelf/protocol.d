/**

D module for GELF format.

Graylog Extended Logging Format (https://www.graylog.org/resources/gelf/)
The Graylog Extended Log Format (GELF) is a log format that avoids the shortcomings of classic plain syslog, when logging to Graylog (graylog.org)

GELF is a pure JSON format.
This module aims to provide a very simple way of generating log messages in GELF format.

Author:   Adil Baig 
*/

module gelf.protocol;

private:
	import std.conv : to;
	import std.datetime : SysTime;
	import core.sys.posix.syslog;
	
public : 

	enum Level {
		ALERT = LOG_ALERT,
		EMERGENCY = LOG_EMERG,
	    CRITICAL = LOG_CRIT,
	    ERROR = LOG_ERR,
	    WARNING = LOG_WARNING,
	    NOTICE = LOG_NOTICE,
	    INFO = LOG_INFO,
	    DEBUG = LOG_DEBUG,
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
		
		this(string host, string short_message) 
		{
			this.host = host;
			this.short_message = short_message;
		}
		
		this(string host, string short_message, Level level) 
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
	    
	    void opIndexAssign(string key, string value)
	    {
	        fields[key] = Field(value);
	    }
	    
	    string toString()
		{
			import std.array;
			
			auto app = appender!string();
			toString((const(char)[] s) { app.put(s); });
			
			return app.data;
		}
		
		void toString(scope void delegate(const(char)[]) sink) const
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
			static if (!is(V : size_t))
				enclose = true;
			
			this.val = to!string(val);
		}
	}

unittest
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
	
	// Strings are automatically escaped.
	s = Message("localhost", "SOME ERROR!").fullMessage("{\"name\" : \"Adil\"}").toString();
	s1 = "{\"version\":1.1, \"host\":\"localhost\", \"short_message\":\"SOME ERROR!\", \"full_message\":\"{\\\"name\\\" : \\\"Adil\\\"}\"}";
	assert(s == s);
}