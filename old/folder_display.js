// Handle folder display updates
Shiny.addCustomMessageHandler("updateFolderDisplay", function(message) {
  var element = document.getElementById(message.id);
  if (element) {
    element.innerHTML = '<span style="color: #333;">' + message.path + '</span>';
  }
});

// Handle folder navigation on click
$(document).on('click', '.file-browser-folder', function(e) {
  // Don't navigate if clicking on the "Select" button
  if ($(e.target).is('button') || $(e.target).closest('button').length > 0) {
    return;
  }

  var path = $(this).data('path');
  if (path) {
    var containerId = $(this).closest('[id]').attr('id');
    var inputId;

    // Handle both OHDSI (file_browser) and UMLS (umls_file_browser) browser containers
    if (containerId.indexOf('-umls_file_browser') !== -1) {
      inputId = containerId.replace('-umls_file_browser', '-umls_navigate_to');
    } else {
      inputId = containerId.replace('-file_browser', '-navigate_to');
    }

    Shiny.setInputValue(inputId, path, {priority: 'event'});
  }
});
