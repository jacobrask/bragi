"use strict"

express = require 'express'
mime = require 'mime'
socketio = require 'socket.io'
{ Db, Connection, Server, BSONPure: { ObjectID } } = require 'mongodb'

files = require './files'
media = require './media'
_ = require './utils'

db = require('./db') new Db(
  "bragi-mediaserver#{if process.env.NODE_ENV is 'production' then '' else '-dev'}"
  new Server 'localhost', Connection.DEFAULT_PORT)

db.open (err) ->
  console.log err.message if err?
  db.syncPaths (err) ->
    console.log err.message if err?
    console.log 'done'

  app = express.createServer()
  io = socketio.listen app
  app.configure ->
    app.use express.static "#{__dirname}/web"
    app.set 'view engine', 'jade'
    app.set 'views', "#{__dirname}/web/views"
  io.configure ->
    io.disable 'log'

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

  io.sockets.on 'connection', (socket) ->
    socket.on 'getDirectories', (root, cb) ->
      getDirData root, (err, dirs) ->
        cb { parent: root, dirs }

    socket.on 'addPath', (root, cb) ->
      files.traverse root,
        (dir, cb) ->
          db.addPath dir, (err) ->
            media.addPath db, dir, cb
        (err) -> console.log err.message if err?

    socket.on 'removePath', (root, cb) ->
      files.traverse root,
        (dir, cb) ->
          db.removePath dir, cb
        (err) -> console.log err.message if err?


  # Gets directories from file system and checks if they are in media database.
  getDirData = (root, cb) ->
    files.getDirectories root, (err, results) ->
      _.async.map results,
        (dir, cb) ->
          db.hasPath dir.path, (err, exists) ->
            dir.exists = exists
            cb null, dir
        cb

  app.listen 3000

  console.log "Bragi web interface started at http://localhost:#{app.address().port}"
