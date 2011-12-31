socket = io.connect 'http://localhost'

renderers = []
renderView = (name, data, cb) ->
  return cb renderers[name] data if name of renderers
  $.get("/views/#{name}.jade").done (tmpl) ->
    renderers[name] = jade.compile tmpl, compileDebug: no
    cb renderers[name] data

$ ->
  $('#files').on 'click', 'a', (ev) ->
    path = @hash.substring 1
    socket.emit 'getFiles', { path }, addFiles
    ev.preventDefault()
    ev.stopImmediatePropagation()

addFiles = (data) ->
  renderView 'files', data, (fileList) ->
    $("a[href='##{data.parent}']")
      .text('-')
      .parent('li')
        .append fileList
