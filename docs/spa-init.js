/**
 * SPA Init — boots the single-page app after all scripts have loaded.
 * Loads data, wires up routes, and starts the hash router.
 */
(function () {
  'use strict';

  var pages = {
    '/concept-sets':    { el: 'page-concept-sets',    mod: ConceptSetsPage },
    '/etl-guidelines':  { el: 'page-etl-guidelines',  mod: EtlGuidelinesPage },
    '/projects':        { el: 'page-projects',        mod: ProjectsPage },
    '/settings':        { el: 'page-settings',        mod: SettingsPage },
    '/general-settings':{ el: 'page-general-settings', mod: GeneralSettingsPage },
    '/dev-tools':       { el: 'page-dev-tools',       mod: DevToolsPage }
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

  // Boot the app
  App.loadData();
  App.checkForDataUpdate();
  App.updateUserBadge();
  App.initSharedEvents();
  App.translateDOM();

  // Footer
  var footer = document.getElementById('app-footer');
  if (footer) footer.textContent = App.APP_NAME + ' v' + App.APP_VERSION;

  Router.init();
})();
