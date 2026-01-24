// Handle View Details button clicks
$(document).on('click', '.view-details-btn', function() {
  var conceptId = $(this).data('id');

  // Find the table ID to get the namespace
  var table = $(this).closest('.dataTables_wrapper').find('table');
  var tableId = table.attr('id');

  // The table ID is in the format: module_id-general_concepts_table
  // We need to send to: module_id-view_concept_details
  var inputName = tableId.replace('general_concepts_table', 'view_concept_details');

  // Send value to Shiny
  if (typeof Shiny !== 'undefined') {
    Shiny.setInputValue(inputName, conceptId, {priority: 'event'});
  }
});
