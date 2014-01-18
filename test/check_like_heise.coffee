net = require 'net'
util = require 'util'

scmmUtil = new require './../lib/scmm'

socket = net.createConnection 32764, 'localhost'

socket.on 'connect', ->
  util.log 'Send message...'
  socket.write new Buffer [10, 10]
  socket.on 'data', (buffer) ->
    util.log "Received: #{buffer.toJSON()}"
    socket.end()
  socket.on 'end', ->
    util.log 'Socket closed'
    util.log 'Test finished'
  socket.on 'error', (error) ->
    util.error "Socket closed with error: #{error}"
  socket.on 'timeout', ->
    util.error "Socket timed out"
socket.on 'error', ->
  util.error 'Could not connect'

util.log 'Test starting...'