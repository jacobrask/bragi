# UPnP Media Server

Bragi is a media server for UPnP (and in the future DLNA) devices. It runs on [Node.js] and is written in CoffeeScript.

___Bragi is still in a very experimental state.___

# Install

First install [Node.js], version 0.4.12 is recommended. Bragi relies on [node-upnp-device] which is ___not___ compatible with Node 0.6.x due to some missing UDP features in 0.6.x. They are expected to be implemented fairly soon, and then node-upnp-device will be ported to 0.6.x.

Then clone this repository. Bragi will be in npm when it's more functional.

# Usage

    ./bragi.js -c [directory]

## Options
* `-c`, `--content` Share the content of directory [required]

# Known issues

* Only gets metadata from audio files.
* No transcoding. Take a look at [mp3fs](http://mp3fs.sourceforge.net/) if you need to stream mp3s.
* Plus still lots of limitations in [node-upnp-device].

[upnp]: http://upnp.org
[node-upnp-device]: https://github.com/jacobrask/node-upnp-device
[node.js]: http://nodejs.org
