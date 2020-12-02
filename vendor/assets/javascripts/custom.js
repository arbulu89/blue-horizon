$(function() {
  // Show/hide passwords
  $(".plan-icon-append.peek").click(function() {
    var group = $("div#admin-password");
    group.find("span.peek").hide()
    group.find("span.unpeek").show()
    $(this)
      .hide()
      .tooltip("hide");
    group.find(".plan-icon-append.unpeek").show();
  });
  $(".plan-icon-append.unpeek").click(function() {
    var group = $("div#admin-password");
    group.find("span.unpeek").hide()
    group.find("span.peek").show()
    $(this)
      .hide()
      .tooltip("hide");
    group.find(".plan-icon-append.peek").show();
  });
});
