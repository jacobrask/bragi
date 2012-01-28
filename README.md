# UPnP Media Server

Bragi is a media server for UPnP (and some DLNA) devices. It runs on [Node.js] and is written in CoffeeScript.

___Bragi is still in a very experimental state.___

# Install

Apart from [Node.js], you first need to install [MongoDB], and if you want transcoding, [ffmpeg].

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
