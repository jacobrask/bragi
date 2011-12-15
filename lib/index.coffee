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
path = require 'path'
{Tag} = require 'taglib'
_ = require 'underscore'
upnp = require 'upnp-device'

# If all keys in array are the same, return the value,
# otherwise return a fallback value (such as 'Various Artists').
getAlbumKey = (arr, key, fallback) ->
    unless arr[0]?[key]?
        return fallback or undefined
    if arr.every((el) -> el[key] is arr[0][key])
        return arr[0][key]
    else
        return fallback or undefined

mediaServer = upnp.createDevice 'MediaServer', 'Bragi'

mediaServer.on 'error', (e) -> throw e

getItemType = (type) ->
    mimeItemMap =
        audio: 'audioItem.musicTrack'
        image: 'imageItem'
    mimeItemMap[type] or null

getContainerType = (fileTypes) ->
    mimeContainerMap =
        audio: 'album.musicAlbum'
    maxVal = 0
    for key, val of fileTypes when val.length > maxVal
        maxVal = val
        type = key
    mimeContainerMap[type] or null

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

makeContainer = (dir, sortedFiles) ->
    media =
        type: 'container'
        instance: getContainerType sortedFiles
        location: dir
    data = []
    for type, files of sortedFiles
        if type is 'audio' and media.instance is 'album.musicAlbum'
            data.push new Tag file for file in files
        else if type is 'folder' and not media.instance?
            media.creator = 'Unknown'
            media.title = path.basename(dir).split('/')[0]

    if data?.length > 0 and media.instance is 'album.musicAlbum'
        media.creator = getAlbumKey data, 'artist', 'Various Artists'
        media.title = getAlbumKey data, 'album', data[0].album
    
    media

makeItem = (type, file) ->
    media =
        type: 'item'
        instance: getItemType type
        location: file
     switch type
        when 'audio'
            try
                data = new Tag file
            catch e
    if data?
        switch media.instance
            when 'audioItem.musicTrack'
                media.creator = data.artist or 'Unknown Artist'
                media.title = data.title or 'Untitled'
                media.album = data.album or 'Untitled'
            else
                media.creator = 'Unknown'
                media.title = file
    else
        media.creator = 'Unknown'
        media.title = file
    media

addContainer = (parentId, dir, callback) ->
    fs.readdir dir, (err, files) ->
        sortFiles dir, files, (err, sortedFiles) ->
            mediaServer.addMedia parentId,
                makeContainer(dir, sortedFiles)
                (err, id) ->
                    add id, dir, sortedFiles, callback

addItem = (parentId, type, file, callback) ->
    mediaServer.addMedia parentId,
        makeItem(type, file)
        callback

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
        callback


mediaServer.on 'ready', ->
    fs.readdir dir, (err, files) ->
        # Determine root container type from its contents.
        sortFiles dir, files, (err, sortedFiles) ->
            mediaServer.addMedia 0, makeContainer(dir, sortedFiles), (err, cntId) ->
                add cntId, dir, sortedFiles, (err, id) -> throw err if err?

    @announce()
