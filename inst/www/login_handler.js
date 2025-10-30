// Toggle password visibility
$(document).on('click', '#login-toggle_password', function(e) {
  e.preventDefault();
  var passwordInput = $('#login-password');
  var icon = $('#login-password_icon');

  if (passwordInput.attr('type') === 'password') {
    passwordInput.attr('type', 'text');
    icon.removeClass('fa-eye').addClass('fa-eye-slash');
  } else {
    passwordInput.attr('type', 'password');
    icon.removeClass('fa-eye-slash').addClass('fa-eye');
  }
});

// Handle Enter key press on login form - IMMEDIATE submission without delay
$(document).on('keydown', '#login-password', function(e) {
  if (e.which === 13) {
    e.preventDefault();
    e.stopPropagation();

    // Force Shiny to update the input value immediately
    var currentValue = $(this).val();
    Shiny.setInputValue('login-password', currentValue, {priority: 'event'});

    // Small delay to ensure the value is sent, then trigger click
    setTimeout(function() {
      $('#login-login_btn').click();
    }, 10);
  }
});

$(document).on('keydown', '#login-login', function(e) {
  if (e.which === 13) {
    e.preventDefault();
    e.stopPropagation();

    // Force Shiny to update the input value immediately
    var currentValue = $(this).val();
    Shiny.setInputValue('login-login', currentValue, {priority: 'event'});

    // Focus password field
    $('#login-password').focus();
  }
});
