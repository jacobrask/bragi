"use strict"

upnp = require 'upnp-device'

db = require './db'

# `web` module exports Express `app`
web = require './web'

db.start (err) ->
  throw err if err?
  web.listen 3000
  console.log "Bragi web interface started at http://#{web.address().address}:#{web.address().port}"
