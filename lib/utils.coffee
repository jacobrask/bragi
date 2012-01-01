# Extend underscore library with utility functions.

"use strict"

_ = require 'underscore'

# Get the key of the biggest array in an object.
_.mixin getBiggestArray: (fileTypes) ->
  maxVal = 0
  for key, val of fileTypes when val.length > maxVal
    maxVal = val
    type = key
  type


# Sort an object on any number of keys.
# An argument is a string or an object with `name`, `primer`, `reverse`.
_.mixin sortObject: ->
  fields = [].slice.call arguments
  (A, B) ->
    for field in fields
      key = if _.isObject field then field.name else field
      primer = if _.isFunction field.primer then field.primer else (v) -> v
      reverse = if field.reverse then -1 else 1
      a = primer A[key]
      b = primer B[key]
      result =
        if a < b
          reverse * -1
        else if a > b
          reverse * 1
        else
          reverse * 0
      break if result isnt 0
    result


module.exports = _
