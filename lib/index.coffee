"use strict"

async = require 'async'
ffmpeg = require 'fluent-ffmpeg'
fs = require 'fs'
mime = require 'mime'
mmd = require 'musicmetadata'
path = require 'path'
redis = require 'redis'
upnp = require 'upnp-device'
url = require 'url'

mime.define 'audio/flac': ['flac']

# Parse command line options
argv = require('optimist')
  .usage('Usage: $0 -c [directory] -p [port]')
  .demand('c')
  .alias('c', 'content')
  .describe('c', 'Share the content of directory')
  .alias('p', 'port')
  .describe('p', 'Start web interface on port')
  .argv

dir = argv.c
port = argv.port or 3333
hostname = '192.168.9.3'

db = redis.createClient()
db.on 'error', (err) -> throw err
db.select 10
db.flushdb()


# Sort `files` after content type into separate arrays in an object.
sortFiles = (dir, files, cb) ->
  sortedFiles = {}
  # Ignore hidden files.
  files = files.filter (file) -> file[...1] isnt '.'
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
  db.incr 'nextid', (err, dbId) ->
    db.hset dbId, 'path', file
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

makeContainer = (sortedFiles, cb) ->
  contentType = getContainerType sortedFiles
  makeObject 'container', contentType, sortedFiles[contentType][0], cb

makeItem = (type, file, cb) ->
  makeObject 'item', type, file, cb


addContainer = (parentId, dir, cb) ->
  fs.readdir dir, (err, files) ->
    sortFiles dir, files, (err, sortedFiles) ->
      makeContainer sortedFiles, (err, container) ->
        mediaServer.addMedia parentId, container, (err, id) ->
          add id, dir, sortedFiles, cb

addItem = (parentId, type, file, cb) ->
  makeItem type, file, (err, item) ->
    mediaServer.addMedia parentId, item, cb

add = (parentId, path, sortedFiles, cb) ->
  async.forEachSeries Object.keys(sortedFiles),
    (type, cb) -> async.forEachLimit sortedFiles[type], 5,
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
  fs.readdir dir, (err, files) ->
    sortFiles dir, files, (err, sortedFiles) ->
      add 0, dir, sortedFiles, ->
        console.log "Added #{dir} to MediaServer."


require('zappa') port, ->
  @get '/res/:id': ->
    db.hget @params.id, 'path', (err, path) =>
      # Transcode to mp3 using ffmpeg
      @response.contentType 'mp3'
      prov = new ffmpeg(path)
        .withAudioCodec('libmp3lame')
        .toFormat('mp3')
        .writeToStream @response, (ret, err) ->
          console.log err if err?
