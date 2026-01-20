// Lightbox functionality for documentation images
document.addEventListener('DOMContentLoaded', function() {
  // Create lightbox overlay
  var overlay = document.createElement('div');
  overlay.className = 'lightbox-overlay';
  overlay.innerHTML = '<span class="lightbox-close">&times;</span><img src="" alt="">';
  document.body.appendChild(overlay);

  var lightboxImg = overlay.querySelector('img');
  var closeBtn = overlay.querySelector('.lightbox-close');

  // Close function
  function closeLightbox() {
    overlay.classList.remove('active');
    document.body.style.overflow = '';
  }

  // Add click handler to all images in doc-main
  var images = document.querySelectorAll('.doc-main img');
  images.forEach(function(img) {
    img.addEventListener('click', function() {
      lightboxImg.src = this.src;
      lightboxImg.alt = this.alt;
      overlay.classList.add('active');
      document.body.style.overflow = 'hidden';
    });
  });

  // Close lightbox on overlay click (but not on image click)
  overlay.addEventListener('click', function(e) {
    if (e.target === overlay) {
      closeLightbox();
    }
  });

  // Close on close button click
  closeBtn.addEventListener('click', function(e) {
    e.stopPropagation();
    closeLightbox();
  });

  // Close on image click (zoom out)
  lightboxImg.addEventListener('click', function(e) {
    e.stopPropagation();
    closeLightbox();
  });

  // Close on Escape key
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && overlay.classList.contains('active')) {
      closeLightbox();
    }
  });
});
