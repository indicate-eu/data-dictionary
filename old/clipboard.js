// Clipboard functionality for copying text
$(document).ready(function() {
  // Handle custom message from Shiny to copy text to clipboard
  Shiny.addCustomMessageHandler('copyToClipboard', function(message) {
    var text = message.text;
    var buttonId = message.buttonId;

    // Create a temporary textarea element
    var textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.top = '0';
    textarea.style.left = '0';
    textarea.style.opacity = '0';
    textarea.style.width = '2em';
    textarea.style.height = '2em';
    textarea.setAttribute('readonly', '');

    document.body.appendChild(textarea);

    // Select and copy the text
    textarea.focus();
    textarea.select();

    try {
      textarea.setSelectionRange(0, 99999);
    } catch (e) {
      // Silently fail on mobile devices
    }

    try {
      var success = document.execCommand('copy');

      if (success && buttonId) {
        var button = $('#' + buttonId);
        if (button.length > 0) {
          button.addClass('copied');

          setTimeout(function() {
            button.removeClass('copied');
          }, 3000);
        }
      }
    } catch (err) {
      console.error('Failed to copy text: ', err);
    }

    // Remove the temporary textarea
    document.body.removeChild(textarea);
  });
});
