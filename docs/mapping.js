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
  var deleteTargetId = null;

  // ==================== TABS ====================
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
    var url = '#/mapping';
    if (tabName === 'recommendations') url += '?tab=recommendations';
    history.replaceState(null, '', url);

    if (tabName === 'recommendations') {
      ensureRecommendationsInit();
      if (!recoEditing) renderRecoView();
      else if (recoEditor) recoEditor.resize();
    } else {
      renderMappingProjects();
    }
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
      // Plain card click: detail view not implemented in this commit. Will land
      // in a follow-up that adds the per-project dashboard.
    });
    document.addEventListener('click', closeAllCardMenus);

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

  // ==================== PAGE MODULE ====================
  function show(query) {
    if (!initialized) {
      initialized = true;
      initEvents();
    }
    var tab = (query && query.tab) === 'recommendations' ? 'recommendations' : 'projects';
    switchTab(tab);
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
