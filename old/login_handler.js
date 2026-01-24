// Toggle password visibility - generic handler for any password field
$(document).on('click', '.password-toggle-btn', function(e) {
  e.preventDefault();
  var $btn = $(this);
  var inputId = $btn.data('input');
  var iconId = $btn.data('icon');

  // Fallback for login page (old format)
  if (!inputId) {
    if ($btn.attr('id') === 'login-toggle_password') {
      inputId = 'login-password';
      iconId = 'login-password_icon';
    }
  }

  var passwordInput = $('#' + inputId);
  var icon = $('#' + iconId);

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
