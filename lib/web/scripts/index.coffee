"use strict"

socket = io.connect 'http://localhost'

renderers = []
renderView = (name, data, cb) ->
  return cb renderers[name] data if name of renderers
  $.get("/views/#{name}.jade").done (tmpl) ->
    renderers[name] = jade.compile tmpl, compileDebug: no
    cb renderers[name] data

$ ->
  $('#files').on 'click', 'a', (ev) ->
    $this = $ @
    if $this.hasClass 'open'
      $this
        .text('+')
        .removeClass('open')
          .nextAll('ul')
          .remove()
    else
      path = @hash.substring 1
      socket.emit 'getDirectories', path, addDirs
    ev.preventDefault()
    ev.stopImmediatePropagation()

  $('#files').on 'click', 'input', (ev) ->
    $this = $ @
    checked = $this.prop 'checked'
    $this.nextAll('ul').find('input').prop 'checked', checked
    if checked
      socket.emit 'addPath', $this.val()
    else
      socket.emit 'removePath', $this.val()
    ev.stopImmediatePropagation()

addDirs = (data) ->
  renderView 'files', data, (fileList) ->
    $("a[href='##{data.parent}']")
      .text('-')
      .addClass('open')
      .parent('li')
        .append fileList
