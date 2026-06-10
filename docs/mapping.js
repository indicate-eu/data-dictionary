// mapping.js — Mapping page module (My mapping projects + Recommendations tabs).
//
// A "mapping project" is a local workspace where a data provider imports their
// source-to-concept-map and evaluates whether the variables required by INDICATE
// projects can be populated by their current OMOP mapping. The Recommendations
// tab carries the bilingual editorial content that used to live on its own page
// (#/mapping-recommendations remains available as a redirect to ?tab=recommendations).
var MappingPage = (function() {
  'use strict';

  var initialized = false;
  var currentTab = 'projects'; // 'projects' | 'recommendations'
  var selectedMappingProjectId = null;
  var detailTab = 'overview'; // 'overview' | 'concepts' | 'eligibility'
  var deleteTargetId = null;

  // ==================== TABS (top-level) ====================
  function switchTab(tabName) {
    if (tabName !== 'projects' && tabName !== 'recommendations') tabName = 'projects';
    currentTab = tabName;
    document.querySelectorAll('#mapping-tabs .settings-tab').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.tab === tabName);
    });
    document.getElementById('mapping-tab-projects').style.display =
      tabName === 'projects' ? '' : 'none';
    document.getElementById('mapping-tab-recommendations').style.display =
      tabName === 'recommendations' ? '' : 'none';

    // Reflect the active tab in the URL so deep-linking + refresh works.
    // The detail view (?id=...) writes its own URL elsewhere.
    if (tabName === 'projects' && !selectedMappingProjectId) {
      Router.replaceState('#/mapping');
    } else if (tabName === 'recommendations') {
      selectedMappingProjectId = null;
      hideDetailView();
      Router.replaceState('#/mapping?tab=recommendations');
    }

    if (tabName === 'recommendations') {
      ensureRecommendationsInit();
      if (!recoEditing) renderRecoView();
      else if (recoEditor) recoEditor.resize();
    } else {
      if (selectedMappingProjectId) {
        showDetailView(selectedMappingProjectId);
      } else {
        showListView();
      }
    }
  }

  // ==================== LIST VIEW ↔ DETAIL VIEW ====================
  function showListView() {
    document.getElementById('mapping-projects-list-view').style.display = '';
    document.getElementById('mapping-project-detail-view').classList.remove('active');
    renderMappingProjects();
  }

  function hideDetailView() {
    document.getElementById('mapping-project-detail-view').classList.remove('active');
    document.getElementById('mapping-projects-list-view').style.display = '';
  }

  function showDetailView(mpId) {
    var mp = App.getMappingProject(mpId);
    if (!mp) { selectedMappingProjectId = null; showListView(); return; }
    selectedMappingProjectId = mpId;
    document.getElementById('mapping-projects-list-view').style.display = 'none';
    document.getElementById('mapping-project-detail-view').classList.add('active');
    renderDetailHeader(mp);
    switchDetailTab(detailTab || 'overview');
    var url = '#/mapping?id=' + encodeURIComponent(mpId);
    if (detailTab && detailTab !== 'overview') url += '&detail=' + detailTab;
    Router.replaceState(url);
  }

  function renderDetailHeader(mp) {
    var tr = App.tMappingProject(mp);
    document.getElementById('mapping-project-detail-title').textContent =
      tr.name || App.i18n('Untitled');
    var n = (mp.conceptIds || []).length;
    var meta = '';
    if (n > 0) {
      meta += '<span class="badge badge-count"><i class="fas fa-list"></i> ' + n + ' ' + App.i18n('mapped concepts') + '</span>';
    } else {
      meta += '<span style="color:var(--text-muted); font-size:13px"><i class="fas fa-info-circle"></i> ' + App.i18n('No mapping data yet') + '</span>';
    }
    meta += '<span style="color:var(--text-muted); font-size:13px; margin-left:8px"><i class="fas fa-calendar-alt"></i> ' + App.escapeHtml(App.formatDate(mp.modifiedDate || mp.createdDate) || '') + '</span>';
    document.getElementById('mapping-project-detail-meta').innerHTML = meta;
  }

  function switchDetailTab(tabName) {
    if (['overview', 'concepts', 'eligibility'].indexOf(tabName) < 0) tabName = 'overview';
    detailTab = tabName;
    document.querySelectorAll('#mapping-project-tabs .settings-tab').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.tab === tabName);
    });
    document.getElementById('mapping-project-tab-overview').style.display =
      tabName === 'overview' ? '' : 'none';
    document.getElementById('mapping-project-tab-concepts').style.display =
      tabName === 'concepts' ? '' : 'none';
    document.getElementById('mapping-project-tab-eligibility').style.display =
      tabName === 'eligibility' ? '' : 'none';

    if (selectedMappingProjectId) {
      var url = '#/mapping?id=' + encodeURIComponent(selectedMappingProjectId);
      if (tabName !== 'overview') url += '&detail=' + tabName;
      Router.replaceState(url);
    }

    if (tabName === 'overview') renderOverview();
    else if (tabName === 'concepts') renderConceptsTab();
    else if (tabName === 'eligibility') renderEligibilityTab();
  }

  function renderOverview() {
    var mp = selectedMappingProjectId && App.getMappingProject(selectedMappingProjectId);
    if (!mp) return;
    if (!ensureResolvedLoaded(renderOverview)) return;
    var widgets = document.getElementById('mapping-project-widgets');
    var ids = mp.conceptIds || [];
    var n = ids.length;

    // Matched-in-dictionary count: how many unique mapped ids are present in
    // at least one resolved concept set of the INDICATE dictionary.
    var matched = 0;
    if (n > 0) {
      var dict = mappedConceptDictionary();
      var seen = new Set();
      ids.forEach(function(id) {
        if (seen.has(id)) return;
        seen.add(id);
        if (dict[id]) matched++;
      });
    }

    // Eligible-projects count: number of INDICATE projects with score 100%.
    var eligible = 0, total = (App.projects || []).length;
    if (n > 0) {
      var results = evaluateAllProjects(mp);
      eligible = results.filter(function(r) { return r.eligible; }).length;
    }

    widgets.innerHTML = [
      widgetCard('fa-list', n, App.i18n('Mapped concepts')),
      widgetCard('fa-check', n > 0 ? matched : '—', App.i18n('Matched in dictionary')),
      widgetCard('fa-check-double', n > 0 ? (eligible + ' / ' + total) : '—', App.i18n('Eligible projects'))
    ].join('');

    // Show an empty-state hint pointing to the Mapped concepts tab when no
    // data has been imported yet; hide it once there's data.
    var empty = document.getElementById('mapping-overview-empty');
    if (empty) empty.style.display = n === 0 ? '' : 'none';

    renderEligibilityPreview(mp);
  }

  function widgetCard(icon, value, label) {
    return '<div class="mapping-widget">' +
      '<div class="mapping-widget-icon"><i class="fas ' + icon + '"></i></div>' +
      '<div class="mapping-widget-value">' + App.escapeHtml(String(value)) + '</div>' +
      '<div class="mapping-widget-label">' + App.escapeHtml(label) + '</div>' +
    '</div>';
  }

  // ==================== MAPPING PROJECTS — LIST ====================
  function renderMappingProjects() {
    var el = document.getElementById('mapping-projects-cards');
    if (!el) return;
    var list = App.getMappingProjects();
    var filter = (document.getElementById('mapping-projects-search') || {}).value || '';
    filter = filter.toLowerCase();
    var filtered = list.filter(function(mp) {
      if (!filter) return true;
      var tr = App.tMappingProject(mp);
      var name = (tr.name || '').toLowerCase();
      var desc = (tr.description || '').toLowerCase();
      return name.indexOf(filter) >= 0 || desc.indexOf(filter) >= 0;
    });

    if (filtered.length === 0) {
      el.innerHTML = '<div class="mapping-projects-empty">' +
        '<i class="fas fa-folder-open" style="font-size:32px; color:var(--text-muted); margin-bottom:8px"></i>' +
        '<p style="margin:0; color:var(--text-muted)">' +
        App.escapeHtml(list.length === 0
          ? App.i18n('No mapping project yet. Create one to evaluate your eligibility to INDICATE projects.')
          : App.i18n('No mapping project matches your search.')) +
        '</p>' +
        '</div>';
      return;
    }

    el.innerHTML = filtered.map(function(mp) {
      var tr = App.tMappingProject(mp);
      var n = (mp.conceptIds || []).length;
      return App.projectCard({
        id: mp.id,
        menuIdPrefix: 'mapping-project-menu-',
        extraClass: 'mapping-project-card',
        title: tr.name || App.i18n('Untitled'),
        description: tr.description || '',
        footer: [
          { icon: 'fa-list', text: n + ' ' + App.i18n('mapped concepts') },
          { icon: 'fa-calendar-alt', text: App.formatDate(mp.modifiedDate || mp.createdDate) || '' }
        ]
      });
    }).join('');
  }

  function closeAllCardMenus() {
    document.querySelectorAll('#mapping-projects-cards .project-card-menu.visible').forEach(function(m) {
      m.classList.remove('visible');
    });
  }

  // ==================== CREATE / EDIT MODAL ====================
  var modalEditingId = null;

  function openCreateModal() {
    modalEditingId = null;
    document.getElementById('mapping-project-modal-title').innerHTML =
      '<i class="fas fa-plus"></i> ' + App.i18n('New mapping project');
    document.getElementById('mapping-project-modal-submit').innerHTML =
      '<i class="fas fa-plus"></i> ' + App.i18n('Create');
    document.getElementById('mapping-project-modal-name').value = '';
    document.getElementById('mapping-project-modal-description').value = '';
    document.getElementById('mapping-project-modal').style.display = '';
    document.getElementById('mapping-project-modal-name').focus();
  }

  function openEditModal(id) {
    var mp = App.getMappingProject(id);
    if (!mp) return;
    modalEditingId = id;
    var tr = App.tMappingProject(mp);
    document.getElementById('mapping-project-modal-title').innerHTML =
      '<i class="fas fa-pen"></i> ' + App.i18n('Edit mapping project');
    document.getElementById('mapping-project-modal-submit').innerHTML =
      '<i class="fas fa-save"></i> ' + App.i18n('Save');
    document.getElementById('mapping-project-modal-name').value = tr.name || '';
    document.getElementById('mapping-project-modal-description').value = tr.description || '';
    document.getElementById('mapping-project-modal').style.display = '';
    document.getElementById('mapping-project-modal-name').focus();
  }

  function closeCreateModal() {
    document.getElementById('mapping-project-modal').style.display = 'none';
    modalEditingId = null;
  }

  // True when another mapping project already uses `name` (any language,
  // case-insensitive) — duplicates would make the cards indistinguishable.
  function mappingProjectNameTaken(name, excludeId) {
    var needle = name.trim().toLowerCase();
    return (App.getMappingProjects() || []).some(function(mp) {
      if (mp.id === excludeId) return false;
      var tr = mp.translations || {};
      return Object.keys(tr).some(function(l) {
        return ((tr[l] && tr[l].name) || '').trim().toLowerCase() === needle;
      });
    });
  }

  function submitCreateModal() {
    var name = document.getElementById('mapping-project-modal-name').value.trim();
    var desc = document.getElementById('mapping-project-modal-description').value.trim();
    if (!name) {
      App.showToast(App.i18n('Project name is required.'), 'error');
      return;
    }
    if (mappingProjectNameTaken(name, modalEditingId)) {
      App.showToast(App.i18n('A mapping project with this name already exists.'), 'error');
      return;
    }
    var today = new Date().toISOString().split('T')[0];
    var lang = App.lang;
    var other = lang === 'en' ? 'fr' : 'en';

    if (modalEditingId) {
      var mp = App.getMappingProject(modalEditingId);
      if (!mp) { closeCreateModal(); return; }
      if (!mp.translations) mp.translations = { en: {}, fr: {} };
      if (!mp.translations[lang]) mp.translations[lang] = {};
      if (!mp.translations[other]) mp.translations[other] = {};
      mp.translations[lang].name = name;
      mp.translations[lang].description = desc;
      // Mirror to the other locale only when it is empty, so independent edits
      // in the other language are preserved.
      if (!mp.translations[other].name) mp.translations[other].name = name;
      if (!mp.translations[other].description) mp.translations[other].description = desc;
      mp.modifiedDate = today;
      App.updateMappingProject(mp);
      App.showToast(App.i18n('Mapping project updated.'), 'success');
    } else {
      var newMp = {
        id: 'mp-' + Date.now(),
        // Mirror the entered name/description into both languages at creation;
        // the edit path then only updates the active language.
        translations: {
          en: { name: name, description: desc },
          fr: { name: name, description: desc }
        },
        createdDate: today,
        modifiedDate: today,
        format: null,
        conceptIds: [],
        stats: null
      };
      App.addMappingProject(newMp);
      App.showToast(App.i18n('Mapping project created.'), 'success');
    }
    closeCreateModal();
    renderMappingProjects();
  }

  // ==================== DELETE MODAL ====================
  function openDeleteModal(id) {
    var mp = App.getMappingProject(id);
    if (!mp) return;
    deleteTargetId = id;
    var tr = App.tMappingProject(mp);
    document.getElementById('mapping-project-delete-name').textContent = tr.name || '';
    document.getElementById('mapping-project-delete-modal').style.display = '';
  }

  function closeDeleteModal() {
    document.getElementById('mapping-project-delete-modal').style.display = 'none';
    deleteTargetId = null;
  }

  function confirmDelete() {
    if (!deleteTargetId) return;
    App.deleteMappingProject(deleteTargetId);
    closeDeleteModal();
    renderMappingProjects();
    App.showToast(App.i18n('Mapping project deleted.'), 'success');
  }

  // ==================== RECOMMENDATIONS TAB ====================
  var recoEditor = null;
  var recoEditing = false;
  var recoTocScrollHandler = null;
  var recoEventsBound = false;

  function recoGetContent() {
    return App.getMappingContent();
  }

  function renderRecoView() {
    var container = document.getElementById('mapping-view-content');
    if (!container) return;
    var md = recoGetContent();
    if (!md.trim()) {
      container.innerHTML = '<div class="markdown-preview-placeholder">' +
        App.escapeHtml(App.i18n('No mapping recommendations available.')) + '</div>';
    } else {
      container.innerHTML = App.renderMarkdown(md);
    }
    renderRecoToc();
    setupRecoTocScroll();
  }

  function renderRecoToc() {
    var container = document.getElementById('mapping-view-content');
    // The TOC list lives next to the action buttons inside the right sidebar.
    // Render into the inner list container so we don't wipe the buttons.
    var tocEl = document.getElementById('mapping-toc-list');
    if (!container || !tocEl) return;
    var headings = container.querySelectorAll('h2, h3');
    if (headings.length === 0) { tocEl.innerHTML = ''; return; }

    for (var i = 0; i < headings.length; i++) {
      if (!headings[i].id) headings[i].id = 'mapping-heading-' + i;
    }

    var en = App.lang === 'en';
    var html = '<div class="doc-toc-title">' + (en ? 'On this page' : 'Sur cette page') + '</div><ul>';
    for (var j = 0; j < headings.length; j++) {
      var h = headings[j];
      var level = h.tagName.toLowerCase();
      html += '<li class="toc-' + level + '"><a href="javascript:void(0)" data-toc-target="' + h.id + '">'
        + App.escapeHtml(h.textContent) + '</a></li>';
    }
    html += '</ul>';
    tocEl.innerHTML = html;
  }

  function setupRecoTocScroll() {
    var contentEl = document.getElementById('mapping-view-container');
    var tocEl = document.getElementById('mapping-toc-list');
    if (!contentEl || !tocEl) return;

    if (recoTocScrollHandler) contentEl.removeEventListener('scroll', recoTocScrollHandler);

    var headings = document.getElementById('mapping-view-content').querySelectorAll('h2, h3');
    if (headings.length === 0) return;

    recoTocScrollHandler = function() {
      var scrollTop = contentEl.scrollTop;
      var viewBottom = scrollTop + contentEl.clientHeight;
      var containerTop = contentEl.offsetTop;
      var links = tocEl.querySelectorAll('a[data-toc-target]');

      for (var j = 0; j < links.length; j++) {
        var hIdx = -1;
        var targetId = links[j].getAttribute('data-toc-target');
        for (var k = 0; k < headings.length; k++) {
          if (headings[k].id === targetId) { hIdx = k; break; }
        }
        if (hIdx === -1) { links[j].classList.remove('active'); continue; }

        var sectionTop = headings[hIdx].offsetTop - containerTop;
        var sectionBottom = (hIdx + 1 < headings.length)
          ? headings[hIdx + 1].offsetTop - containerTop
          : contentEl.scrollHeight;

        var visible = sectionBottom > scrollTop && sectionTop < viewBottom;
        links[j].classList.toggle('active', visible);
      }
    };

    contentEl.addEventListener('scroll', recoTocScrollHandler, { passive: true });
    recoTocScrollHandler();
  }

  // Bind once: keep the ACE editor and the Markdown preview scrolled to the same
  // relative position. Uses ratios (scrollTop / maxScroll) since their content
  // heights differ. A reentrancy guard prevents an infinite scroll loop.
  function wireRecoScrollSync() {
    if (!recoEditor) return;
    var previewScroller = document.querySelector('#mapping-tab-recommendations .mapping-edit-container .mapping-editor-pane:last-child .mapping-pane-body');
    if (!previewScroller) return;
    var syncing = false;

    recoEditor.session.on('changeScrollTop', function() {
      if (syncing) return;
      var renderer = recoEditor.renderer;
      var session = recoEditor.session;
      var lineHeight = renderer.lineHeight || 16;
      var maxEditorScroll = Math.max(0, session.getScreenLength() * lineHeight - renderer.$size.scrollerHeight);
      if (maxEditorScroll <= 0) return;
      var ratio = renderer.getScrollTop() / maxEditorScroll;
      var maxPreviewScroll = previewScroller.scrollHeight - previewScroller.clientHeight;
      if (maxPreviewScroll <= 0) return;
      syncing = true;
      previewScroller.scrollTop = ratio * maxPreviewScroll;
      // Release on next frame so the resulting scroll event doesn't trigger a
      // feedback loop back into the editor.
      requestAnimationFrame(function() { syncing = false; });
    });

    previewScroller.addEventListener('scroll', function() {
      if (syncing) return;
      var maxPreviewScroll = previewScroller.scrollHeight - previewScroller.clientHeight;
      if (maxPreviewScroll <= 0) return;
      var ratio = previewScroller.scrollTop / maxPreviewScroll;
      var renderer = recoEditor.renderer;
      var session = recoEditor.session;
      var lineHeight = renderer.lineHeight || 16;
      var maxEditorScroll = Math.max(0, session.getScreenLength() * lineHeight - renderer.$size.scrollerHeight);
      if (maxEditorScroll <= 0) return;
      syncing = true;
      session.setScrollTop(ratio * maxEditorScroll);
      requestAnimationFrame(function() { syncing = false; });
    });
  }

  function enterRecoEditMode() {
    recoEditing = true;
    document.getElementById('mapping-view-container').style.display = 'none';
    document.getElementById('mapping-edit-container').style.display = 'flex';
    // Keep the right sidebar visible so its action buttons stay at hand; just
    // hide the table-of-contents list (it has no meaning while editing).
    document.getElementById('mapping-toc-list').style.display = 'none';
    document.getElementById('mapping-toolbar-view').style.display = 'none';
    document.getElementById('mapping-toolbar-edit').style.display = '';

    if (!recoEditor) {
      recoEditor = ace.edit('mapping-page-ace-editor');
      recoEditor.setTheme('ace/theme/chrome');
      recoEditor.session.setMode('ace/mode/markdown');
      recoEditor.setFontSize(13);
      recoEditor.setShowPrintMargin(false);
      recoEditor.session.setUseWrapMode(true);
      recoEditor.session.on('change', function() {
        var md = recoEditor.getValue();
        var preview = document.getElementById('mapping-page-preview');
        if (!md.trim()) {
          preview.innerHTML = '<div class="markdown-preview-placeholder">Preview will appear here...</div>';
        } else {
          preview.innerHTML = App.renderMarkdown(md);
        }
      });
      recoEditor.commands.addCommand({
        name: 'saveMappingRecommendations',
        bindKey: { win: 'Ctrl-S', mac: 'Cmd-S' },
        exec: function() { recoSave(); }
      });
      wireRecoScrollSync();
    }
    recoEditor.setValue(recoGetContent(), -1);
    recoEditor.resize();
    var initMd = recoEditor.getValue();
    var preview = document.getElementById('mapping-page-preview');
    if (initMd.trim()) preview.innerHTML = App.renderMarkdown(initMd);
    else preview.innerHTML = '<div class="markdown-preview-placeholder">Preview will appear here...</div>';
  }

  function exitRecoEditMode() {
    recoEditing = false;
    document.getElementById('mapping-view-container').style.display = '';
    document.getElementById('mapping-edit-container').style.display = 'none';
    document.getElementById('mapping-toc-list').style.display = '';
    document.getElementById('mapping-toolbar-view').style.display = '';
    document.getElementById('mapping-toolbar-edit').style.display = 'none';
  }

  function recoSave() {
    if (!recoEditor) return;
    App.setMappingContent(recoEditor.getValue());
    renderRecoView();
    exitRecoEditMode();
    App.showToast(App.i18n('Mapping recommendations saved.'), 'success');
  }

  function recoCancel() { exitRecoEditMode(); }

  function recoExport() {
    var content = JSON.stringify(App.mappingRecommendations, null, 2);
    App.openExportModal({
      title: App.i18n('Export Mapping Recommendations'),
      content: content,
      filename: 'mapping_recommendations.json',
      type: 'application/json',
      clipboardDesc: App.i18n('Copy JSON to clipboard'),
      fileDesc: App.i18n('Download as mapping_recommendations.json'),
      githubUrl: App.githubEdit('mapping_recommendations/mapping_recommendations.json')
    });
  }

  function ensureRecommendationsInit() {
    if (recoEventsBound) return;
    recoEventsBound = true;
    document.getElementById('mapping-page-export-btn').addEventListener('click', recoExport);
    document.getElementById('mapping-page-edit-btn').addEventListener('click', enterRecoEditMode);
    document.getElementById('mapping-page-cancel-btn').addEventListener('click', recoCancel);
    document.getElementById('mapping-page-save-btn').addEventListener('click', recoSave);
    document.getElementById('mapping-toc').addEventListener('click', function(e) {
      var link = e.target.closest('[data-toc-target]');
      if (!link) return;
      e.preventDefault();
      var target = document.getElementById(link.getAttribute('data-toc-target'));
      if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }

  // ==================== EVENT WIRING (one-shot) ====================
  function initEvents() {
    // Tabs
    document.getElementById('mapping-tabs').addEventListener('click', function(e) {
      var tab = e.target.closest('.settings-tab');
      if (!tab) return;
      switchTab(tab.dataset.tab);
    });

    // Projects tab: search
    document.getElementById('mapping-projects-search').addEventListener('input', renderMappingProjects);

    // Projects tab: create button
    document.getElementById('mapping-projects-create-btn').addEventListener('click', openCreateModal);

    // Projects tab: card clicks (menu open / menu item / card)
    document.getElementById('mapping-projects-cards').addEventListener('click', function(e) {
      var menuBtn = e.target.closest('.project-card-menu-btn');
      if (menuBtn) {
        e.stopPropagation();
        var id = menuBtn.dataset.menuId;
        var menu = document.getElementById('mapping-project-menu-' + id);
        if (menu) {
          var wasVisible = menu.classList.contains('visible');
          closeAllCardMenus();
          if (!wasVisible) menu.classList.add('visible');
        }
        return;
      }
      var menuItem = e.target.closest('.project-card-menu-item');
      if (menuItem) {
        e.stopPropagation();
        var action = menuItem.dataset.action;
        var iid = menuItem.dataset.id;
        closeAllCardMenus();
        if (action === 'edit') openEditModal(iid);
        else if (action === 'delete') openDeleteModal(iid);
        return;
      }
      // Plain card click: open the per-project detail view.
      var card = e.target.closest('.project-card[data-id]');
      if (card) {
        var cardId = card.dataset.id;
        if (cardId) {
          detailTab = 'overview';
          showDetailView(cardId);
        }
        return;
      }
    });
    document.addEventListener('click', closeAllCardMenus);

    // Detail view: back button + internal tabs + import button
    document.getElementById('mapping-project-back').addEventListener('click', function() {
      selectedMappingProjectId = null;
      detailTab = 'overview';
      showListView();
      Router.replaceState('#/mapping');
    });
    document.getElementById('mapping-project-tabs').addEventListener('click', function(e) {
      var tab = e.target.closest('.settings-tab');
      if (!tab) return;
      switchDetailTab(tab.dataset.tab);
    });

    // Import CSV modal
    document.getElementById('mapping-import-modal-close').addEventListener('click', closeImportModal);
    document.getElementById('mapping-import-modal-cancel').addEventListener('click', closeImportModal);
    document.getElementById('mapping-import-modal-submit').addEventListener('click', submitImport);
    document.getElementById('mapping-import-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('mapping-import-modal')) closeImportModal();
    });
    document.getElementById('mapping-import-file').addEventListener('change', onImportFileChange);

    // CS coverage details modal — handlers go via event delegation on the
    // overlay itself so they survive any potential later re-renders, and an
    // Escape listener closes the modal when it's open.
    var detailsModal = document.getElementById('mapping-cs-details-modal');
    detailsModal.addEventListener('click', function(e) {
      // Close on overlay click OR on any close-trigger inside the box.
      if (e.target === detailsModal ||
          e.target.closest('#mapping-cs-details-close') ||
          e.target.closest('#mapping-cs-details-done')) {
        e.stopPropagation();
        closeCSDetailsModal();
      }
    });
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && detailsModal.style.display !== 'none') {
        closeCSDetailsModal();
      }
    });

    // Create / edit modal
    document.getElementById('mapping-project-modal-close').addEventListener('click', closeCreateModal);
    document.getElementById('mapping-project-modal-cancel').addEventListener('click', closeCreateModal);
    document.getElementById('mapping-project-modal-submit').addEventListener('click', submitCreateModal);
    document.getElementById('mapping-project-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('mapping-project-modal')) closeCreateModal();
    });
    document.getElementById('mapping-project-modal-name').addEventListener('keydown', function(e) {
      if (e.key === 'Enter') { e.preventDefault(); submitCreateModal(); }
    });

    // Delete modal
    document.getElementById('mapping-project-delete-close').addEventListener('click', closeDeleteModal);
    document.getElementById('mapping-project-delete-cancel').addEventListener('click', closeDeleteModal);
    document.getElementById('mapping-project-delete-confirm').addEventListener('click', confirmDelete);
    document.getElementById('mapping-project-delete-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('mapping-project-delete-modal')) closeDeleteModal();
    });
  }

  // ==================== CSV PARSER ====================
  // Minimal RFC 4180-ish CSV parser: handles commas / tabs / semicolons as
  // separators, quoted fields with embedded commas and doubled quotes, and
  // CRLF / LF line endings.
  function parseCSV(text) {
    if (!text) return { sep: ',', rows: [] };
    // Strip BOM if present.
    if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);

    // Detect separator from the first non-empty line (try , then ; then \t).
    var firstLine = '';
    for (var i = 0; i < text.length; i++) {
      var ch = text[i];
      if (ch === '\n' || ch === '\r') {
        if (firstLine) break;
      } else {
        firstLine += ch;
      }
    }
    var sep = ',';
    if (firstLine.indexOf('\t') >= 0 && (firstLine.indexOf(',') < 0 || firstLine.split('\t').length > firstLine.split(',').length)) {
      sep = '\t';
    } else if (firstLine.indexOf(';') >= 0 && firstLine.indexOf(',') < 0) {
      sep = ';';
    }

    var rows = [];
    var row = [];
    var field = '';
    var inQuotes = false;
    var len = text.length;
    for (var p = 0; p < len; p++) {
      var c = text[p];
      if (inQuotes) {
        if (c === '"') {
          if (text[p + 1] === '"') { field += '"'; p++; }
          else { inQuotes = false; }
        } else {
          field += c;
        }
        continue;
      }
      if (c === '"') { inQuotes = true; continue; }
      if (c === sep) { row.push(field); field = ''; continue; }
      if (c === '\n' || c === '\r') {
        // Push the field + row if we have content. Skip blank lines.
        if (field !== '' || row.length > 0) {
          row.push(field);
          if (row.some(function(v) { return String(v).trim() !== ''; })) rows.push(row);
          row = []; field = '';
        }
        // Swallow CRLF as a single line break.
        if (c === '\r' && text[p + 1] === '\n') p++;
        continue;
      }
      field += c;
    }
    if (field !== '' || row.length > 0) {
      row.push(field);
      if (row.some(function(v) { return String(v).trim() !== ''; })) rows.push(row);
    }
    return { sep: sep, rows: rows };
  }

  // ==================== CSV FORMAT DETECTION ====================
  // Returns { format, idIndex, sourceIndex|null, hasHeader, headers|null }.
  // format ∈ 'stcm' | 'concept_id_with_source' | 'concept_id_list'.
  function detectFormat(rows) {
    if (rows.length === 0) return null;
    var first = rows[0].map(function(c) { return String(c).trim().toLowerCase(); });

    // Looks like a header? Header = first row contains only non-numeric tokens
    // AND at least one token matches our well-known column names.
    var allNonNumeric = first.every(function(c) { return c !== '' && !/^-?\d+$/.test(c); });
    var hasKnownColumn = first.some(function(c) {
      return c === 'target_concept_id' || c === 'concept_id' || c === 'omop_concept_id' ||
             c === 'source_code' || c === 'source_concept_id' || c === 'source_value';
    });
    var hasHeader = allNonNumeric && hasKnownColumn;

    if (hasHeader) {
      var targetIdx = first.indexOf('target_concept_id');
      if (targetIdx < 0) targetIdx = first.indexOf('concept_id');
      if (targetIdx < 0) targetIdx = first.indexOf('omop_concept_id');
      if (targetIdx < 0) return null; // no usable column

      var sourceIdx = first.indexOf('source_code');
      if (sourceIdx < 0) sourceIdx = first.indexOf('source_value');
      if (sourceIdx < 0) sourceIdx = first.indexOf('source_label');

      var stcmCols = ['source_code', 'source_concept_id', 'target_concept_id', 'source_vocabulary_id'];
      var isStcm = stcmCols.filter(function(c) { return first.indexOf(c) >= 0; }).length >= 2;

      return {
        format: isStcm ? 'stcm' : (sourceIdx >= 0 ? 'concept_id_with_source' : 'concept_id_list'),
        idIndex: targetIdx,
        sourceIndex: sourceIdx >= 0 ? sourceIdx : null,
        hasHeader: true,
        headers: rows[0]
      };
    }

    // No header — does every row consist of a single numeric field? Then it's
    // a bare list of concept ids.
    var allSingleNumeric = rows.every(function(r) {
      return r.length === 1 && /^-?\d+$/.test(String(r[0]).trim());
    });
    if (allSingleNumeric) {
      return {
        format: 'concept_id_list',
        idIndex: 0,
        sourceIndex: null,
        hasHeader: false,
        headers: null
      };
    }
    return null;
  }

  // Extract { conceptIds, sources } from rows + detection info.
  function extractMapping(rows, detection) {
    var startIdx = detection.hasHeader ? 1 : 0;
    var conceptIds = [];
    var sources = detection.sourceIndex !== null ? [] : null;
    for (var i = startIdx; i < rows.length; i++) {
      var raw = String(rows[i][detection.idIndex] || '').trim();
      if (!/^-?\d+$/.test(raw)) continue;
      var id = parseInt(raw, 10);
      if (!id || id === 0) continue; // 0 = unmapped placeholder in STCM
      conceptIds.push(id);
      if (sources) sources.push(String(rows[i][detection.sourceIndex] || '').trim());
    }
    return { conceptIds: conceptIds, sources: sources };
  }

  // ==================== ELIGIBILITY ENGINE ====================
  // Per concept set: covered if at least one resolved concept id is in the
  // mapping. Per group: rule decides whether the group is satisfied + computes
  // a coverage score (0..1). Per project: average of non-optional group
  // scores. Optional groups are computed but excluded from the project score.
  function buildMappedSet(mp) {
    var s = new Set();
    (mp.conceptIds || []).forEach(function(id) { s.add(id); });
    return s;
  }

  function evaluateProject(project, mappedSet) {
    var groups = App.getProjectGroups(project) || [];
    var groupResults = groups.map(function(g) {
      var entries = g.conceptSets || [];
      var coveredCount = 0;
      var perCS = entries.map(function(e) {
        var resolved = App.getResolvedConceptSet(e.id, e.version) || [];
        var covered = false;
        for (var i = 0; i < resolved.length; i++) {
          if (mappedSet.has(resolved[i].conceptId)) { covered = true; break; }
        }
        if (covered) coveredCount++;
        return { id: e.id, version: e.version, covered: covered, total: resolved.length };
      });
      var rule = g.rule || App.DEFAULT_GROUP_RULE;
      var score;
      var satisfied;
      if (entries.length === 0) { score = 1; satisfied = true; }
      else if (rule === 'all_required') {
        score = coveredCount / entries.length;
        satisfied = coveredCount === entries.length;
      } else if (rule === 'at_least_one') {
        score = coveredCount > 0 ? 1 : 0;
        satisfied = coveredCount > 0;
      } else { // optional
        score = entries.length > 0 ? coveredCount / entries.length : 1;
        satisfied = true;
      }
      return {
        id: g.id, name: App.getGroupName(g), rule: rule,
        coveredCount: coveredCount, total: entries.length,
        perCS: perCS, score: score, satisfied: satisfied
      };
    });

    // Project score: average of non-optional group scores (0..1). If a project
    // has only optional groups, fall back to their average.
    var nonOptional = groupResults.filter(function(g) { return g.rule !== 'optional'; });
    var scored = nonOptional.length > 0 ? nonOptional : groupResults;
    var avg = scored.length > 0
      ? scored.reduce(function(a, g) { return a + g.score; }, 0) / scored.length
      : 1;
    var pct = Math.round(avg * 100);
    return {
      project: project,
      groups: groupResults,
      score: pct,
      eligible: scored.every(function(g) { return g.satisfied; })
    };
  }

  function evaluateAllProjects(mp) {
    var mappedSet = buildMappedSet(mp);
    return (App.projects || []).map(function(p) { return evaluateProject(p, mappedSet); });
  }

  // ==================== IMPORT MODAL ====================
  var importParsed = null; // { conceptIds, sources, detection, rowsPreview }

  function openImportModal() {
    if (!selectedMappingProjectId) return;
    importParsed = null;
    document.getElementById('mapping-import-file').value = '';
    document.getElementById('mapping-import-preview').style.display = 'none';
    document.getElementById('mapping-import-error').style.display = 'none';
    document.getElementById('mapping-import-modal-submit').disabled = true;
    document.getElementById('mapping-import-modal-box').classList.remove('expanded');
    document.getElementById('mapping-import-modal').style.display = '';
  }
  function closeImportModal() {
    document.getElementById('mapping-import-modal').style.display = 'none';
    importParsed = null;
  }
  function importError(message) {
    var err = document.getElementById('mapping-import-error');
    err.textContent = message;
    err.style.display = '';
    document.getElementById('mapping-import-preview').style.display = 'none';
    document.getElementById('mapping-import-modal-box').classList.remove('expanded');
    document.getElementById('mapping-import-modal-submit').disabled = true;
  }
  function onImportFileChange(e) {
    document.getElementById('mapping-import-error').style.display = 'none';
    document.getElementById('mapping-import-preview').style.display = 'none';
    document.getElementById('mapping-import-modal-submit').disabled = true;
    importParsed = null;
    var file = e.target.files && e.target.files[0];
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function() {
      try {
        var parsed = parseCSV(reader.result);
        var detection = detectFormat(parsed.rows);
        if (!detection) {
          importError(App.i18n("Couldn't detect a usable concept_id column. Expected either an OMOP source_to_concept_map header, a concept_id column, or a single-column list of concept ids."));
          return;
        }
        var extracted = extractMapping(parsed.rows, detection);
        if (extracted.conceptIds.length === 0) {
          importError(App.i18n('No valid concept_id rows found in the file.'));
          return;
        }
        importParsed = {
          fileName: file.name,
          detection: detection,
          conceptIds: extracted.conceptIds,
          sources: extracted.sources,
          rows: parsed.rows
        };
        renderImportPreview();
        document.getElementById('mapping-import-modal-submit').disabled = false;
      } catch (err) {
        console.error(err);
        importError(App.i18n('Failed to parse CSV: ') + (err && err.message ? err.message : err));
      }
    };
    reader.onerror = function() { importError(App.i18n('Failed to read the file.')); };
    reader.readAsText(file);
  }
  function renderImportPreview() {
    if (!importParsed) return;
    var detection = importParsed.detection;
    var n = importParsed.conceptIds.length;
    var unique = new Set(importParsed.conceptIds).size;
    var formatLabel;
    if (detection.format === 'stcm') formatLabel = App.i18n('OMOP source_to_concept_map');
    else if (detection.format === 'concept_id_with_source') formatLabel = App.i18n('CSV with concept_id + source');
    else formatLabel = App.i18n('Single-column concept_id list');

    document.getElementById('mapping-import-summary').innerHTML =
      '<div><strong>' + App.escapeHtml(formatLabel) + '</strong></div>' +
      '<div>' + n + ' ' + App.i18n('rows with a valid concept_id') + ' · <strong>' + unique + '</strong> ' + App.i18n('unique concepts') + '</div>';

    // Show the first 25 rows as a quick sanity check.
    var startIdx = detection.hasHeader ? 1 : 0;
    var sampleRows = importParsed.rows.slice(startIdx, startIdx + 25);
    var sample = document.getElementById('mapping-import-sample');
    var headerCells;
    if (detection.hasHeader) {
      headerCells = importParsed.rows[0].map(function(h) {
        return '<th>' + App.escapeHtml(String(h)) + '</th>';
      }).join('');
    } else {
      headerCells = '<th>concept_id</th>';
    }
    var bodyRows = sampleRows.map(function(r) {
      return '<tr>' + r.map(function(c) { return '<td>' + App.escapeHtml(String(c)) + '</td>'; }).join('') + '</tr>';
    }).join('');
    sample.innerHTML = '<table><thead><tr>' + headerCells + '</tr></thead><tbody>' + bodyRows + '</tbody></table>';

    // Grow the modal so the preview datatable is comfortable to read.
    document.getElementById('mapping-import-modal-box').classList.add('expanded');
    document.getElementById('mapping-import-preview').style.display = '';
  }
  function submitImport() {
    if (!importParsed || !selectedMappingProjectId) return;
    var mp = App.getMappingProject(selectedMappingProjectId);
    if (!mp) return;
    var ids = importParsed.conceptIds.slice();
    mp.conceptIds = ids;
    mp.format = importParsed.detection.format;
    mp.stats = {
      total: ids.length,
      unique: new Set(ids).size,
      importedAt: new Date().toISOString(),
      sourceFile: importParsed.fileName
    };
    mp.modifiedDate = new Date().toISOString().split('T')[0];
    App.updateMappingProject(mp);
    closeImportModal();
    App.showToast(App.i18n('Imported {n} concepts.').replace('{n}', ids.length), 'success');
    // Refresh detail view.
    renderDetailHeader(mp);
    if (detailTab === 'overview') renderOverview();
    else if (detailTab === 'concepts') renderConceptsTab();
    else if (detailTab === 'eligibility') renderEligibilityTab();
  }

  // ==================== POST-IMPORT RENDERS ====================
  // Sort state for the Mapped concepts table. key === null means no sort
  // (insertion order, i.e. order of arrival in the CSV).
  var conceptsSort = { key: null, asc: true };
  var conceptsFilters = {
    name: '',
    vocabularies: new Set(),
    domains: new Set(),
    inDict: new Set()
  };

  function renderConceptsTab() {
    var mp = selectedMappingProjectId && App.getMappingProject(selectedMappingProjectId);
    if (!mp) return;
    if (!ensureResolvedLoaded(renderConceptsTab)) return;
    var panel = document.getElementById('mapping-project-tab-concepts');
    var ids = mp.conceptIds || [];

    // Top toolbar: import button + summary.
    var toolbar =
      '<div class="mapping-concepts-toolbar">' +
        '<button class="btn-outline-sm" id="mapping-concepts-import-btn">' +
          '<i class="fas fa-upload"></i> ' + App.escapeHtml(App.i18n(ids.length === 0 ? 'Import CSV' : 'Re-import CSV')) +
        '</button>' +
        (ids.length > 0
          ? '<span id="mapping-concepts-summary" style="color:var(--text-muted); font-size:13px; margin-left:8px"></span>'
          : '') +
      '</div>';

    if (ids.length === 0) {
      panel.innerHTML = toolbar +
        '<div class="mapping-empty-state">' +
          '<i class="fas fa-file-csv"></i>' +
          '<p>' + App.escapeHtml(App.i18n('No mapping data imported yet. Upload a CSV to populate this table.')) + '</p>' +
        '</div>';
      document.getElementById('mapping-concepts-import-btn').addEventListener('click', openImportModal);
      return;
    }

    // Reset filters/sort when entering the tab afresh.
    conceptsSort = { key: null, asc: true };
    conceptsFilters = { name: '', vocabularies: new Set(), domains: new Set(), inDict: new Set() };

    // Build the table shell that mirrors #cs-table styling on the Data
    // Dictionary page (sortable headers + filter row). Column order matches
    // what helps the user spot mapped-but-not-in-dictionary concepts first:
    // vocabulary → name → domain → in dictionary.
    panel.innerHTML = toolbar +
      '<div class="table-container">' +
        '<table id="mapping-concepts-table">' +
          '<thead>' +
            '<tr>' +
              '<th data-sort="vocab" style="width:14%"><span data-i18n="Vocabulary">Vocabulary</span> <span class="sort-icon">&#9650;</span></th>' +
              '<th data-sort="id" style="width:12%"><span data-i18n="concept_id">concept_id</span> <span class="sort-icon">&#9650;</span></th>' +
              '<th data-sort="name" style="width:38%"><span data-i18n="Name">Name</span> <span class="sort-icon">&#9650;</span></th>' +
              '<th data-sort="domain" style="width:14%"><span data-i18n="Domain">Domain</span> <span class="sort-icon">&#9650;</span></th>' +
              '<th data-sort="inDict" style="width:12%" class="td-center"><span data-i18n="In dictionary">In dictionary</span> <span class="sort-icon">&#9650;</span></th>' +
            '</tr>' +
            '<tr class="filter-row">' +
              '<th><div class="ms-container" id="mapping-concepts-filter-vocab"></div></th>' +
              '<th></th>' +
              '<th><input type="text" class="column-filter" id="mapping-concepts-filter-name" placeholder="Filter..." data-i18n-placeholder="Filter..."></th>' +
              '<th><div class="ms-container" id="mapping-concepts-filter-domain"></div></th>' +
              '<th><div class="ms-container" id="mapping-concepts-filter-inDict"></div></th>' +
            '</tr>' +
          '</thead>' +
          '<tbody id="mapping-concepts-tbody"></tbody>' +
        '</table>' +
      '</div>';

    document.getElementById('mapping-concepts-import-btn').addEventListener('click', openImportModal);

    // Compute the full row dataset once (it doesn't change while we filter/sort).
    var dictById = mappedConceptDictionary();
    var unique = Array.from(new Set(ids));
    var allRows = unique.map(function(id) {
      var c = dictById[id];
      // status:
      //   'resolved'   → metadata available (from INDICATE dictionary or later
      //                  from the OHDSI vocabulary DB).
      //   'loading'    → vocab DB query is in progress for this concept.
      //   'unresolved' → no metadata available: either no vocab DB loaded, or
      //                  the DB had no row for this id.
      // Start everything missing as 'unresolved'; the async vocab probe below
      // promotes the eligible rows to 'loading' once it has confirmed the DB
      // is actually ready (required tables present).
      return {
        id: id,
        name: c ? (c.conceptName || '') : '',
        vocab: c ? (c.vocabularyId || '') : '',
        domain: c ? (c.domainId || '') : '',
        inDict: !!c,
        status: c ? 'resolved' : 'unresolved'
      };
    });

    // Populate filter dropdowns once from the full dataset.
    var allVocabs = [...new Set(allRows.map(function(r) { return r.vocab; }).filter(Boolean))].sort();
    var allDomains = [...new Set(allRows.map(function(r) { return r.domain; }).filter(Boolean))].sort();
    var inDictLabels = { 'yes': App.i18n('Yes'), 'no': App.i18n('No') };
    App.buildMultiSelectDropdown('mapping-concepts-filter-vocab', allVocabs, conceptsFilters.vocabularies, renderConceptsRows);
    App.buildMultiSelectDropdown('mapping-concepts-filter-domain', allDomains, conceptsFilters.domains, renderConceptsRows);
    App.buildMultiSelectDropdown('mapping-concepts-filter-inDict', ['yes', 'no'], conceptsFilters.inDict, renderConceptsRows, inDictLabels);

    document.getElementById('mapping-concepts-filter-name').addEventListener('input', function(e) {
      conceptsFilters.name = e.target.value;
      renderConceptsRows();
    });

    // Sort on header click.
    panel.querySelector('thead').addEventListener('click', function(e) {
      var th = e.target.closest('th[data-sort]');
      if (!th) return;
      var key = th.dataset.sort;
      if (conceptsSort.key !== key) { conceptsSort.key = key; conceptsSort.asc = true; }
      else if (conceptsSort.asc) conceptsSort.asc = false;
      else { conceptsSort.key = null; conceptsSort.asc = true; }
      renderConceptsRows();
    });

    // Keep a reference to allRows so renderConceptsRows can reuse it without
    // recomputing every filter cycle.
    panel._mappingConceptsRows = allRows;
    renderConceptsRows();

    // Best-effort enrichment: for ids without dictionary metadata, query the
    // user's locally-loaded OHDSI vocabulary DB (DuckDB-WASM) for vocabulary /
    // name / domain so they show up in the table instead of empty cells.
    enrichConceptsFromVocabDB(allRows, panel);
  }

  // Cached result of isDatabaseReady() so the renderer can pick the right
  // unresolved-cell message synchronously. null = not checked yet, true/false
  // = last known answer.
  var _vocabReadyCached = null;

  function enrichConceptsFromVocabDB(allRows, panel) {
    if (!window.VocabDB) { _vocabReadyCached = false; return; }
    // While the auto-mount flow runs (may take a few seconds when remounting
    // stored Parquet handles), keep cells in a "Loading…" state so the user
    // doesn't see a misleading "Load OHDSI vocabularies" flash.
    _vocabReadyCached = null;
    var candidates = allRows.filter(function(r) { return r.status === 'unresolved' && !r.inDict; });
    candidates.forEach(function(r) { r.status = 'loading'; });
    if (candidates.length > 0) renderConceptsRows();

    // Trigger the same auto-mount flow other pages use (Add Concepts modal,
    // Dev Tools): init DuckDB if needed, check readiness, fall back to
    // re-mounting stored Parquet handles from IndexedDB if the tables are
    // still missing. This lets a returning user pick up the vocabulary they
    // imported in a previous session without re-uploading anything.
    ensureVocabDB().then(function(ready) {
      _vocabReadyCached = !!ready;
      if (!ready) {
        // Revert the loading rows back to unresolved so the renderer picks
        // the "Load OHDSI vocabularies" message instead of a stale spinner.
        candidates.forEach(function(r) {
          if (r.status === 'loading') r.status = 'unresolved';
        });
        renderConceptsRows();
        return;
      }
      if (candidates.length === 0) { renderConceptsRows(); return; }
      // Rows are already in 'loading' state from above; query now.
      runEnrichmentQuery(allRows, candidates);
    });
  }

  // Mirror of ensureVocabDB() from concept-sets.js: brings the user's stored
  // OHDSI vocabularies back online if they were imported in a previous
  // session. Returns a Promise<bool> that resolves to true ⇔ vocab tables are
  // queryable.
  function ensureVocabDB() {
    if (!window.VocabDB) return Promise.resolve(false);
    if (window.VocabDB.getImportMode && window.VocabDB.getImportMode()) {
      return Promise.resolve(true);
    }
    if (!window.VocabDB.initDuckDB) return Promise.resolve(false);
    return window.VocabDB.initDuckDB().then(function() {
      return window.VocabDB.isDatabaseReady();
    }).then(function(ready) {
      if (ready) return true;
      if (window.VocabDB.remountFromStoredHandles) {
        return window.VocabDB.remountFromStoredHandles();
      }
      return false;
    }).catch(function() { return false; });
  }

  function runEnrichmentQuery(allRows, loadingRows) {
    var missingIds = loadingRows.map(function(r) { return r.id; });
    // Cap to avoid pathological queries on truly large mappings; the OMOP
    // `concept` table is millions of rows but a literal IN(...) of a few
    // thousand ids stays fast.
    var capped = missingIds.slice(0, 5000);
    window.VocabDB.lookupConcepts(capped).then(function(rows) {
      var byId = {};
      (rows || []).forEach(function(r) { byId[r.concept_id] = r; });
      loadingRows.forEach(function(r) {
        var v = byId[r.id];
        if (v) {
          r.name = r.name || v.concept_name || '';
          r.vocab = r.vocab || v.vocabulary_id || '';
          r.domain = r.domain || v.domain_id || '';
          r.status = 'resolved';
        } else {
          r.status = 'unresolved';
        }
        // Note: not flipping inDict — these come from the vocab, not from
        // INDICATE concept sets.
      });
      // Any rows beyond the cap stay 'loading' indefinitely — they will not be
      // queried in this round. Flip them to 'unresolved' to avoid a permanent
      // spinner state in the UI.
      if (missingIds.length > capped.length) {
        allRows.forEach(function(r) {
          if (r.status === 'loading' && capped.indexOf(r.id) < 0) r.status = 'unresolved';
        });
      }
      // Refresh dropdowns to surface newly-discovered vocab/domain values,
      // then re-render.
      var fVocab = [...new Set(allRows.map(function(r) { return r.vocab; }).filter(Boolean))].sort();
      var fDom = [...new Set(allRows.map(function(r) { return r.domain; }).filter(Boolean))].sort();
      App.buildMultiSelectDropdown('mapping-concepts-filter-vocab', fVocab, conceptsFilters.vocabularies, renderConceptsRows);
      App.buildMultiSelectDropdown('mapping-concepts-filter-domain', fDom, conceptsFilters.domains, renderConceptsRows);
      renderConceptsRows();
    }).catch(function(err) {
      console.warn('VocabDB lookup failed for mapped concepts enrichment:', err);
      // On error, the loading rows fall back to unresolved.
      loadingRows.forEach(function(r) { r.status = 'unresolved'; });
      renderConceptsRows();
    });
  }

  function renderConceptsRows() {
    var panel = document.getElementById('mapping-project-tab-concepts');
    var allRows = panel._mappingConceptsRows || [];
    var f = conceptsFilters;
    var rows = allRows.filter(function(r) {
      if (f.vocabularies.size > 0 && !f.vocabularies.has(r.vocab)) return false;
      if (f.domains.size > 0 && !f.domains.has(r.domain)) return false;
      if (f.inDict.size > 0) {
        var key = r.inDict ? 'yes' : 'no';
        if (!f.inDict.has(key)) return false;
      }
      if (f.name) {
        var q = f.name.toLowerCase();
        var hay = (String(r.id) + ' ' + r.name + ' ' + r.vocab + ' ' + r.domain).toLowerCase();
        if (hay.indexOf(q) < 0) return false;
      }
      return true;
    });

    if (conceptsSort.key) {
      var k = conceptsSort.key;
      var asc = conceptsSort.asc ? 1 : -1;
      rows.sort(function(a, b) {
        var va = a[k], vb = b[k];
        if (k === 'id') return (va - vb) * asc;
        if (k === 'inDict') return ((va === vb) ? 0 : (va ? -1 : 1)) * asc;
        return String(va).toLowerCase().localeCompare(String(vb).toLowerCase()) * asc;
      });
    }

    // Sort indicators
    panel.querySelectorAll('thead th[data-sort]').forEach(function(th) {
      var isActive = conceptsSort.key === th.dataset.sort;
      th.classList.toggle('sorted', !!isActive);
      var icon = th.querySelector('.sort-icon');
      if (icon) icon.textContent = (isActive && !conceptsSort.asc) ? '▼' : '▲';
    });

    // Summary
    var summary = document.getElementById('mapping-concepts-summary');
    if (summary) {
      var inDictCount = allRows.filter(function(r) { return r.inDict; }).length;
      summary.textContent = allRows.length + ' ' + App.i18n('unique') +
        ' · ' + inDictCount + ' ' + App.i18n('in dictionary') +
        (rows.length !== allRows.length ? ' · ' + rows.length + ' ' + App.i18n('shown') : '');
    }

    var tbody = document.getElementById('mapping-concepts-tbody');
    var capped = rows.slice(0, 500);
    var loadingCell = '<span class="mapping-cell-loading"><i class="fas fa-circle-notch fa-spin"></i> ' +
      App.escapeHtml(App.i18n('Loading…')) + '</span>';
    // Pick the unresolved cell based on the cached vocab-readiness probe:
    //   - null  → probe still in flight → show the loading spinner; we don't
    //             yet know whether a vocab DB is available, so we mustn't tell
    //             the user "Load OHDSI vocabularies" prematurely.
    //   - true  → tables are loaded, the id just isn't in the OMOP vocabulary.
    //   - false → no DB, or tables not imported yet → tell the user how to
    //             get this resolved.
    var unresolvedCell;
    if (_vocabReadyCached === null) {
      unresolvedCell = loadingCell;
    } else if (_vocabReadyCached === true) {
      unresolvedCell = '<span class="mapping-cell-unresolved"><i class="fas fa-question-circle"></i> ' +
        App.escapeHtml(App.i18n('Not in vocabulary')) + '</span>';
    } else {
      unresolvedCell = '<span class="mapping-cell-unresolved"><i class="fas fa-info-circle"></i> ' +
        App.escapeHtml(App.i18n('Load OHDSI vocabularies to resolve')) + '</span>';
    }

    tbody.innerHTML = capped.map(function(r) {
      var inDictBadge = r.inDict
        ? '<span class="mapping-yes-badge">' + App.escapeHtml(App.i18n('Yes')) + '</span>'
        : '<span class="mapping-no-badge">' + App.escapeHtml(App.i18n('No')) + '</span>';

      var vocabCell, nameCell, domainCell;
      if (r.status === 'loading') {
        vocabCell = '<td>' + loadingCell + '</td>';
        nameCell = '<td>' + loadingCell + '</td>';
        domainCell = '<td>' + loadingCell + '</td>';
      } else if (r.status === 'unresolved') {
        vocabCell = '<td>' + unresolvedCell + '</td>';
        nameCell = '<td>' + unresolvedCell + '</td>';
        domainCell = '<td>' + unresolvedCell + '</td>';
      } else {
        vocabCell = '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(r.vocab) + '">' + App.escapeHtml(r.vocab) + '</td>';
        nameCell = '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(r.name) + '"><strong>' + App.escapeHtml(r.name) + '</strong></td>';
        domainCell = '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(r.domain) + '">' + App.escapeHtml(r.domain) + '</td>';
      }

      return '<tr>' +
        vocabCell +
        '<td><a class="concept-id-link" href="https://athena.ohdsi.org/search-terms/terms/' + r.id + '" target="_blank" rel="noopener">' + r.id + '</a></td>' +
        nameCell +
        domainCell +
        '<td class="td-center">' + inDictBadge + '</td>' +
      '</tr>';
    }).join('');
    if (rows.length > 500) {
      tbody.innerHTML += '<tr><td colspan="5" style="text-align:center; color:var(--text-muted); font-style:italic; padding:10px">' +
        App.i18n('Showing the first 500 rows out of') + ' ' + rows.length + '.</td></tr>';
    }
    App.initColResize('mapping-concepts-table', { lockNow: true });
  }

  // Resolved sets >100 concepts are deferred by build.py and only loaded via
  // App.fetchResolved; computing eligibility from the sync API alone would
  // silently treat them as empty. Prefetch them all once, then re-render.
  var _resolvedReady = false;
  var _resolvedLoading = null;
  function ensureResolvedLoaded(onReady) {
    if (_resolvedReady) return true;
    if (!_resolvedLoading) {
      var ids = Object.keys(App.resolvedDeferred || {});
      _resolvedLoading = Promise.all(ids.map(function(id) { return App.fetchResolved(Number(id)); }))
        .then(function() { _resolvedReady = true; _conceptDictCache = null; });
    }
    if (onReady) _resolvedLoading.then(onReady);
    return false;
  }

  // Map concept_id → metadata (from resolved concept sets of the dictionary).
  // Built lazily and cached for the lifetime of the page module.
  var _conceptDictCache = null;
  function mappedConceptDictionary() {
    if (_conceptDictCache) return _conceptDictCache;
    var dict = {};
    (App.conceptSets || []).forEach(function(cs) {
      var resolved = App.getResolvedConceptSet(cs.id) || [];
      resolved.forEach(function(c) {
        // Keep the first occurrence; resolved concepts share metadata across CS.
        if (!dict[c.conceptId]) dict[c.conceptId] = c;
      });
    });
    _conceptDictCache = dict;
    return dict;
  }

  // Project selected in the Eligibility tab. null = first project, or none if
  // the user has not imported a mapping yet.
  var selectedEligibilityProjectId = null;
  var eligibilitySort = { key: null, asc: true };
  var eligibilityFilters = {
    name: '',
    groups: new Set(),
    rules: new Set(),
    statuses: new Set() // 'covered' | 'not_covered'
  };

  function ruleLabel(r) {
    if (r === 'all_required') return App.i18n('All required');
    if (r === 'at_least_one') return App.i18n('At least one');
    return App.i18n('Optional');
  }

  // Single-select dropdown styled like the .ms-toggle / .ms-dropdown pattern
  // used by the multi-select filters elsewhere in the app, so the look is
  // consistent. Closes on outside click; values is an array of
  // { value, label } objects.
  var singleSelectClosers = {};

  function buildSingleSelectPicker(containerId, values, selectedValue, onChange) {
    var container = document.getElementById(containerId);
    if (!container) return;
    function selectedLabel() {
      var found = values.find(function(v) { return String(v.value) === String(selectedValue); });
      return found ? found.label : App.i18n('Select…');
    }
    var showSearch = values.length > 10;
    container.innerHTML =
      '<div class="ms-toggle" tabindex="0">' + App.escapeHtml(selectedLabel()) + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i></div>' +
      '<div class="ms-dropdown" style="display:none">' +
        (showSearch ? '<div class="ms-search-wrap"><input type="text" class="ms-search" placeholder="' + App.escapeHtml(App.i18n('Search')) + '…"></div>' : '') +
        '<div class="ms-options">' +
          values.map(function(v) {
            var isSel = String(v.value) === String(selectedValue);
            return '<div class="ms-option-single' + (isSel ? ' ms-option-selected' : '') + '" data-value="' + App.escapeHtml(String(v.value)) + '">' +
              App.escapeHtml(v.label) + '</div>';
          }).join('') +
        '</div>' +
      '</div>';

    var toggle = container.querySelector('.ms-toggle');
    var dropdown = container.querySelector('.ms-dropdown');
    var searchInput = container.querySelector('.ms-search');

    toggle.addEventListener('click', function(e) {
      e.stopPropagation();
      document.querySelectorAll('.ms-dropdown').forEach(function(d) { if (d !== dropdown) d.style.display = 'none'; });
      var wasHidden = dropdown.style.display === 'none';
      dropdown.style.display = wasHidden ? '' : 'none';
      if (wasHidden && searchInput) { searchInput.value = ''; searchInput.focus(); }
    });
    if (searchInput) {
      searchInput.addEventListener('input', function() {
        var q = searchInput.value.toLowerCase();
        container.querySelectorAll('.ms-option-single').forEach(function(opt) {
          var label = opt.textContent.toLowerCase();
          opt.style.display = label.indexOf(q) !== -1 ? '' : 'none';
        });
      });
      searchInput.addEventListener('click', function(e) { e.stopPropagation(); });
    }
    dropdown.addEventListener('click', function(e) {
      var btn = e.target.closest('.ms-option-single');
      if (!btn) return;
      selectedValue = btn.dataset.value;
      // Update visual state.
      container.querySelectorAll('.ms-option-single').forEach(function(o) {
        o.classList.toggle('ms-option-selected', o === btn);
      });
      toggle.innerHTML = App.escapeHtml(selectedLabel()) + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i>';
      dropdown.style.display = 'none';
      onChange(selectedValue);
    });

    // Close on outside click — replace (not stack) the previous handler for
    // this container, since the picker is rebuilt on every render.
    if (singleSelectClosers[containerId]) document.removeEventListener('click', singleSelectClosers[containerId]);
    singleSelectClosers[containerId] = function(e) {
      if (!container.contains(e.target)) dropdown.style.display = 'none';
    };
    document.addEventListener('click', singleSelectClosers[containerId]);
  }

  function renderEligibilityTab() {
    var mp = selectedMappingProjectId && App.getMappingProject(selectedMappingProjectId);
    if (!mp) return;
    if (!ensureResolvedLoaded(renderEligibilityTab)) return;
    var panel = document.getElementById('mapping-project-tab-eligibility');
    if (!mp.conceptIds || mp.conceptIds.length === 0) {
      panel.innerHTML = '<div class="mapping-empty-state">' +
        '<i class="fas fa-check-double"></i>' +
        '<p>' + App.escapeHtml(App.i18n('Import a CSV to see how your mapping covers each INDICATE project.')) + '</p>' +
      '</div>';
      return;
    }

    var results = evaluateAllProjects(mp);
    if (results.length === 0) {
      panel.innerHTML = '<div class="mapping-empty-state"><p>' +
        App.escapeHtml(App.i18n('No INDICATE projects to evaluate.')) + '</p></div>';
      return;
    }

    // Pick a project: honour the explicit selection if still valid, else the
    // first project. The selection survives across tab switches.
    var resultById = {};
    results.forEach(function(r) { resultById[r.project.id] = r; });
    if (!resultById[selectedEligibilityProjectId]) {
      selectedEligibilityProjectId = results[0].project.id;
    }

    // Project picker values (label = project name + score %).
    var pickerValues = results.map(function(r) {
      var projName = App.tProj(r.project).name || ('#' + r.project.id);
      return { value: r.project.id, label: projName };
    });

    eligibilitySort = { key: null, asc: true };
    eligibilityFilters = { name: '', groups: new Set(), rules: new Set(), statuses: new Set() };

    panel.innerHTML =
      '<div class="mapping-eligibility-toolbar">' +
        '<label class="form-label" style="margin-bottom:0; align-self:center">' +
          App.escapeHtml(App.i18n('Project')) + '</label>' +
        '<div class="ms-container mapping-eligibility-project-picker" id="mapping-eligibility-project"></div>' +
        '<span id="mapping-eligibility-summary" style="color:var(--text-muted); font-size:13px; margin-left:auto"></span>' +
      '</div>' +
      '<div class="table-container">' +
        '<table id="mapping-eligibility-table">' +
          '<thead>' +
            '<tr>' +
              '<th data-sort="groupName" style="width:18%"><span data-i18n="Group">Group</span> <span class="sort-icon">&#9650;</span></th>' +
              '<th data-sort="rule" style="width:14%"><span data-i18n="Group rule">Group rule</span> <span class="sort-icon">&#9650;</span></th>' +
              '<th data-sort="csName" style="width:32%"><span data-i18n="Concept set">Concept set</span> <span class="sort-icon">&#9650;</span></th>' +
              '<th data-sort="resolved" style="width:10%" class="td-center"><span data-i18n="Resolved">Resolved</span> <span class="sort-icon">&#9650;</span></th>' +
              '<th data-sort="covered" style="width:14%" class="td-center"><span data-i18n="Status">Status</span> <span class="sort-icon">&#9650;</span></th>' +
              '<th style="width:8%" class="td-center"><span data-i18n="Details">Details</span></th>' +
            '</tr>' +
            '<tr class="filter-row">' +
              '<th><div class="ms-container" id="mapping-eligibility-filter-group"></div></th>' +
              '<th><div class="ms-container" id="mapping-eligibility-filter-rule"></div></th>' +
              '<th><input type="text" class="column-filter" id="mapping-eligibility-filter-name" placeholder="Filter..." data-i18n-placeholder="Filter..."></th>' +
              '<th></th>' +
              '<th><div class="ms-container" id="mapping-eligibility-filter-status"></div></th>' +
              '<th></th>' +
            '</tr>' +
          '</thead>' +
          '<tbody id="mapping-eligibility-tbody"></tbody>' +
        '</table>' +
      '</div>';

    // Wire the project picker (styled dropdown, single-select).
    buildSingleSelectPicker('mapping-eligibility-project', pickerValues, selectedEligibilityProjectId, function(newValue) {
      selectedEligibilityProjectId = parseInt(newValue, 10);
      writeEligibilityUrl();
      // Reset filters & sort when the project changes.
      eligibilitySort = { key: null, asc: true };
      eligibilityFilters = { name: '', groups: new Set(), rules: new Set(), statuses: new Set() };
      renderEligibilityRows();
    });

    panel.querySelector('thead').addEventListener('click', function(e) {
      var th = e.target.closest('th[data-sort]');
      if (!th) return;
      var key = th.dataset.sort;
      if (eligibilitySort.key !== key) { eligibilitySort.key = key; eligibilitySort.asc = true; }
      else if (eligibilitySort.asc) eligibilitySort.asc = false;
      else { eligibilitySort.key = null; eligibilitySort.asc = true; }
      renderEligibilityRows();
    });

    document.getElementById('mapping-eligibility-filter-name').addEventListener('input', function(e) {
      eligibilityFilters.name = e.target.value;
      renderEligibilityRows();
    });

    // tbody delegated click: magnifier button opens the details modal; any
    // other click on the row navigates to the concept set detail page.
    document.getElementById('mapping-eligibility-tbody').addEventListener('click', function(e) {
      var btn = e.target.closest('.mapping-cs-details-btn');
      if (btn) {
        e.stopPropagation();
        openCSDetailsModal(parseInt(btn.dataset.csId, 10), btn.dataset.csVersion || '');
        return;
      }
      var row = e.target.closest('tr[data-cs-id]');
      if (!row) return;
      var query = { id: row.dataset.csId };
      var v = row.dataset.csVersion;
      if (v) query.version = v;
      Router.navigate('/concept-sets', query);
    });

    renderEligibilityRows();
    writeEligibilityUrl();
  }

  function writeEligibilityUrl() {
    if (!selectedMappingProjectId) return;
    var url = '#/mapping?id=' + encodeURIComponent(selectedMappingProjectId) + '&detail=eligibility';
    if (selectedEligibilityProjectId) url += '&project=' + selectedEligibilityProjectId;
    Router.replaceState(url);
  }

  function renderEligibilityRows(skipFilterId) {
    var mp = selectedMappingProjectId && App.getMappingProject(selectedMappingProjectId);
    if (!mp || !selectedEligibilityProjectId) return;
    var project = (App.projects || []).find(function(p) { return p.id === selectedEligibilityProjectId; });
    if (!project) return;
    var mappedSet = buildMappedSet(mp);
    var result = evaluateProject(project, mappedSet);

    // Flatten groups → per-CS rows (one row per concept set in the project).
    var rows = [];
    result.groups.forEach(function(g) {
      g.perCS.forEach(function(cs) {
        var live = App.getConceptSet(cs.id, cs.version) || App.getConceptSet(cs.id);
        var name = live ? (App.t(live).name || live.name || ('#' + cs.id)) : ('#' + cs.id);
        rows.push({
          groupName: g.name || '',
          rule: g.rule,
          csId: cs.id,
          csVersion: cs.version || '',
          csName: name,
          resolved: cs.total,
          covered: cs.covered
        });
      });
    });

    // Populate filter dropdowns from the full row set.
    var allGroups = [...new Set(rows.map(function(r) { return r.groupName; }).filter(Boolean))].sort();
    var allRules = [...new Set(rows.map(function(r) { return r.rule; }))].sort();
    var ruleLabelMap = {};
    allRules.forEach(function(r) { ruleLabelMap[r] = ruleLabel(r); });
    var statusLabelMap = {
      'covered': App.i18n('Covered'),
      'not_covered': App.i18n('Not covered')
    };
    // Re-rendering must not rebuild the dropdown being interacted with —
    // rebuilding wipes the open dropdown and closes it after every checkbox.
    function buildOrRefresh(id, values, selectedSet, labelMap) {
      if (skipFilterId === id) {
        App.updateMsToggleLabel(id, selectedSet, labelMap);
      } else {
        App.buildMultiSelectDropdown(id, values, selectedSet, function() { renderEligibilityRows(id); }, labelMap);
      }
    }
    buildOrRefresh('mapping-eligibility-filter-group', allGroups, eligibilityFilters.groups);
    buildOrRefresh('mapping-eligibility-filter-rule', allRules, eligibilityFilters.rules, ruleLabelMap);
    buildOrRefresh('mapping-eligibility-filter-status', ['covered', 'not_covered'], eligibilityFilters.statuses, statusLabelMap);

    // Filtering.
    var f = eligibilityFilters;
    var filtered = rows.filter(function(r) {
      if (f.groups.size > 0 && !f.groups.has(r.groupName)) return false;
      if (f.rules.size > 0 && !f.rules.has(r.rule)) return false;
      if (f.statuses.size > 0) {
        var key = r.covered ? 'covered' : 'not_covered';
        if (!f.statuses.has(key)) return false;
      }
      if (f.name) {
        var q = f.name.toLowerCase();
        if (r.csName.toLowerCase().indexOf(q) < 0) return false;
      }
      return true;
    });

    if (eligibilitySort.key) {
      var k = eligibilitySort.key;
      var asc = eligibilitySort.asc ? 1 : -1;
      filtered.sort(function(a, b) {
        var va = a[k], vb = b[k];
        if (k === 'resolved') return ((va || 0) - (vb || 0)) * asc;
        if (k === 'covered') return ((va === vb) ? 0 : (va ? -1 : 1)) * asc;
        return String(va || '').toLowerCase().localeCompare(String(vb || '').toLowerCase()) * asc;
      });
    }

    // Sort indicators.
    var panel = document.getElementById('mapping-project-tab-eligibility');
    panel.querySelectorAll('thead th[data-sort]').forEach(function(th) {
      var isActive = eligibilitySort.key === th.dataset.sort;
      th.classList.toggle('sorted', !!isActive);
      var icon = th.querySelector('.sort-icon');
      if (icon) icon.textContent = (isActive && !eligibilitySort.asc) ? '▼' : '▲';
    });

    // Summary line.
    var summary = document.getElementById('mapping-eligibility-summary');
    if (summary) {
      var coveredCount = rows.filter(function(r) { return r.covered; }).length;
      summary.textContent = App.i18n('Coverage:') + ' ' + coveredCount + ' / ' + rows.length +
        ' · ' + App.i18n('Project score:') + ' ' + result.score + '%';
    }

    var tbody = document.getElementById('mapping-eligibility-tbody');
    tbody.innerHTML = filtered.map(function(r) {
      var statusCell = r.covered
        ? '<span class="badge" style="background:#dcfce7; color:#166534"><i class="fas fa-check"></i> ' + App.escapeHtml(App.i18n('Covered')) + '</span>'
        : '<span class="badge" style="background:#fee2e2; color:#991b1b"><i class="fas fa-times"></i> ' + App.escapeHtml(App.i18n('Not covered')) + '</span>';
      return '<tr data-cs-id="' + r.csId + '" data-cs-version="' + App.escapeHtml(r.csVersion) + '" style="cursor:pointer">' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(r.groupName) + '">' + App.escapeHtml(r.groupName) + '</td>' +
        '<td>' + App.escapeHtml(ruleLabel(r.rule)) + '</td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(r.csName) + '"><strong>' + App.escapeHtml(r.csName) + '</strong></td>' +
        '<td class="td-center" style="font-family:monospace">' + r.resolved + '</td>' +
        '<td class="td-center">' + statusCell + '</td>' +
        '<td class="td-center"><button class="mapping-cs-details-btn" data-cs-id="' + r.csId + '" data-cs-version="' + App.escapeHtml(r.csVersion) + '" title="' + App.escapeHtml(App.i18n('View coverage details')) + '"><i class="fas fa-search"></i></button></td>' +
      '</tr>';
    }).join('');
    App.initColResize('mapping-eligibility-table', { lockNow: true });
  }

  // ==================== CS COVERAGE DETAILS MODAL ====================
  function openCSDetailsModal(csId, csVersion) {
    var mp = selectedMappingProjectId && App.getMappingProject(selectedMappingProjectId);
    if (!mp) return;
    if (!ensureResolvedLoaded(function() { openCSDetailsModal(csId, csVersion); })) return;
    var live = App.getConceptSet(csId, csVersion) || App.getConceptSet(csId);
    var resolved = App.getResolvedConceptSet(csId, csVersion) || [];
    var mappedSet = buildMappedSet(mp);
    var covered = [];
    var missing = [];
    resolved.forEach(function(c) {
      if (mappedSet.has(c.conceptId)) covered.push(c);
      else missing.push(c);
    });

    var csName = live ? (App.t(live).name || live.name || ('#' + csId)) : ('#' + csId);
    document.getElementById('mapping-cs-details-title').innerHTML =
      '<i class="fas fa-search"></i> ' + App.escapeHtml(csName);

    // Use neutral wording: this set's "resolved concepts" split into ones the
    // user already has locally vs the others. Coverage is binary (≥1 concept
    // mapped suffices), so framing the missing ones as a "gap" would mislead.
    document.getElementById('mapping-cs-details-summary').innerHTML =
      '<span>' + App.escapeHtml(App.i18n('Resolved concepts in this set')) + ': <strong>' + resolved.length + '</strong></span>' +
      ' &middot; <span style="color:#166534"><strong>' + covered.length + '</strong> ' + App.escapeHtml(App.i18n('local')) + '</span>' +
      ' &middot; <span style="color:var(--text-muted)"><strong>' + missing.length + '</strong> ' + App.escapeHtml(App.i18n('other')) + '</span>';

    var lists = document.getElementById('mapping-cs-details-lists');
    function renderList(title, items, color, sign) {
      if (items.length === 0) return '';
      return '<h4 style="margin:12px 0 6px; font-size:13px; color:' + color + '">' + App.escapeHtml(title) + ' (' + items.length + ')</h4>' +
        '<ul style="list-style:none; margin:0; padding:4px 8px; max-height:200px; overflow-y:auto; border:1px solid var(--border); border-radius:4px">' +
          items.map(function(c) { return mappingCSDetailsLine(c, sign); }).join('') +
        '</ul>';
    }
    lists.innerHTML =
      renderList(App.i18n('Local concepts in this set'), covered, '#166534', '✓') +
      renderList(App.i18n('Other concepts in this set'), missing, 'var(--text-muted)', '·');

    document.getElementById('mapping-cs-details-modal').style.display = '';
  }

  function mappingCSDetailsLine(c, sign) {
    var isLocal = sign === '✓';
    return App.conceptListLine(c, {
      sign: sign,
      color: isLocal ? '#166534' : 'var(--text-muted)',
      bg: isLocal ? '#dcfce7' : 'var(--bg-muted, #f1f5f9)'
    });
  }

  function closeCSDetailsModal() {
    document.getElementById('mapping-cs-details-modal').style.display = 'none';
  }

  function renderEligibilityPreview(mp) {
    var preview = document.getElementById('mapping-project-eligibility-preview');
    if (!mp || !mp.conceptIds || mp.conceptIds.length === 0) {
      preview.innerHTML = '';
      return;
    }
    var results = evaluateAllProjects(mp);
    if (results.length === 0) { preview.innerHTML = ''; return; }

    preview.innerHTML =
      '<h4 style="margin:24px 0 12px; font-size:13px; text-transform:uppercase; letter-spacing:0.3px; color:var(--text-muted)">' +
        App.escapeHtml(App.i18n('Eligibility per INDICATE project')) +
      '</h4>' +
      '<div class="project-cards mapping-eligibility-cards">' +
        results.map(function(r) {
          var cls = r.score === 100 ? 'score-full' : (r.score >= 75 ? 'score-mid' : 'score-low');
          var projTr = App.tProj(r.project);
          var projName = projTr.name || ('#' + r.project.id);
          var shortDesc = projTr.shortDescription || '';
          // Count covered / total CS across the project (informative footer).
          var total = 0, covered = 0;
          r.groups.forEach(function(g) {
            total += g.total;
            covered += g.coveredCount;
          });
          return '<div class="project-card mapping-eligibility-card ' + cls + '" data-project-id="' + r.project.id + '" title="' + App.escapeHtml(App.i18n('See coverage breakdown')) + '">' +
            '<div class="mapping-eligibility-card-score">' + r.score + '%</div>' +
            '<h3>' + App.escapeHtml(projName) + '</h3>' +
            '<p>' + App.escapeHtml(shortDesc || ' ') + '</p>' +
            '<div class="project-card-footer">' +
              '<span><i class="fas fa-check"></i> ' + covered + ' / ' + total + ' ' + App.escapeHtml(App.i18n('concept sets covered')) + '</span>' +
            '</div>' +
          '</div>';
        }).join('') +
      '</div>';

    // Delegate click → switch to Eligibility tab pre-filtered on that project.
    preview.querySelector('.mapping-eligibility-cards').addEventListener('click', function(e) {
      var card = e.target.closest('.mapping-eligibility-card[data-project-id]');
      if (!card) return;
      selectedEligibilityProjectId = parseInt(card.dataset.projectId, 10);
      switchDetailTab('eligibility');
    });
  }

  // ==================== PAGE MODULE ====================
  function show(query) {
    if (!initialized) {
      initialized = true;
      initEvents();
    }
    var qTab = query && query.tab;
    var qId = query && query.id;
    var qDetail = query && query.detail;
    if (qTab === 'recommendations') {
      selectedMappingProjectId = null;
      switchTab('recommendations');
      return;
    }
    // Default to the projects tab (with optional detail-view selection).
    if (qId) {
      selectedMappingProjectId = qId;
      detailTab = ['overview', 'concepts', 'eligibility'].indexOf(qDetail) >= 0 ? qDetail : 'overview';
      var qProject = query && query.project;
      if (detailTab === 'eligibility' && qProject) {
        var pid = parseInt(qProject, 10);
        if (!isNaN(pid)) selectedEligibilityProjectId = pid;
      }
    } else {
      selectedMappingProjectId = null;
      detailTab = 'overview';
    }
    switchTab('projects');
  }

  function hide() {
    closeCreateModal();
    closeDeleteModal();
    closeImportModal();
    closeCSDetailsModal();
    closeAllCardMenus();
  }

  function onLanguageChange() {
    if (!initialized) return;
    if (currentTab === 'recommendations') {
      if (!recoEditing) renderRecoView();
      else if (recoEditor) recoEditor.setValue(recoGetContent(), -1);
    } else {
      renderMappingProjects();
    }
  }

  return {
    show: show,
    hide: hide,
    onLanguageChange: onLanguageChange
  };
})();
