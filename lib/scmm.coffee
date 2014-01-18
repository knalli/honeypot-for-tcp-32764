{jspack} = require 'jspack'
# Extending Buffer
require('buffertools').extend()

SCM_MAGIC = 0x53634D4D
SCM_MAGIC_BE = SCM_MAGIC
SCM_MAGIC_LE = 0x4D4D6353

util = require 'util'
class Utils

  @FORMATS:
    'LE': '<III'
    'BE': '>III'

  @resolveEndianness: (buffer) ->
    unpackedBuffer = jspack.Unpack(Utils.FORMATS.BE, buffer, 0)
    return 'BE' unless unpackedBuffer
    switch unpackedBuffer[0]
      when SCM_MAGIC_BE
        'BE'
      when SCM_MAGIC_LE
        'LE'

  @unpackFromBuffer: (endianness = 'BE', buffer) ->
    unpackedBuffer = jspack.Unpack(Utils.FORMATS[endianness], buffer, 0)
    unless unpackedBuffer
      return
    [header, type, payloadLength] = unpackedBuffer
    return {header, type, payloadLength}

  @packToBuffer: (endianness = 'BE', code = 0, payload = '') ->
    header = jspack.Pack Utils.FORMATS[endianness], [SCM_MAGIC, code, payload.length]
    return new Buffer(header).concat(payload, '\x00')

  @createInitSequence: (endianness = 'BE') ->
    jspack.Pack Utils.FORMATS[endianness], [SCM_MAGIC, 0xFFFFFFFF, 0x00000000]

  @createInitSequenceBuffer: (endianness = 'BE') ->
    new Buffer @createInitSequence endianness


module.exports = {Utils, SCM_MAGIC}