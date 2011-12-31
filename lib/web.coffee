express = require 'express'
socketio = require 'socket.io'

files = require './files'

app = express.createServer()
app.listen 3000
io = socketio.listen app

app.configure ->
  app.use express.static __dirname + '/web'
  app.set 'view engine', 'jade'
  app.set 'views', __dirname + '/web/views'

io.sockets.on 'connection', (socket) ->
  socket.on 'getFiles', (data, cb) ->
    files.getFiles data.path, (err, res) ->
      cb { parent: data.path, files: res }

app.get '/', (req, res) ->
  files.getFiles '/', (err, results) ->
    res.render 'index', { files: results }
