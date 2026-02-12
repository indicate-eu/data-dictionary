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
    }, 500)
  );

  // Listen for changes on limit checkbox
  $(document).on('change', '.fuzzy-search-limit-checkbox input[type="checkbox"]', function() {
    var inputId = $(this).attr('id');
    var checked = $(this).is(':checked');
    Shiny.setInputValue(inputId, checked, {priority: 'event'});
  });

  // Listen for clicks on settings button
  $(document).on('click', '.fuzzy-search-settings-btn', function(e) {
    e.preventDefault();
    e.stopPropagation();
    var inputId = $(this).attr('id');
    console.log('Settings button clicked, id:', inputId);
    Shiny.setInputValue(inputId, Math.random(), {priority: 'event'});
  });
});
