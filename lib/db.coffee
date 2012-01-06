"use strict"

media = require './media'
_ = require './utils'

{ Db, Connection, Server, BSONPure: { ObjectID } } = require 'mongodb'

db = new Db 'bragi-mediaserver',
       new Server 'localhost',
       Connection.DEFAULT_PORT

exports.init = (cb = ->) ->
  db.open (err) ->
    return cb err if err?
    # Drop library and then rebuild it by scanning `paths`.
    action 'library', cb, (coll) ->
      coll.drop (err, res) ->
        console.log err.message if err?
        get 'paths', {}, (err, docs) ->
          console.log err.message if err?
          # Call back but continue adding media in the background.
          cb err
          if docs?.length > 0
            _.async.forEachSeries docs.filter((doc) -> doc.path?),
              (doc, cb) -> media.addPath doc.path, cb
              (err) -> console.log err.message if err?

action = (collName, errback, callback) ->
  db.collection collName, (err, coll) ->
    return errback err if err?
    callback coll

add = (collName, obj, cb) -> action collName, cb, (coll) ->
  coll.insert obj, safe: true, cb

update = (collName, filter, updateAction, cb) -> action collName, cb, (coll) ->
  coll.update filter, updateAction, safe: true, cb

get = exports.get = (collName, filter = {}, cb) -> action collName, cb, (coll) ->
  coll.find(filter).toArray cb

getProperty = (filter, prop, cb) ->
  action 'library', cb, (coll) ->
    (o = {})[prop] = 1
    coll.find(filter, o).toArray (err, obj) ->
      cb err, obj?[0]?[prop]

exports.addPath = (path, cb) ->
  add 'paths', { path }, cb

exports.getPath = (id, cb) ->
  getProperty { _id: new ObjectID id.toString() }, 'path', cb

exports.getProperty = (id, prop, cb) ->
  getProperty { _id: new ObjectID id.toString() }, prop, cb

exports.addToLibrary = (obj, cb) ->
  action 'library', cb, (coll) ->
    obj2 = _.clone obj
    coll.findAndModify obj2, [['_id', 'asc']], { $set: obj2 }, { safe: on, upsert: on, new: yes }, (err, doc) ->
      cb err, doc._id

exports.set = (id, obj, cb) ->
  update 'library', { _id: new ObjectID id.toString() }, { $set: obj }, cb

exports.push = (id, obj, cb) ->
  update 'library', { _id: new ObjectID id.toString() }, { $push: obj }, cb

exports.pathExists = (path, cb) ->
  action 'paths', cb, (coll) ->
    coll.count { path }, (err, count) ->
      cb err, count > 0
