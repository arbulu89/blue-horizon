$(function() {
  var intervalId = undefined;
  var finished = false;

  $("#submit-deploy")
    .bind("ajax:beforeSend", function() {
      $("#output").text("");
      $(this).addClass("no-hover");
      $(".float-right .steps-container .btn").addClass("disabled");
      $(".list-group-flush a").addClass("disabled");
      $("#loading").show();
      $("a[data-toggle]").tooltip("hide");
      intervalId = setTimeout(function() {
        fetch_output(finished, intervalId);
      }, 5000);
    })
    .bind("ajax:success", function() {
      $("#notice").html("<%= flash[:error] %>");
      if ($("#output").text().length > 0) {
        clearTimeout(intervalId);
      }
      finished = true;
    })
    .bind("ajax:complete", function() {
      $(this).removeClass("no-hover");
      if ($("#output").text().length > 0) {
        clearTimeout(intervalId);
        finished = true;
      }
    })
    .bind("ajax:error", function() {
      $("#loading").hide();
      clearTimeout(intervalId);
    });
});

function update_progress_bar(progress_data, error) {
  const bar_id = "#progress-bar";
  const progress_bar_id = "div" + bar_id;

  $(progress_bar_id).css("width", progress_data.progress + "%");
  $(progress_bar_id).find("span").html(progress_data.progress + "%");
  $("label" + bar_id).html(progress_data.text);
  if (progress_data.progress == 100) {
    $(progress_bar_id).removeClass("progress-bar-striped progress-bar-animated");
  } else {
    $(progress_bar_id).addClass("progress-bar-striped progress-bar-animated");
  }
  if (error !== null) {
    $(progress_bar_id).addClass("bg-danger");
  }
}

function update_tasks(progress_data) {
  Object.entries(progress_data).forEach(entry=>{
    const [task_id, task_data] = entry;
    progress_text = task_data.progress + "% - " + task_data.text;

    $("span#" + task_id).html(progress_text);
    if (task_data.success) {
      if (task_data.progress < 100) {
        $("img#" + task_id).show();
        $("i#" + task_id).hide();
      } else {
        $("img#" + task_id).hide();
        $("i#" + task_id).show();
        $("i#" + task_id).html("check");
        $("i#" + task_id).addClass("green");
      }
    } else {
      $("img#" + task_id).hide();
      $("i#" + task_id).show();
      $("i#" + task_id).html("close");
      $("i#" + task_id).addClass("red");
    }
  });
}

function fetch_output(finished, intervalId) {
  $.ajax({
    type: "GET",
    url: "deploy/send_current_status",
    dataType: "json",
    success: function(data) {
      if (data.error !== null) {
        $("#loading").hide();
        // show rails flash message
        $("#error_message").text("Deploy operation has failed.");
        $("#flash").show();
        // show terraform error message in output section
        $("#output").text($("#output").text() + data.error);
        clearTimeout(intervalId);
        $(".steps-container .btn.disabled").removeClass("disabled");
        $("#loading").hide();
      } else {
        // update scrollable
        $(".pre-scrollable").html(data.new_html);
        var autoscroll = $("#deploy_log_autoscroll").prop("checked");
        if (autoscroll) {
          $(".pre-scrollable").scrollTop($("#output").height());
        }
        if (!finished && !data.success) {
          intervalId = setTimeout(function() {
            fetch_output();
          }, 5000);
        } else {
          $(".steps-container .btn.disabled").removeClass("disabled");
          $("#loading").hide();
        }
      }
      // update progress bar
      if ("progress" in data) {
        if ("total_progress" in data.progress) {
          update_progress_bar(
              data.progress.total_progress, data.error)
        }
        if ("tasks_progress" in data.progress) {
          update_tasks(data.progress.tasks_progress)
        }
      }
    },
    error: function(data) {
      var endIndex = data.responseText.indexOf("#");
      if (endIndex == -1) endIndex = data.responseText.indexOf("\n");
      $("#error_message").text(data.responseText.substring(0, endIndex));
      $("#flash").show();
      $(".steps-container .btn.disabled").removeClass("disabled");
      $("#loading").hide();
    }
  });

  $("#flash .close").click(function() {
    $("#flash").hide();
  });
}
