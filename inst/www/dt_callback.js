table.on('select', function(e, dt, type, indexes) {
  if (type === 'row') {
    // R indexing adjustment
    var r_indexed_indexes = [];
    for (var i = 0; i < indexes.length; i++) {
      r_indexed_indexes.push(indexes[i] + 1);
    }
    
    Shiny.setInputValue('details_table_rows_selected', r_indexed_indexes, {priority: 'event'});
  }
});

// Add handler for deselect
table.on('deselect', function(e, dt, type, indexes) {
  try {
    // Send empty array to indicate that no row is selected
    Shiny.setInputValue('details_table_rows_selected', [], {priority: 'event'});
  } catch(err) {
    console.error('Error in deselect event:', err);
  }
});

// Add handler for page change
table.on('page.dt', function() {
  setTimeout(function() {
    try {
      var visibleIndexes = table.rows({search: 'applied', page: 'current'}).indexes();
      if (visibleIndexes.length > 0) {
        table.rows().deselect();
        table.row(visibleIndexes[0]).select();
      }
    } catch(err) {
      console.error('Error in page change handler:', err);
    }
  }, 100);
});

// Add handler for sorting and filtering
table.on('draw.dt', function() {
  setTimeout(function() {
    try {
      var visibleIndexes = table.rows({search: 'applied', page: 'current'}).indexes();
      if (visibleIndexes.length > 0) {
        table.rows().deselect();
        table.row(visibleIndexes[0]).select();
      }
    } catch(err) {
      console.error('Error in draw handler:', err);
    }
  }, 100);
});
