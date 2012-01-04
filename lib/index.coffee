"use strict"

db = require './db'
web = require './web'

db.connect (err) ->
  console.error err if err?
  web.listen 3000
  console.log "Bragi web interface started at http://#{web.address().address}:#{web.address().port}"
