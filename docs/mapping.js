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
      history.replaceState(null, '', '#/mapping');
    } else if (tabName === 'recommendations') {
      selectedMappingProjectId = null;
      hideDetailView();
      history.replaceState(null, '', '#/mapping?tab=recommendations');
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
    history.replaceState(null, '', url);
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
      history.replaceState(null, '', url);
    }

    if (tabName === 'overview') renderOverview();
    else if (tabName === 'concepts') renderConceptsTab();
    else if (tabName === 'eligibility') renderEligibilityTab();
  }

  function renderOverview() {
    var mp = selectedMappingProjectId && App.getMappingProject(selectedMappingProjectId);
    if (!mp) return;
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

    // Toggle the import CTA depending on whether data is already present.
    var cta = document.getElementById('mapping-project-import-cta');
    var ctaText = document.getElementById('mapping-import-text');
    if (n === 0) {
      ctaText.textContent = App.i18n('No mapping data imported yet. Upload a source-to-concept-map CSV to evaluate your eligibility to INDICATE projects.');
    } else {
      var imported = mp.stats && mp.stats.sourceFile ? mp.stats.sourceFile : '';
      ctaText.textContent = App.i18n('{n} concepts imported.').replace('{n}', n) +
        (imported ? ' ' + App.i18n('Source:') + ' ' + imported : '') +
        ' ' + App.i18n('Re-import a CSV to replace the current mapping.');
    }
    cta.style.display = '';

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
      return '<div class="project-card mapping-project-card" data-id="' + App.escapeHtml(mp.id) + '">' +
        '<button class="project-card-menu-btn" data-menu-id="' + App.escapeHtml(mp.id) + '" title="' + App.escapeHtml(App.i18n('Actions')) + '"><i class="fas fa-ellipsis-v"></i></button>' +
        '<div class="project-card-menu" id="mapping-project-menu-' + App.escapeHtml(mp.id) + '">' +
          '<button class="project-card-menu-item" data-action="edit" data-id="' + App.escapeHtml(mp.id) + '"><i class="fas fa-pen"></i> ' + App.i18n('Edit') + '</button>' +
          '<button class="project-card-menu-item danger" data-action="delete" data-id="' + App.escapeHtml(mp.id) + '"><i class="fas fa-trash"></i> ' + App.i18n('Delete') + '</button>' +
        '</div>' +
        '<h3>' + App.escapeHtml(tr.name || App.i18n('Untitled')) + '</h3>' +
        '<p title="' + App.escapeHtml(tr.description || '') + '">' +
          App.escapeHtml(tr.description || App.i18n('No description')) +
        '</p>' +
        '<div class="project-card-footer">' +
          '<span><i class="fas fa-list"></i> ' + n + ' ' + App.i18n('mapped concepts') + '</span>' +
          '<span><i class="fas fa-calendar-alt"></i> ' + App.escapeHtml(App.formatDate(mp.modifiedDate || mp.createdDate) || '') + '</span>' +
        '</div>' +
        '</div>';
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

  function submitCreateModal() {
    var name = document.getElementById('mapping-project-modal-name').value.trim();
    var desc = document.getElementById('mapping-project-modal-description').value.trim();
    if (!name) {
      App.showToast(App.i18n('Project name is required.'), 'error');
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
        translations: {
          en: { name: lang === 'en' ? name : name, description: lang === 'en' ? desc : desc },
          fr: { name: lang === 'fr' ? name : name, description: lang === 'fr' ? desc : desc }
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
      container.innerHTML = marked.parse(md);
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
        + h.textContent + '</a></li>';
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
          preview.innerHTML = marked.parse(md);
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
    if (initMd.trim()) preview.innerHTML = marked.parse(initMd);
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
      history.replaceState(null, '', '#/mapping');
    });
    document.getElementById('mapping-project-tabs').addEventListener('click', function(e) {
      var tab = e.target.closest('.settings-tab');
      if (!tab) return;
      switchDetailTab(tab.dataset.tab);
    });

    // Import CSV button (Overview tab)
    document.getElementById('mapping-project-import-btn').addEventListener('click', openImportModal);

    // Import CSV modal
    document.getElementById('mapping-import-modal-close').addEventListener('click', closeImportModal);
    document.getElementById('mapping-import-modal-cancel').addEventListener('click', closeImportModal);
    document.getElementById('mapping-import-modal-submit').addEventListener('click', submitImport);
    document.getElementById('mapping-import-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('mapping-import-modal')) closeImportModal();
    });
    document.getElementById('mapping-import-file').addEventListener('change', onImportFileChange);

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

    // Show the first 10 rows as a quick sanity check.
    var startIdx = detection.hasHeader ? 1 : 0;
    var sampleRows = importParsed.rows.slice(startIdx, startIdx + 10);
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
  function renderConceptsTab() {
    var mp = selectedMappingProjectId && App.getMappingProject(selectedMappingProjectId);
    if (!mp) return;
    var panel = document.getElementById('mapping-project-tab-concepts');
    var ids = mp.conceptIds || [];
    if (ids.length === 0) {
      panel.innerHTML = '<div class="mapping-empty-state">' +
        '<i class="fas fa-table"></i>' +
        '<p>' + App.escapeHtml(App.i18n('Import a CSV to see your mapped concepts here.')) + '</p>' +
      '</div>';
      return;
    }
    // Build a lookup of concept_id → resolved concept metadata across the whole
    // dictionary (so we can tell which mapped ids are in INDICATE concept sets).
    var dictById = mappedConceptDictionary();
    var unique = Array.from(new Set(ids));
    var matchedCount = unique.filter(function(id) { return dictById[id]; }).length;

    panel.innerHTML =
      '<div style="padding:16px; display:flex; flex-direction:column; min-height:0; flex:1">' +
        '<div class="mapping-concepts-toolbar">' +
          '<input type="text" class="search-input" id="mapping-concepts-search" placeholder="' + App.escapeHtml(App.i18n('Filter by concept id or name...')) + '">' +
          '<label style="font-size:13px; color:var(--text-muted)"><input type="checkbox" id="mapping-concepts-only-matched"> ' + App.escapeHtml(App.i18n('Only show concepts present in the dictionary')) + '</label>' +
          '<span style="color:var(--text-muted); font-size:13px; margin-left:auto">' + unique.length + ' ' + App.i18n('unique') + ' · ' + matchedCount + ' ' + App.i18n('in dictionary') + '</span>' +
        '</div>' +
        '<div class="mapping-concepts-table-wrap"><table id="mapping-concepts-table"><thead><tr>' +
          '<th>concept_id</th>' +
          '<th>' + App.escapeHtml(App.i18n('Name')) + '</th>' +
          '<th>' + App.escapeHtml(App.i18n('Vocabulary')) + '</th>' +
          '<th>' + App.escapeHtml(App.i18n('Domain')) + '</th>' +
          '<th>' + App.escapeHtml(App.i18n('In dictionary')) + '</th>' +
        '</tr></thead><tbody id="mapping-concepts-tbody"></tbody></table></div>' +
      '</div>';

    function renderRows() {
      var q = (document.getElementById('mapping-concepts-search').value || '').toLowerCase();
      var onlyMatched = document.getElementById('mapping-concepts-only-matched').checked;
      var rows = unique
        .filter(function(id) { return !onlyMatched || dictById[id]; })
        .map(function(id) {
          var c = dictById[id];
          var name = c ? c.conceptName : '';
          var vocab = c ? c.vocabularyId : '';
          var domain = c ? c.domainId : '';
          return { id: id, name: name || '', vocab: vocab || '', domain: domain || '', inDict: !!c };
        })
        .filter(function(r) {
          if (!q) return true;
          return String(r.id).indexOf(q) >= 0 ||
            r.name.toLowerCase().indexOf(q) >= 0 ||
            r.vocab.toLowerCase().indexOf(q) >= 0;
        });
      var tbody = document.getElementById('mapping-concepts-tbody');
      // Cap at 500 rows to keep things responsive in this first pass.
      var capped = rows.slice(0, 500);
      tbody.innerHTML = capped.map(function(r) {
        return '<tr>' +
          '<td><a href="https://athena.ohdsi.org/search-terms/terms/' + r.id + '" target="_blank" rel="noopener" style="font-family:monospace">' + r.id + '</a></td>' +
          '<td>' + App.escapeHtml(r.name) + '</td>' +
          '<td>' + App.escapeHtml(r.vocab) + '</td>' +
          '<td>' + App.escapeHtml(r.domain) + '</td>' +
          '<td>' + (r.inDict
            ? '<span style="color:#166534"><i class="fas fa-check"></i></span>'
            : '<span style="color:var(--text-muted)">—</span>') + '</td>' +
          '</tr>';
      }).join('');
      if (rows.length > 500) {
        tbody.innerHTML += '<tr><td colspan="5" style="text-align:center; color:var(--text-muted); font-style:italic; padding:10px">' +
          App.i18n('Showing the first 500 rows out of') + ' ' + rows.length + '.</td></tr>';
      }
    }

    document.getElementById('mapping-concepts-search').addEventListener('input', renderRows);
    document.getElementById('mapping-concepts-only-matched').addEventListener('change', renderRows);
    renderRows();
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

  function renderEligibilityTab() {
    var mp = selectedMappingProjectId && App.getMappingProject(selectedMappingProjectId);
    if (!mp) return;
    var panel = document.getElementById('mapping-project-tab-eligibility');
    if (!mp.conceptIds || mp.conceptIds.length === 0) {
      panel.innerHTML = '<div class="mapping-empty-state">' +
        '<i class="fas fa-check-double"></i>' +
        '<p>' + App.escapeHtml(App.i18n('Import a CSV to see how your mapping covers each INDICATE project.')) + '</p>' +
      '</div>';
      return;
    }
    var results = evaluateAllProjects(mp);
    var rows = [];
    results.forEach(function(r) {
      var projTr = App.tProj(r.project);
      var projName = projTr.name || ('#' + r.project.id);
      r.groups.forEach(function(g) {
        rows.push({
          projectId: r.project.id, projectName: projName,
          groupName: g.name, rule: g.rule,
          coveredCount: g.coveredCount, total: g.total,
          score: Math.round(g.score * 100), satisfied: g.satisfied
        });
      });
    });

    var ruleLabel = function(r) {
      if (r === 'all_required') return App.i18n('All required');
      if (r === 'at_least_one') return App.i18n('At least one');
      return App.i18n('Optional');
    };
    panel.innerHTML =
      '<div style="padding:16px; display:flex; flex-direction:column; min-height:0; flex:1">' +
        '<div class="mapping-eligibility-table-wrap"><table id="mapping-eligibility-table"><thead><tr>' +
          '<th>' + App.escapeHtml(App.i18n('Project')) + '</th>' +
          '<th>' + App.escapeHtml(App.i18n('Group')) + '</th>' +
          '<th>' + App.escapeHtml(App.i18n('Group rule')) + '</th>' +
          '<th>' + App.escapeHtml(App.i18n('Covered')) + '</th>' +
          '<th>' + App.escapeHtml(App.i18n('Score')) + '</th>' +
          '<th>' + App.escapeHtml(App.i18n('Status')) + '</th>' +
        '</tr></thead><tbody>' +
          rows.map(function(r) {
            var statusBadge = r.rule === 'optional'
              ? '<span style="color:var(--text-muted); font-size:12px">' + App.escapeHtml(App.i18n('Informative')) + '</span>'
              : (r.satisfied
                  ? '<span class="badge" style="background:#dcfce7; color:#166534"><i class="fas fa-check"></i> ' + App.escapeHtml(App.i18n('Satisfied')) + '</span>'
                  : '<span class="badge" style="background:#fee2e2; color:#991b1b"><i class="fas fa-times"></i> ' + App.escapeHtml(App.i18n('Not satisfied')) + '</span>');
            return '<tr>' +
              '<td>' + App.escapeHtml(r.projectName) + '</td>' +
              '<td>' + App.escapeHtml(r.groupName || '') + '</td>' +
              '<td>' + App.escapeHtml(ruleLabel(r.rule)) + '</td>' +
              '<td style="font-family:monospace">' + r.coveredCount + ' / ' + r.total + '</td>' +
              '<td style="font-weight:600">' + r.score + '%</td>' +
              '<td>' + statusBadge + '</td>' +
            '</tr>';
          }).join('') +
        '</tbody></table></div>' +
      '</div>';
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
      '<div class="mapping-eligibility-list">' +
        results.map(function(r) {
          var cls = r.score === 100 ? 'score-full' : (r.score >= 75 ? 'score-mid' : 'score-low');
          var projTr = App.tProj(r.project);
          var projName = projTr.name || ('#' + r.project.id);
          return '<div class="mapping-eligibility-row ' + cls + '">' +
            '<div>' + App.escapeHtml(projName) + '</div>' +
            '<div class="mapping-eligibility-bar"><div class="mapping-eligibility-fill" style="width:' + r.score + '%"></div></div>' +
            '<div class="mapping-eligibility-score">' + r.score + '%</div>' +
          '</div>';
        }).join('') +
      '</div>';
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
    } else {
      selectedMappingProjectId = null;
      detailTab = 'overview';
    }
    switchTab('projects');
  }

  function hide() {
    closeCreateModal();
    closeDeleteModal();
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
