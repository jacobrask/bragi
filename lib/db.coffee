"use strict"

redis = require 'redis'

db = redis.createClient()
db.on 'error', (err) ->
  if err?
    throw new Error "Database error, make sure redis is installed. #{err.message}"
db.select 10
db.flushdb()


exports.getPath = (id, cb) ->
  db.hget @params.id, 'path', (err, path) =>
    cb path
    
exports.addPath = (id, cb) ->
  db.hget @params.id, 'path', (err, path) =>
    cb path
