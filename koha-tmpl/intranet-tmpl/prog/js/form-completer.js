(function ($) {

  var defaults = {
    "modal": null,
    "form_id": null,
    "url": null,
    "input": "input",
    "button": "button.btn-primary",
    "fetch_msg": null,
    "modal_form_id": null,
    "id_field": null
  };

  if (!String.prototype.startsWith) {
    Object.defineProperty(String.prototype, 'startsWith', {
      value: function(search, pos) {
        pos = !pos || pos < 0 ? 0 : +pos;
        return this.substring(pos, pos + search.length) === search;
      }
    });
  }
  if (!String.prototype.endsWith) {
    String.prototype.endsWith = function(search, this_len) {
      if (this_len === undefined || this_len > this.length) {
        this_len = this.length;
      }
      return this.substring(this_len - search.length, this_len) === search;
    };
  }

  function FormCompleter(opts) {

    var keys = Object.keys(opts);

    for (var i = 0; i < keys.length; i++) {
      var opt = keys[i];
      if (Object.keys(defaults).indexOf(opt) < 0) {
        throw new Error("Invalid option: " + opt);
      }
    }

    this.opts = $.extend({}, defaults, opts);

    var required = ["modal", "form_id", "url"];
    for (var i = 0; i < required.length; i += 1) {
      var opt = required[i];
      if (this.opts[opt] === null) {
        throw new Error("Missing required option: " + opt);
      }
    }

    this._init();
  }

  var p = FormCompleter.prototype;

  p._init = function _init() {
    var $modal = $(this.opts.modal);
    var $input = $modal.find(this.opts.input);
    var $button = $modal.find(this.opts.button);

    var form_id = '';
    if (Array.isArray(this.opts.form_id)) {
      for (var i = 0; i < this.opts.form_id.length; i+=1) {
        var fi = this.opts.form_id[i];
        form_id += (i > 0 ? ', #' : '#') + fi;
      }
    } else {
      form_id = '#' + this.opts.form_id;
    }
    this.form_id = form_id;

    var self = this;
    var $modal_form = this.opts.modal_form_id !== null ? $("#" + this.opts.modal_form_id) : $modal.parents("form");
    $modal.on("shown.bs.modal", function () {
      $input.focus();
      if (self.opts.id_field !== null) {
        var $id_field = self.input_for(self.opts.id_field);
        $id_field.each(function (index, element) {
          var val = $(element).val();
          if (typeof val !== "undefined" && val != "") {
            $input.val(val);
            return false;
          }
        })
      }
    });
    var submit = function submit (event) {
      event.stopPropagation();
      event.preventDefault();
      var valid = true;

      $input.each(function(index, element) {
        valid = valid && element.reportValidity();
      });

      if (!valid) {
        return;
      }

      var id = $input.val();
      KOHA.AJAX.MarkRunning(self.opts.modal, self.opts.fetch_msg);
      $.ajax({
        "url": self.opts.url + "/" + id.trim(),
        "dataType": "json",
        "statusCode": {
          400: self.handle400.bind(self),
          401: self.handle401.bind(self),
          404: self.handle404.bind(self),
          500: self.handle500.bind(self),
          503: self.handle503.bind(self)
        }
      }).always(self.always.bind(self))
        .fail(self.fail.bind(self))
        .done(self.done.bind(self));

    };

    $modal_form.on("submit", submit);
    $button.click(submit);
  }

  p.done = function done (data, textStatus, jqXHR) {
    $(this.opts.modal).modal('hide');
    for (var i = 0; i < data.form_fields.length; i+=1) {
      var f = data.form_fields[i];

      var $input = this.input_for(f);

      $input.each(function (index, element) {
        var old = $(element).val();
        if (old != f.value) {
          if ($(element).hasClass('flatpickr')) { // check if it has the flatpickr class
            $(element).flatpickr().setDate(f.value);
          } else {
            $(element).val(f.value);
          }
          $(element).addClass('form-completer-updated');
        }
      })
    }
  };

  p.input_for =  function inputs_for (f) {
    var $form = $(this.form_id);
    if (typeof f.attrname !== "undefined") {
      var inputs = [];
      $form.each(function (index, form) {
        var names = [];
        $(form).find('[value="' + f.attrname + '"]').each(function (index, element) {
          if (element.name.startsWith(f.name) && element.name.endsWith('_code')) {
            var name = element.name.substring(0, element.name.length - '_code'.length);
            if (names.indexOf(name) < 0) {
              names.push(name);
            }
          }
        });
        for (var i = 0; i < names.length; i+=1) {
          var name = names[i];
          var $inputs = $(form).find('[name="' + name + '"]');
          for (var j = 0;  j < $inputs.length; j+=1) {
            inputs.push($inputs.get(j));
          }
        }
      });
      return $(inputs);
    } else {
      return $form.find('[name="' + f.name + '"]');
    }
  }

  var displayError = function (msg, jqXHR, textStatus, errorThrown) {
    var msg = "<h3>" + msg + "</h3>";
    if (typeof jqXHR.responseJSON.error !== undefined) {
      msg += "<p>" + jqXHR.responseJSON.error + "</p>";
    }
    humanMsg.displayMsg( msg, { className: "humanError"} );
  }

  p.fail = function fail (jqXHR, textStatus, errorThrown) {
  }

  p.handle400 = function handle400 (jqXHR, textStatus, errorThrown) {
    displayError(MSG_BAD_REQUEST, jqXHR, textStatus, errorThrown);
  }
  p.handle401 = function handle401 (jqXHR, textStatus, errorThrown) {
    displayError(MSG_UNAUTHORIZED, jqXHR, textStatus, errorThrown);
  }
  p.handle403 = function handle403 (jqXHR, textStatus, errorThrown) {
    displayError(MSG_FORBIDDEN, jqXHR, textStatus, errorThrown);
  }
  p.handle404 = function handle404 (jqXHR, textStatus, errorThrown) {
    displayError(MSG_NOT_FOUND, jqXHR, textStatus, errorThrown);
  }
  p.handle500 = function handle500 (jqXHR, textStatus, errorThrown) {
    displayError(MSG_INTERNAL_SERVER_ERROR, jqXHR, textStatus, errorThrown);
  }
  p.handle503 = function handle503 (jqXHR, textStatus, errorThrown) {
    displayError(MSG_SERVICE_UNAVAILABLE, jqXHR, textStatus, errorThrown);
  }

  p.always = function always () {
      KOHA.AJAX.MarkDone(this.opts.modal);
  }

  window.FormCompleter = FormCompleter;

})($);