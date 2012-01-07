"use strict"

express = require 'express'
mime = require 'mime'
socketio = require 'socket.io'

db = require './db'
files = require './files'
media = require './media'
_ = require './utils'

app = module.exports = express.createServer()
app.configure ->
  app.use express.static "#{__dirname}/web"
  app.set 'view engine', 'jade'
  app.set 'views', "#{__dirname}/web/views"

io = socketio.listen app
io.configure ->
  io.disable 'log'


# Gets directories from file system and checks if they are in media database.
getDirData = (root, cb) ->
  files.getDirectories root, (err, results) ->
    _.async.map results,
      (dir, cb) ->
        db.pathExists dir.path, (err, exists) ->
          dir.exists = exists
          cb null, dir
      cb

io.sockets.on 'connection', (socket) ->
  socket.on 'getDirectories', (root, cb) ->
    getDirData root, (err, dirs) ->
      cb { parent: root, dirs }

  socket.on 'addPath', (root, cb) ->
    files.traverse root,
      (dir, cb) ->
        db.addPath dir, (err) ->
          media.addPath dir, cb
      (err) -> console.log err.message if err?

  socket.on 'removePath', (root, cb) ->
    files.traverse root,
      (dir, cb) ->
        db.removePath dir, cb
      (err) -> console.log err.message if err?


app.get '/', (req, res) ->
  getDirData '/', (err, dirs) ->
    res.render 'index', { dirs }

# Render (and transcode) media resource with id `:id`.
app.get '/res/:id', (req, res) ->
  db.getPath req.params.id, (err, file) ->
    if err? or not file?
      res.writeHead 500
      res.end()
    else
      res.contentType 'mp3'
      if mime.lookup(file) is 'audio/mpeg'
        res.sendfile file
      # Transcode to mp3 using ffmpeg.
      else
        new ffmpeg(path)
          .withAudioCodec('libmp3lame')
          .toFormat('mp3')
          .writeToStream res, (ret, err) ->
            console.log err.message if err?
