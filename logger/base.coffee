util = require 'util'

class BaseLogger

  lookup: false

  # Implement this methods
  doConnectLog: (socket) ->
  doTimeoutLog: (socket) ->
  doHostnameLog: (socket, domains) ->
  doEndLog: (socket) ->
  doErrorLog: (socket, error) ->
  doLog: (socket, message) ->

  # @param lookup - Do DNS lookups for every connect
  # @param redisPrefix - Use prefix for Redis DB Keys
  # @param redisSettings... - Settings for Redis constructor
  constructor: (@lookup = yes) ->
    if @lookup then @dns = require 'dns'
    @socketIdKey = "$_id#{Math.round Math.random() * 10000}"

  # Attach event listeners to the serves' events.
  # @param server - Server Object created by net.createServer()
  bindServer: (server) ->
    util.log "Logger '#{@name}' binds to server..."
    server.on 'connection', (socket) =>
      @connectLog(socket)
      socket.on 'end',      @endLog.bind this, socket
      socket.on 'error',    @errorLog.bind this, socket
      socket.on 'timeout',  @timeoutLog.bind this, socket

  # Internal. Log start of a connection, store on socket object.
  connectLog: (socket) ->
    socket.timeStart = new Date()
    @doConnectLog(socket)
    @hostnameLog(socket) if @lookup

  # Internal. Log timeouts to the socket and calculate duration.
  timeoutLog: (socket) ->
    socket.duration = ((new Date()) - socket.timeStart)
    @doTimeoutLog(socket)
    @db.set "#{socket.dbKey}.duration", socket.duration
    @db.append "#{socket.dbKey}.lastlog", "\nSOCKET-TIMEOUT after #{socket.duration}ms."
  
  # Internal. If LogRedis was initializes with DNS lookup = yes, then do a DNS reverse
  # lookup and log it, asynchronously.
  hostnameLog: (socket) ->
    @dns.reverse socket.remoteAddress, (err, domains) =>
      if err then return console.error "Could not resolve #{socket.remoteAddress} to hostname."
      @doHostnameLog(socket, domains)

  # Internal. Finish up logging this connection. Calculate duration.
  endLog: (socket) ->
    socket.duration = ((new Date()) - socket.timeStart)
    @doEndLog(socket)

  # Internal. Log errors on the socket.
  errorLog: (socket, error) ->
    @doErrorLog(socket, error)

  # Log messages for this socket. It has to be initialized by LogRedis which is usually done after
  # calling LogRedis.attachToServer(server). 
  log: (socket, message) ->
    @doLog(socket, message)


module.exports = BaseLogger