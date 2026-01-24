// Handle copy dropdown menu
$(document).ready(function() {

  // Toggle dropdown menu when copy button is clicked
  $(document).on('click', '.copy-menu-trigger', function(e) {
    e.stopPropagation();
    const $container = $(this).closest('.copy-dropdown-container');
    const $menu = $container.find('.copy-dropdown-menu');

    // Close all other dropdowns first
    $('.copy-dropdown-menu').not($menu).hide();

    // Toggle this dropdown
    $menu.toggle();
  });

  // Close dropdown when clicking outside
  $(document).on('click', function(e) {
    if (!$(e.target).closest('.copy-dropdown-container').length) {
      $('.copy-dropdown-menu').hide();
    }
  });

  // Handle menu item clicks
  $(document).on('click', '.copy-menu-item', function(e) {
    e.stopPropagation();
    const itemId = $(this).attr('id');

    // Close the menu
    $(this).closest('.copy-dropdown-menu').hide();

    // Trigger Shiny input
    Shiny.setInputValue(itemId, Date.now(), {priority: 'event'});
  });

});
