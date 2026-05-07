/**
 * SPA Init — boots the single-page app after all scripts have loaded.
 * Loads data, wires up routes, and starts the hash router.
 */
(function () {
  'use strict';

  var pages = {
    '/concept-sets':    { el: 'page-concept-sets',    mod: ConceptSetsPage },
    '/mapping-recommendations': { el: 'page-mapping-recommendations', mod: MappingRecommendationsPage },
    '/projects':        { el: 'page-projects',        mod: ProjectsPage },
    '/settings':        { el: 'page-settings',        mod: SettingsPage },
    '/dev-tools':       { el: 'page-dev-tools',       mod: DevToolsPage },
    '/documentation':   { el: 'page-documentation',   mod: DocumentationPage }
  };

  var currentPage = null;

  function hideAllPages() {
    if (currentPage && pages[currentPage] && pages[currentPage].mod.hide) {
      pages[currentPage].mod.hide();
    }
    var keys = Object.keys(pages);
    for (var i = 0; i < keys.length; i++) {
      document.getElementById(pages[keys[i]].el).style.display = 'none';
    }
  }

  function updateActiveNav(pageName) {
    var tabs = document.querySelectorAll('.header-nav .nav-tab');
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].classList.toggle('active', tabs[i].getAttribute('data-page') === pageName);
    }
    // Close settings dropdown menu after navigation
    var menu = document.getElementById('nav-settings-menu');
    if (menu) menu.style.display = 'none';
  }

  // Register routes
  var keys = Object.keys(pages);
  for (var i = 0; i < keys.length; i++) {
    (function (path) {
      var page = pages[path];
      Router.register(path, function (_path, query) {
        hideAllPages();
        currentPage = path;
        document.getElementById(page.el).style.display = 'flex';
        page.mod.show(query);
        updateActiveNav(page.el.replace('page-', ''));
      });
    })(keys[i]);
  }

  // Register language change callbacks for pages that support it
  if (ConceptSetsPage.onLanguageChange) App.onLanguageChange(ConceptSetsPage.onLanguageChange);
  if (ProjectsPage.onLanguageChange) App.onLanguageChange(ProjectsPage.onLanguageChange);
  if (MappingRecommendationsPage.onLanguageChange) App.onLanguageChange(MappingRecommendationsPage.onLanguageChange);
  if (DocumentationPage.onLanguageChange) App.onLanguageChange(DocumentationPage.onLanguageChange);

  // Global tooltip for elements with [data-tooltip]
  (function () {
    var tip = document.createElement('div');
    tip.className = 'app-tooltip';
    tip.style.display = 'none';
    document.body.appendChild(tip);
    var current = null;

    function position(e) {
      var pad = 14;
      var x = e.clientX + pad;
      var y = e.clientY + pad;
      var rect = tip.getBoundingClientRect();
      if (x + rect.width + 4 > window.innerWidth) x = e.clientX - rect.width - pad;
      if (y + rect.height + 4 > window.innerHeight) y = e.clientY - rect.height - pad;
      if (x < 4) x = 4;
      if (y < 4) y = 4;
      tip.style.left = x + 'px';
      tip.style.top = y + 'px';
    }

    document.addEventListener('mouseover', function (e) {
      var el = e.target.closest && e.target.closest('[data-tooltip]');
      if (!el) return;
      var text = el.getAttribute('data-tooltip');
      if (!text) return;
      current = el;
      tip.textContent = text;
      tip.style.display = 'block';
      position(e);
      requestAnimationFrame(function () { tip.classList.add('visible'); });
    });
    document.addEventListener('mousemove', function (e) {
      if (!current) return;
      position(e);
    });
    document.addEventListener('mouseout', function (e) {
      if (!current) return;
      if (e.relatedTarget && current.contains(e.relatedTarget)) return;
      current = null;
      tip.classList.remove('visible');
      tip.style.display = 'none';
    });
  })();

  // Centralized Escape key handler
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      // Close any open modal overlays
      var modals = document.querySelectorAll('.modal-overlay');
      for (var i = 0; i < modals.length; i++) {
        if (modals[i].style.display !== 'none') {
          modals[i].style.display = 'none';
          return;
        }
      }
      // Close fullscreen modals
      var fsModals = document.querySelectorAll('.modal-fs');
      for (var j = 0; j < fsModals.length; j++) {
        if (fsModals[j].style.display !== 'none') {
          fsModals[j].style.display = 'none';
          return;
        }
      }
      // Close column visibility dropdown
      var colVis = document.getElementById('col-vis-dropdown');
      if (colVis && colVis.style.display !== 'none') {
        colVis.style.display = 'none';
      }
    }
  });

  // Apply branding from config (title, favicon, header logo and title)
  var cfg = App.config || {};
  if (cfg.title) document.title = cfg.title;
  var branding = cfg.branding || {};
  if (branding.favicon) {
    var favLink = document.querySelector('link[rel="icon"]');
    if (favLink) favLink.href = branding.favicon;
  }
  var headerLogo = document.querySelector('.header-logo');
  if (headerLogo) {
    if (branding.logo) headerLogo.src = branding.logo;
    if (branding.logoAlt) headerLogo.alt = branding.logoAlt;
  }
  var headerTitle = document.querySelector('.header-title');
  if (headerTitle && cfg.title) headerTitle.textContent = cfg.title;

  // Hide nav tabs that are disabled in config (showProjects / showMappingRecommendations default to true)
  var tabs = cfg.tabs || {};
  if (tabs.showProjects === false) {
    var projTab = document.querySelector('.nav-tab[data-page="projects"]');
    if (projTab) projTab.style.display = 'none';
  }
  if (tabs.showMappingRecommendations === false) {
    var mrTab = document.querySelector('.nav-tab[data-page="mapping-recommendations"]');
    if (mrTab) mrTab.style.display = 'none';
  }

  // Boot the app
  App.loadData();
  App.checkForDataUpdate();
  App.updateUserBadge();
  App.initSharedEvents();
  App.translateDOM();

  // Footer — fixed: references the master upstream app, not the fork's dictionary.
  // The version reflects the app code running here, not the dictionary content (which is
  // versioned per concept set).
  var footer = document.getElementById('app-footer');
  if (footer) {
    footer.innerHTML = App.APP_NAME + ' v' + App.APP_VERSION +
      ' · <a href="' + App.APP_GITHUB_URL + '" target="_blank" rel="noopener">GitHub</a>';
  }

  Router.init();
})();
