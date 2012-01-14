{ EventEmitter } = require 'events'
fs   = require 'fs'
path = require 'path'
url  = require 'url'

mime  = require 'mime'
mmd   = require 'musicmetadata'
upnp = require 'upnp-device'

db    = require './db'
files = require './files'
_     = require './utils'


ms = upnp.createDevice 'MediaServer', 'Bragi'

addPath = exports.addPath = (root, cb) ->
  files.getSortedFiles root, (err, sortedFiles) ->
    if err? or _.isEmpty sortedFiles
      return cb err
    type = _.getBiggestArray sortedFiles
    add type, sortedFiles[type], cb


add = (type, mediaFiles, cb) ->
  if type is 'audio'
    artist = new Artist mediaFiles
    artist.on 'added', ->
      album = new Album mediaFiles, artist
      album.on 'added', ->
        new Track file, album for file in mediaFiles
        cb null
  else
    cb null

hostname = '192.168.9.3'
port = 3000

class MediaObject extends EventEmitter

  constructor: -> @

  addToLibrary: (cb) ->
    obj = _.clone @upnpObject
    db.addToLibrary obj, (err, @id) =>
      if err? then @emit 'error', err else cb()

  addToMediaServer: (cb) ->
    db.getProperty @id, 'upnpId', (err, upnpId) =>
      if err? then return @emit 'error', err
      if upnpId?
        @upnpId = upnpId
        return cb null
      ms.addMedia @parent?.upnpId or 0, @upnpObject, (err, @upnpId) =>
        if err? then return @emit 'error', err
        db.set @id, { upnpId: @upnpId }, (err) =>
          if err? then @emit 'error', err else cb()

  addAsChild: (cb) ->
    db.push @parent.id, { children: @id }, (err) =>
      if err? then @emit 'error', err else cb()


class Artist extends MediaObject

  constructor: (@files) ->
    @makeUpnpObject =>
      @addToLibrary =>
        @addToMediaServer =>
          @emit 'added'
    @

  makeUpnpObject: (cb) ->
    @upnpObject = class: 'object.container.person.musicArtist'
    parseTags @files[0], (data) =>
      @upnpObject.title = data.albumartist or data.artist or 'Unknown'
      cb()


class Album extends MediaObject

  constructor: (@files, @parent) ->
    @makeUpnpObject =>
      @addToLibrary =>
        @addToMediaServer =>
          @addAsChild =>
            @emit 'added'
    @

  makeUpnpObject: (cb) ->
    @upnpObject = class: 'object.container.album.musicAlbum'
    parseTags @files[0], (data) =>
      @upnpObject.artist = data.albumartist or data.artist or 'Unknown'
      @upnpObject.title = data.album or path.basename path.dirname @file
      cb()


class Track extends MediaObject

  constructor: (@file, @parent) ->
    @makeUpnpObject =>
      @upnpObject.path = @file
      @addToLibrary =>
        @upnpObject.location = url.format { protocol: 'http', pathname: "/res/#{@id}", hostname, port }
        @addToMediaServer =>
          @addAsChild =>
            @emit 'added'
    @

  makeUpnpObject: (cb) ->
    @upnpObject = class: 'object.item.audioItem.musicTrack'
    parseTags @file, (data) =>
      @upnpObject.artist = data.artist or 'Unknown'
      @upnpObject.creator = data.artist or 'Unknown'
      @upnpObject.title = data.title or path.basename @file, path.extname @file
      @upnpObject.album = data.album or 'Untitled'
      @upnpObject.genre = data.genre if data.genre?
      @upnpObject.track = data.track if data.track?
      @upnpObject.date = data.year if data.year?
      @upnpObject.contenttype = 'audio/mpeg'
      fs.stat @file, (err, stats) =>
        @upnpObject.filesize = stats?.size or 0
        cb()


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
