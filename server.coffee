net = require 'net'
util = require 'util'
FS = require 'fs'
p = require 'path'
Q = require 'q'

# using jspack using the same Pack/Unpack like Python's one
{jspack} = require 'jspack'
# Extending Buffer
require('buffertools').extend()

DEFAULT_CONFIG =
  loggers: [ 
    (name: 'console', enabled: true)
    (name: 'redis',   enabled: false)
  ]

# Message protocol statics
PORT = 32764
SCM_MAGIC = 0x53634D4D
MESSAGE_PACK_FMT = '>III'
WELCOME_HEADER = jspack.Pack MESSAGE_PACK_FMT, [SCM_MAGIC, 0xFFFFFFFF, 0x00000000]

# Pseudos for the honey pot
PSEUDO_LOCAL_IP = '192.168.1.1'
PSEUDO_PUBLIC_IP = ''
PSEUDO_VERSION = 'R.000000'
PSEUDO_CONFIGURATIONS = []

# Read configuration examples
readDirFiles = (path) -> 
  readDir = Q.denodeify FS.readdir
  readFile = Q.denodeify FS.readFile
  readDir(path).then (files) ->
    # extract to complete relative paths
    files.map (file) -> p.join(path, file)
  .then (files) ->
    # spawn reads per file
    Q.all files.map readFile

loadConfig = ->
  config = try
    config = require './config.json'
    util.log "Using local configuration file: config.json"
    for own key, value of DEFAULT_CONFIG when not config[key]
      config[key] = value
    config
  catch
    DEFAULT_CONFIG
  util.log "Active configuration is"
  util.log util.inspect config, colors: true, depth: null
  return config

loadLoggers = (appConfig) ->
  onlyEnabled = (config) ->
    config?.enabled is true
  notNull = (object) ->
    typeof object isnt 'undefined'
  requireModule = (config) ->
    try 
      new (require "./logger/#{config.name}")(config.options)
    catch e
      util.error "Could not find logger #{config.name} -- caused by #{e.message}"
  appConfig.loggers.filter(onlyEnabled).map(requireModule).filter(notNull)

readDirFiles('./pseudo_data').then (contents) ->
  PSEUDO_CONFIGURATIONS = contents
  log null, "Found #{contents.length} pseudo configurations."

pseudoContext = {}
clients = []
appConfig = loadConfig()
loggers = loadLoggers(appConfig)

# Configure publicIpResolve.url to any Server which responses your public ip as text
if appConfig.publicIpResolve?.enabled and appConfig.publicIpResolve.url
  require('http').request(appConfig.publicIpResolve.url, (res) ->
    res.on "data", (chunk) -> PSEUDO_PUBLIC_IP += chunk
    res.on "end", -> util.log "Resolved public ip to #{PSEUDO_PUBLIC_IP}"
  ).end()

# build message data as byte buffer
# @param code - the result/status code
# @param payload - optional string (text)
# @return Buffer
buildMessage = (code, payload = '') ->
  header = jspack.Pack MESSAGE_PACK_FMT, [SCM_MAGIC, code, payload.length]
  return new Buffer(header).concat(payload, '\x00')

# Logging
log = (socket, message) ->
  if loggers?.length
    for logger in loggers
      try logger.log socket, message


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
      socket.write buildMessage 0, PSEUDO_CONFIGURATIONS[socket.$_pseudoConfigurationKey]
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
      socket.write buildMessage 0, "#{PSEUDO_VERSION}\x00"
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
server = net.createServer()

# attach loggers
if loggers?.length
  for logger in loggers
   logger.bindServer server

server.on 'connection', (socket) ->

  # define some socket-only data
  socket.name = "#{socket.remoteAddress}:#{socket.remotePort}"
  log(socket, "Client joined...")

  # Choose a configuration random per socket
  socket.$_pseudoConfigurationKey = Math.floor Math.random() * PSEUDO_CONFIGURATIONS.length

  clients.push socket

  socket.on 'data', (buffer) ->
    # Make the "poc.py" be happy with this here.
    if "#{buffer}" is "blablablabla"
      log(socket, "Ignore 'blablablabla' request, maybe this is a test by 'poc.py'.")
      handle socket
      return
    try
      log(socket, "Message as bytes: [#{buffer.toJSON()}]")
      unpackedBuffer = jspack.Unpack(MESSAGE_PACK_FMT, buffer, 0)
      unless unpackedBuffer
        log(socket, "Processing failed: Invalid message")
        handle socket
        return 
      [header, type, payloadLength] = unpackedBuffer
      #console.log util.inspect ({header, type, payloadLength}), colors: true, depth: null
      if "#{header}" is "#{SCM_MAGIC}"
        #console.log "Processing correct message, type=#{type}, payloadLength=#{payloadLength}"
        # first 12 bytes are for the header above, the rest is payload
        payload = buffer.slice(12).toString()
        # Remove all data after the payload (should be only the zero byte sequence)
        payload = payload.slice(0, payloadLength-1)
        handle socket, type, payload
      else
        log(socket, "Skipping message because invalid header: #{header}")
      return
    catch e
      log(socket, "Processing failed: #{e.message}")
      handle socket

  socket.on 'end', ->
    log(socket, "Client left")
    clients.splice(clients.indexOf(socket), 1)

  socket.on 'error', (error) ->
    log(socket, "Connection to client crashed")
    clients.splice(clients.indexOf(socket), 1)

server.listen PORT, ->
  log null, "Honeypot is running at #{PORT}"

log null, 'Starting Honeypot for router backdoor "TCP32764"...'
