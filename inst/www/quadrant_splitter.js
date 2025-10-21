// Simple horizontal splitter
$(document).ready(function() {

  let isResizing = false;
  let startY = 0;
  let startTopHeight = 0;
  let startBottomHeight = 0;

  function initSplitter() {
    const $splitter = $('.splitter-h');
    if (!$splitter.length) return;

    const $topSection = $('.top-section');
    const $bottomSection = $('.bottom-section');

    $splitter.off('mousedown').on('mousedown', function(e) {
      e.preventDefault();

      isResizing = true;
      startY = e.pageY;
      startTopHeight = $topSection.height();
      startBottomHeight = $bottomSection.height();

      $splitter.addClass('splitter-active');
      $('body').addClass('resizing');
    });
  }

  $(document).on('mousemove', function(e) {
    if (!isResizing) return;

    const $topSection = $('.top-section');
    const $bottomSection = $('.bottom-section');
    const $splitter = $('.splitter-h');
    const containerHeight = $('.quadrant-layout').height();
    const splitterHeight = $splitter.outerHeight();

    const deltaY = e.pageY - startY;
    let newTopHeight = startTopHeight + deltaY;
    let newBottomHeight = startBottomHeight - deltaY;

    const minHeight = 200;
    const maxTopHeight = containerHeight - splitterHeight - minHeight;

    if (newTopHeight < minHeight) newTopHeight = minHeight;
    if (newTopHeight > maxTopHeight) newTopHeight = maxTopHeight;

    newBottomHeight = containerHeight - newTopHeight - splitterHeight;

    $topSection.css('height', newTopHeight + 'px');
    $bottomSection.css('height', newBottomHeight + 'px');
  });

  $(document).on('mouseup', function() {
    if (isResizing) {
      isResizing = false;
      $('.splitter-h').removeClass('splitter-active');
      $('body').removeClass('resizing');
    }
  });

  // Initialize when quadrant layout appears
  const observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(mutation) {
      if (mutation.addedNodes.length) {
        mutation.addedNodes.forEach(function(node) {
          if (node.nodeType === 1 && ($(node).hasClass('quadrant-layout') || $(node).find('.quadrant-layout').length)) {
            setTimeout(initSplitter, 100);
          }
        });
      }
    });
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  // Initialize if already present
  if ($('.quadrant-layout').length) {
    setTimeout(initSplitter, 100);
  }
});
