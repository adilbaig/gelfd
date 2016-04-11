module gelf.transport;

private
    import std.socket : Socket;
    import gelf.protocol : Message;
    
public:

    enum MAX_CHUNKS = 128; //"A message MUST NOT consist of more than 128 chunks."

    /**
    This function provides a convenient way to send chunked GELF messages to Graylog.
    It automatically chunks a message based on $(D_PARAM packetSizeBytes).

    Params:
         packetSizeBytes = The size of each chunk in bytes. Default : 81924
         compressed      = If true, compress the message using zlib. Default : false

    Throws: Exception if # of chunks > 128.

    Examples:
    -------------------------
    auto s = new UdpSocket();
    s.connect(new InternetAddress("localhost", 12200));

    // Start netcat to watch this packet : `nc -lu 12200`
    s.sendChunked(gelfMessage, 500);
    -------------------------

    Returns: The number of packets sent
    */
    auto sendChunked(Socket socket, Message message, uint packetSizeBytes = 8192, bool compressed = false)
    {
        import std.zlib;
        return chunkAndSend(socket, (compressed) ? compress(message.toString()) : cast(ubyte[])message.toString(), packetSizeBytes);
    }

private:

    pragma(inline):
    auto chunkAndSend(Socket socket, const(ubyte[]) message, uint packetSizeBytes)
    {
        import std.random : uniform;
        import std.outbuffer : OutBuffer;
        import std.range : chunks;
    
        auto msgLength = message.length;
        if(msgLength < packetSizeBytes) {
            socket.send(message);
            return 1;
        }

        auto t = (msgLength / packetSizeBytes) + 1;
        if (t > MAX_CHUNKS) {
            throw new Exception("Message too large");
        }

        ubyte total = cast(ubyte)t;
        ulong messageId = uniform(0, long.max);

        auto buffer = new OutBuffer();
        buffer.reserve(packetSizeBytes);

        byte sequenceNo = 0;
        auto chks = chunks(message, packetSizeBytes - 12);
        foreach(c; chks) {
            buffer.offset = 0;
            buffer.write(cast(ubyte)0x1e);
            buffer.write(cast(ubyte)0x0f);
            buffer.write(messageId);
            buffer.write(sequenceNo++);
            buffer.write(total);
            buffer.write(c);

            socket.send(buffer.toBytes());
        }

        return total;
    }
