{jspack} = require 'jspack'
# Extending Buffer
require('buffertools').extend()

SCM_MAGIC = 0x53634D4D
SCM_MAGIC_2 = 0x4D4D6353

class Utils

  @FORMATS:
    'LE': '<III'
    'BE': '>III'

  @resolveEndianness: (buffer) ->
    unpackedBuffer = jspack.Unpack(Utils.FORMATS.BE, buffer, 0)
    unless unpackedBuffer
      unpackedBuffer = jspack.Unpack(Utils.FORMATS.LE, buffer, 0)
      return unless unpackedBuffer
      return unless unpackedBuffer[0] is SCM_MAGIC_2
      'LE'
    return unless unpackedBuffer[0] is SCM_MAGIC
    'BE'

  @unpackFromBuffer: (endianness = 'BE', buffer) ->
    unpackedBuffer = jspack.Unpack(Utils.FORMATS[endianness], buffer, 0)
    unless unpackedBuffer
      return
    [header, type, payloadLength] = unpackedBuffer
    {header, type, payloadLength}

  @packToBuffer: (endianness = 'BE', code = 0, payload = '') ->
    header = jspack.Pack Utils.FORMATS[endianness], [SCM_MAGIC, code, payload.length]
    return new Buffer(header).concat(payload, '\x00')


module.exports = {Utils, SCM_MAGIC}