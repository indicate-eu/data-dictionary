// Make modals draggable and resizable
$(document).ready(function() {

  // Initialize draggable and resizable for modals when they are shown
  function initializeDraggableResizable() {
    $('.draggable-resizable-modal').each(function() {
      const $modal = $(this);

      // Only initialize if not already initialized
      if (!$modal.hasClass('ui-draggable')) {
        // Make draggable
        $modal.draggable({
          handle: '.modal-drag-handle',
          containment: 'window',
          cancel: 'button, input, textarea, select',
          // Reset transform when dragging starts
          start: function(event, ui) {
            $(this).css('transform', 'none');
            const top = $(this).offset().top;
            const left = $(this).offset().left;
            $(this).css({
              top: top + 'px',
              left: left + 'px'
            });
          }
        });
      }

      // Only initialize resizable if not already initialized
      if (!$modal.hasClass('ui-resizable')) {
        // Make resizable
        $modal.resizable({
          handles: 'n, e, s, w, ne, se, sw, nw',
          minWidth: 400,
          minHeight: 300,
          // Reset transform when resizing starts
          start: function(event, ui) {
            $(this).css('transform', 'none');
            const top = $(this).offset().top;
            const left = $(this).offset().left;
            $(this).css({
              top: top + 'px',
              left: left + 'px'
            });
          }
        });
      }
    });
  }

  // Watch for modal visibility changes
  const observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(mutation) {
      if (mutation.type === 'attributes' && mutation.attributeName === 'style') {
        const $target = $(mutation.target);
        if ($target.hasClass('modal-overlay-draggable') && $target.is(':visible')) {
          initializeDraggableResizable();
        }
      }
    });
  });

  // Observe all modal overlays
  $('.modal-overlay-draggable').each(function() {
    observer.observe(this, {
      attributes: true,
      attributeFilter: ['style']
    });
  });

  // Also initialize on page load for any visible modals
  initializeDraggableResizable();
});
