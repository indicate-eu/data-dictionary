// Store current selection before action button click
var evalMappingsCurrentSelection = null;

// Capture selection before mousedown on action buttons
$(document).on('mousedown', '.btn-eval-action', function(e) {
  // Store current selection
  var table = $(this).closest('table').DataTable();
  if (table) {
    evalMappingsCurrentSelection = table.rows({ selected: true }).indexes().toArray();
  }
});

// Handle evaluation action buttons
$(document).on('click', '.btn-eval-action', function(e) {
  e.preventDefault();

  var $btn = $(this);
  var action = $btn.data('action');
  var row = $btn.data('row');
  var mappingId = $btn.data('mapping-id');

  // Send action to Shiny
  Shiny.setInputValue('concept_mapping-eval_action', {
    action: action,
    row: row,
    mapping_id: mappingId,
    timestamp: new Date().getTime()
  }, {priority: 'event'});

  // Restore selection after a short delay
  setTimeout(function() {
    if (evalMappingsCurrentSelection !== null) {
      var table = $btn.closest('table').DataTable();
      if (table && evalMappingsCurrentSelection.length > 0) {
        table.rows().deselect();
        table.rows(evalMappingsCurrentSelection).select();
      }
    }
  }, 50);
});
