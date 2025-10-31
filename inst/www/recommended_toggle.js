// Handle recommended column toggle and delete actions in edit mode
$(document).ready(function() {

  // Use event delegation on document to handle clicks on toggle switches
  $(document).on('change', '.toggle-switch input[type="checkbox"]', function(e) {
    e.stopPropagation();

    try {
      var $label = $(this).closest('.toggle-switch');
      var omopId = $label.data('omop-id');
      var customId = $label.data('custom-id');
      var isCustom = customId !== '' && customId !== undefined;
      var isChecked = $(this).is(':checked');

      // Send to Shiny
      Shiny.setInputValue('dictionary_explorer-toggle_recommended', {
        omop_id: omopId,
        custom_id: customId,
        is_custom: isCustom,
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

  // Handle delete icon clicks
  $(document).on('click', '.delete-icon', function(e) {
    e.stopPropagation();

    try {
      var omopId = $(this).data('omop-id');
      var customId = $(this).data('custom-id');
      var isCustom = customId !== '' && customId !== undefined;

      // Send delete request to Shiny
      Shiny.setInputValue('dictionary_explorer-delete_concept', {
        omop_id: omopId,
        custom_id: customId,
        is_custom: isCustom
      }, {priority: 'event'});

    } catch (error) {
      console.error('Error deleting concept:', error);
    }
  });
});
