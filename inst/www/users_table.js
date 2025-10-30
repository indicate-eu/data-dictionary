// Handle edit and delete buttons in users table
$(document).on('click', '.btn-edit', function() {
  var userId = $(this).data('user-id');
  Shiny.setInputValue('settings-users-edit_user', userId, {priority: 'event'});
});

$(document).on('click', '.btn-delete', function() {
  var userId = $(this).data('user-id');
  if (confirm('Are you sure you want to delete this user?')) {
    Shiny.setInputValue('settings-users-delete_user', userId, {priority: 'event'});
  }
});
