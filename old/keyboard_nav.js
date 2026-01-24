function(settings, json) {
  // Get parameters from json or use defaults
  var config = $.extend({
    autoSelectFirstRow: true,
    autoFocus: true
  }, json || {});
  
  // Wait for the table to be fully loaded
  setTimeout(function() {
    // Find the table
    var tableEl = settings.nTable;
    if (!tableEl) return;
    
    // Get DataTable instance
    var table = $(tableEl).DataTable();
    
    // Add tabindex for keyboard navigation only if autoFocus is true
    if (config.autoFocus) {
      $(tableEl).attr('tabindex', '0');
    } else {
      // If we don't want auto focus, use a negative tabindex
      $(tableEl).attr('tabindex', '-1');
    }
    
    // Add keyboard navigation
    $(tableEl).off('keydown').on('keydown', function(e) {
      try {
        // Get only visible (filtered) rows indexes on the current page
        var pageInfo = table.page.info();
        var visibleIndexes = table.rows({search: 'applied', page: 'current'}).indexes();
        var totalVisibleRows = visibleIndexes.length;
        
        if (totalVisibleRows === 0) return; // No visible rows, don't proceed
        
        // Get the index of the selected row, if any
        var selectedIndexes = table.rows({selected: true}).indexes();
        var currentIndex = selectedIndexes.length > 0 ? selectedIndexes[0] : -1;
        
        // Find the position of the currentIndex in the visibleIndexes array
        var currentPosition = -1;
        for (var i = 0; i < visibleIndexes.length; i++) {
          if (visibleIndexes[i] === currentIndex) {
            currentPosition = i;
            break;
          }
        }
        
        switch(e.keyCode) {
          // Down arrow
          case 40:
            if (currentPosition < totalVisibleRows - 1 && currentPosition !== -1) {
              try {
                // Deselect all rows first
                table.rows().deselect();
                
                // Get the next visible row index
                var nextVisibleIndex = visibleIndexes[currentPosition + 1];
                
                // Normal selection
                table.row(nextVisibleIndex).select();
                
                // Scroll if necessary
                var nextRow = table.row(nextVisibleIndex).node();
                if (nextRow && nextRow.scrollIntoView) {
                  nextRow.scrollIntoView({block: 'nearest'});
                }
              } catch(err) {
                console.error('Error navigating down:', err);
              }
            } else if (currentPosition === -1 && totalVisibleRows > 0) {
              // If no row is selected, select the first visible one
              try {
                var firstVisibleIndex = visibleIndexes[0];
                table.row(firstVisibleIndex).select();
              } catch(err) {
                console.error('Error selecting first row:', err);
              }
            } else if (pageInfo.page < pageInfo.pages - 1) {
              // If we're at the last row of the current page but not the last page, go to next page
              // and select the first row of that page
              table.page('next').draw('page');
              // Already handled by the page.dt event, but we can add this for clarity
              setTimeout(function() {
                try {
                  var newVisibleIndexes = table.rows({search: 'applied', page: 'current'}).indexes();
                  if (newVisibleIndexes.length > 0) {
                    // Select the first row on the new page
                    var firstRowIndex = newVisibleIndexes[0];
                    table.row(firstRowIndex).select();
                    
                    // Scroll to make it visible
                    var firstRow = table.row(firstRowIndex).node();
                    if (firstRow && firstRow.scrollIntoView) {
                      firstRow.scrollIntoView({block: 'nearest'});
                    }
                  }
                } catch(err) {
                  console.error('Error selecting first row on next page:', err);
                }
              }, 100);
            }
            e.preventDefault();
            break;
          
          // Up arrow
          case 38:
            if (currentPosition > 0) {
              try {
                // Deselect all rows first
                table.rows().deselect();
                
                // Get the previous visible row index
                var prevVisibleIndex = visibleIndexes[currentPosition - 1];
                
                // Normal selection
                table.row(prevVisibleIndex).select();
                
                // Scroll if necessary
                var prevRow = table.row(prevVisibleIndex).node();
                if (prevRow && prevRow.scrollIntoView) {
                  prevRow.scrollIntoView({block: 'nearest'});
                }
              } catch(err) {
                console.error('Error navigating up:', err);
              }
            } else if (currentPosition === -1 && totalVisibleRows > 0) {
              // If no row is selected, select the first visible one
              try {
                var firstVisibleIndex = visibleIndexes[0];
                table.row(firstVisibleIndex).select();
              } catch(err) {
                console.error('Error selecting first row:', err);
              }
            } else if (pageInfo.page > 0) {
              // If we're at the first row of the current page but not the first page, go to previous page
              // and select the last row of that page
              table.page('previous').draw('page');
              // Add this part to select the last row after page change
              setTimeout(function() {
                try {
                  var newVisibleIndexes = table.rows({search: 'applied', page: 'current'}).indexes();
                  if (newVisibleIndexes.length > 0) {
                    // Select the last row on the page
                    var lastRowIndex = newVisibleIndexes[newVisibleIndexes.length - 1];
                    table.row(lastRowIndex).select();
                    
                    // Scroll to make it visible
                    var lastRow = table.row(lastRowIndex).node();
                    if (lastRow && lastRow.scrollIntoView) {
                      lastRow.scrollIntoView({block: 'nearest'});
                    }
                  }
                } catch(err) {
                  console.error('Error selecting last row on previous page:', err);
                }
              }, 100);
            }
            e.preventDefault();
            break;
            
          // Left arrow - go to previous page
          case 37:
            try {
              if (pageInfo.page > 0) {
                // Move to previous page
                table.page('previous').draw('page');
              }
            } catch(err) {
              console.error('Error navigating to previous page:', err);
            }
            e.preventDefault();
            break;
          
          // Right arrow - go to next page
          case 39:
            try {
              if (pageInfo.page < pageInfo.pages - 1) {
                // Move to next page
                table.page('next').draw('page');
              }
            } catch(err) {
              console.error('Error navigating to next page:', err);
            }
            e.preventDefault();
            break;
        }
      } catch(err) {
        console.error('Error in key handler:', err);
      }
    });
    
    // Focus on the table only if autoFocus is true
    if (config.autoFocus) {
      $(tableEl).focus();
    }
    
    // Initialize first row selection only if autoSelectFirstRow is true
    if (config.autoSelectFirstRow) {
      setTimeout(function() {
        try {
          var visibleIndexes = table.rows({search: 'applied', page: 'current'}).indexes();
          if (visibleIndexes.length > 0) {
            table.row(visibleIndexes[0]).select();
          }
        } catch(err) {
          console.error('Error selecting initial row:', err);
        }
      }, 100);
    }
  }, 500);
}
