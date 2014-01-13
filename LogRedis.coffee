# Logging to redis
db = require 'redis'


module.exports = class LogRedis

  constructor: (@redisPrefix, @lookup=yes) ->
    if lookup then @dns = require 'dns'

  attachToSocket: (socket) ->
    socket.on 'connect', @connectLog
    socket.on 'end', @endLog
    socket.on 'error', @errorLog

  connectLog: (socket) ->
    socket.timeStart = timeStart = new Date()
    socket.dbKey = "#{@redisPrefix}.'#{socket.remoteAddress}'"
    db.incr "#{socket.dbKey}.cnt"
    db.set "#{socket.dbKey}.date", timeStart
    if @lookup then @hostnameLog(socket)
      
  hostnameLog: (socket) ->
    @dns.reverse socket.remoteAddress, (err, domains) =>
      if err then return console.error "Could not resolve #{socket.remoteAddress} to hostname."
      @db.set "#{socket.dbKey}.hostnames", domains.join ','

  endLog: (socket) ->
    @db.set "#{socket.dbKey}.duration", (new Date())-socket.timeStart

  errorLog: (socket) ->
    console.error "ERROR, Not yet implemented"

  log: (socket, message) ->
    console.error "ERROR, Not yet implemented, MSG: '#{message}'"