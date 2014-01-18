# Logging to redis
redis = require 'redis'
util = require 'util'

BaseLogger = require './base'

###
  Logger class for 'honeypot-for-tcp-32764'
  An instance of this logger has to be attached to a Server instance at first place! 
  Otherwise, the sockets aren't initialized correctly.
  The following example adds three loggers:
   - The first one sets DNS Reverse-Lookups to yes, and prefixes all Keys with 'honey1'. 
     That means, if an attacker has ip 1.2.3.4, you can get the logs 
     by redis command "GET honey1.'1.2.3.4'.lastlog". The defaults for the redis connection 
     are used, which are localhost at port 6379.
   - The second logger does not do DNS reverse lookups, uses prefix 'honey2' and connects to
     'server2' at redis default port. For convinience, this is a constant in LogRedis.
   - The third logger does not do DNS reverse lookups, uses prefix 'honey3' and connects to 
     'server3' at port '1234'. Additionally, this add a custom options map.
     
    LogRedis = require './LogRedis'
    loggers = [
      new LogRedis(yes, {prefix: 'honey1'})
      new LogRedis(no , {prefix: 'honey2', port: LogRedis.DEFAULT_REDIS_PORT, host: 'server'})
      new LogRedis(no , {prefix: 'honey3', port: 1234, host: 'server', options: {no_ready_check: true}})
    ]
###
class RedisLogger extends BaseLogger

  name: 'Redis'

  # The redis connection port can be ommited to use the lib's default
  # For easier reading, this var can be used, anyway
  @DEFAULT_REDIS_PORT: null #6379

  # @param lookup - Do DNS lookups for every connect
  # @param options
  #                prefix - Optional: Use prefix for Redis DB Keys
  #                host - Optional: server host
  #                port - Optional: server port
  #                options -Optional: Options for Redis constructor
  constructor: (options) ->
    super(options)
    @redisPrefix = options.prefix or ''
    if @redisPrefix?.substr(-1) isnt '.'
      @redisPrefix += '.'
    redisPort = options?.port or RedisLogger.DEFAULT_REDIS_PORT
    redisHost = options?.host or 'localhost'
    redisOptions = options?.options or []
    unless Object::toString.call(redisOptions) is '[object Array]'
      redisOptions = [ redisOptions ]
    @db = redis.createClient redisPort, redisHost, redisOptions

  # Internal. Log start of a connection and save DB Prefix on socket object.
  doConnectLog: (socket) ->
    socket.dbKey = "#{@redisPrefix}'#{socket.remoteAddress}'"
    @db.incr "#{socket.dbKey}.cnt"
    @db.set "#{socket.dbKey}.date", socket.timeStart

  # Internal. Log timeouts to the socket and calculate duration.
  doTimeoutLog: (socket) ->
    @db.set "#{socket.dbKey}.duration", socket.duration
    @db.append "#{socket.dbKey}.lastlog", "\nSOCKET-TIMEOUT after #{socket.duration}ms."
  
  # Internal. If LogRedis was initializes with DNS lookup = yes, then do a DNS reverse
  # lookup and log it, asynchronously.
  doHostnameLog: (socket, domains) ->
    @db.set "#{socket.dbKey}.hostnames", domains.join ','

  # Internal. Finish up logging this connection. Calculate duration.
  doEndLog: (socket) ->
    @db.set "#{socket.dbKey}.duration", socket.duration
    @db.append "#{socket.dbKey}.lastlog", "\nSocket hungup. 
      #{socket.bytesRead} Bytes read and 
      #{socket.bytesWritten} Bytes written.\n"

  # Internal. Log errors on the socket.
  doErrorLog: (socket, error) ->
    @db.append "#{socket.dbKey}.lastlog", "\nSOCKET-ERROR:" + util.inspect error

  # Log messages for this socket. It has to be initialized by LogRedis which is usually done after
  # calling LogRedis.attachToServer(server). 
  doLog: (socket, message) ->
    unless socket.dbKey?
      return console.error "Socket not initialized to log to redis. Attach server to this logger first!"
    @db.append "#{socket.dbKey}.lastlog", "\n" + message


module.exports = RedisLogger