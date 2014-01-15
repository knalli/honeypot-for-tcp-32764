util = require 'util'

BaseLogger = require './base'


class ConsoleLogger extends BaseLogger

  name: 'Console'

  constructor: (options) ->
    super(options)

  _log: (socket, message) ->
    if socket
      util.log "#{socket[@socketIdKey]} - #{message}"
    else
      util.log message

  _error: (socket, message) ->
    util.error "#{socket[@socketIdKey]} - #{message}"

  # Internal. Log start of a connection and save DB Prefix on socket object.
  doConnectLog: (socket) ->
    socket[@socketIdKey] = "#{socket.remoteAddress}:#{socket.remotePort}"
    @_log socket, 'Connecting...'

  # Internal. Log timeouts to the socket and calculate duration.
  doTimeoutLog: (socket) ->
    @_log socket, "Connection timed out after #{socket.duration/1000}s..."

  doHostnameLog: (socket, domains) ->
    @_log socket, "Reverse DNS: '#{domains.join(',')}'"

  # Internal. Finish up logging this connection. Calculate duration.
  doEndLog: (socket) ->
    @_log socket, "Connection closed after #{socket.duration/1000}s, #{socket.bytesRead} Bytes read and #{socket.bytesWritten} Bytes written"

  # Internal. Log errors on the socket.
  doErrorLog: (socket, error) ->
    @_error socket, "ERROR: #{util.inspect error}"

  # Log messages for this socket. It has to be initialized by LogRedis which is usually done after
  # calling LogRedis.attachToServer(server). 
  doLog: (socket, message) ->
    @_log socket, message


module.exports = ConsoleLogger