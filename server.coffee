net = require 'net'
util = require 'util'
fs = require 'fs'

# using jspack using the same Pack/Unpack like Python's one
{jspack} = require 'jspack'
# Extending Buffer
require('buffertools').extend()

# Message protocol statics
HEADER_ID = 0x53634D4D
MESSAGE_PACK_FMT = '>III'
WELCOME_HEADER = jspack.Pack MESSAGE_PACK_FMT, [HEADER_ID, 0xFFFFFFFF, 0x00000000]

# Pseudos for the honey pot
PSEUDO_CONF_CONTENT = fs.readFileSync('./pseudo_conf.dat').toString()
PSEUDO_LOCAL_IP = '192.168.1.1'
PSEUDO_PUBLIC_IP = ''
PSEUDO_VERSION = '1.2.3'

pseudoContext = {}
clients = []
logger = new require('LogRedis')()

# TODO: How we get the public ip?
#require('dns').lookup require('os').hostname(), (err, address, fam) ->
#  PSEUDO_PUBLIC_IP = address

# build message data as byte buffer
# @param code - the result/status code
# @param payload - optional string (text)
# @return Buffer
buildMessage = (code, payload = '') ->
  header = jspack.Pack MESSAGE_PACK_FMT, [HEADER_ID, code, payload.length]
  return new Buffer(header).concat(payload, '\x00')

# Logging
log = (socket, message) ->
  util.log "Attacker #{socket.name}: #{message}"
  if logger then logger.log message

# Handle an incoming call and response probably good..
# @param socket - tcp socket
# @param type - message type
# @param payload - optional payload string (text)
handle = (socket, type = 0, payload) ->
  switch type
    when 0
      # Init
      socket.write new Buffer(WELCOME_HEADER)
    when 1
      # Config
      log(socket, "Sending config...")
      buffer = buildMessage 0, PSEUDO_CONF_CONTENT.replace('DATETIME', new Date().toString())
      socket.write buffer
    when 2
      # Get var
      key = payload
      val = pseudoContext[payload]
      log(socket, "Getting pseudo variable #{key} => '#{val}'")
      if typeof val isnt 'undefined'
        socket.write buildMessage 0, val
      else
        socket.write buildMessage 1, "Variable '#{key}' not found."
    when 3
      # Set var
      parts = payload.split('=', 2)
      key = parts[0]
      val = parts[1]
      log(socket, "Setting pseudo variable #{key} => '#{val}'")
      if parts.length >= 2 and key
        pseudoContext[key] = val
        socket.write buildMessage 0, "Variable '#{key}' => '#{val}'."
      else
        socket.write buildMessage 1, "Missing parameters"
    when 4
      log(socket, "commit nvram: #{payload}")
      socket.write buildMessage 1, "Not supported"
    when 5
      log(socket, "bridge mode: #{payload}")
      socket.write buildMessage 1, "Not supported"
    when 6
      log(socket, "show speed: #{payload}")
      socket.write buildMessage 0, "127"
    when 7
      socket._shellIsOpen = true
      log(socket, "execute/cmd: #{payload}")
      switch payload
        when 'cd'
          parts = payload.split(' ', 2)
          socket.write buildMessage 0, "Directory changed to '#{parts[1]}'"
        when 'quit', 'exit', 'bye'
          socket._shellIsOpen = false
          socket.write buildMessage 0, "Exit\n"
          # FIXME destroy too early?
          socket.destroy()
        else
          socket.write buildMessage 0, "#{payload}"
    when 8
      log(socket, "write file: #{payload}")
      socket.write buildMessage 1, "Not supported"
    when 9
      log(socket, "version: #{payload}")
      socket.write buildMessage 0, "#{PSEUDO_VERSION}"
    when 10
      log(socket, "modem router ip")
      socket.write buildMessage 0, "#{PSEUDO_LOCAL_IP}"
    when 11
      log(socket, "resaure default setting")
      socket.write buildMessage 1, "Not supported"
    when 12
      log(socket, "read /dev/mtdblock/0")
      socket.write buildMessage 1, "Not supported"
    when 13
      log(socket, "ump nvram on disk")
      socket.write buildMessage 1, "Not supported"


# Create and open TCP server
server = net.createServer (socket) ->

  # define some socket-only data
  socket.name = "#{socket.remoteAddress}:#{socket.remotePort}"
  log "Client (#{socket.name}) joined..."

  clients.push socket

  socket.on 'data', (buffer) ->
    # Make the "poc.py" be happy with this here.
    if "#{buffer}" is "blablablabla"
      log "Ignore 'blablablabla' request."
      handle socket
      return
    try
      unpackedBuffer = jspack.Unpack(MESSAGE_PACK_FMT, buffer, 0)
      unless unpackedBuffer
        log(socket, "Processing failed: Invalid message")
        handle socket
        return 
      [header, type, payloadLength] = unpackedBuffer
      #console.log util.inspect ({header, type, payloadLength}), colors: true, depth: null
      if "#{header}" is "#{HEADER_ID}"
        #console.log "Processing correct message, type=#{type}, payloadLength=#{payloadLength}"
        # first 12 bytes are for the header above, the rest is payload
        payload = buffer.slice(12).toString()
        # Remove all data after the payload (should be only the zero byte sequence)
        payload = payload.slice(0, payloadLength-1)
        handle socket, type, payload
      else
        log "Skipping message because invalid header: #{header}"
      return
    catch e
      log(socket, "Processing failed: #{e.message}")
      handle socket

  socket.on 'end', ->
    clients.splice(clients.indexOf(socket), 1)
    log "Client (#{socket.name}) left."
    return

  socket.on 'error', (error) ->
    clients.splice(clients.indexOf(socket), 1)
    log "ERROR: #{util.inspect error}"

server.listen 32764

console.log "Honeypot is running at 32764"