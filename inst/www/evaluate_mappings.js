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

// Handle double-click on table rows for comment editing
$(document).on('dblclick', '#concept_mapping-evaluate_mappings_table tbody tr', function(e) {
  try {
    var $row = $(this);
    var $table = $row.closest('table');

    // Try to get DataTable instance
    if ($.fn.DataTable && $.fn.DataTable.isDataTable($table)) {
      var table = $table.DataTable();
      var rowData = table.row($row).data();

      if (rowData && rowData.length >= 3) {
        // mapping_id is in column 0 (hidden)
        var mappingId = rowData[0];
        var source = rowData[1];
        var target = rowData[2];

        // Send to Shiny
        Shiny.setInputValue('concept_mapping-eval_table_dblclick', {
          mapping_id: mappingId,
          source: source,
          target: target,
          timestamp: new Date().getTime()
        }, {priority: 'event'});
      }
    }
  } catch (error) {
    console.error('Error in double-click handler:', error);
  }
});
