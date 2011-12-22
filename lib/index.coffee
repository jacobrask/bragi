argv = require('optimist')
    .usage('Usage: $0 -c [directory]')
    .demand('c')
    .alias('c', 'content')
    .describe('c', 'Share the content of directory')
    .argv

dir = argv.c

async = require 'async'
fs = require 'fs'
mime = require 'mime'
mmd = require 'musicmetadata'
path = require 'path'
upnp = require 'upnp-device'
mime.define 'audio/flac': ['flac']

getContainerType = (fileTypes) ->
    maxVal = 0
    for key, val of fileTypes when val.length > maxVal
        maxVal = val
        type = key
    type

sortFiles = (dir, files, callback) ->
    sortedFiles = {}
    async.forEach files,
        (file, callback) ->
            fullPath = path.join dir, file
            fs.stat fullPath, (err, stat) ->
                type =
                    if stat?.isDirectory()
                        'folder'
                    else if stat?.isFile()
                        mime.lookup(file).split('/')[0]
                    else
                        'unknown'
                (sortedFiles[type]?=[]).push fullPath
                callback (if err? then err else null)
        (err) -> callback err, sortedFiles

mimeContainerMap =
    audio: 'object.container.album.musicAlbum'

# Parse tags using musicmediadata module
parseTags = (file, cb) ->
    stream = fs.createReadStream file
    stream.on 'error', (err) -> console.log "#{err.message} - #{stream.path}"
    parser = new mmd stream
    parser.on 'metadata', (data) -> cb data
    parser.on 'done', (err) ->
        console.log "#{err.message} - #{stream.path}" if err?
        stream.destroy()

makeContainer = (dir, sortedFiles, callback) ->
    contentType = getContainerType sortedFiles
    media =
        class: mimeContainerMap[contentType] or 'object.container'
        location: dir
    
    if contentType is 'audio'
        parseTags sortedFiles[contentType][0], (data) ->
            media.creator = media.artist =
                if data.albumartist.length > 0
                    data.albumartist[0]
                else if data.artist.length > 0
                    data.artist
                else
                    'Unknown'
            media.title = data.album or path.basename(dir).split('/')[0]
            callback null, media
    else
        media.creator = 'Unknown'
        media.title = path.basename(dir).split('/')[0]
        callback null, media

mimeItemMap =
    audio: 'object.item.audioItem.musicTrack'
    image: 'object.item.imageItem'
    text: 'object.item.textItem'

makeItem = (type, file, callback) ->
    media =
        class: mimeItemMap[type] or 'object.item'
        location: file
     switch type
        when 'audio'
            parseTags file, (data) ->
                media.creator = media.artist = data.artist?[0] or 'Unknown'
                media.title = data.title or 'Untitled'
                media.album = data.album or 'Untitled'
                media.genre = data.genre?[0] if data.genre?[0]?
                media.track = data.track?.no if data.track?.no > 0
                media.date = data.year if data.year > 0
                callback null, media
        else
            media.creator = 'Unknown'
            media.title = path.basename file, path.extname file
            callback null, media

addContainer = (parentId, dir, callback) ->
    fs.readdir dir, (err, files) ->
        # Ignore hidden files.
        files = files.filter (file) -> file[...1] isnt '.'
        sortFiles dir, files, (err, sortedFiles) ->
            makeContainer dir, sortedFiles, (err, container) ->
                mediaServer.addMedia parentId, container, (err, id) ->
                    add id, dir, sortedFiles, callback

addItem = (parentId, type, file, callback) ->
    makeItem type, file, (err, item) ->
        mediaServer.addMedia parentId, item, callback

add = (parentId, path, sortedFiles, callback) ->
    async.forEachLimit Object.keys(sortedFiles), 5,
        (type, callback) ->
            async.forEach sortedFiles[type],
                (item, callback) ->
                    if type is 'folder'
                        addContainer parentId, item, callback
                    else
                        addItem parentId, type, item, callback
                callback
        (err) ->
            callback null

mediaServer = upnp.createDevice 'MediaServer', 'Bragi'

mediaServer.on 'error', (e) -> throw e

mediaServer.on 'ready', ->
    addContainer 0, dir, (err, id) -> throw err if err?
