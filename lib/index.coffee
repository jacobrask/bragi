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

makeContainer = (dir, sortedFiles, callback) ->
    contentType = getContainerType sortedFiles
    media =
        class: mimeContainerMap[contentType] or 'object.container'
        location: dir
    
    if contentType is 'audio'
        parser = new mmd stream = fs.createReadStream sortedFiles[contentType][0]
        parser.on 'metadata', (data) ->
            media.creator = data.albumartist?[0] or data.artist?[0] or 'Unknown'
            media.title = data.album
            callback null, media
        parser.on 'done', (err) ->
            console.error(err) if err?
            stream.destroy()
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
            parser = new mmd stream = fs.createReadStream file
            parser.on 'metadata', (data) ->
                media.creator = data.artist?[0] or 'Unknown'
                media.title = data.title or 'Untitled'
                media.album = data.album or 'Untitled'
                callback null, media
            parser.on 'done', (err) ->
                console.error(err) if err?
                stream.destroy()
        else
            media.creator = 'Unknown'
            media.title = path.basename file, path.extname file
            callback null, media

addContainer = (parentId, dir, callback) ->
    fs.readdir dir, (err, files) ->
        sortFiles dir, files, (err, sortedFiles) ->
            makeContainer dir, sortedFiles, (err, container) ->
                mediaServer.addMedia parentId, container, (err, id) ->
                    add id, dir, sortedFiles, callback

addItem = (parentId, type, file, callback) ->
    makeItem type, file, (err, item) ->
        mediaServer.addMedia parentId, item, callback

add = (parentId, path, sortedFiles, callback) ->
    async.forEach Object.keys(sortedFiles),
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
    addContainer 0, dir, (err) -> throw err if err?
    @announce()
