// projects.js — Projects page module
var ProjectsPage = (function() {
  'use strict';

  var initialized = false;
  var selectedProject = null;

  // ==================== PROJECT CS TABLE STATE ====================
  var projCsSort = { key: 'groupName', asc: true };
  var projCsFilterName = '';
  var projCsCategories = new Set();
  var projCsSubcategories = new Set();
  var projCsReviewStatuses = new Set();
  var projCsGroups = new Set();
  var projCsRules = new Set();
  var projCsVersionStatuses = new Set();
  // Frozen display order for the read-mode project CS table. Captured when sort
  // criteria change, then reused as-is by subsequent renders so actions like
  // "update to latest" never reshuffle the rows. null = needs (re)computation.
  var readOrderedCSIds = null;

  // ==================== EDIT MODE STATE ====================
  var editMode = false;
  var editLongDesc = '';
  // Working copy of project groups during edit: [{id, name:{en,fr}, rule, conceptSets:[{id,version}]}]
  var editGroups = [];
  // Id of the group that new CS are added to (and where bulk-moved CS land); always one of editGroups[*].id
  var editActiveGroupId = null;
  // Checked CS ids in the project-side edit table (for bulk move-to-group)
  var editSelectedCS = new Set();
  // Stable display order of concept sets in the PROJECT CS edit table. Initialized when
  // entering edit mode (sorted by group + category + subcategory + name), then only
  // mutated when CS are added (append) or removed (drop). Changing a CS's group does NOT
  // reorder it.
  var editOrderedCSIds = [];
  var currentTab = 'context';

  // ==================== GROUP HELPERS (edit-mode) ====================
  function editGroupsAllEntries() {
    var out = [];
    editGroups.forEach(function(g) { (g.conceptSets || []).forEach(function(e) { out.push(e); }); });
    return out;
  }
  // Committed JSON uses the language-first translations shape; the legacy
  // field-first `name: {en, fr}` shape only survives in old localStorage data.
  function legacyNameToTranslations(name) {
    if (!name) return { en: {}, fr: {} };
    if (typeof name === 'string') return { en: { name: name }, fr: { name: name } };
    return { en: { name: name.en || '' }, fr: { name: name.fr || '' } };
  }
  function ensureActiveGroup() {
    if (editGroups.length === 0) {
      editGroups.push({
        id: 'group-default',
        translations: { en: { name: 'Default' }, fr: { name: 'Par défaut' } },
        rule: App.DEFAULT_GROUP_RULE,
        conceptSets: []
      });
    }
    if (!editGroups.some(function(g) { return g.id === editActiveGroupId; })) {
      editActiveGroupId = editGroups[0].id;
    }
  }

  // ==================== RULE BADGE ====================
  var RULE_META = {
    all_required: { i18n: 'All required',   color: '#fee2e2', fg: '#991b1b', icon: 'fa-asterisk' },
    at_least_one: { i18n: 'At least one',  color: '#fef3c7', fg: '#92400e', icon: 'fa-check-circle' },
    optional:     { i18n: 'Optional',      color: '#dbeafe', fg: '#1e40af', icon: 'fa-circle' }
  };
  function ruleBadge(rule) {
    var meta = RULE_META[rule] || RULE_META.optional;
    return '<span class="badge rule-badge rule-' + rule + '" style="background:' + meta.color + '; color:' + meta.fg + '"><i class="fas ' + meta.icon + '"></i> ' + App.i18n(meta.i18n) + '</span>';
  }

  // CS edit table filter state (available = right panel, project = left panel)
  var availFilterCategories = new Set();
  var availFilterSubcategories = new Set();
  var availFilterName = '';
  var availFilterReviewStatuses = new Set();
  var projEditFilterCategories = new Set();
  var projEditFilterSubcategories = new Set();
  var projEditFilterName = '';
  var projEditFilterReviewStatuses = new Set();

  // CS edit table column visibility: full config per column (label + visible). All
  // visibility toggles are driven by `data-col="<key>"` attributes on the matching
  // <th> and <td> cells.
  var projEditColumns = {
    group:       { label: 'Group',       visible: true },
    category:    { label: 'Category',    visible: true },
    subcategory: { label: 'Subcategory', visible: true },
    name:        { label: 'Name',        visible: true },
    review:      { label: 'Review',      visible: false },
    version:     { label: 'Version',     visible: false }
  };
  var availEditColumns = {
    category:    { label: 'Category',    visible: true },
    subcategory: { label: 'Subcategory', visible: true },
    name:        { label: 'Name',        visible: true },
    review:      { label: 'Review',      visible: false },
    version:     { label: 'Version',     visible: false }
  };

  // CS edit table sort state. key === null means "no sort" — the project-side table
  // falls back to the stable editOrderedCSIds order, the available-side table falls
  // back to alphabetic (category + subcategory + name).
  var projEditSort = { key: null, asc: true };  // for the project-CS table (left in HTML)
  var availEditSort = { key: null, asc: true }; // for the available-CS table (right in HTML)

  // ==================== CREATE/EDIT MODAL STATE ====================
  var modalEditingId = null; // null = create, number = edit
  var deleteTargetId = null;

  // ==================== CARD MENU STATE ====================
  var openMenuId = null;

  // ==================== PROJECT CARDS ====================
  function renderProjectCards() {
    var filter = document.getElementById('proj-search').value.toLowerCase();
    var filtered = App.projects.filter(function(p) {
      if (!filter) return true;
      var tr = App.tProj(p);
      var name = (tr.name || '').toLowerCase();
      var desc = (tr.shortDescription || '').toLowerCase();
      return App.fuzzyMatch(name, filter) !== -1 || App.fuzzyMatch(desc, filter) !== -1;
    });

    var el = document.getElementById('proj-cards');
    el.innerHTML = filtered.map(function(p) {
      var tr = App.tProj(p);
      var csCount = App.getProjectConceptSetEntries(p).length;
      return App.projectCard({
        id: p.id,
        menuIdPrefix: 'proj-card-menu-',
        title: tr.name || '',
        description: tr.shortDescription || '',
        footer: [
          { icon: 'fa-list', text: csCount + ' ' + App.i18n('concept sets') },
          { icon: 'fa-user', text: p.createdBy || '' },
          { icon: 'fa-calendar-alt', text: App.formatDate(p.createdDate) || '' }
        ]
      });
    }).join('');
  }

  // ==================== CARD MENU ====================
  function closeAllMenus() {
    document.querySelectorAll('.project-card-menu.visible').forEach(function(m) {
      m.classList.remove('visible');
    });
    openMenuId = null;
  }

  // ==================== CREATE/EDIT MODAL ====================
  function openCreateModal() {
    modalEditingId = null;
    document.getElementById('proj-modal-title').innerHTML = '<i class="fas fa-plus"></i> ' + App.i18n('New Project');
    document.getElementById('proj-modal-submit').innerHTML = '<i class="fas fa-plus"></i> ' + App.i18n('Create');
    document.getElementById('proj-modal-name').value = '';
    document.getElementById('proj-modal-short-desc').value = '';
    var profile = App.getUserProfile();
    var authorName = ((profile.firstName || '') + ' ' + (profile.lastName || '')).trim();
    document.getElementById('proj-modal-author').value = authorName || '';
    document.getElementById('proj-modal').style.display = '';
    document.getElementById('proj-modal-name').focus();
  }

  function openEditModal(id) {
    var proj = App.projects.find(function(p) { return p.id === id; });
    if (!proj) return;
    modalEditingId = id;
    var tr = App.tProj(proj);
    document.getElementById('proj-modal-title').innerHTML = '<i class="fas fa-pen"></i> ' + App.i18n('Edit Project');
    document.getElementById('proj-modal-submit').innerHTML = '<i class="fas fa-save"></i> ' + App.i18n('Save');
    document.getElementById('proj-modal-name').value = tr.name || '';
    document.getElementById('proj-modal-short-desc').value = tr.shortDescription || '';
    document.getElementById('proj-modal-author').value = proj.createdBy || '';
    document.getElementById('proj-modal').style.display = '';
    document.getElementById('proj-modal-name').focus();
  }

  function closeCreateModal() {
    document.getElementById('proj-modal').style.display = 'none';
  }

  function submitModal() {
    var name = document.getElementById('proj-modal-name').value.trim();
    var shortDesc = document.getElementById('proj-modal-short-desc').value.trim();
    var author = document.getElementById('proj-modal-author').value.trim();
    if (!name) { App.showToast(App.i18n('Project name is required.'), 'error'); return; }

    if (modalEditingId != null) {
      // Edit existing project
      var proj = App.projects.find(function(p) { return p.id === modalEditingId; });
      if (!proj) return;
      if (!proj.translations) proj.translations = { en: {}, fr: {} };
      if (!proj.translations.en) proj.translations.en = {};
      if (!proj.translations.fr) proj.translations.fr = {};
      proj.translations[App.lang].name = name;
      proj.translations[App.lang].shortDescription = shortDesc;
      proj.createdBy = author;
      proj.modifiedDate = new Date().toISOString().split('T')[0];
      App.updateProject(proj);
      closeCreateModal();
      renderProjectCards();
      if (selectedProject && selectedProject.id === modalEditingId) {
        showProjectDetail(modalEditingId);
      }
      App.showToast(App.i18n('Project updated.'), 'success');
    } else {
      // Create new project
      var today = new Date().toISOString().split('T')[0];
      var proj = {
        id: App.nextProjectId(),
        translations: {
          en: { name: name, shortDescription: shortDesc, longDescription: '' },
          fr: { name: name, shortDescription: shortDesc, longDescription: '' }
        },
        createdBy: author,
        createdDate: today,
        modifiedDate: today,
        groups: [{
          id: 'group-default',
          name: { en: 'Default', fr: 'Par défaut' },
          rule: App.DEFAULT_GROUP_RULE,
          conceptSets: []
        }]
      };
      App.addProject(proj);
      closeCreateModal();
      renderProjectCards();
      Router.navigate('/projects', { id: proj.id });
      App.showToast(App.i18n('Project created.'), 'success');
    }
  }

  // ==================== DELETE ====================
  function openDeleteModal(id) {
    var proj = App.projects.find(function(p) { return p.id === id; });
    if (!proj) return;
    deleteTargetId = id;
    var tr = App.tProj(proj);
    document.getElementById('proj-delete-name').textContent = tr.name || '';
    document.getElementById('proj-delete-modal').style.display = '';
  }

  function closeDeleteModal() {
    document.getElementById('proj-delete-modal').style.display = 'none';
    deleteTargetId = null;
  }

  function confirmDelete() {
    if (deleteTargetId == null) return;
    // closeDeleteModal() nulls deleteTargetId — capture it first.
    var id = deleteTargetId;
    App.deleteProject(id);
    closeDeleteModal();
    if (selectedProject && selectedProject.id === id) {
      hideProjectDetail();
    }
    renderProjectCards();
    App.showToast(App.i18n('Project deleted.'), 'success');
  }

  // ==================== DETAIL VIEW ====================
  function switchProjectTab(tabName) {
    currentTab = tabName;
    document.querySelectorAll('#proj-tabs .panel-tab').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.tab === tabName);
    });
    var isVars = tabName === 'variables';

    if (editMode) {
      document.getElementById('proj-tab-context').style.display = 'none';
      document.getElementById('proj-tab-context-edit').style.display = isVars ? 'none' : '';
      document.getElementById('proj-tab-variables').style.display = 'none';
      document.getElementById('proj-tab-variables-edit').style.display = isVars ? '' : 'none';
      if (isVars) {
        App.initColResize('proj-cs-edit-left-table', { lockNow: true });
        App.initColResize('proj-cs-edit-right-table', { lockNow: true });
      }
    } else {
      document.getElementById('proj-tab-context').style.display = isVars ? 'none' : '';
      document.getElementById('proj-tab-context-edit').style.display = 'none';
      document.getElementById('proj-tab-variables').style.display = isVars ? '' : 'none';
      document.getElementById('proj-tab-variables-edit').style.display = 'none';
      if (isVars) {
        App.initColResize('proj-cs-table', { lockNow: true });
      }
    }

    document.getElementById('proj-export-csv').style.display = (isVars && !editMode) ? '' : 'none';

    // Update all button: only on variables tab in read mode, and only if there are outdated CS
    var updateAllBtn = document.getElementById('proj-update-all-btn');
    if (updateAllBtn) {
      if (!isVars || editMode || !selectedProject) {
        updateAllBtn.style.display = 'none';
      } else {
        var entries = App.getProjectConceptSetEntries(selectedProject);
        var nOutdated = entries.filter(function(e) {
          var latest = App.getLatestVersion(e.id);
          return latest && e.version && latest !== e.version;
        }).length;
        updateAllBtn.style.display = nOutdated > 0 ? '' : 'none';
        var countSpan = updateAllBtn.querySelector('.update-all-count');
        if (countSpan) countSpan.textContent = nOutdated > 0 ? ' (' + nOutdated + ')' : '';
      }
    }

    if (selectedProject) {
      var url = '#/projects?id=' + selectedProject.id;
      if (tabName !== 'context') url += '&tab=' + tabName;
      // Go through the router so the active language (?lang=fr) is preserved.
      Router.replaceState(url);
    }
  }

  function updateEditButtons() {
    document.getElementById('proj-export-json').style.display = editMode ? 'none' : '';
    document.getElementById('proj-edit-btn').style.display = editMode ? 'none' : '';
    document.getElementById('proj-edit-cancel-btn').style.display = editMode ? '' : 'none';
    document.getElementById('proj-edit-save-btn').style.display = editMode ? '' : 'none';
  }

  function showProjectDetail(id) {
    var proj = App.projects.find(function(p) { return p.id === id; });
    if (!proj) return;
    selectedProject = proj;
    editMode = false;
    updateEditButtons();

    var tr = App.tProj(proj);

    document.getElementById('proj-list-view').classList.add('hidden');
    document.getElementById('proj-detail-view').classList.add('active');

    document.getElementById('proj-detail-title').textContent = tr.name || '';
    document.getElementById('proj-detail-meta').innerHTML =
      '<span class="badge badge-count"><i class="fas fa-list"></i> ' + App.getProjectConceptSetEntries(proj).length + ' ' + App.i18n('concept sets') + '</span>' +
      '<span style="color:var(--text-muted); font-size:13px"><i class="fas fa-user"></i> ' + App.escapeHtml(proj.createdBy || '') + ' <i class="fas fa-calendar-alt" style="margin-left:8px"></i> ' + App.escapeHtml(App.formatDate(proj.createdDate) || '') + '</span>';

    // Context tab (read mode)
    renderContextReadMode();

    // Reset filters
    projCsSort = { key: 'groupName', asc: true };
    projCsFilterName = '';
    projCsCategories.clear();
    projCsSubcategories.clear();
    projCsReviewStatuses.clear();
    projCsGroups.clear();
    projCsRules.clear();
    projCsVersionStatuses.clear();
    readOrderedCSIds = null;
    document.getElementById('proj-filter-name').value = '';
    populateProjColumnFilters();
    renderProjectCSTable();

    // Reset to context tab
    switchProjectTab('context');
  }

  function renderContextReadMode() {
    if (!selectedProject) return;
    var tr = App.tProj(selectedProject);

    var sec = document.getElementById('proj-long-description-section');
    if (tr.longDescription) {
      sec.innerHTML = App.renderMarkdown(tr.longDescription);
    } else {
      sec.innerHTML = '<p style="color:var(--text-muted); font-style:italic">' + App.i18n('No description') + '</p>';
    }
  }

  // ==================== EDIT MODE ====================
  function enterEditMode() {
    if (!selectedProject) return;
    editMode = true;
    var tr = App.tProj(selectedProject);
    editLongDesc = tr.longDescription || '';
    // Deep-copy the project's groups so cancel() can discard cleanly.
    editGroups = App.getProjectGroups(selectedProject).map(function(g) {
      return {
        id: g.id,
        translations: { en: { name: App.getGroupName(g, 'en') }, fr: { name: App.getGroupName(g, 'fr') } },
        rule: g.rule || App.DEFAULT_GROUP_RULE,
        conceptSets: (g.conceptSets || []).map(function(e) { return { id: e.id, version: e.version }; })
      };
    });
    if (editGroups.length === 0) {
      editGroups.push({
        id: 'group-default',
        translations: { en: { name: 'Default' }, fr: { name: 'Par défaut' } },
        rule: App.DEFAULT_GROUP_RULE,
        conceptSets: []
      });
    }
    editActiveGroupId = editGroups[0].id;
    editSelectedCS.clear();
    projEditSort = { key: null, asc: true };
    availEditSort = { key: null, asc: true };

    // Seed the stable display order: sort once by group + category + subcategory + name,
    // then freeze. From here on, the order only mutates when CS are added (append) or
    // removed (drop) — moving a CS between groups won't shuffle the table.
    var csById = {};
    App.getCSData().forEach(function(d) { csById[d.id] = d; });
    var groupByCS = {};
    editGroups.forEach(function(g) {
      (g.conceptSets || []).forEach(function(e) { groupByCS[e.id] = g; });
    });
    editOrderedCSIds = editGroupsAllEntries()
      .map(function(e) { return e.id; })
      .sort(function(aId, bId) {
        var a = csById[aId] || { category: '', subcategory: '', name: '' };
        var b = csById[bId] || { category: '', subcategory: '', name: '' };
        var ga = groupByCS[aId], gb = groupByCS[bId];
        var gan = ga ? App.getGroupName(ga) : '';
        var gbn = gb ? App.getGroupName(gb) : '';
        return (gan + a.category + a.subcategory + a.name)
          .localeCompare(gbn + b.category + b.subcategory + b.name);
      });

    updateEditButtons();

    // Populate editor
    initLongDescAceEditor();
    longDescAceEditor.setValue(editLongDesc, -1);
    longDescAceEditor.resize();
    updateLongDescPreview();

    // Reset CS edit filters
    availFilterCategories.clear();
    availFilterSubcategories.clear();
    availFilterReviewStatuses.clear();
    availFilterName = '';
    projEditFilterCategories.clear();
    projEditFilterSubcategories.clear();
    projEditFilterReviewStatuses.clear();
    projEditFilterName = '';
    document.getElementById('proj-avail-filter-name').value = '';
    document.getElementById('proj-proj-filter-name').value = '';
    populateCSEditFilters();
    renderCSEditTables();

    // Show correct panels
    switchProjectTab(currentTab);
  }

  function exitEditMode() {
    editMode = false;
    updateEditButtons();
    switchProjectTab(currentTab);
  }

  function cancelEdit() {
    exitEditMode();
  }

  function saveEdit() {
    if (!selectedProject) return;
    if (!selectedProject.translations) selectedProject.translations = { en: {}, fr: {} };
    if (!selectedProject.translations[App.lang]) selectedProject.translations[App.lang] = {};
    selectedProject.translations[App.lang].longDescription = editLongDesc;
    // Persist every group the user defined, including empty ones (they may want to add
    // concept sets later). Only ensure at least one group exists.
    var groupsOut = editGroups.map(function(g) {
      return {
        id: g.id,
        translations: g.translations || legacyNameToTranslations(g.name),
        rule: g.rule,
        conceptSets: (g.conceptSets || []).map(function(e) { return { id: e.id, version: e.version }; })
      };
    });
    if (groupsOut.length === 0) {
      groupsOut.push({
        id: 'group-default',
        translations: { en: { name: 'Default' }, fr: { name: 'Par défaut' } },
        rule: App.DEFAULT_GROUP_RULE,
        conceptSets: []
      });
    }
    App.setProjectGroups(selectedProject, groupsOut);
    selectedProject.modifiedDate = new Date().toISOString().split('T')[0];
    App.updateProject(selectedProject);

    exitEditMode();

    // Refresh read views
    renderContextReadMode();
    var tr = App.tProj(selectedProject);
    document.getElementById('proj-detail-meta').innerHTML =
      '<span class="badge badge-count"><i class="fas fa-list"></i> ' + App.getProjectConceptSetEntries(selectedProject).length + ' ' + App.i18n('concept sets') + '</span>' +
      '<span style="color:var(--text-muted); font-size:13px"><i class="fas fa-user"></i> ' + App.escapeHtml(selectedProject.createdBy || '') + ' <i class="fas fa-calendar-alt" style="margin-left:8px"></i> ' + App.escapeHtml(App.formatDate(selectedProject.createdDate) || '') + '</span>';
    // Groups may have been added/renamed/reordered; rebuild the read-mode order.
    readOrderedCSIds = null;
    populateProjColumnFilters();
    renderProjectCSTable();
    renderProjectCards();

    App.showToast(App.i18n('Project saved.'), 'success');
  }

  // ==================== MARKDOWN EDITOR (Ace, same as CS comments) ====================
  var longDescAceEditor = null;

  function initLongDescAceEditor() {
    if (longDescAceEditor) return;
    longDescAceEditor = ace.edit('proj-edit-long-desc-ace');
    longDescAceEditor.setTheme('ace/theme/chrome');
    longDescAceEditor.session.setMode('ace/mode/markdown');
    longDescAceEditor.setFontSize(12);
    longDescAceEditor.setShowPrintMargin(false);
    longDescAceEditor.session.setUseWrapMode(true);
    longDescAceEditor.session.on('change', updateLongDescPreview);
    longDescAceEditor.commands.addCommand({
      name: 'saveProjectEdits',
      bindKey: { win: 'Ctrl-S', mac: 'Cmd-S' },
      exec: function() { saveEdit(); }
    });
  }

  function updateLongDescPreview() {
    if (!longDescAceEditor) return;
    var val = longDescAceEditor.getValue();
    editLongDesc = val;
    var preview = document.getElementById('proj-edit-long-desc-preview');
    if (val.trim()) {
      preview.innerHTML = App.renderMarkdown(val);
    } else {
      preview.innerHTML = '<span class="md-preview-empty">Preview will appear here...</span>';
    }
  }

  // ==================== CS EDIT FILTERS ====================
  function populateCSEditFilters(skipId) {
    var allCS = App.getCSData();
    var idSet = {};
    editGroupsAllEntries().forEach(function(e) { idSet[e.id] = true; });

    var availData = allCS.filter(function(d) { return !idSet[d.id]; });
    var projData = allCS.filter(function(d) { return idSet[d.id]; });

    function sortCats(arr) {
      return arr.sort(function(a, b) {
        var aO = a.toLowerCase() === 'other' || a.toLowerCase() === 'autres';
        var bO = b.toLowerCase() === 'other' || b.toLowerCase() === 'autres';
        if (aO && !bO) return 1;
        if (!aO && bO) return -1;
        return a.localeCompare(b);
      });
    }

    // Available table filters
    var availCats = sortCats([...new Set(availData.map(function(d) { return d.category; }))]);
    var availSubData = availFilterCategories.size > 0 ? availData.filter(function(d) { return availFilterCategories.has(d.category); }) : availData;
    var availSubs = [...new Set(availSubData.map(function(d) { return d.subcategory; }))].filter(Boolean).sort();
    availFilterSubcategories.forEach(function(s) { if (!availSubs.includes(s)) availFilterSubcategories.delete(s); });

    if (skipId !== 'proj-avail-filter-category') {
      App.buildMultiSelectDropdown('proj-avail-filter-category', availCats, availFilterCategories, function() {
        populateCSEditFilters('proj-avail-filter-category');
        renderCSEditTables();
      });
    } else {
      App.updateMsToggleLabel('proj-avail-filter-category', availFilterCategories);
    }
    if (skipId !== 'proj-avail-filter-subcategory') {
      App.buildMultiSelectDropdown('proj-avail-filter-subcategory', availSubs, availFilterSubcategories, function() {
        renderCSEditTables();
      });
    } else {
      App.updateMsToggleLabel('proj-avail-filter-subcategory', availFilterSubcategories);
    }

    var availStatuses = [...new Set(availData.map(function(d) { return d.reviewStatus; }))].filter(Boolean).sort();
    var availStatusLabelMap = {};
    availStatuses.forEach(function(s) { availStatusLabelMap[s] = App.statusLabelsMap[s] || s; });
    availFilterReviewStatuses.forEach(function(s) { if (!availStatuses.includes(s)) availFilterReviewStatuses.delete(s); });
    if (skipId !== 'proj-avail-filter-reviewStatus') {
      App.buildMultiSelectDropdown('proj-avail-filter-reviewStatus', availStatuses, availFilterReviewStatuses, function() {
        renderCSEditTables();
      }, availStatusLabelMap);
    } else {
      App.updateMsToggleLabel('proj-avail-filter-reviewStatus', availFilterReviewStatuses);
    }

    // Project table filters
    var projCats = sortCats([...new Set(projData.map(function(d) { return d.category; }))]);
    var projSubData = projEditFilterCategories.size > 0 ? projData.filter(function(d) { return projEditFilterCategories.has(d.category); }) : projData;
    var projSubs = [...new Set(projSubData.map(function(d) { return d.subcategory; }))].filter(Boolean).sort();
    projEditFilterSubcategories.forEach(function(s) { if (!projSubs.includes(s)) projEditFilterSubcategories.delete(s); });

    if (skipId !== 'proj-proj-filter-category') {
      App.buildMultiSelectDropdown('proj-proj-filter-category', projCats, projEditFilterCategories, function() {
        populateCSEditFilters('proj-proj-filter-category');
        renderCSEditTables();
      });
    } else {
      App.updateMsToggleLabel('proj-proj-filter-category', projEditFilterCategories);
    }
    if (skipId !== 'proj-proj-filter-subcategory') {
      App.buildMultiSelectDropdown('proj-proj-filter-subcategory', projSubs, projEditFilterSubcategories, function() {
        renderCSEditTables();
      });
    } else {
      App.updateMsToggleLabel('proj-proj-filter-subcategory', projEditFilterSubcategories);
    }

    var projStatuses = [...new Set(projData.map(function(d) { return d.reviewStatus; }))].filter(Boolean).sort();
    var projStatusLabelMap = {};
    projStatuses.forEach(function(s) { projStatusLabelMap[s] = App.statusLabelsMap[s] || s; });
    projEditFilterReviewStatuses.forEach(function(s) { if (!projStatuses.includes(s)) projEditFilterReviewStatuses.delete(s); });
    if (skipId !== 'proj-proj-filter-reviewStatus') {
      App.buildMultiSelectDropdown('proj-proj-filter-reviewStatus', projStatuses, projEditFilterReviewStatuses, function() {
        renderCSEditTables();
      }, projStatusLabelMap);
    } else {
      App.updateMsToggleLabel('proj-proj-filter-reviewStatus', projEditFilterReviewStatuses);
    }
  }

  // ==================== CS EDIT TABLES ====================
  function renderCSEditTables() {
    ensureActiveGroup();
    renderGroupsToolbar();

    var allCS = App.getCSData();
    var allEntries = editGroupsAllEntries();
    var idSet = {};
    allEntries.forEach(function(e) { idSet[e.id] = true; });
    var groupById = {};
    editGroups.forEach(function(g) {
      (g.conceptSets || []).forEach(function(e) { groupById[e.id] = g; });
    });

    // Left table: concept sets in the project (right pane in UI)
    var leftData = allCS.filter(function(d) { return idSet[d.id]; });
    if (projEditFilterCategories.size > 0) leftData = leftData.filter(function(d) { return projEditFilterCategories.has(d.category); });
    if (projEditFilterSubcategories.size > 0) leftData = leftData.filter(function(d) { return projEditFilterSubcategories.has(d.subcategory); });
    if (projEditFilterReviewStatuses.size > 0) leftData = leftData.filter(function(d) { return projEditFilterReviewStatuses.has(d.reviewStatus); });
    if (projEditFilterName) {
      var q = projEditFilterName.toLowerCase();
      leftData = leftData.filter(function(d) {
        var text = d.name.toLowerCase();
        return App.fuzzyMatch(text, q) !== -1;
      });
    }
    var pinnedById = {};
    allEntries.forEach(function(e) { pinnedById[e.id] = e.version; });
    // Decorate rows with group name + pinned version for sorting / display.
    leftData.forEach(function(d) {
      var g = groupById[d.id];
      d.groupName = g ? (App.getGroupName(g) || '') : '';
      d.version = pinnedById[d.id] || '';
    });

    if (projEditSort.key) {
      // User-driven sort overrides the stable order.
      var k = projEditSort.key, asc = projEditSort.asc ? 1 : -1;
      leftData.sort(function(a, b) {
        var va = (a[k] || '').toString().toLowerCase();
        var vb = (b[k] || '').toString().toLowerCase();
        if (va < vb) return -1 * asc;
        if (va > vb) return 1 * asc;
        return 0;
      });
    } else {
      // Default: stable order from editOrderedCSIds (preserves positions across group
      // changes). Any CS missing from the order list (defensive) sorts to the end.
      var orderPos = {};
      editOrderedCSIds.forEach(function(id, idx) { orderPos[id] = idx; });
      leftData.sort(function(a, b) {
        var pa = a.id in orderPos ? orderPos[a.id] : Number.MAX_SAFE_INTEGER;
        var pb = b.id in orderPos ? orderPos[b.id] : Number.MAX_SAFE_INTEGER;
        return pa - pb;
      });
    }

    var leftTbody = document.getElementById('proj-cs-edit-left-tbody');
    leftTbody.innerHTML = leftData.map(function(d) {
      var pinned = pinnedById[d.id] || '';
      var g = groupById[d.id];
      var groupCell = g
        ? '<span class="proj-cs-group-pill clickable" data-cs-id="' + d.id + '" data-tooltip="' + App.escapeHtml(App.getGroupName(g)) + ' · ' + App.escapeHtml(App.i18n((RULE_META[g.rule] || RULE_META.optional).i18n)) + '">' + App.escapeHtml(App.getGroupName(g)) + ' <i class="fas fa-chevron-down" style="font-size:9px; opacity:0.6"></i></span>'
        : '';
      var checked = editSelectedCS.has(d.id) ? ' checked' : '';
      var groupNameTooltip = g ? App.getGroupName(g) : '';
      return '<tr data-id="' + d.id + '">' +
        '<td><input type="checkbox" class="proj-cs-select-cb" data-id="' + d.id + '"' + checked + '></td>' +
        '<td><button class="proj-cs-remove-btn" data-id="' + d.id + '" title="Remove"><i class="fas fa-minus-circle"></i></button></td>' +
        '<td data-col="group" class="cell-truncate"' + (groupNameTooltip ? ' data-tooltip="' + App.escapeHtml(groupNameTooltip) + '"' : '') + '>' + groupCell + '</td>' +
        '<td data-col="category" class="cell-truncate" data-tooltip="' + App.escapeHtml(d.category) + '"><span class="badge badge-category">' + App.escapeHtml(d.category) + '</span></td>' +
        '<td data-col="subcategory" class="cell-truncate" data-tooltip="' + App.escapeHtml(d.subcategory) + '"><span class="badge badge-subcategory">' + App.escapeHtml(d.subcategory) + '</span></td>' +
        '<td data-col="name" class="cell-truncate" data-tooltip="' + App.escapeHtml(d.name) + '"><strong>' + App.escapeHtml(d.name) + '</strong></td>' +
        '<td data-col="review" style="white-space:nowrap">' + App.statusBadge(d.reviewStatus) + '</td>' +
        '<td data-col="version" style="white-space:nowrap; font-family:monospace; font-size:12px">' + App.escapeHtml(pinned) + '</td>' +
        '</tr>';
    }).join('');
    applyCSEditColVis('proj-cs-edit-left-table', projEditColumns);
    renderBulkActionBar();

    document.getElementById('proj-cs-edit-count').textContent = '(' + allEntries.length + ')';

    // Right table: available concept sets (not in project, left pane in UI)
    var rightData = allCS.filter(function(d) { return !idSet[d.id]; });
    if (availFilterCategories.size > 0) rightData = rightData.filter(function(d) { return availFilterCategories.has(d.category); });
    if (availFilterSubcategories.size > 0) rightData = rightData.filter(function(d) { return availFilterSubcategories.has(d.subcategory); });
    if (availFilterReviewStatuses.size > 0) rightData = rightData.filter(function(d) { return availFilterReviewStatuses.has(d.reviewStatus); });
    if (availFilterName) {
      var q = availFilterName.toLowerCase();
      rightData = rightData.filter(function(d) {
        var text = d.name.toLowerCase();
        return App.fuzzyMatch(text, q) !== -1;
      });
    }
    if (availEditSort.key) {
      var rk = availEditSort.key, rasc = availEditSort.asc ? 1 : -1;
      rightData.sort(function(a, b) {
        var va = (a[rk] || '').toString().toLowerCase();
        var vb = (b[rk] || '').toString().toLowerCase();
        if (va < vb) return -1 * rasc;
        if (va > vb) return 1 * rasc;
        return 0;
      });
    } else {
      rightData.sort(function(a, b) { return (a.category + a.subcategory + a.name).localeCompare(b.category + b.subcategory + b.name); });
    }

    var rightTbody = document.getElementById('proj-cs-edit-right-tbody');
    rightTbody.innerHTML = rightData.map(function(d) {
      return '<tr>' +
        '<td data-col="category" class="cell-truncate" data-tooltip="' + App.escapeHtml(d.category) + '"><span class="badge badge-category">' + App.escapeHtml(d.category) + '</span></td>' +
        '<td data-col="subcategory" class="cell-truncate" data-tooltip="' + App.escapeHtml(d.subcategory) + '"><span class="badge badge-subcategory">' + App.escapeHtml(d.subcategory) + '</span></td>' +
        '<td data-col="name" class="cell-truncate" data-tooltip="' + App.escapeHtml(d.name) + '"><strong>' + App.escapeHtml(d.name) + '</strong></td>' +
        '<td data-col="review" style="white-space:nowrap">' + App.statusBadge(d.reviewStatus) + '</td>' +
        '<td data-col="version" style="white-space:nowrap; font-family:monospace; font-size:12px">' + App.escapeHtml(d.version) + '</td>' +
        '<td><button class="proj-cs-add-btn" data-id="' + d.id + '" title="Add"><i class="fas fa-plus-circle"></i></button></td>' +
        '</tr>';
    }).join('');
    applyCSEditColVis('proj-cs-edit-right-table', availEditColumns);

    refreshSortIndicators('proj-cs-edit-left-table', projEditSort);
    refreshSortIndicators('proj-cs-edit-right-table', availEditSort);
  }

  function refreshSortIndicators(tableId, sortState) {
    var table = document.getElementById(tableId);
    if (!table) return;
    table.querySelectorAll('thead th[data-sort]').forEach(function(th) {
      var isActive = sortState.key && th.dataset.sort === sortState.key;
      th.classList.toggle('sorted', !!isActive);
      var icon = th.querySelector('.sort-icon');
      if (icon) icon.textContent = (isActive && !sortState.asc) ? '▼' : '▲';
    });
  }

  // Three-state cycle on a header click: asc → desc → no sort (default).
  function cycleSort(sortState, key) {
    if (sortState.key !== key) { sortState.key = key; sortState.asc = true; return; }
    if (sortState.asc) { sortState.asc = false; return; }
    sortState.key = null;
    sortState.asc = true;
  }

  function applyCSEditColVis(tableId, columns) {
    var table = document.getElementById(tableId);
    if (!table) return;
    Object.keys(columns).forEach(function(col) {
      var vis = columns[col].visible;
      table.querySelectorAll('[data-col="' + col + '"]').forEach(function(el) {
        el.style.display = vis ? '' : 'none';
      });
    });
  }

  function addCSToProject(csId) {
    if (editGroupsAllEntries().some(function(e) { return e.id === csId; })) return;
    ensureActiveGroup();
    var target = editGroups.find(function(g) { return g.id === editActiveGroupId; }) || editGroups[0];
    target.conceptSets.push({ id: csId, version: App.getLatestVersion(csId) });
    if (editOrderedCSIds.indexOf(csId) < 0) editOrderedCSIds.push(csId);
    populateCSEditFilters();
    renderCSEditTables();
  }

  function removeCSFromProject(csId) {
    editGroups.forEach(function(g) {
      g.conceptSets = (g.conceptSets || []).filter(function(e) { return e.id !== csId; });
    });
    editSelectedCS.delete(csId);
    editOrderedCSIds = editOrderedCSIds.filter(function(id) { return id !== csId; });
    populateCSEditFilters();
    renderCSEditTables();
  }

  function moveSelectedToGroup(groupId) {
    var target = editGroups.find(function(g) { return g.id === groupId; });
    if (!target) return;
    var moved = 0;
    editSelectedCS.forEach(function(csId) {
      var entry = null;
      editGroups.forEach(function(g) {
        var idx = (g.conceptSets || []).findIndex(function(e) { return e.id === csId; });
        if (idx >= 0) {
          if (g.id !== target.id) {
            entry = g.conceptSets.splice(idx, 1)[0];
          }
        }
      });
      if (entry) { target.conceptSets.push(entry); moved += 1; }
    });
    editSelectedCS.clear();
    renderCSEditTables();
    if (moved > 0) {
      App.showToast(App.i18n('Moved {n} concept set(s).').replace('{n}', moved), 'success');
    }
  }

  // ==================== GROUPS TOOLBAR ====================
  function renderGroupsToolbar() {
    var bar = document.getElementById('proj-groups-toolbar');
    if (!bar) return;
    ensureActiveGroup();
    var lang = App.lang;
    var rows = editGroups.map(function(g, idx) {
      var n = (g.conceptSets || []).length;
      var name = App.getGroupName(g, lang);
      var isActive = g.id === editActiveGroupId;
      return '<div class="proj-group-row' + (isActive ? ' active' : '') + '" data-group-id="' + App.escapeHtml(g.id) + '">' +
        '<button class="proj-group-select" data-group-id="' + App.escapeHtml(g.id) + '" title="' + App.escapeHtml(App.i18n('Make active group')) + '">' +
          '<span class="proj-group-name"><strong>' + App.escapeHtml(name || App.i18n('Unnamed')) + '</strong>' +
          ' <span class="proj-group-count">(' + n + ')</span></span>' +
        '</button>' +
        '<select class="proj-group-rule form-input" data-group-id="' + App.escapeHtml(g.id) + '" title="' + App.escapeHtml(App.i18n('Group rule')) + '">' +
          App.GROUP_RULES.map(function(r) {
            return '<option value="' + r + '"' + (g.rule === r ? ' selected' : '') + '>' + App.escapeHtml(App.i18n((RULE_META[r] || {}).i18n || r)) + '</option>';
          }).join('') +
        '</select>' +
        '<div class="proj-group-actions">' +
          '<button class="proj-group-action proj-group-rename" data-group-id="' + App.escapeHtml(g.id) + '" title="' + App.escapeHtml(App.i18n('Rename')) + '"><i class="fas fa-pen"></i></button>' +
          '<button class="proj-group-action proj-group-move" data-group-id="' + App.escapeHtml(g.id) + '" data-dir="up" title="' + App.escapeHtml(App.i18n('Move up')) + '"' + (idx === 0 ? ' disabled' : '') + '><i class="fas fa-arrow-up"></i></button>' +
          '<button class="proj-group-action proj-group-move" data-group-id="' + App.escapeHtml(g.id) + '" data-dir="down" title="' + App.escapeHtml(App.i18n('Move down')) + '"' + (idx === editGroups.length - 1 ? ' disabled' : '') + '><i class="fas fa-arrow-down"></i></button>' +
          '<button class="proj-group-action proj-group-delete" data-group-id="' + App.escapeHtml(g.id) + '" title="' + App.escapeHtml(App.i18n('Delete group')) + '"' + (editGroups.length <= 1 ? ' disabled' : '') + '><i class="fas fa-trash"></i></button>' +
        '</div>' +
      '</div>';
    }).join('');
    bar.innerHTML =
      '<div class="proj-groups-header">' +
        '<span class="proj-groups-title"><i class="fas fa-layer-group"></i> ' + App.escapeHtml(App.i18n('Groups')) + '</span>' +
        '<button class="btn-outline-sm proj-group-add"><i class="fas fa-plus"></i> ' + App.escapeHtml(App.i18n('Add group')) + '</button>' +
      '</div>' +
      '<div class="proj-group-rows">' + rows + '</div>';
  }

  function renderBulkActionBar() {
    var bar = document.getElementById('proj-cs-bulk-bar');
    if (!bar) return;
    if (editSelectedCS.size === 0) {
      bar.style.display = 'none';
      return;
    }
    bar.style.display = '';
    bar.innerHTML =
      '<span class="proj-cs-bulk-count">' + App.escapeHtml(App.i18n('{n} selected').replace('{n}', editSelectedCS.size)) + '</span>' +
      '<label for="proj-cs-bulk-target" class="proj-cs-bulk-label">' + App.escapeHtml(App.i18n('Move to')) + '</label>' +
      '<select id="proj-cs-bulk-target" class="proj-cs-bulk-select">' +
        editGroups.map(function(g) {
          return '<option value="' + App.escapeHtml(g.id) + '">' + App.escapeHtml(App.getGroupName(g) || App.i18n('Unnamed')) + '</option>';
        }).join('') +
      '</select>' +
      '<button class="btn-primary-custom" id="proj-cs-bulk-apply"><i class="fas fa-arrow-right"></i> ' + App.escapeHtml(App.i18n('Move')) + '</button>';
  }

  function addGroup() {
    var id = App.newGroupId({ groups: editGroups });
    editGroups.push({
      id: id,
      translations: { en: { name: 'New group' }, fr: { name: 'Nouveau groupe' } },
      rule: App.DEFAULT_GROUP_RULE,
      conceptSets: []
    });
    editActiveGroupId = id;
    renderCSEditTables();
  }

  var deletingGroupId = null;

  function openDeleteGroupModal(groupId) {
    if (editGroups.length <= 1) return;
    var g = editGroups.find(function(x) { return x.id === groupId; });
    if (!g) return;
    deletingGroupId = groupId;
    var n = (g.conceptSets || []).length;
    var name = App.getGroupName(g) || App.i18n('Unnamed');
    document.getElementById('proj-group-delete-name').textContent = name;
    var moveLine = document.getElementById('proj-group-delete-move-line');
    if (n > 0) {
      var target = editGroups.find(function(x) { return x.id !== groupId; });
      var targetName = target ? (App.getGroupName(target) || App.i18n('Unnamed')) : '';
      moveLine.style.display = '';
      moveLine.innerHTML = App.i18n('Its {n} concept set(s) will be moved to "{target}".')
        .replace('{n}', n).replace('{target}', App.escapeHtml(targetName));
    } else {
      moveLine.style.display = 'none';
    }
    document.getElementById('proj-group-delete-modal').style.display = '';
  }

  function closeDeleteGroupModal() {
    var m = document.getElementById('proj-group-delete-modal');
    if (m) m.style.display = 'none';
    deletingGroupId = null;
  }

  function confirmDeleteGroup() {
    if (deletingGroupId == null) return;
    var groupId = deletingGroupId;
    closeDeleteGroupModal();
    if (editGroups.length <= 1) return;
    var g = editGroups.find(function(x) { return x.id === groupId; });
    if (!g) return;
    if ((g.conceptSets || []).length > 0) {
      var target = editGroups.find(function(x) { return x.id !== groupId; });
      if (target) {
        target.conceptSets = (target.conceptSets || []).concat(g.conceptSets);
      }
    }
    editGroups = editGroups.filter(function(x) { return x.id !== groupId; });
    ensureActiveGroup();
    renderCSEditTables();
  }

  function moveGroup(groupId, dir) {
    var idx = editGroups.findIndex(function(g) { return g.id === groupId; });
    if (idx < 0) return;
    var j = dir === 'up' ? idx - 1 : idx + 1;
    if (j < 0 || j >= editGroups.length) return;
    var tmp = editGroups[idx]; editGroups[idx] = editGroups[j]; editGroups[j] = tmp;
    renderGroupsToolbar();
  }

  // Group being edited in the rename modal (null when modal is closed).
  var renamingGroupId = null;

  // ==================== CHANGE-GROUP POPUP MENU ====================
  // Lightweight dropdown anchored under the clicked group pill.
  function openChangeGroupMenu(csId, anchor) {
    if (!selectedProject || !anchor) return;
    closeChangeGroupMenu();
    var inEdit = editMode;
    var groups = inEdit ? editGroups : App.getProjectGroups(selectedProject);
    var currentGroupId = null;
    groups.forEach(function(g) {
      if ((g.conceptSets || []).some(function(e) { return e.id === csId; })) currentGroupId = g.id;
    });

    var menu = document.createElement('div');
    menu.className = 'proj-cs-group-menu';
    menu.innerHTML = groups.map(function(g) {
      var isCurrent = g.id === currentGroupId;
      var name = App.getGroupName(g) || App.i18n('Unnamed');
      var ruleLabel = App.i18n((RULE_META[g.rule] || RULE_META.optional).i18n);
      return '<button class="proj-cs-group-menu-item' + (isCurrent ? ' current' : '') + '" data-group-id="' + App.escapeHtml(g.id) + '">' +
        '<i class="fas fa-check proj-cs-group-menu-check"' + (isCurrent ? '' : ' style="visibility:hidden"') + '></i>' +
        '<span class="proj-cs-group-menu-name">' + App.escapeHtml(name) + '</span>' +
        '<span class="proj-cs-group-menu-rule">' + App.escapeHtml(ruleLabel) + '</span>' +
      '</button>';
    }).join('');
    document.body.appendChild(menu);

    // Position under the anchor, clamped to viewport.
    var rect = anchor.getBoundingClientRect();
    var menuW = menu.offsetWidth || 240;
    var left = Math.max(8, Math.min(window.innerWidth - menuW - 8, rect.left));
    var top = rect.bottom + 4;
    if (top + menu.offsetHeight > window.innerHeight - 8) {
      top = Math.max(8, rect.top - menu.offsetHeight - 4);
    }
    menu.style.left = left + 'px';
    menu.style.top = top + 'px';

    menu.addEventListener('click', function(e) {
      var item = e.target.closest('.proj-cs-group-menu-item');
      if (!item) return;
      e.stopPropagation();
      applyGroupChange(csId, item.dataset.groupId, inEdit);
      closeChangeGroupMenu();
    });

    // Close on outside click / scroll / resize.
    setTimeout(function() {
      document.addEventListener('click', closeChangeGroupMenu, { once: true });
    }, 0);
    window.addEventListener('scroll', closeChangeGroupMenu, { once: true, capture: true });
    window.addEventListener('resize', closeChangeGroupMenu, { once: true });
  }

  function closeChangeGroupMenu() {
    var menus = document.querySelectorAll('.proj-cs-group-menu');
    menus.forEach(function(m) { m.remove(); });
  }

  function applyGroupChange(csId, targetGroupId, inEdit) {
    if (!selectedProject) return;
    if (inEdit) {
      var entry = null;
      editGroups.forEach(function(g) {
        var idx = (g.conceptSets || []).findIndex(function(e) { return e.id === csId; });
        if (idx >= 0 && g.id !== targetGroupId) entry = g.conceptSets.splice(idx, 1)[0];
      });
      var target = editGroups.find(function(g) { return g.id === targetGroupId; });
      if (entry && target) target.conceptSets.push(entry);
      if (!entry) return; // already in target group
      renderCSEditTables();
      return;
    }
    // Read mode: mutate selectedProject through setProjectGroups.
    var groups = App.getProjectGroups(selectedProject).map(function(g) {
      return {
        id: g.id, translations: g.translations, rule: g.rule || App.DEFAULT_GROUP_RULE,
        conceptSets: (g.conceptSets || []).map(function(e) { return { id: e.id, version: e.version }; })
      };
    });
    var entry = null;
    groups.forEach(function(g) {
      var idx = g.conceptSets.findIndex(function(e) { return e.id === csId; });
      if (idx >= 0 && g.id !== targetGroupId) entry = g.conceptSets.splice(idx, 1)[0];
    });
    if (!entry) return; // no-op: clicked the current group
    var target = groups.find(function(g) { return g.id === targetGroupId; });
    if (target) target.conceptSets.push(entry);
    App.setProjectGroups(selectedProject, groups);
    selectedProject.modifiedDate = new Date().toISOString().split('T')[0];
    App.updateProject(selectedProject);
    populateProjColumnFilters();
    renderProjectCSTable();
    App.showToast(App.i18n('Concept set moved to group.'), 'success');
  }

  function openRenameModal(groupId) {
    var g = editGroups.find(function(x) { return x.id === groupId; });
    if (!g) return;
    renamingGroupId = groupId;
    document.getElementById('proj-group-modal-name-en').value = App.getGroupName(g, 'en');
    document.getElementById('proj-group-modal-name-fr').value = App.getGroupName(g, 'fr');
    document.getElementById('proj-group-modal').style.display = '';
    setTimeout(function() {
      var input = document.getElementById('proj-group-modal-name-' + App.lang);
      if (input) { input.focus(); input.select(); }
    }, 0);
  }

  function closeRenameModal() {
    document.getElementById('proj-group-modal').style.display = 'none';
    renamingGroupId = null;
  }

  function submitRenameModal() {
    if (renamingGroupId == null) return;
    var g = editGroups.find(function(x) { return x.id === renamingGroupId; });
    if (!g) { closeRenameModal(); return; }
    var en = document.getElementById('proj-group-modal-name-en').value.trim();
    var fr = document.getElementById('proj-group-modal-name-fr').value.trim();
    // Require at least one non-empty name; mirror it to the other locale if missing.
    if (!en && !fr) {
      App.showToast(App.i18n('Group name is required.'), 'error');
      return;
    }
    g.translations = { en: { name: en || fr }, fr: { name: fr || en } };
    closeRenameModal();
    renderCSEditTables();
  }

  function setGroupRule(groupId, rule) {
    if (App.GROUP_RULES.indexOf(rule) < 0) return;
    var g = editGroups.find(function(x) { return x.id === groupId; });
    if (!g) return;
    g.rule = rule;
    renderGroupsToolbar();
  }

  // ==================== READ-MODE CS TABLE ====================
  function getProjectCSData() {
    if (!selectedProject) return [];
    var groups = App.getProjectGroups(selectedProject);
    var pinnedById = {};
    var groupById = {};
    groups.forEach(function(g) {
      (g.conceptSets || []).forEach(function(e) {
        pinnedById[e.id] = e.version || '';
        groupById[e.id] = g;
      });
    });
    var ids = new Set(Object.keys(pinnedById).map(function(k) { return parseInt(k); }));
    return App.getCSData().filter(function(d) { return ids.has(d.id); }).map(function(d) {
      var pinned = pinnedById[d.id] || '';
      var latest = d.version || '';
      var g = groupById[d.id];
      d.pinnedVersion = pinned;
      d.latestVersion = latest;
      d.outdated = pinned && latest && pinned !== latest;
      d.versionStatus = !pinned ? 'no_version' : (d.outdated ? 'outdated' : 'up_to_date');
      d.groupName = g ? App.getGroupName(g) : '';
      d.groupRule = g ? (g.rule || '') : '';
      return d;
    });
  }

  function populateProjColumnFilters(skipId) {
    var data = getProjectCSData();

    // Group filter
    var groupNames = [...new Set(data.map(function(d) { return d.groupName; }))].filter(Boolean).sort();
    projCsGroups.forEach(function(s) { if (!groupNames.includes(s)) projCsGroups.delete(s); });
    if (skipId !== 'proj-filter-group') {
      App.buildMultiSelectDropdown('proj-filter-group', groupNames, projCsGroups, function() {
        renderProjectCSTable();
      });
    } else {
      App.updateMsToggleLabel('proj-filter-group', projCsGroups);
    }

    // Rule filter
    var rules = [...new Set(data.map(function(d) { return d.groupRule; }))].filter(Boolean).sort();
    var ruleLabelMap = {};
    rules.forEach(function(r) { ruleLabelMap[r] = App.i18n((RULE_META[r] || {}).i18n || r); });
    projCsRules.forEach(function(s) { if (!rules.includes(s)) projCsRules.delete(s); });
    if (skipId !== 'proj-filter-rule') {
      App.buildMultiSelectDropdown('proj-filter-rule', rules, projCsRules, function() {
        renderProjectCSTable();
      }, ruleLabelMap);
    } else {
      App.updateMsToggleLabel('proj-filter-rule', projCsRules);
    }

    // Version-status filter (Update column)
    var versionStatuses = [...new Set(data.map(function(d) { return d.versionStatus; }))].filter(Boolean).sort();
    var versionStatusLabels = {
      outdated: App.i18n('Outdated'),
      up_to_date: App.i18n('Up to date'),
      no_version: App.i18n('No version')
    };
    projCsVersionStatuses.forEach(function(s) { if (!versionStatuses.includes(s)) projCsVersionStatuses.delete(s); });
    if (skipId !== 'proj-filter-versionStatus') {
      App.buildMultiSelectDropdown('proj-filter-versionStatus', versionStatuses, projCsVersionStatuses, function() {
        renderProjectCSTable();
      }, versionStatusLabels);
    } else {
      App.updateMsToggleLabel('proj-filter-versionStatus', projCsVersionStatuses);
    }

    var categories = [...new Set(data.map(function(d) { return d.category; }))].sort(function(a, b) {
      var aO = a.toLowerCase() === 'other' || a.toLowerCase() === 'autres';
      var bO = b.toLowerCase() === 'other' || b.toLowerCase() === 'autres';
      if (aO && !bO) return 1;
      if (!aO && bO) return -1;
      return a.localeCompare(b);
    });

    var subData = data;
    if (projCsCategories.size > 0) subData = subData.filter(function(d) { return projCsCategories.has(d.category); });
    var subcategories = [...new Set(subData.map(function(d) { return d.subcategory; }))].filter(Boolean).sort();
    projCsSubcategories.forEach(function(s) { if (!subcategories.includes(s)) projCsSubcategories.delete(s); });

    if (skipId !== 'proj-filter-category') {
      App.buildMultiSelectDropdown('proj-filter-category', categories, projCsCategories, function() {
        populateProjColumnFilters('proj-filter-category');
        renderProjectCSTable();
      });
    } else {
      App.updateMsToggleLabel('proj-filter-category', projCsCategories);
    }

    if (skipId !== 'proj-filter-subcategory') {
      App.buildMultiSelectDropdown('proj-filter-subcategory', subcategories, projCsSubcategories, function() {
        renderProjectCSTable();
      });
    } else {
      App.updateMsToggleLabel('proj-filter-subcategory', projCsSubcategories);
    }

    var statuses = [...new Set(data.map(function(d) { return d.reviewStatus; }))].filter(Boolean).sort();
    var statusLabelMap = {};
    statuses.forEach(function(s) { statusLabelMap[s] = App.statusLabelsMap[s] || s; });
    if (skipId !== 'proj-filter-reviewStatus') {
      App.buildMultiSelectDropdown('proj-filter-reviewStatus', statuses, projCsReviewStatuses, function() {
        renderProjectCSTable();
      }, statusLabelMap);
    } else {
      App.updateMsToggleLabel('proj-filter-reviewStatus', projCsReviewStatuses);
    }
  }

  function renderProjectCSTable() {
    if (!selectedProject) return;
    var data = getProjectCSData();

    if (projCsGroups.size > 0) data = data.filter(function(d) { return projCsGroups.has(d.groupName); });
    if (projCsRules.size > 0) data = data.filter(function(d) { return projCsRules.has(d.groupRule); });
    if (projCsCategories.size > 0) data = data.filter(function(d) { return projCsCategories.has(d.category); });
    if (projCsSubcategories.size > 0) data = data.filter(function(d) { return projCsSubcategories.has(d.subcategory); });
    if (projCsReviewStatuses.size > 0) data = data.filter(function(d) { return projCsReviewStatuses.has(d.reviewStatus); });
    if (projCsVersionStatuses.size > 0) data = data.filter(function(d) { return projCsVersionStatuses.has(d.versionStatus); });
    if (projCsFilterName) {
      var q = projCsFilterName.toLowerCase();
      data = data.filter(function(d) {
        var text = d.name.toLowerCase();
        return App.fuzzyMatch(text, q) !== -1;
      });
    }

    // If we have a frozen display order, reuse it as-is (actions like "update to
    // latest" don't reshuffle the table). Otherwise apply the active sort criterion
    // and freeze the resulting order for subsequent renders.
    if (readOrderedCSIds) {
      var pos = {};
      readOrderedCSIds.forEach(function(id, idx) { pos[id] = idx; });
      data.sort(function(a, b) {
        var pa = a.id in pos ? pos[a.id] : Number.MAX_SAFE_INTEGER;
        var pb = b.id in pos ? pos[b.id] : Number.MAX_SAFE_INTEGER;
        return pa - pb;
      });
    } else {
      data.sort(function(a, b) {
        var cmp;
        if (/version/i.test(projCsSort.key)) {
          cmp = App.compareVersions(a[projCsSort.key], b[projCsSort.key]);
        } else {
          var va = (a[projCsSort.key] || '').toString().toLowerCase();
          var vb = (b[projCsSort.key] || '').toString().toLowerCase();
          cmp = va < vb ? -1 : va > vb ? 1 : 0;
        }
        if (cmp !== 0) return projCsSort.asc ? cmp : -cmp;
        return a.id - b.id;
      });
      readOrderedCSIds = data.map(function(d) { return d.id; });
    }

    var tbody = document.getElementById('proj-cs-tbody');
    tbody.innerHTML = data.map(function(d) {
      var statusCell;
      if (!d.pinnedVersion) {
        statusCell = '<span style="color:var(--text-muted); font-size:12px">' + App.i18n('No version') + '</span>';
      } else if (d.outdated) {
        statusCell = '<span class="badge proj-cs-update-badge" data-cs-id="' + d.id + '" title="' + App.escapeHtml(App.i18n('Click to view changes and update')) + '" style="background:#fef3c7; color:#92400e; cursor:pointer"><i class="fas fa-exclamation-triangle"></i> ' + App.i18n('Outdated') + '</span>';
      } else {
        statusCell = '<span class="badge" style="background:#dcfce7; color:#166534"><i class="fas fa-check"></i> ' + App.i18n('Up to date') + '</span>';
      }
      var ruleCell = d.groupRule ? ruleBadge(d.groupRule) : '';
      // Read-mode pill is informational only — switching a CS to another group is
      // a structural edit and belongs to the edit-mode UI.
      var groupCell = d.groupName
        ? '<span class="proj-cs-group-pill">' + App.escapeHtml(d.groupName) + '</span>'
        : '';
      return '<tr data-id="' + d.id + '" data-pinned="' + App.escapeHtml(d.pinnedVersion) + '" style="cursor:pointer">' +
        '<td class="cell-truncate"' + (d.groupName ? ' data-tooltip="' + App.escapeHtml(d.groupName) + '"' : '') + '>' + groupCell + '</td>' +
        '<td style="white-space:nowrap">' + ruleCell + '</td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(d.category) + '"><span class="badge badge-category">' + App.escapeHtml(d.category) + '</span></td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(d.subcategory) + '"><span class="badge badge-subcategory">' + App.escapeHtml(d.subcategory) + '</span></td>' +
        '<td class="cell-truncate" data-tooltip="' + App.escapeHtml(d.name) + '"><strong>' + App.escapeHtml(d.name) + '</strong></td>' +
        '<td class="cell-truncate"' + (d.description ? ' data-tooltip="' + App.escapeHtml(d.description) + '"' : '') + '>' + App.escapeHtml(d.description) + '</td>' +
        '<td style="white-space:nowrap">' + App.statusBadge(d.reviewStatus) + '</td>' +
        '<td style="white-space:nowrap; font-family:monospace; font-size:12px">' + App.escapeHtml(d.pinnedVersion) + '</td>' +
        '<td style="white-space:nowrap; font-family:monospace; font-size:12px' + (d.outdated ? '; font-weight:bold' : '') + '">' + App.escapeHtml(d.latestVersion) + '</td>' +
        '<td class="td-center" style="white-space:nowrap">' + statusCell + '</td>' +
        '</tr>';
    }).join('');

    // Update toolbar buttons
    var updateAllBtn = document.getElementById('proj-update-all-btn');
    if (updateAllBtn) {
      var nOutdated = data.filter(function(d) { return d.outdated; }).length;
      updateAllBtn.style.display = nOutdated > 0 ? '' : 'none';
      updateAllBtn.querySelector('.update-all-count').textContent = nOutdated > 0 ? ' (' + nOutdated + ')' : '';
    }

    // Sort indicators
    document.querySelectorAll('#proj-cs-table thead th').forEach(function(th) {
      th.classList.toggle('sorted', th.dataset.sort === projCsSort.key);
      var icon = th.querySelector('.sort-icon');
      if (icon) icon.textContent = (th.dataset.sort === projCsSort.key && !projCsSort.asc) ? '\u25BC' : '\u25B2';
    });
  }

  // ==================== UPDATE PINNED VERSIONS ====================
  function bumpInGroups(groups, csId, version) {
    // Mutates groups in place: bumps every entry with matching id (should be a single one).
    var changed = false;
    groups.forEach(function(g) {
      (g.conceptSets || []).forEach(function(e) {
        if (e.id === csId && e.version !== version) { e.version = version; changed = true; }
      });
    });
    return changed;
  }

  function updatePinnedVersion(csId) {
    if (!selectedProject) return;
    var latest = App.getLatestVersion(csId);
    if (!latest) return;
    // Materialize the groups (handles legacy fallback) and write back through setProjectGroups
    // so the project is canonicalized to the new schema even if it was legacy on entry.
    var groups = App.getProjectGroups(selectedProject).map(function(g) {
      return {
        id: g.id, translations: g.translations, rule: g.rule || App.DEFAULT_GROUP_RULE,
        conceptSets: (g.conceptSets || []).map(function(e) { return { id: e.id, version: e.version }; })
      };
    });
    if (!bumpInGroups(groups, csId, latest)) return;
    App.setProjectGroups(selectedProject, groups);
    selectedProject.modifiedDate = new Date().toISOString().split('T')[0];
    App.updateProject(selectedProject);
    populateProjColumnFilters();
    renderProjectCSTable();
    App.showToast(App.i18n('Concept set updated to latest version.'), 'success');
  }

  function updateAllOutdated() {
    if (!selectedProject) return;
    var data = getProjectCSData();
    var outdatedIds = data.filter(function(d) { return d.outdated; }).map(function(d) { return d.id; });
    if (outdatedIds.length === 0) return;
    var groups = App.getProjectGroups(selectedProject).map(function(g) {
      return {
        id: g.id, translations: g.translations, rule: g.rule || App.DEFAULT_GROUP_RULE,
        conceptSets: (g.conceptSets || []).map(function(e) { return { id: e.id, version: e.version }; })
      };
    });
    outdatedIds.forEach(function(id) {
      var latest = App.getLatestVersion(id);
      if (latest) bumpInGroups(groups, id, latest);
    });
    App.setProjectGroups(selectedProject, groups);
    selectedProject.modifiedDate = new Date().toISOString().split('T')[0];
    App.updateProject(selectedProject);
    populateProjColumnFilters();
    renderProjectCSTable();
    App.showToast(App.i18n('Updated {n} concept set(s) to latest version.').replace('{n}', outdatedIds.length), 'success');
  }

  // ==================== UPDATE-CS MODAL ====================
  var updatingCSId = null;

  // Compute the added / removed concept ids between the pinned and the latest version
  // of a concept set, by diffing their resolved-concept lists. Returns null when
  // either list is unknown (missing snapshot or unfetched deferred set) — unknown
  // must not be rendered as "everything added/removed".
  function diffResolved(csId, pinnedVersion) {
    var oldList = App.getResolvedConceptSet(csId, pinnedVersion);
    var newList = App.getResolvedConceptSet(csId);
    if (!oldList || !newList) return null;
    var oldById = {};
    oldList.forEach(function(c) { oldById[c.conceptId] = c; });
    var newById = {};
    newList.forEach(function(c) { newById[c.conceptId] = c; });
    var added = newList.filter(function(c) { return !oldById[c.conceptId]; });
    var removed = oldList.filter(function(c) { return !newById[c.conceptId]; });
    return { added: added, removed: removed, oldCount: oldList.length, newCount: newList.length };
  }

  function conceptLine(c, sign) {
    return App.conceptListLine(c, sign === '+'
      ? { sign: '+', color: '#166534', bg: '#dcfce7' }
      : { sign: '-', color: '#991b1b', bg: '#fee2e2' });
  }

  function openUpdateCSModal(csId) {
    if (!selectedProject) return;
    var cs = App.getConceptSet(csId);
    if (!cs) return;
    // Find pinned version from current project state.
    var pinned = '';
    App.getProjectGroups(selectedProject).forEach(function(g) {
      (g.conceptSets || []).forEach(function(e) { if (e.id === csId) pinned = e.version || ''; });
    });
    var latest = App.getLatestVersion(csId);
    if (!pinned || !latest || pinned === latest) return; // not really outdated

    // Large resolved sets are deferred by build.py — fetch before diffing.
    if (App.resolvedDeferred && App.resolvedDeferred[csId] && !App.resolvedIndex[csId]) {
      App.fetchResolved(csId).then(function() { openUpdateCSModal(csId); });
      return;
    }
    updatingCSId = csId;

    var tr = App.t(cs);
    var csName = tr.name || cs.name || ('#' + csId);
    document.getElementById('proj-cs-update-modal-name').textContent = csName;
    document.getElementById('proj-cs-update-modal-from').textContent = 'v' + pinned;
    document.getElementById('proj-cs-update-modal-to').textContent = 'v' + latest;

    var diff = diffResolved(csId, pinned);
    var summary = document.getElementById('proj-cs-update-modal-summary');
    if (!diff) {
      summary.innerHTML = '';
      document.getElementById('proj-cs-update-modal-diff').innerHTML =
        '<p style="color:var(--text-muted); font-style:italic; margin:8px 0">' +
        App.escapeHtml(App.i18n('Resolved concept data is not available for these versions, so the change list cannot be shown.')) +
        '</p>';
      document.getElementById('proj-cs-update-modal').style.display = '';
      return;
    }
    summary.innerHTML =
      '<span>' + App.escapeHtml(App.i18n('Resolved concepts')) + ': <strong>' + diff.oldCount + '</strong> → <strong>' + diff.newCount + '</strong></span>' +
      ' &middot; ' +
      '<span style="color:#166534"><strong>+' + diff.added.length + '</strong> ' + App.i18n('added') + '</span>' +
      ' &middot; ' +
      '<span style="color:#991b1b"><strong>−' + diff.removed.length + '</strong> ' + App.i18n('removed') + '</span>';

    var body = document.getElementById('proj-cs-update-modal-diff');
    if (diff.added.length === 0 && diff.removed.length === 0) {
      body.innerHTML = '<p style="color:var(--text-muted); font-style:italic; margin:8px 0">' +
        App.i18n('No change in the resolved concept list between these two versions. Only metadata was updated.') +
        '</p>';
    } else {
      body.innerHTML =
        (diff.added.length > 0 ? '<h4 style="margin:12px 0 6px; font-size:13px; color:#166534">' + App.i18n('Added') + ' (' + diff.added.length + ')</h4>' +
          '<ul style="list-style:none; margin:0; padding:0; max-height:200px; overflow-y:auto; border:1px solid var(--border); border-radius:4px; padding:4px 8px">' +
          diff.added.map(function(c) { return conceptLine(c, '+'); }).join('') +
          '</ul>' : '') +
        (diff.removed.length > 0 ? '<h4 style="margin:12px 0 6px; font-size:13px; color:#991b1b">' + App.i18n('Removed') + ' (' + diff.removed.length + ')</h4>' +
          '<ul style="list-style:none; margin:0; padding:0; max-height:200px; overflow-y:auto; border:1px solid var(--border); border-radius:4px; padding:4px 8px">' +
          diff.removed.map(function(c) { return conceptLine(c, '-'); }).join('') +
          '</ul>' : '');
    }

    document.getElementById('proj-cs-update-modal').style.display = '';
  }

  function closeUpdateCSModal() {
    var m = document.getElementById('proj-cs-update-modal');
    if (m) m.style.display = 'none';
    updatingCSId = null;
  }

  function confirmUpdateCS() {
    if (updatingCSId == null) return;
    var csId = updatingCSId;
    closeUpdateCSModal();
    updatePinnedVersion(csId);
  }

  function hideProjectDetail() {
    if (editMode) exitEditMode();
    document.getElementById('proj-detail-view').classList.remove('active');
    document.getElementById('proj-list-view').classList.remove('hidden');
    selectedProject = null;
  }

  // ==================== EVENTS ====================
  function initEvents() {
    // Project card click (ignore if clicking menu)
    document.getElementById('proj-cards').addEventListener('click', function(e) {
      // Handle menu button click
      var menuBtn = e.target.closest('.project-card-menu-btn');
      if (menuBtn) {
        e.stopPropagation();
        var id = parseInt(menuBtn.dataset.menuId);
        var menu = document.getElementById('proj-card-menu-' + id);
        if (menu) {
          var wasVisible = menu.classList.contains('visible');
          closeAllMenus();
          if (!wasVisible) {
            menu.classList.add('visible');
            openMenuId = id;
          }
        }
        return;
      }

      // Handle menu item click
      var menuItem = e.target.closest('.project-card-menu-item');
      if (menuItem) {
        e.stopPropagation();
        var action = menuItem.dataset.action;
        var id = parseInt(menuItem.dataset.id);
        closeAllMenus();
        if (action === 'edit') openEditModal(id);
        else if (action === 'delete') openDeleteModal(id);
        return;
      }

      // Handle card click (navigate to detail)
      var card = e.target.closest('.project-card[data-id]');
      if (!card) return;
      Router.navigate('/projects', { id: parseInt(card.dataset.id) });
    });

    // Close menus on outside click
    document.addEventListener('click', function() { closeAllMenus(); });

    // Project back button — always return to the projects list, regardless of
    // how the detail view was reached. history.back() is unreliable: if the
    // user got here via another page, the previous history entry is that other
    // page, not the list. (Same fix as the concept-set detail back button.)
    document.getElementById('proj-back').addEventListener('click', function() {
      Router.navigate('/projects');
    });

    // Project search
    document.getElementById('proj-search').addEventListener('input', renderProjectCards);

    // Project tabs
    document.getElementById('proj-tabs').addEventListener('click', function(e) {
      var tab = e.target.closest('.panel-tab');
      if (!tab) return;
      switchProjectTab(tab.dataset.tab);
    });

    // Project concept set click -> navigate to concept sets page via router
    document.getElementById('proj-cs-tbody').addEventListener('click', function(e) {
      // Group pill: open change-group dropdown, don't navigate
      var groupPill = e.target.closest('.proj-cs-group-pill.clickable');
      if (groupPill) {
        e.stopPropagation();
        openChangeGroupMenu(parseInt(groupPill.dataset.csId), groupPill);
        return;
      }
      // Outdated badge: open the per-CS update modal with diff + confirm
      var updateBadge = e.target.closest('.proj-cs-update-badge');
      if (updateBadge) {
        e.stopPropagation();
        openUpdateCSModal(parseInt(updateBadge.dataset.csId));
        return;
      }
      var tr = e.target.closest('tr[data-id]');
      if (!tr) return;
      var query = { id: tr.dataset.id };
      var pinned = tr.dataset.pinned;
      if (pinned) query.version = pinned;
      if (selectedProject) {
        query.from = 'project';
        query.projectId = selectedProject.id;
      }
      Router.navigate('/concept-sets', query);
    });

    // Update all outdated concept sets
    var updateAllBtn = document.getElementById('proj-update-all-btn');
    if (updateAllBtn) {
      updateAllBtn.addEventListener('click', updateAllOutdated);
    }

    // Project CS sort
    document.getElementById('proj-cs-table').querySelector('thead').addEventListener('click', function(e) {
      var th = e.target.closest('th[data-sort]');
      if (!th) return;
      var key = th.dataset.sort;
      if (projCsSort.key === key) projCsSort.asc = !projCsSort.asc;
      else { projCsSort.key = key; projCsSort.asc = true; }
      // Header click is the only path that re-sorts the table; drop the frozen
      // order so renderProjectCSTable() rebuilds it from projCsSort.
      readOrderedCSIds = null;
      renderProjectCSTable();
    });

    // Project CS name filter
    document.getElementById('proj-filter-name').addEventListener('input', function(e) {
      projCsFilterName = e.target.value;
      renderProjectCSTable();
    });

    // Quote every cell, escape embedded quotes, and neutralize spreadsheet
    // formula injection (=, +, -, @ prefixes) — pure numbers are left intact.
    function csvField(v) {
      var s = v == null ? '' : String(v);
      if (/^[=+\-@]/.test(s) && !/^-?\d+(\.\d+)?$/.test(s)) s = "'" + s;
      return '"' + s.replace(/"/g, '""') + '"';
    }

    // CSV export for project concepts
    document.getElementById('proj-export-csv').addEventListener('click', function() {
      if (!selectedProject) return;
      var groups = App.getProjectGroups(selectedProject);
      var rows = [];
      rows.push(['group_name', 'group_rule',
        'concept_set_id', 'concept_set_name', 'concept_set_category', 'concept_set_subcategory',
        'concept_id', 'concept_name', 'domain_id', 'vocabulary_id', 'concept_class_id', 'concept_code',
        'standard_concept', 'invalid_reason', 'valid_start_date', 'valid_end_date',
        'is_excluded', 'include_descendants', 'include_mapped'].join(','));

      groups.forEach(function(g) {
        var groupName = App.getGroupName(g) || '';
        var groupRule = g.rule || '';
        (g.conceptSets || []).forEach(function(e) {
          var cs = App.getConceptSet(e.id, e.version);
          if (!cs) return;
          var tr = App.t(cs);
          var items = (cs.expression && cs.expression.items) || [];
          items.forEach(function(item) {
            var c = item.concept;
            rows.push([
              csvField(groupName),
              csvField(groupRule),
              cs.id,
              csvField(tr.name || cs.name || ''),
              csvField(tr.category || ''),
              csvField(tr.subcategory || ''),
              c.conceptId,
              csvField(c.conceptName || ''),
              csvField(c.domainId || ''),
              csvField(c.vocabularyId || ''),
              csvField(c.conceptClassId || ''),
              csvField(c.conceptCode || ''),
              csvField(c.standardConcept || ''),
              csvField(c.invalidReason || ''),
              csvField(c.validStartDate || ''),
              csvField(c.validEndDate || ''),
              item.isExcluded ? 'TRUE' : 'FALSE',
              item.includeDescendants ? 'TRUE' : 'FALSE',
              item.includeMapped ? 'TRUE' : 'FALSE'
            ].join(','));
          });
        });
      });

      // BOM so Excel detects UTF-8 (accented French names) on double-click open.
      var csv = '\uFEFF' + rows.join('\n');
      var blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      var projTr = App.tProj(selectedProject);
      a.download = (projTr.name || 'project').replace(/[^a-zA-Z0-9]/g, '_') + '_concepts.csv';
      a.click();
      URL.revokeObjectURL(url);
    });

    // Project JSON export
    document.getElementById('proj-export-json').addEventListener('click', function() {
      if (!selectedProject) return;
      var json = JSON.stringify(selectedProject, null, 2);
      App.openExportModal({
        title: App.i18n('Export Project'),
        content: json,
        filename: selectedProject.id + '.json',
        type: 'application/json',
        clipboardDesc: App.i18n('Copy JSON to clipboard'),
        fileDesc: App.i18n('Download as {file}').replace('{file}', selectedProject.id + '.json'),
        githubUrl: App.githubEdit('projects/' + selectedProject.id + '.json')
      });
    });

    // ==================== EDIT MODE EVENTS ====================
    document.getElementById('proj-edit-btn').addEventListener('click', enterEditMode);
    document.getElementById('proj-edit-cancel-btn').addEventListener('click', cancelEdit);
    document.getElementById('proj-edit-save-btn').addEventListener('click', saveEdit);


    // CS edit name filters
    document.getElementById('proj-avail-filter-name').addEventListener('input', function(e) {
      availFilterName = e.target.value;
      renderCSEditTables();
    });
    document.getElementById('proj-proj-filter-name').addEventListener('input', function(e) {
      projEditFilterName = e.target.value;
      renderCSEditTables();
    });

    // CS edit add/remove buttons + checkbox selection (delegated)
    document.getElementById('proj-cs-edit-left-tbody').addEventListener('click', function(e) {
      var groupPill = e.target.closest('.proj-cs-group-pill.clickable');
      if (groupPill) { e.stopPropagation(); openChangeGroupMenu(parseInt(groupPill.dataset.csId), groupPill); return; }
      var btn = e.target.closest('.proj-cs-remove-btn');
      if (btn) { removeCSFromProject(parseInt(btn.dataset.id)); return; }
    });
    document.getElementById('proj-cs-edit-left-tbody').addEventListener('change', function(e) {
      var cb = e.target.closest('.proj-cs-select-cb');
      if (!cb) return;
      var id = parseInt(cb.dataset.id);
      if (cb.checked) editSelectedCS.add(id);
      else editSelectedCS.delete(id);
      renderBulkActionBar();
    });
    document.getElementById('proj-cs-edit-right-tbody').addEventListener('click', function(e) {
      var btn = e.target.closest('.proj-cs-add-btn');
      if (!btn) return;
      addCSToProject(parseInt(btn.dataset.id));
    });

    // Sortable headers on both edit tables.
    document.getElementById('proj-cs-edit-left-table').querySelector('thead').addEventListener('click', function(e) {
      var th = e.target.closest('th[data-sort]');
      if (!th) return;
      cycleSort(projEditSort, th.dataset.sort);
      renderCSEditTables();
    });
    document.getElementById('proj-cs-edit-right-table').querySelector('thead').addEventListener('click', function(e) {
      var th = e.target.closest('th[data-sort]');
      if (!th) return;
      cycleSort(availEditSort, th.dataset.sort);
      renderCSEditTables();
    });

    // Select all checkbox header
    var selectAllCb = document.getElementById('proj-cs-select-all');
    if (selectAllCb) {
      selectAllCb.addEventListener('change', function(e) {
        var rows = document.querySelectorAll('#proj-cs-edit-left-tbody .proj-cs-select-cb');
        rows.forEach(function(cb) {
          var id = parseInt(cb.dataset.id);
          cb.checked = e.target.checked;
          if (e.target.checked) editSelectedCS.add(id);
          else editSelectedCS.delete(id);
        });
        renderBulkActionBar();
      });
    }

    // Groups toolbar (delegated)
    document.getElementById('proj-groups-toolbar').addEventListener('click', function(e) {
      var addBtn = e.target.closest('.proj-group-add');
      if (addBtn) { addGroup(); return; }
      var selectBtn = e.target.closest('.proj-group-select');
      if (selectBtn) { editActiveGroupId = selectBtn.dataset.groupId; renderGroupsToolbar(); return; }
      var renameBtn = e.target.closest('.proj-group-rename');
      if (renameBtn) { openRenameModal(renameBtn.dataset.groupId); return; }
      var moveBtn = e.target.closest('.proj-group-move');
      if (moveBtn) { moveGroup(moveBtn.dataset.groupId, moveBtn.dataset.dir); return; }
      var deleteBtn = e.target.closest('.proj-group-delete');
      if (deleteBtn) { openDeleteGroupModal(deleteBtn.dataset.groupId); return; }
    });
    document.getElementById('proj-groups-toolbar').addEventListener('change', function(e) {
      var sel = e.target.closest('.proj-group-rule');
      if (sel) setGroupRule(sel.dataset.groupId, sel.value);
    });

    // Bulk action bar (delegated)
    document.getElementById('proj-cs-bulk-bar').addEventListener('click', function(e) {
      if (e.target.closest('#proj-cs-bulk-apply')) {
        var target = document.getElementById('proj-cs-bulk-target');
        if (target) moveSelectedToGroup(target.value);
        return;
      }
    });

    // CS edit column visibility dropdowns — auto-generated from the column configs.
    function buildCSEditColDropdown(ddId, columns) {
      var dd = document.getElementById(ddId);
      dd.innerHTML = Object.keys(columns).map(function(col) {
        var c = columns[col];
        return '<label><input type="checkbox" data-col="' + col + '"' +
          (c.visible ? ' checked' : '') + '> ' + App.escapeHtml(App.i18n(c.label)) + '</label>';
      }).join('');
    }
    function wireColVis(btnId, ddId, columns, tableId) {
      buildCSEditColDropdown(ddId, columns);
      document.getElementById(btnId).addEventListener('click', function(e) {
        e.stopPropagation();
        var dd = document.getElementById(ddId);
        dd.style.display = dd.style.display === 'none' ? '' : 'none';
      });
      document.getElementById(ddId).addEventListener('change', function(e) {
        var cb = e.target;
        if (!cb.dataset.col || !columns[cb.dataset.col]) return;
        columns[cb.dataset.col].visible = cb.checked;
        applyCSEditColVis(tableId, columns);
      });
    }
    wireColVis('proj-avail-col-vis-btn', 'proj-avail-col-vis-dropdown', availEditColumns, 'proj-cs-edit-right-table');
    wireColVis('proj-proj-col-vis-btn', 'proj-proj-col-vis-dropdown', projEditColumns, 'proj-cs-edit-left-table');
    document.addEventListener('click', function(e) {
      var availDd = document.getElementById('proj-avail-col-vis-dropdown');
      var projDd = document.getElementById('proj-proj-col-vis-dropdown');
      if (availDd && availDd.style.display !== 'none' && !document.getElementById('proj-avail-col-vis-wrapper').contains(e.target)) {
        availDd.style.display = 'none';
      }
      if (projDd && projDd.style.display !== 'none' && !document.getElementById('proj-proj-col-vis-wrapper').contains(e.target)) {
        projDd.style.display = 'none';
      }
    });

    // ==================== CREATE/EDIT MODAL EVENTS ====================
    document.getElementById('proj-create-btn').addEventListener('click', openCreateModal);
    document.getElementById('proj-modal-close').addEventListener('click', closeCreateModal);
    document.getElementById('proj-modal-cancel').addEventListener('click', closeCreateModal);
    document.getElementById('proj-modal-submit').addEventListener('click', submitModal);
    document.getElementById('proj-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('proj-modal')) closeCreateModal();
    });
    // Enter key in modal name field
    document.getElementById('proj-modal-name').addEventListener('keydown', function(e) {
      if (e.key === 'Enter') { e.preventDefault(); submitModal(); }
    });

    // ==================== DELETE MODAL EVENTS ====================
    document.getElementById('proj-delete-close').addEventListener('click', closeDeleteModal);
    document.getElementById('proj-delete-cancel').addEventListener('click', closeDeleteModal);
    document.getElementById('proj-delete-confirm').addEventListener('click', confirmDelete);
    document.getElementById('proj-delete-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('proj-delete-modal')) closeDeleteModal();
    });

    // ==================== GROUP RENAME MODAL EVENTS ====================
    document.getElementById('proj-group-modal-close').addEventListener('click', closeRenameModal);
    document.getElementById('proj-group-modal-cancel').addEventListener('click', closeRenameModal);
    document.getElementById('proj-group-modal-submit').addEventListener('click', submitRenameModal);
    document.getElementById('proj-group-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('proj-group-modal')) closeRenameModal();
    });
    ['proj-group-modal-name-en', 'proj-group-modal-name-fr'].forEach(function(id) {
      document.getElementById(id).addEventListener('keydown', function(e) {
        if (e.key === 'Enter') { e.preventDefault(); submitRenameModal(); }
        else if (e.key === 'Escape') { e.preventDefault(); closeRenameModal(); }
      });
    });

    // ==================== GROUP DELETE MODAL EVENTS ====================
    document.getElementById('proj-group-delete-close').addEventListener('click', closeDeleteGroupModal);
    document.getElementById('proj-group-delete-cancel').addEventListener('click', closeDeleteGroupModal);
    document.getElementById('proj-group-delete-confirm').addEventListener('click', confirmDeleteGroup);
    document.getElementById('proj-group-delete-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('proj-group-delete-modal')) closeDeleteGroupModal();
    });

    // ==================== UPDATE-CS MODAL EVENTS ====================
    document.getElementById('proj-cs-update-modal-close').addEventListener('click', closeUpdateCSModal);
    document.getElementById('proj-cs-update-modal-cancel').addEventListener('click', closeUpdateCSModal);
    document.getElementById('proj-cs-update-modal-confirm').addEventListener('click', confirmUpdateCS);
    document.getElementById('proj-cs-update-modal').addEventListener('click', function(e) {
      if (e.target === document.getElementById('proj-cs-update-modal')) closeUpdateCSModal();
    });

  }

  // ==================== PAGE MODULE ====================
  function init() {
    if (initialized) return;
    initialized = true;
    initEvents();
    renderProjectCards();
  }

  function show(query) {
    init();
    var projId = query && query.id;
    if (projId) {
      showProjectDetail(parseInt(projId));
      var tab = query && query.tab;
      if (tab && ['context', 'variables'].indexOf(tab) !== -1) {
        switchProjectTab(tab);
      }
    } else if (selectedProject) {
      // Back to list view (e.g. browser back button)
      if (editMode) exitEditMode();
      document.getElementById('proj-detail-view').classList.remove('active');
      document.getElementById('proj-list-view').classList.remove('hidden');
      selectedProject = null;
    }
  }

  function hide() {
    closeCreateModal();
    closeDeleteModal();
    closeRenameModal();
    closeChangeGroupMenu();
    closeDeleteGroupModal();
    closeUpdateCSModal();
    closeAllMenus();
  }

  function onLanguageChange() {
    if (!initialized) return;
    renderProjectCards();
    if (selectedProject) {
      // showProjectDetail resets to the context tab; preserve the active one.
      var savedTab = currentTab;
      showProjectDetail(selectedProject.id);
      if (savedTab && savedTab !== 'context') switchProjectTab(savedTab);
    }
  }

  return {
    show: show,
    hide: hide,
    onLanguageChange: onLanguageChange
  };
})();
