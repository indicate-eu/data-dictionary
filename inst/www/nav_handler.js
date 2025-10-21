// Navigation tab handler
$(document).ready(function() {
  // Handle navigation button clicks
  $('.nav-tab').on('click', function() {
    // Remove active class from all nav tabs
    $('.nav-tab').removeClass('nav-tab-active');

    // Add active class to clicked tab
    $(this).addClass('nav-tab-active');
  });
});
