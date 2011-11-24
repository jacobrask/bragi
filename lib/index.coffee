argv = require('optimist')
    .usage('Usage: $0 -c [directory]')
    .demand('c')
    .alias('c', 'content')
    .describe('c', 'Share the content of directory')
    .argv

dir = argv.c

fs = require 'fs'
Tag = require('taglib').Tag
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

mediaServer = upnp.createDevice 'MediaServer', 'Bragi', (err, device, msg) ->
    throw err if err
    device.start (err) ->
        throw err if err
        # Read through directory passed as argument.
        fs.readdir dir, (err, files) ->
            media = type: 'musicalbum', children: []
            tags = []
            for file in files
                try
                    tags.push new Tag(dir + file)
                catch err
                    console.log err

            media.creator = getAlbumKey(tags, 'artist', 'Various Artists')
            media.title = getAlbumKey(tags, 'album', tags[0].album)
            for tag in tags
                media.children.push(
                    title: tag.title
                    location: dir + file
                )

            device.addMedia 0, media, (err, id) ->
                throw err if err
