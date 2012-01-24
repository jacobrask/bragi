# UPnP Media Server

Bragi is a media server for UPnP (and some DLNA) devices. It runs on [Node.js] and is written in CoffeeScript.

___Bragi is still in a very experimental state.___

# Install

First install [Node.js], version 0.4.12 is recommended. Bragi relies on [node-upnp-device] which is ___not___ compatible with Node 0.6.x due to some missing UDP features in 0.6.x. They are expected to be implemented fairly soon, and then node-upnp-device will be ported to 0.6.x. I suggest using [nvm] to install and keep track of different Node versions.

You also need to install [MongoDB], and if you want transcoding, [ffmpeg].

Then clone this repository and run `node bragi.js`. Bragi will be published in npm when it's more functional.

# Known issues

* Only gets metadata from audio files.
* When paths are removed, Bragi needs to be restarted for changes to take effect.
* Transcoding only for audio.
* UI under construction.

[upnp]: http://upnp.org
[node-upnp-device]: https://github.com/jacobrask/node-upnp-device
[node.js]: http://nodejs.org
[nvm]: https://github.com/creationix/nvm
[ffmpeg]: http://ffmpeg.org
[mongodb]: http://mongodb.org
