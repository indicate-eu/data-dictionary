// Settings dropdown menu handler
$(document).on('shiny:connected', function() {
  // Toggle dropdown when settings button is clicked
  $(document).on('click', '#nav_settings', function(e) {
    e.stopPropagation();
    $('#settings_dropdown').toggle();
  });

  // Close dropdown when clicking outside
  $(document).on('click', function(e) {
    if (!$(e.target).closest('#nav_settings').length && !$(e.target).closest('#settings_dropdown').length) {
      $('#settings_dropdown').hide();
    }
  });

  // Add hover effects to dropdown items
  $(document).on('mouseenter', '.settings-dropdown-item', function() {
    $(this).css('background', 'rgba(15, 96, 175, 0.2)');
  });

  $(document).on('mouseleave', '.settings-dropdown-item', function() {
    $(this).css('background', 'transparent');
  });
});
