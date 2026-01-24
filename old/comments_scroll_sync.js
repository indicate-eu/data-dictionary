/**
 * Comments Fullscreen Modal - Scroll Synchronization
 *
 * This script manages scroll position synchronization between the markdown editor
 * textarea and the markdown preview pane in the fullscreen comments modal.
 *
 * Features:
 * 1. Preserves preview scroll position when content updates
 * 2. Synchronizes preview scroll position when user scrolls in textarea
 */

$(document).ready(function() {

  // Store last scroll position of preview
  let lastPreviewScrollTop = 0;
  let lastPreviewScrollHeight = 0;

  /**
   * Get the preview container element
   */
  function getPreviewContainer() {
    // The preview is inside the fullscreen modal
    return $('#dictionary_explorer-fullscreen_markdown_preview .markdown-content');
  }

  /**
   * Get the textarea element
   */
  function getTextarea() {
    return $('#dictionary_explorer-fullscreen_comments_input');
  }

  /**
   * Save current preview scroll position
   */
  function savePreviewScrollPosition() {
    const preview = getPreviewContainer();
    if (preview.length > 0) {
      lastPreviewScrollTop = preview.scrollTop();
      lastPreviewScrollHeight = preview[0].scrollHeight;
    }
  }

  /**
   * Restore preview scroll position after content update
   * This function is called after the preview is re-rendered
   */
  function restorePreviewScrollPosition() {
    const preview = getPreviewContainer();
    if (preview.length > 0 && lastPreviewScrollTop > 0) {
      // Calculate scroll position adjustment if content height changed
      const newScrollHeight = preview[0].scrollHeight;
      const heightDiff = newScrollHeight - lastPreviewScrollHeight;

      // If content grew, adjust scroll position proportionally
      let newScrollTop = lastPreviewScrollTop;
      if (heightDiff !== 0 && lastPreviewScrollHeight > 0) {
        const scrollRatio = lastPreviewScrollTop / lastPreviewScrollHeight;
        newScrollTop = scrollRatio * newScrollHeight;
      }

      preview.scrollTop(newScrollTop);
    }
  }

  /**
   * Synchronize preview scroll based on textarea scroll position
   * Maps textarea scroll percentage to preview scroll position
   */
  function syncScrollFromTextarea() {
    const textarea = getTextarea();
    const preview = getPreviewContainer();

    if (textarea.length === 0 || preview.length === 0) return;

    // Get textarea scroll percentage
    const textareaScrollTop = textarea.scrollTop();
    const textareaScrollHeight = textarea[0].scrollHeight - textarea[0].clientHeight;

    if (textareaScrollHeight <= 0) return;

    const scrollPercentage = textareaScrollTop / textareaScrollHeight;

    // Apply same percentage to preview
    const previewScrollHeight = preview[0].scrollHeight - preview[0].clientHeight;
    const newPreviewScrollTop = scrollPercentage * previewScrollHeight;

    preview.scrollTop(newPreviewScrollTop);

    // Update saved position
    lastPreviewScrollTop = newPreviewScrollTop;
    lastPreviewScrollHeight = preview[0].scrollHeight;
  }

  /**
   * Initialize scroll synchronization
   * Sets up event listeners when modal becomes visible
   */
  function initializeScrollSync() {
    const textarea = getTextarea();

    if (textarea.length === 0) return;

    // Remove any existing listeners to avoid duplicates
    textarea.off('scroll.commentsSync');
    textarea.off('input.commentsSync');

    // Save preview scroll position before any input changes
    textarea.on('input.commentsSync', function() {
      savePreviewScrollPosition();
    });

    // Synchronize scroll when user scrolls in textarea
    let scrollTimeout;
    textarea.on('scroll.commentsSync', function() {
      clearTimeout(scrollTimeout);
      scrollTimeout = setTimeout(function() {
        syncScrollFromTextarea();
      }, 50); // Small delay to avoid too many updates
    });
  }

  /**
   * Watch for preview container changes and restore scroll
   * Uses MutationObserver to detect when preview is re-rendered
   */
  function watchPreviewChanges() {
    const previewWrapper = document.getElementById('dictionary_explorer-fullscreen_markdown_preview');

    if (!previewWrapper) return;

    // Disconnect any existing observer
    if (window.commentsPreviewObserver) {
      window.commentsPreviewObserver.disconnect();
    }

    // Create new observer
    const observer = new MutationObserver(function(mutations) {
      // Wait a tiny bit for rendering to complete
      setTimeout(function() {
        restorePreviewScrollPosition();
      }, 10);
    });

    // Observe changes to preview wrapper
    observer.observe(previewWrapper, {
      childList: true,
      subtree: true
    });

    // Store observer globally so we can disconnect it later
    window.commentsPreviewObserver = observer;
  }

  /**
   * Main initialization function
   * Called when fullscreen modal is shown
   */
  function initializeCommentsScrollSync() {
    // Small delay to ensure modal DOM is ready
    setTimeout(function() {
      initializeScrollSync();
      watchPreviewChanges();

      // Initialize scroll position tracking
      const preview = getPreviewContainer();
      if (preview.length > 0) {
        lastPreviewScrollTop = preview.scrollTop();
        lastPreviewScrollHeight = preview[0].scrollHeight;
      }
    }, 100);
  }

  /**
   * Watch for modal visibility changes
   * Initialize when modal becomes visible
   */
  function watchModalVisibility() {
    const modal = document.getElementById('dictionary_explorer-comments_fullscreen_modal');

    if (!modal) {
      // Modal not found yet, try again later
      setTimeout(watchModalVisibility, 500);
      return;
    }

    // Use MutationObserver to detect when modal becomes visible
    const observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        if (mutation.type === 'attributes' && mutation.attributeName === 'style') {
          const isVisible = modal.style.display !== 'none' &&
                          window.getComputedStyle(modal).display !== 'none';

          if (isVisible) {
            initializeCommentsScrollSync();
          }
        }
      });
    });

    observer.observe(modal, {
      attributes: true,
      attributeFilter: ['style']
    });

    // Also check if modal is already visible
    const isVisible = modal.style.display !== 'none' &&
                     window.getComputedStyle(modal).display !== 'none';
    if (isVisible) {
      initializeCommentsScrollSync();
    }
  }

  // Start watching for modal visibility
  watchModalVisibility();
});
