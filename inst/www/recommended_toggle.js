// Handle recommended column toggle in edit mode
$(document).ready(function() {

  // Use event delegation on document to handle clicks on toggle switches
  $(document).on('change', '.toggle-switch input[type="checkbox"]', function(e) {
    e.stopPropagation();

    try {
      var $label = $(this).closest('.toggle-switch');
      var omopId = $label.data('omop-id');
      var isChecked = $(this).is(':checked');

      // Send to Shiny
      Shiny.setInputValue('dictionary_explorer-toggle_recommended', {
        omop_id: omopId,
        new_value: isChecked ? 'Yes' : 'No'
      }, {priority: 'event'});

    } catch (error) {
      console.error('Error toggling recommended value:', error);
    }
  });

  // Prevent toggle clicks from triggering row selection
  $(document).on('click', '.toggle-switch', function(e) {
    e.stopPropagation();
  });
});
