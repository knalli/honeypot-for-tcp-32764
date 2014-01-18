net = require 'net'
util = require 'util'
colors = require 'colors'
ScmmUtil = require('./../lib/scmm').Utils

###
  Acts like an attacker using Little Endianness (i.e. the web test router-backdoor.de)
###

socket = net.createConnection 32764, 'localhost'
socket.setTimeout 5000

socket.on 'connect', ->
  util.log 'Send message...'
  socket.write ScmmUtil.packToBuffer 'LE'
  socket.on 'data', (buffer) ->
    util.log "Received: Raw:        #{buffer.toJSON()}"
    util.log "          Endianness: #{ScmmUtil.resolveEndianness(buffer)}"
    util.log "          Unpacked:   #{util.inspect ScmmUtil.unpackFromBuffer('LE', buffer)}"
    util.log "Test finished OK".green
    socket.end()
socket.on 'error', ->
  util.error 'Could not connect'.red
socket.on 'error', (error) ->
  util.error "Socket closed with error: #{error}".red
socket.on 'timeout', ->
 util.error "Socket timed out".red
 socket.end()
socket.on 'end', ->
  util.log 'Socket closed'

util.log 'Test starting...'