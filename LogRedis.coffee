# Logging to redis
redis = require 'redis'
util = require 'util'

###
  Logger class for 'honeypot-for-tcp-32764'
  An instance of this logger has to be attached to a Server instance at first place! 
  Otherwise, the sockets aren't initialized correctly.
  The following example adds two loggers:
   - The first one sets DNS Reverse-Lookups to yes, and prefixes all Keys with 'honey1'. 
     That means, if an attacker has ip 1.2.3.4, you can get the logs 
     by redis command "GET honey1.'1.2.3.4'.lastlog". The defaults for the redis connection 
     are used, which are localhost at port 6379.
   - The second Logger does not do DNS reverse Lookups, uses prefix 'honey2' and connects to
     'server2' at redis default port. For convinience, this is a constant in LogRedis.
     
    LogRedis = require './LogRedis'
    loggers = [
      new LogRedis(yes, 'honey1')
      new LogRedis(no , 'honey2',  LogRedis.DEFAULT_REDIS_PORT, 'server')
    ]
###
module.exports = class LogRedis
  # The redis connection port can be ommited to use the lib's default
  # For easier reading, this var can be used, anyway
  @DEFAULT_REDIS_PORT=null

  # @param lookup - Do DNS lookups for every connect
  # @param redisPrefix - Use prefix for Redis DB Keys
  # @param redisSettings... - Settings for Redis constructor
  constructor: (@lookup=yes, @redisPrefix='', redisSettings...) ->
    if @lookup then @dns = require 'dns'
    if @redisPrefix?.substr(-1) isnt '.'
      @redisPrefix += '.'
    @db = redis.createClient redisSettings...

  # Attach event listeners to the serves' events.
  # @param server - Server Object created by net.createServer()
  attachToServer: (server) ->
    server.on 'connection', (socket) =>
      @connectLog socket
      socket.on 'end',      @endLog.bind @, socket
      socket.on 'error',    @errorLog.bind @, socket
      socket.on 'timeout',  @timeoutLog.bind @, socket

  # Internal. Log start of a connection and save DB Prefix on socket object.
  # Also used to save start time on socket object.
  connectLog: (socket) ->
    socket.timeStart = timeStart = new Date()
    socket.dbKey = "#{@redisPrefix}'#{socket.remoteAddress}'"
    @db.incr "#{socket.dbKey}.cnt"
    @db.set "#{socket.dbKey}.date", timeStart
    if @lookup then @hostnameLog(socket)

  # Internal. Log timeouts to the socket and calculate duration.
  timeoutLog: (socket) ->
    duration = ((new Date()) - socket.timeStart)
    @db.set "#{socket.dbKey}.duration", duration
    @db.append "#{socket.dbKey}.lastlog", "\nSOCKET-TIMEOUT after #{duration}ms."
  
  # Internal. If LogRedis was initializes with DNS lookup = yes, then do a DNS reverse
  # lookup and log it, asynchronously.
  hostnameLog: (socket) ->
    @dns.reverse socket.remoteAddress, (err, domains) =>
      if err then return console.error "Could not resolve #{socket.remoteAddress} to hostname."
      @db.set "#{socket.dbKey}.hostnames", domains.join ','

  # Internal. Finish up logging this connection. Calculate duration.
  endLog: (socket) ->
    @db.set "#{socket.dbKey}.duration", (new Date())-socket.timeStart
    @db.append "#{socket.dbKey}.lastlog", "\nSocket hungup. 
      #{socket.bytesRead} Bytes read and 
      #{socket.bytesWritten} Bytes written.\n"

  # Internal. Log errors on the socket.
  errorLog: (socket, error) ->
    @db.append "#{socket.dbKey}.lastlog", "\nSOCKET-ERROR:" + util.inspect error

  # Log messages for this socket. It has to be initialized by LogRedis which is usually done after
  # calling LogRedis.attachToServer(server). 
  log: (socket, message) ->
    unless socket.dbKey?
      return console.error "Socket not initialized to log to redis. Attach server to this logger first!"
    @db.append "#{socket.dbKey}.lastlog", "\n" + message
