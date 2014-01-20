pad = require 'pad'

class Utils

  useUppercase: false

  constructor: ({columns, columnsPerLine, showString, prefixLength, prefixChar, prefixInFirstRow} = {}) ->
    @columns = columns or 8
    @columnsPerLine = columnsPerLine or 2
    @showString = showString isnt false
    @prefixLength = prefixLength or 0
    @prefixChar = prefixChar or ''
    @prefixInFirstRow = prefixInFirstRow isnt false

  ###
    Converts the buffer into a 8bit array of its integer presentation.
  ###
  @bufferToIntArray: (buffer) ->
    length = buffer.length
    offset = 0
    array = []
    while offset < length
      value = buffer.readUInt8(offset)
      array.push value
      offset++
    return array

  @buildHexEntriesByIntArray: (array, startIndex, endIndex) ->
    line = '<'
    for idx in [startIndex...endIndex]
      value = array[idx]
      if typeof value isnt 'undefined'
        line += " #{pad 2, value.toString(16), '0'}"
      else
        line += ' 00'
    line += ' >'
    return line

  ###
    Returns the array (of integers, chrs) as a string wrapped in "[" and "]"
  ###
  @buildChrEntriesByIntArray: (array, startIndex, endIndex) ->
    line = '['
    for idx in [startIndex...endIndex]
      value = array[idx]
      if typeof value isnt 'undefined' and value > 31
        if value > 31
          line += "#{String.fromCharCode(value)}"
        else if value is 0
          line += " "
        else
          # FIXME print out < 32
      else
        line += '.'
    line += ']'
    return line

  @buildTableByBuffer: (data, columns = 8, columnsPerLine = 2, showString = true, prefixLength = 0, prefixChar = ' ', prefixInFirstRow = true) ->
    intArray = @bufferToIntArray data
    lines = []
    for idx in [0..intArray.length] by columns*columnsPerLine
      maxColIdx = columns*columnsPerLine
      line = ''
      if idx > 0 or prefixInFirstRow
        line += new Array(prefixLength).join(prefixChar) if prefixLength and prefixChar
      for idy in [idx...idx+maxColIdx] by columns
        if idy > idx
          line += '    '
        line += @buildHexEntriesByIntArray(intArray, idy, idy + columns)
      if showString
        line += '        '
        line += @buildChrEntriesByIntArray(intArray, idx, idx + (columns*columnsPerLine))
      lines.push line
    return lines.join('\n')

  buildTable: (data) ->
    if Buffer.isBuffer data
      Utils.buildTableByBuffer(data, @columns, @columnsPerLine, @showString, @prefixLength, @prefixChar, @prefixInFirstRow)
    else
      "NOT BUFFER: #{data}"


utils = new Utils
module.exports = {Utils, utils}