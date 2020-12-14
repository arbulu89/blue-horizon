$(function() {
  $('.ssh-command').click(function(e) {
    text = $(this).find('input')[0].value;
    // Create a dummy input to copy the string array inside it
    var clipboard = document.createElement('input');
    document.body.appendChild(clipboard);
    clipboard.setAttribute('id', 'clipboard_id');
    document.getElementById('clipboard_id').value=text;
    clipboard.select();
    document.execCommand('copy');
    document.body.removeChild(clipboard);
    });
});
