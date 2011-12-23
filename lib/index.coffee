# vim: ts=2 sw=2 sts=2

"use strict"

async = require 'async'
fs = require 'fs'
mime = require 'mime'
mmd = require 'musicmetadata'
path = require 'path'
upnp = require 'upnp-device'
mime.define 'audio/flac': ['flac']

# Parse command line options
argv = require('optimist')
  .usage('Usage: $0 -c [directory]')
  .demand('c')
  .alias('c', 'content')
  .describe('c', 'Share the content of directory')
  .argv

dir = argv.c


# Sort `files` after content type into separate arrays in an object.
sortFiles = (dir, files, cb) ->
  sortedFiles = {}
  async.forEach files,
    (file, cb) ->
      fullPath = path.join dir, file
      fs.stat fullPath, (err, stat) ->
        type =
          if stat?.isDirectory() then 'folder'
          else if stat?.isFile() then mime.lookup(file).split('/')[0]
          else 'unknown'
        (sortedFiles[type]?=[]).push fullPath
        cb (if err? then err else null)
    (err) -> cb err, sortedFiles


# Get the key of the biggest array in an object.
getContainerType = (fileTypes) ->
  maxVal = 0
  for key, val of fileTypes when val.length > maxVal
    maxVal = val
    type = key
  type


# Parse tags using musicmediadata module
parseTags = (file, cb) ->
  stream = fs.createReadStream file
  stream.on 'error', (err) -> console.log "#{err.message} - #{stream.path}"
  parser = new mmd stream
  parser.on 'metadata', (data) ->
    # Massage output a little. Will make it easier to switch parsing module
    # in the future.
    data.track = if data.track?.no > 0 then data.track.no else null
    data.year = if data.year > 0 then data.year else null
    data.genre = if data.genre?[0]? then data.genre[0] else null
    data.artist = if data.artist?[0]? then data.artist[0] else null
    data.albumartist = if data.albumartist?[0]? then data.albumartist[0] else null
    cb data
  parser.on 'done', (err) ->
    console.log "#{err.message} - #{stream.path}" if err?
    stream.destroy()


mimeMap =
  container:
    audio: 'object.container.album.musicAlbum'
    image: 'object.container.photoAlbum'
  item:
    audio: 'object.item.audioItem.musicTrack'
    image: 'object.item.imageItem'
    text: 'object.item.textItem'

# Make UPnP objects.
makeObject = (base, type, file, cb) ->
  getDir = if base is 'container' then path.dirname else (p) -> p
  media =
    class: mimeMap[base][type] or "object.#{base}"
    location: getDir file
  filename = path.basename getDir file
  if type is 'audio'
    parseTags file, (data) ->
      if base is 'container'
        media.creator = media.artist = data.albumartist or data.artist or 'Unknown'
        media.title = data.album or filename
      else
        media.creator = media.artist = data.artist or 'Unknown'
        media.title = data.title or filename
        media.album = data.album or 'Untitled'
        media.genre = data.genre if data.genre?
        media.track = data.track if data.track?
        media.date = data.year if data.year?
      cb null, media
  else
    media.creator = 'Unknown'
    media.title = filename
    cb null, media

makeContainer = (sortedFiles, cb) ->
  contentType = getContainerType sortedFiles
  makeObject 'container', contentType, sortedFiles[contentType][0], cb

makeItem = (type, file, cb) ->
  makeObject 'item', type, file, cb


addContainer = (parentId, dir, cb) ->
  fs.readdir dir, (err, files) ->
    # Ignore hidden files.
    files = files.filter (file) -> file[...1] isnt '.'
    sortFiles dir, files, (err, sortedFiles) ->
      makeContainer sortedFiles, (err, container) ->
        mediaServer.addMedia parentId, container, (err, id) ->
          add id, dir, sortedFiles, cb

addItem = (parentId, type, file, cb) ->
  makeItem type, file, (err, item) ->
    mediaServer.addMedia parentId, item, cb

add = (parentId, path, sortedFiles, cb) ->
  async.forEachLimit Object.keys(sortedFiles), 5,
    (type, cb) -> async.forEach sortedFiles[type],
      (item, cb) ->
        if type is 'folder'
          addContainer parentId, item, cb
        else
          addItem parentId, type, item, cb
      cb
    (err) -> cb null


mediaServer = upnp.createDevice 'MediaServer', 'Bragi'

mediaServer.on 'error', (e) -> throw e

mediaServer.on 'ready', ->
  addContainer 0, dir, (err, id) -> throw err if err?
