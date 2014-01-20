utils = new (require('../lib/bytes').Utils)(prefixLength: 19, prefixChar: ' ', prefixInFirstRow: false)
util = require 'util'

util.log utils.buildTable "String"
util.log utils.buildTable new Buffer [77, 77, 99, 83, 0x5353D4D4, 2, 3, 4, 5, 6, 7, 8, 9, 10, 77, 77, 99, 83, 0x5353D4D4, 2, 3, 4, 5, 6, 7, 8, 9, 10]