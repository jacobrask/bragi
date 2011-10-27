upnp = require 'upnp'
config =
    app:
        name: 'Bragi'
        version: '0.0.1'
        url: 'http://'
    device:
        type: 'MediaServer'
        version: '1.0'

upnp.start config, ->
    console.log 'Bragi running! :-)'
