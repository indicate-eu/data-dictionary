// Tab handler for concept relationships tabs
$(document).ready(function() {

  // Handle tab button clicks
  $(document).on('click', '.tab-btn', function() {
    // Get the parent section
    var $section = $(this).closest('.section-header-with-tabs');

    // Remove active class from all tabs in this section
    $section.find('.tab-btn').removeClass('tab-btn-active');

    // Add active class to clicked tab
    $(this).addClass('tab-btn-active');
  });

});
