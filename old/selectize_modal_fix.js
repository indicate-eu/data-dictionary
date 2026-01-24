// Fix selectize dropdowns in modals by detaching them to body
// This prevents overflow:hidden on parent containers from clipping the dropdown

$(document).ready(function() {

  // Function to fix a selectize instance
  function fixSelectizeInModal(selectize) {
    if (!selectize || !selectize.$dropdown) return;

    var $dropdown = selectize.$dropdown;
    var $control = selectize.$control;

    // Store original parent
    var originalParent = $dropdown.parent();

    // Override the positionDropdown method
    var originalPositionDropdown = selectize.positionDropdown;

    selectize.positionDropdown = function() {
      // Check if inside a modal
      var $modal = $control.closest('.modal-overlay, .modal-content');
      if ($modal.length === 0) {
        // Not in modal, use default behavior
        originalPositionDropdown.call(this);
        return;
      }

      // Detach dropdown to body if not already
      if (!$dropdown.hasClass('dropdown-detached')) {
        $dropdown.addClass('dropdown-detached');
        $dropdown.appendTo('body');
      }

      // Calculate position relative to viewport
      var controlOffset = $control.offset();
      var controlHeight = $control.outerHeight();
      var controlWidth = $control.outerWidth();

      // Position dropdown below the control
      $dropdown.css({
        position: 'fixed',
        top: controlOffset.top + controlHeight - $(window).scrollTop(),
        left: controlOffset.left - $(window).scrollLeft(),
        width: controlWidth
      });
    };

    // When dropdown closes, move it back to original parent
    var originalClose = selectize.close;
    selectize.close = function() {
      originalClose.call(this);
      if ($dropdown.hasClass('dropdown-detached')) {
        $dropdown.removeClass('dropdown-detached');
        $dropdown.appendTo(originalParent);
      }
    };
  }

  // Apply fix to all selectize instances in modals
  function applyFixToModalSelectize() {
    $('.modal-overlay select, .modal-content select').each(function() {
      var selectize = this.selectize;
      if (selectize && !selectize._modalFixed) {
        fixSelectizeInModal(selectize);
        selectize._modalFixed = true;
      }
    });
  }

  // Apply fix when document is ready
  applyFixToModalSelectize();

  // Apply fix when new selectize instances are created (for dynamic content)
  var observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(mutation) {
      if (mutation.addedNodes.length) {
        setTimeout(applyFixToModalSelectize, 100);
      }
    });
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  // Reapply fix when modal is shown
  $(document).on('click', '[data-toggle="modal"], .show-modal', function() {
    setTimeout(applyFixToModalSelectize, 200);
  });

  // Also fix when modal becomes visible via jQuery show()
  var originalShow = $.fn.show;
  $.fn.show = function() {
    var result = originalShow.apply(this, arguments);
    if (this.hasClass('modal-overlay') || this.find('.modal-content').length) {
      setTimeout(applyFixToModalSelectize, 100);
    }
    return result;
  };
});
