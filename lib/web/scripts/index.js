(function() {
  "use strict";
  var addDirs, renderView, renderers, socket;
  socket = io.connect('http://localhost');
  renderers = {};
  renderView = function(name, data, cb) {
    if (name in renderers) {
      return cb(renderers[name](data));
    }
    return $.get("/views/" + name + ".jade").done(function(tmpl) {
      renderers[name] = jade.compile(tmpl, {
        compileDebug: false
      });
      return cb(renderers[name](data));
    });
  };
  $(function() {
    $('#files').on('click', 'a', function(ev) {
      var $this, path;
      $this = $(this);
      if ($this.hasClass('open')) {
        $this.text('+').removeClass('open').nextAll('ul').remove();
      } else {
        path = this.hash.substring(1);
        socket.emit('getDirectories', path, addDirs);
      }
      ev.preventDefault();
      return ev.stopImmediatePropagation();
    });
    return $('#files').on('click', 'input', function(ev) {
      var $this, checked;
      $this = $(this);
      checked = $this.prop('checked');
      $this.nextAll('ul').find('input').prop('checked', checked);
      if (checked) {
        socket.emit('addPath', $this.val());
      } else {
        socket.emit('removePath', $this.val());
      }
      return ev.stopImmediatePropagation();
    });
  });
  addDirs = function(data) {
    return renderView('files', data, function(fileList) {
      return $("a[href='#" + data.parent + "']").text('-').addClass('open').parent('li').append(fileList);
    });
  };
}).call(this);
