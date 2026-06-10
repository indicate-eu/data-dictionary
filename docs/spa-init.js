/**
 * SPA Init — boots the single-page app after all scripts have loaded.
 * Loads data, wires up routes, and starts the hash router.
 */
(function () {
  'use strict';

  var pages = {
    '/concept-sets':    { el: 'page-concept-sets',    mod: ConceptSetsPage },
    '/mapping':         { el: 'page-mapping',         mod: MappingPage },
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

  // Remember the last full hash visited for each top-level page (session-only,
  // i.e. not persisted across reloads). Lets the user click a header nav tab
  // and land back where they were on that page, including any query state
  // (e.g. opened mapping project, current Eligibility selection, etc.).
  var lastHashByPath = {};

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

  // Track the latest hash per page so a header click can restore it. We read
  // the path straight from the URL (not from currentPage) because `hashchange`
  // fires before the Router updates currentPage when the user navigates from
  // page A to page B — using currentPage there would mis-attribute the new
  // hash to page A.
  function rememberHash() {
    var hash = window.location.hash;
    if (!hash) return;
    var parsed = Router.parseHash();
    if (!parsed || !parsed.path) return;
    // Only track paths we registered (skip legacy aliases that redirect).
    if (!pages[parsed.path]) return;
    lastHashByPath[parsed.path] = hash;
  }
  window.addEventListener('hashchange', rememberHash);
  // Also pick up replaceState updates from page modules (which don't fire
  // hashchange). They go through Router.replaceState() to notify us.
  if (Router.onHashReplaced) Router.onHashReplaced(rememberHash);
  // Also after the initial render — the very first route was set before this
  // listener was attached.
  setTimeout(rememberHash, 0);

  // Legacy alias: the old Mapping Recommendations page now lives as a tab of
  // the Mapping page. Redirect bookmarks / external links to the new URL.
  Router.register('/mapping-recommendations', function () {
    Router.navigate('/mapping', { tab: 'recommendations' });
  });

  // Append ?lang=fr to a hash if the current URL has it and `hash` doesn't.
  // English is the default and stays implicit.
  function withCurrentLang(hash) {
    if (!hash) return hash;
    if (hash.indexOf('lang=') !== -1) return hash;
    var cur = window.location.hash || '';
    if (cur.indexOf('lang=fr') === -1) return hash;
    var sep = hash.indexOf('?') === -1 ? '?' : '&';
    return hash + sep + 'lang=fr';
  }

  // Intercept clicks on header nav tabs so they restore the last visited URL
  // for that page (including query state) instead of always going to the bare
  // path. If we don't have a remembered URL yet, we let the default href run.
  document.addEventListener('click', function(e) {
    var link = e.target.closest('.header-nav .nav-tab[data-page]');
    if (!link) return;
    var pageName = link.getAttribute('data-page');
    var path = '/' + pageName;
    var remembered = lastHashByPath[path];
    if (!remembered) {
      // First visit → default href takes you to the bare path. Still preserve
      // the active language by intercepting and rewriting the hash.
      var bare = link.getAttribute('href');
      var withLang = withCurrentLang(bare);
      if (withLang !== bare) {
        e.preventDefault();
        window.location.hash = withLang;
      }
      return;
    }
    if (window.location.hash === remembered) {
      // Already on the exact URL — clicking again resets to the bare path,
      // which feels natural (a "Home" shortcut for that section).
      e.preventDefault();
      window.location.hash = withCurrentLang(link.getAttribute('href'));
      return;
    }
    // The default href would replace the hash with /pageName (no query). Use
    // the remembered hash instead.
    e.preventDefault();
    window.location.hash = withCurrentLang(remembered);
  });

  // Register language change callbacks for pages that support it
  if (ConceptSetsPage.onLanguageChange) App.onLanguageChange(ConceptSetsPage.onLanguageChange);
  if (ProjectsPage.onLanguageChange) App.onLanguageChange(ProjectsPage.onLanguageChange);
  if (MappingPage.onLanguageChange) App.onLanguageChange(MappingPage.onLanguageChange);
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

    function isTruncated(el) {
      // An element is truncated only if its layout actually clips text — i.e.
      // it has overflow != visible AND content overflows. Wrapping onto multi-
      // ple lines is not truncation (the text is still all visible).
      // Also check direct children: a wrapper cell may not overflow if a child
      // (e.g. a badge) truncates itself.
      function check(node) {
        var cs = window.getComputedStyle(node);
        var clipsX = cs.overflowX !== 'visible' || cs.textOverflow === 'ellipsis';
        if (clipsX && node.scrollWidth > node.clientWidth + 1) return true;
        var clipsY = cs.overflowY !== 'visible';
        if (clipsY && node.scrollHeight > node.clientHeight + 1) return true;
        return false;
      }
      if (check(el)) return true;
      for (var i = 0; i < el.children.length; i++) {
        if (check(el.children[i])) return true;
      }
      return false;
    }

    document.addEventListener('mouseover', function (e) {
      var el = e.target.closest && e.target.closest('[data-tooltip]');
      if (!el) return;
      var text = el.getAttribute('data-tooltip');
      if (!text) return;
      if (!isTruncated(el)) return;
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
    var mrTab = document.querySelector('.nav-tab[data-page="mapping"]');
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
      ' · <a href="' + App.APP_GITHUB_URL + '" target="_blank" rel="noopener"><i class="fab fa-github"></i>GitHub</a>';
  }

  Router.init();
})();
