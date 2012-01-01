redis = require 'redis'
upnp = require 'upnp-device'

db = redis.createClient()
db.on 'error', (err) ->
  if err?
    throw new Error "Database error, make sure redis is installed. #{err.message}"
db.select 10
db.flushdb()


exports.getPath = (id, cb) ->
  db.hget @params.id, 'path', (err, path) =>
    cb path
