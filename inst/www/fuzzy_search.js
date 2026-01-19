// Fuzzy search input handler with debounce
// Supports multiple fuzzy search inputs across the application
$(document).ready(function() {
  // Debounce function
  function debounce(func, wait) {
    var timeout;
    return function() {
      var context = this, args = arguments;
      clearTimeout(timeout);
      timeout = setTimeout(function() {
        func.apply(context, args);
      }, wait);
    };
  }

  // Listen for input on any fuzzy search field (class-based)
  $(document).on('input', '.fuzzy-search-input',
    debounce(function() {
      var val = $(this).val();
      var inputId = $(this).attr('id');
      // Send to Shiny with "_query" suffix
      Shiny.setInputValue(inputId + '_query', val, {priority: 'event'});
    }, 300)
  );

  // Listen for changes on limit checkbox
  $(document).on('change', '.fuzzy-search-limit-checkbox input[type="checkbox"]', function() {
    var inputId = $(this).attr('id');
    var checked = $(this).is(':checked');
    Shiny.setInputValue(inputId, checked, {priority: 'event'});
  });
});
