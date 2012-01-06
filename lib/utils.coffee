# Extend underscore library with utility functions.

"use strict"

async = require 'async'
_ = require 'underscore'

_.async = async

# Get the key of the biggest array in an object.
_.mixin getBiggestArray: (fileTypes) ->
  maxVal = 0
  for key, val of fileTypes when val.length > maxVal
    maxVal = val
    type = key
  type


module.exports = _
