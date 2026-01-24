// Settings dropdown menu handler
$(document).ready(function() {
  console.log('Settings menu handler initialized');

  // Toggle dropdown when settings button is clicked (namespace-aware)
  // Using event delegation on body to handle dynamically created elements
  $('body').on('click', 'button[id$="-nav_settings"], a[id$="-nav_settings"]', function(e) {
    console.log('Settings button clicked:', $(this).attr('id'));
    e.stopPropagation();
    e.preventDefault();

    // Find the dropdown associated with this button
    var buttonId = $(this).attr('id');
    var namespace = buttonId.substring(0, buttonId.lastIndexOf('-nav_settings'));
    var dropdownId = '#' + namespace + '-settings_dropdown';

    console.log('Toggling dropdown:', dropdownId);
    console.log('Dropdown current display:', $(dropdownId).css('display'));
    console.log('Dropdown is visible:', $(dropdownId).is(':visible'));

    // Toggle visibility
    if ($(dropdownId).is(':visible')) {
      $(dropdownId).hide();
    } else {
      $(dropdownId).css('display', 'block');
    }

    console.log('Dropdown after toggle display:', $(dropdownId).css('display'));
  });

  // Close dropdown when clicking outside (namespace-aware)
  $('body').on('click', function(e) {
    if (!$(e.target).closest('[id$="-nav_settings"]').length && !$(e.target).closest('[id$="-settings_dropdown"]').length) {
      $('[id$="-settings_dropdown"]').hide();
    }
  });

  // Add hover effects to dropdown items
  $('body').on('mouseenter', '.settings-dropdown-item', function() {
    $(this).css('background', 'rgba(15, 96, 175, 0.2)');
  });

  $('body').on('mouseleave', '.settings-dropdown-item', function() {
    $(this).css('background', 'transparent');
  });
});
