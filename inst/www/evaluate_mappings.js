// Evaluate Mappings table - Manual row selection and action buttons
// Using selection='none' in DataTable to prevent button clicks from affecting selection

$(document).ready(function() {

  // Handle row clicks for manual selection (not on action column)
  $(document).on('click', '#concept_mapping-evaluate_mappings_table tbody td', function(e) {
    // If clicking on action button or inside action button, do nothing for selection
    if ($(e.target).hasClass('btn-eval-action') ||
        $(e.target).closest('.btn-eval-action').length > 0 ||
        $(this).find('.btn-eval-action').length > 0 && $(e.target).closest('button').length > 0) {
      return; // Don't change selection when clicking action buttons
    }

    var $row = $(this).closest('tr');
    var $table = $(this).closest('table');
    var rowIndex = $table.DataTable().row($row).index() + 1; // 1-based for Shiny

    // Toggle selection only when clicking on non-action cells
    if ($row.hasClass('selected')) {
      $row.removeClass('selected');
      Shiny.setInputValue('concept_mapping-evaluate_mappings_table_row_selected', null, {priority: 'event'});
    } else {
      // Deselect all other rows
      $table.find('tbody tr.selected').removeClass('selected');
      // Select this row
      $row.addClass('selected');
      Shiny.setInputValue('concept_mapping-evaluate_mappings_table_row_selected', rowIndex, {priority: 'event'});
    }
  });

  // Handle action button clicks - just send action, don't touch selection
  $(document).on('click', '.btn-eval-action', function(e) {
    e.preventDefault();
    e.stopPropagation();

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
  });

});
