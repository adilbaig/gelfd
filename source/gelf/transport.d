module gelf.transport;

private
    import std.socket : Socket;
    import gelf.protocol : Message;
    
public:

    enum MAX_CHUNKS = 128; //"A message MUST NOT consist of more than 128 chunks."

    /**
     This struct converts a Message into chunks as defined in http://docs.graylog.org/en/latest/pages/gelf.html#chunked-gelf
     
     It is an InputRange.
     */
    struct Chunks {

        import std.outbuffer : OutBuffer;
        import std.range : Chunks;
        import std.random : uniform;
        
        private :
            Chunks!(const(ubyte)[]) byteChunks;
            OutBuffer buffer;
            ulong messageId;
            byte sequenceNo;
            ubyte total;
        
        public:
        
        /**
         Convert a Message into chunks
         
         Params:
             message   = The message to compress
             chunkSize = The size of each chunk in bytes. Default : 8192
             
         Throws: MessageTooLargeException if # of chunks > 128.
         */
        this(Message message, uint chunkSize = 8192)
        {
            this(message.toBytes(), chunkSize);
        }
        
        /**
         In LDC 0.17.2, std.zlib.compress returns in const(void)[].
         This ctor is the fix for now. Remove when LDC catches up.
         */
        this(const void[] message, uint chunkSize = 8192, ulong messageId = uniform(0, ulong.max))
        {
        	this(cast(ubyte[]) message, chunkSize, messageId);
        }
        
        /**
         Use this when you've converted a message to bytes. Use this after you have compressed your message
         
         Params:
             message   = The compressed message.
             chunkSize = The size of each chunk in bytes. Default : 8192 
             messageId = The messageId. Do not use this, it is only used for unittests. Default : uniform(0, ulong.max) 
             
         Throws: MessageTooLargeException if # of chunks > 128.
         */
        this(const ubyte[] message, uint chunkSize = 8192, ulong messageId = uniform(0, ulong.max))
        {
            auto t = (message.length / (chunkSize - 12)) + 1;
            if (t > MAX_CHUNKS) {
                import std.conv : to;
                throw new MessageTooLargeException("Message has "~ to!string(t) ~" chunks. Cannot be larger than " ~ MAX_CHUNKS ~ " chunks");
            }
            
            this.messageId = messageId;
            sequenceNo = 0;
            
            buffer = new OutBuffer();
            buffer.reserve(chunkSize);

            import std.range : chunks;    
            byteChunks = chunks(message, chunkSize - 12);
            total = cast(ubyte)byteChunks.length();
        }
        
        ubyte[] front() {
            buffer.offset = 0;
            buffer.write(cast(ubyte)0x1e);
            buffer.write(cast(ubyte)0x0f);
            buffer.write(messageId);
            buffer.write(sequenceNo);
            buffer.write(total);
            buffer.write(byteChunks[sequenceNo]);
            
            return buffer.toBytes();
        }
    
        void popFront() {
            sequenceNo++;
        }
        
        bool empty() {
            return !(sequenceNo < byteChunks.length());
        }
        
        auto length() {
            return byteChunks.length();
        }
    }
    
    /**
    This function provides a convenient way to send chunked GELF messages to Graylog.
    It automatically chunks a message based on $(D_PARAM packetSizeBytes).

    Params:
         packetSizeBytes = The size of each chunk in bytes. Default : 8192
         compressed      = If true, compress the message using zlib. Default : false

    Throws: Exception if # of chunks > 128.

    Examples:
    -------------------------
    auto s = new UdpSocket();
    s.connect(new InternetAddress("localhost", 12200));

    // Start netcat to watch this packet : `nc -lu 12200`
    s.sendChunked(gelfMessage, 500);
    -------------------------

    Returns: void
    */
    auto sendChunked(Socket socket, Message message, uint packetSizeBytes = 8192, bool compressed = false)
    {
        import std.zlib;
        foreach(c; Chunks((compressed) ? cast(ubyte[])compress(message.toString()) : message.toBytes(), 500))
            socket.send(c);
    }

    class MessageTooLargeException : Exception {
        this(string msg) { super(msg); }
    }

unittest {
    
    auto m = Message("localhost","An alert message");
//    import std.stdio;
//    writeln(m.toBytes, m.toBytes().length);

    import std.random : uniform;
    auto mid = uniform(0, ulong.max);
    auto chunks = Chunks(m.toBytes, 20, mid);
    foreach(c; chunks) {
//        writeln(c);
        assert(c[0 .. 2] == [0x1e, 0x0f]); //Magic bytes
        
        import std.bitmanip : littleEndianToNative;
        
        ubyte[8] bytes = c[2 .. 10];
        assert(littleEndianToNative!ulong(bytes) == mid); // 8byte message id
        
        assert(c[11] == (m.toBytes().length / (20 - 12)) + 1); //1 byte - Total number of chunks this message has
    }
    
    import std.zlib : compress;
    
    auto compressed = compress(m.toBytes);
    chunks = Chunks(compressed, 20, mid);
    foreach(c; chunks) {
        assert(c[11] == (compressed.length / (20 - 12)) + 1); //1 byte - Total number of chunks this message has
    }
    
    // Check if message is smaller than chunk length, then it makes one chunk only
    chunks = Chunks(m.toBytes, cast(uint)(m.toBytes.length + 12), mid);
    foreach(c; chunks) {
        assert(c[11] == 1); //Only 1 chunk
    }
}