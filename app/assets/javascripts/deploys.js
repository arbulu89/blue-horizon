function _slicedToArray(arr, i) { return _arrayWithHoles(arr) || _iterableToArrayLimit(arr, i) || _unsupportedIterableToArray(arr, i) || _nonIterableRest(); }

function _nonIterableRest() { throw new TypeError("Invalid attempt to destructure non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }

function _unsupportedIterableToArray(o, minLen) { if (!o) return; if (typeof o === "string") return _arrayLikeToArray(o, minLen); var n = Object.prototype.toString.call(o).slice(8, -1); if (n === "Object" && o.constructor) n = o.constructor.name; if (n === "Map" || n === "Set") return Array.from(o); if (n === "Arguments" || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(n)) return _arrayLikeToArray(o, minLen); }

function _arrayLikeToArray(arr, len) { if (len == null || len > arr.length) len = arr.length; for (var i = 0, arr2 = new Array(len); i < len; i++) { arr2[i] = arr[i]; } return arr2; }

function _iterableToArrayLimit(arr, i) { if (typeof Symbol === "undefined" || !(Symbol.iterator in Object(arr))) return; var _arr = []; var _n = true; var _d = false; var _e = undefined; try { for (var _i = arr[Symbol.iterator](), _s; !(_n = (_s = _i.next()).done); _n = true) { _arr.push(_s.value); if (i && _arr.length === i) break; } } catch (err) { _d = true; _e = err; } finally { try { if (!_n && _i["return"] != null) _i["return"](); } finally { if (_d) throw _e; } } return _arr; }

function _arrayWithHoles(arr) { if (Array.isArray(arr)) return arr; }

$(function () {
  var intervalId = undefined;
  var finished = false;
  $("#submit-deploy").bind("ajax:beforeSend", function () {
    $("#output").text("");
    $(this).addClass("no-hover");
    $(".float-right .steps-container .btn").addClass("disabled");
    $(".list-group-flush a").addClass("disabled");
    $("#loading").show();
    $("a[data-toggle]").tooltip("hide");
    intervalId = setTimeout(function () {
      fetch_output(finished, intervalId);
    }, 5000);
  }).bind("ajax:success", function () {
    $("#notice").html("<%= flash[:error] %>");

    if ($("#output").text().length > 0) {
      clearTimeout(intervalId);
    }

    finished = true;
  }).bind("ajax:complete", function () {
    $(this).removeClass("no-hover");

    if ($("#output").text().length > 0) {
      clearTimeout(intervalId);
      finished = true;
    }
  }).bind("ajax:error", function () {
    $("#loading").hide();
    clearTimeout(intervalId);
  });
});

function update_progress_bar(progress_data, error, finished) {
  const bar_id = "#progress-bar";
  const $progress_bar = $("div" + bar_id);

  $progress_bar
    .css("width", progress_data.progress + "%")
    .find("span").html(progress_data.progress + "%");
  $("label" + bar_id).html(progress_data.text);

  if (error !== null) {
    $progress_bar.addClass("bg-danger");
  }

  if (finished) {
    $progress_bar.removeClass("progress-bar-striped progress-bar-animated");
    return;
  }

  $progress_bar.addClass("progress-bar-striped progress-bar-animated");
}

function update_tasks(progress_data, finished) {
  Object.entries(progress_data).forEach(entry=>{
    const [task_id, task_data] = entry;
    const $img_task_id = $("img#" + task_id);
    const $i_task_id = $("i#" + task_id);
    const $span_task_id = $("span#" + task_id);

    progress_text = task_data.progress + "% - " + task_data.text;
    $span_task_id.html(progress_text);

    if (!task_data.success || (task_data.progress < 100 && finished)) {
      $img_task_id.hide();
      $i_task_id
        .show()
        .html("close")
        .addClass("red");
      return;
    }

    if (task_data.progress < 100) {
      $img_task_id.show();
      $i_task_id.hide();
      return;
    }

    $img_task_id.hide();
    $i_task_id
      .show()
      .html("check")
      .addClass("green");
  });
}

function update_progress(data, finished) {
  if (!("progress" in data)) {
    return;
  }
  if ("total_progress" in data.progress) {
    update_progress_bar(
      data.progress.total_progress, data.error, finished);
  }
  if ("tasks_progress" in data.progress) {
    update_tasks(data.progress.tasks_progress, finished);
  }
}

function fetch_output(finished, intervalId) {
  $.ajax({
    type: "GET",
    url: "deploy/send_current_status",
    dataType: "json",
    success: function success(data) {
      if (data.error !== null) {
        $("#loading").hide(); // show rails flash message

        $("#error_message").text("Deploy operation has failed.");
        $("#flash").show(); // show terraform error message in output section

        $("#output").text($("#output").text() + data.error);
        clearTimeout(intervalId);
        $(".steps-container .btn.disabled").removeClass("disabled");
        $("#loading").hide();
        finished = true;
      } else {
        // update scrollable
        $(".pre-scrollable").html(data.new_html);
        var autoscroll = $("#deploy_log_autoscroll").prop("checked");

        if (autoscroll) {
          $(".pre-scrollable").scrollTop($("#output").height());
        }

        if (!finished && !data.success) {
          intervalId = setTimeout(function () {
            fetch_output();
          }, 5000);
        } else {
          $(".steps-container .btn.disabled").removeClass("disabled");
          $("#loading").hide();
          finished = true;
        }
      }
      update_progress(data, finished);
    },
    error: function error(data) {
      var endIndex = data.responseText.indexOf("#");
      if (endIndex == -1) endIndex = data.responseText.indexOf("\n");
      $("#error_message").text(data.responseText.substring(0, endIndex));
      $("#flash").show();
      $(".steps-container .btn.disabled").removeClass("disabled");
      $("#loading").hide();
      update_progress(data, true);
    }
  });
  $("#flash .close").click(function () {
    $("#flash").hide();
  });
}
