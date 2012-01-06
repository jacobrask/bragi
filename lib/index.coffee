"use strict"

db = require './db'
web = require './web'

db.init (err) ->
  throw err if err?
  web.listen 3000
  console.log "Bragi web interface started at http://#{web.address().address}:#{web.address().port}"
