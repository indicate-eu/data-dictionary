// Prevent text selection during double-click on DataTables
$(document).on('shiny:connected', function() {

  // Track if we're in the middle of a double-click
  let isDoubleClicking = false;
  let doubleClickTimer = null;

  // Listen for mousedown on DataTable rows
  $(document).on('mousedown', '.dataTable tbody tr', function(e) {
    const $table = $(this).closest('.dataTable');

    // If this is potentially the start of a double-click
    if (doubleClickTimer) {
      // This is the second click of a double-click
      isDoubleClicking = true;

      // Add no-select class to prevent selection
      $table.addClass('no-select');

      // Clear any existing selection
      if (window.getSelection) {
        window.getSelection().removeAllRanges();
      }

      // Remove the class after a short delay
      setTimeout(function() {
        $table.removeClass('no-select');
        isDoubleClicking = false;
      }, 300);

      clearTimeout(doubleClickTimer);
      doubleClickTimer = null;
    } else {
      // This is the first click
      doubleClickTimer = setTimeout(function() {
        doubleClickTimer = null;
      }, 300);
    }
  });

  // Also handle the dblclick event to ensure selection is cleared
  $(document).on('dblclick', '.dataTable tbody tr', function(e) {
    const $table = $(this).closest('.dataTable');

    // Add no-select class
    $table.addClass('no-select');

    // Clear any selection that might have occurred
    if (window.getSelection) {
      window.getSelection().removeAllRanges();
    }

    // Remove the class after a short delay
    setTimeout(function() {
      $table.removeClass('no-select');
    }, 300);
  });

});
