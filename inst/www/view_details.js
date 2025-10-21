// Handle View Details button clicks
$(document).on('click', '.view-details-btn', function() {
  console.log('=== View Details Button Clicked ===');

  var conceptId = $(this).data('id');
  console.log('1. Concept ID from button:', conceptId);

  // Find the table ID to get the namespace
  var table = $(this).closest('.dataTables_wrapper').find('table');
  console.log('2. Table found:', table.length > 0 ? 'Yes' : 'No');

  var tableId = table.attr('id');
  console.log('3. Table ID:', tableId);

  // The table ID is in the format: module_id-general_concepts_table
  // We need to send to: module_id-view_concept_details
  var inputName = tableId.replace('general_concepts_table', 'view_concept_details');
  console.log('4. Input name to send:', inputName);
  console.log('5. Concept ID to send:', conceptId);

  // Check if Shiny is available
  if (typeof Shiny !== 'undefined') {
    console.log('6. Shiny is available, sending value...');
    Shiny.setInputValue(inputName, conceptId, {priority: 'event'});
    console.log('7. Value sent to Shiny');
  } else {
    console.error('6. ERROR: Shiny is not available!');
  }
});
