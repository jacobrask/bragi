fs = require 'fs'
upnp = require 'upnp-server'
Tag = require('taglib').Tag

mediaServer = upnp.createDevice 'MediaServer', 'Bragi', (err, device, msg) ->
    throw err if err
    device.start (err) ->
        throw err if err
        fs.readdir dir, (err, files) ->
            for file in files
                try
                    t = new Tag(dir + file)
                catch err
                    console.log err
                finally
                    media.children.push(
                        title: t.title
                        location: dir + file
                    )

            device.addMedia 0, media, (err, id) ->
                console.log id
