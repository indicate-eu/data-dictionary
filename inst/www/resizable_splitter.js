$(document).ready(function() {
  // Wait a bit for Shiny to render the page
  setTimeout(initSplitter, 300);
  
  // Also listen for shiny:idle if available
  $(document).on('shiny:idle', function() {
    initSplitter();
  });
  
  function initSplitter() {
    // Find the hr element and replace it with our splitter
    var $hr = $('.main-content hr');
    if ($hr.length === 0) {
      return; // No hr found, exit
    }
    
    // Create splitter element
    var $splitter = $('<div class="splitter"></div>');
    
    // Replace hr with splitter
    $hr.replaceWith($splitter);
    
    var isDragging = false;
    var startY, startTopHeight;
    
    // Get the elements that will be resized
    var $mainContent = $('.main-content');
    var $topElement = $('.summary-container');
    var $lowerSection = $('.lower-section');
    
    // Style the splitter
    $splitter.css({
      'height': '8px',
      'background-color': '#dee2e6',
      'border-radius': '4px',
      'margin': '15px 0',
      'cursor': 'row-resize',
      'position': 'relative',
      'flex-shrink': '0',
      'z-index': '10',
      'transition': 'background-color 0.2s'
    });
    
    // Add hover effects
    $splitter.on('mouseenter', function() {
      $(this).css('background-color', '#0f60af');
    }).on('mouseleave', function() {
      if (!isDragging) {
        $(this).css('background-color', '#dee2e6');
      }
    });
    
    // Add mousedown event to splitter
    $splitter.on('mousedown', function(e) {
      isDragging = true;
      startY = e.clientY;
      startTopHeight = $topElement.height();
      
      // Add visual feedback
      $('body').addClass('resizing');
      $splitter.css('background-color', '#0f60af');
      
      // Prevent text selection during dragging
      e.preventDefault();
      e.stopPropagation();
    });
    
    // Handle mouse movement
    $(document).on('mousemove.splitter', function(e) {
      if (!isDragging) return;
      
      // Calculate new height
      var deltaY = e.clientY - startY;
      var newHeight = startTopHeight + deltaY;
      
      // Get available space
      var mainContentHeight = $mainContent.height();
      var splitterHeight = $splitter.outerHeight(true);
      
      // Set constraints
      var minTopHeight = 150;
      var minBottomHeight = 200;
      var maxTopHeight = mainContentHeight - splitterHeight - minBottomHeight;
      
      // Apply constraints
      newHeight = Math.max(minTopHeight, Math.min(newHeight, maxTopHeight));
      
      // Force override the CSS using style attribute with !important
      $topElement[0].style.setProperty('height', newHeight + 'px', 'important');
      $topElement[0].style.setProperty('max-height', newHeight + 'px', 'important');
      
      e.preventDefault();
    });
    
    // Handle mouse release
    $(document).on('mouseup.splitter', function(e) {
      if (isDragging) {
        isDragging = false;
        $('body').removeClass('resizing');
        $splitter.css('background-color', '#dee2e6');
        
        // Adjust DataTables if they exist
        setTimeout(function() {
          if ($.fn.dataTable) {
            $.fn.dataTable.tables({ visible: true, api: true }).columns.adjust();
          }
        }, 50);
      }
    });
    
    console.log('Splitter initialized successfully');
  }
  
  // Handle window resize
  $(window).on('resize', function() {
    setTimeout(function() {
      if ($.fn.dataTable) {
        $.fn.dataTable.tables({ visible: true, api: true }).columns.adjust();
      }
    }, 100);
  });
});