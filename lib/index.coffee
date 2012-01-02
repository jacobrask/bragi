"use strict"

async = require 'async'
upnp = require 'upnp-device'

db = require './db'
files = require './files'
media = require './media'
_ = require './utils'
web = require './web'

ms = upnp.createDevice 'MediaServer', 'Express Test'

# Specifies base categories for content types.
categories =
  audio:
    artists:
      title: 'Artists'
      class: 'person.musicArtist'
    albums:
      title: 'Albums'
      class: 'album.musicAlbum'

db.connect (err) ->
  throw err if err?
  ms.on 'ready', ->
    files.getSortedFiles '/home/jacob/music/Argentum-Salve_Victoria-2011', (err, sortedFiles) ->
      addToCategories sortedFiles, (err, foo) -> console.log err if err?

getCategoryUpnpId = (category, cb) ->
  return cb null, category.upnpId if category.upnpId?
  ms.addMedia 0, { title: category.title, class: 'object.container' }, (err, upnpId) ->
    return cb err if err?
    category.upnpId = upnpId
    db.addToLibrary { title: category.title, upnpId }, (err, doc) ->
      return cb err if err?
      cb null, upnpId

addToCategories = (sortedFiles, cb) ->
  type = _.getBiggestArray sortedFiles
  file = sortedFiles[type][0]
  async.forEach Object.keys(categories[type]),
    (name, cb) ->
      addInCategory categories[type][name], file, cb
    (err) -> cb err

addInCategory = (category, file, cb) ->
  media.makeContainerObject category.class, file, (err, obj) ->
    getCategoryUpnpId category, (err, upnpId) ->
      ms.addMedia category.upnpId, obj, (err, id) ->
        obj.upnpId = id
        db.addToLibrary obj, cb

  ###
  web.listen 3000
  console.log "Bragi web interface started at http://#{web.address().address}:#{web.address().port}"
