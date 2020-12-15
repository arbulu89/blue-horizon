$(function() {
  $('.ssh-command').find('.input-group-button').click(function() {
    text = $(this).parent().find('input')[0].value;

    // Change tooltip text to copied
    updated_text = $(this).find('i')
      .attr('data-copied-hint');
    $(this).find('i')
      .tooltip('hide')
      .attr('data-original-title', updated_text)
      .tooltip('show');

    // Create a dummy input to copy the string array inside it
    var clipboard = document.createElement('input');
    document.body.appendChild(clipboard);
    clipboard.setAttribute('id', 'clipboard_id');
    document.getElementById('clipboard_id').value=text;
    clipboard.select();
    document.execCommand('copy');
    document.body.removeChild(clipboard);
  });

  $('.ssh-command').find('.input-group-button').mouseout(function() {
    initial_text = $(this).find('i')
      .attr('data-initial-hint');
    $(this).find('i')
      .attr('data-original-title', initial_text)
      .tooltip('hide');
  });
});
