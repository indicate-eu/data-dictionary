// Prevent mousedown on action buttons from triggering row selection
$(document).on('mousedown', '.btn-eval-action', function(e) {
  e.stopPropagation();
});

// Handle evaluation action buttons
$(document).on('click', '.btn-eval-action', function(e) {
  e.preventDefault();
  e.stopPropagation();

  var action = $(this).data('action');
  var row = $(this).data('row');
  var mappingId = $(this).data('mapping-id');

  // Send action to Shiny
  Shiny.setInputValue('concept_mapping-eval_action', {
    action: action,
    row: row,
    mapping_id: mappingId,
    timestamp: new Date().getTime()
  }, {priority: 'event'});
});

