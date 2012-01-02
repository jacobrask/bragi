fs   = require 'fs'
path = require 'path'
url  = require 'url'

async = require 'async'
mime  = require 'mime'
mmd   = require 'musicmetadata'

db    = require './db'
files = require './files'
_     = require './utils'

# Parse tags using musicmetadata module.
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


hostname = 'localhost'
port = 3000

exports.makeContainerObject = (baseClass, file, cb) ->
  obj = {}
  obj.class = "object.container#{if baseClass? then '.' + baseClass else ''}"

  switch baseClass
    when 'album.musicAlbum'
      parseTags file, (data) ->
        obj.artist = data.albumartist or data.artist or 'Unknown'
        obj.title = data.album
        cb null, obj
    when 'person.musicArtist'
      parseTags file, (data) ->
        obj.title = data.albumartist or data.artist or 'Unknown'
        cb null, obj
    else
      obj.title ?= path.basename path.dirname file
      cb null, obj


# Make UPnP objects.
makeUpnpObject = (base, dbId, type, file, cb) ->
  media = class: mimeMap[base][type] or "object.#{base}"
  filename =
    if base is 'container'
      # `file` is a file in the directory/container, get the parent dir name.
      path.basename path.dirname file
    else
      path.basename file, path.extname file
      media.location = url.format { protocol: 'http', pathname: "/res/#{dbId}", hostname, port }
  if type is 'audio'
    parseTags file, (data) ->
      if base is 'container'
        media.creator = media.artist = data.albumartist or data.artist or 'Unknown'
        media.title = data.album or filename
        cb null, media
      else
        media.creator = media.artist = data.artist or 'Unknown'
        media.title = data.title or filename
        media.album = data.album or 'Untitled'
        media.genre = data.genre if data.genre?
        media.track = data.track if data.track?
        media.date = data.year if data.year?
        media.contenttype = 'audio/mpeg'
        fs.stat file, (err, stats) ->
          media.filesize = stats?.size or 0
          cb null, media
  else
    media.creator = 'Unknown'
    media.title = filename
    if base is 'item'
      media.contenttype = mime.lookup file
      fs.stat file, (err, stats) ->
        media.filesize = stats?.size or 0
        cb null, media
    else
      cb null, media

makeContainer = (dbId, sortedFiles, cb) ->
  contentType = _.getBiggestArray sortedFiles
  makeUpnpObject 'container', dbId, contentType, sortedFiles[contentType][0], cb

makeItem = (dbId, type, file, cb) ->
  makeUpnpObject 'item', dbId, type, file, cb


makeStorageObject = (dir, cb) ->
  db.add { path: dir }, (err, obj) ->
    cb err, obj[0]._id

addContainer = exports.addContainer = (parentId, dir, cb) ->
  makeStorageObject dir, (err, dbId) ->
    files.getSortedFiles dir, (err, sortedFiles) ->
      makeContainer dbId, sortedFiles, (err, container) ->
        console.log container
        add 0, dir, sortedFiles, cb
      ###
      mediaServer.addMedia parentId, container, (err, id) ->
        add id, dir, sortedFiles, cb
      ###

addItem = (parentId, type, file, cb) ->
  makeStorageObject file, (err, dbId) ->
    makeItem dbId, type, file, (err, item) ->
      console.log item
    #mediaServer.addMedia parentId, item, cb

add = (parentId, path, sortedFiles, cb) ->
  async.forEachSeries Object.keys(sortedFiles),
    (type, cb) -> async.forEachLimit sortedFiles[type], 5,
      (item, cb) ->
        if type is 'folder'
          addContainer parentId, item, cb
        else
          addItem parentId, type, item, cb
      cb
    (err) -> cb err
