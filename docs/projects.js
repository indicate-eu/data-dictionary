// projects.js — Projects page module
var ProjectsPage = (function() {
  'use strict';

  var initialized = false;
  var selectedProject = null;

  // ==================== PROJECT CS TABLE STATE ====================
  var projCsSort = { key: 'category', asc: true };
  var projCsFilterName = '';
  var projCsCategories = new Set();
  var projCsSubcategories = new Set();
  var projCsReviewStatuses = new Set();

  // ==================== EDIT MODE STATE ====================
  var editMode = false;
  var editLongDesc = '';
  var editConceptSets = []; // working copy of [{id, version}] entries
  var currentTab = 'context';

  // CS edit table filter state (available = right panel, project = left panel)
  var availFilterCategories = new Set();
  var availFilterSubcategories = new Set();
  var availFilterName = '';
  var availFilterReviewStatuses = new Set();
  var projEditFilterCategories = new Set();
  var projEditFilterSubcategories = new Set();
  var projEditFilterName = '';
  var projEditFilterReviewStatuses = new Set();

  // CS edit table column visibility (review and version hidden by default)
  var availColVis = { review: false, version: false };
  var projColVis = { review: false, version: false };

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
      var desc = (tr.short_description || '').toLowerCase();
      function fuzzy(text) {
        var ti = 0;
        for (var qi = 0; qi < filter.length; qi++) {
          var ch = filter[qi];
          while (ti < text.length && text[ti] !== ch) ti++;
          if (ti >= text.length) return false;
          ti++;
        }
        return true;
      }
      return fuzzy(name) || fuzzy(desc);
    });

    var el = document.getElementById('proj-cards');
    el.innerHTML = filtered.map(function(p) {
      var tr = App.tProj(p);
      var csCount = App.getProjectConceptSetEntries(p).length;
      return '<div class="project-card" data-id="' + p.id + '">' +
        '<button class="project-card-menu-btn" data-menu-id="' + p.id + '" title="Actions"><i class="fas fa-ellipsis-v"></i></button>' +
        '<div class="project-card-menu" id="proj-card-menu-' + p.id + '">' +
          '<button class="project-card-menu-item" data-action="edit" data-id="' + p.id + '"><i class="fas fa-pen"></i> ' + App.i18n('Edit') + '</button>' +
          '<button class="project-card-menu-item danger" data-action="delete" data-id="' + p.id + '"><i class="fas fa-trash"></i> ' + App.i18n('Delete') + '</button>' +
        '</div>' +
        '<h3>' + App.escapeHtml(tr.name || '') + '</h3>' +
        '<p title="' + App.escapeHtml(tr.short_description || '') + '">' + App.escapeHtml(tr.short_description || App.i18n('No description')) + '</p>' +
        '<div class="project-card-footer">' +
          '<span><i class="fas fa-list"></i> ' + csCount + ' ' + App.i18n('concept sets') + '</span>' +
          '<span><i class="fas fa-user"></i> ' + App.escapeHtml(p.createdBy || '') + '</span>' +
          '<span><i class="fas fa-calendar-alt"></i> ' + App.escapeHtml(App.formatDate(p.createdDate) || '') + '</span>' +
        '</div>' +
        '</div>';
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
    document.getElementById('proj-modal-short-desc').value = tr.short_description || '';
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
      proj.translations[App.lang].short_description = shortDesc;
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
          en: { name: name, short_description: shortDesc, long_description: '' },
          fr: { name: name, short_description: shortDesc, long_description: '' }
        },
        createdBy: author,
        createdDate: today,
        modifiedDate: today,
        conceptSets: []
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
    var name = '';
    var proj = App.projects.find(function(p) { return p.id === deleteTargetId; });
    if (proj) { var tr = App.tProj(proj); name = tr.name || ''; }
    App.deleteProject(deleteTargetId);
    closeDeleteModal();
    if (selectedProject && selectedProject.id === deleteTargetId) {
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
    } else {
      document.getElementById('proj-tab-context').style.display = isVars ? 'none' : '';
      document.getElementById('proj-tab-context-edit').style.display = 'none';
      document.getElementById('proj-tab-variables').style.display = isVars ? '' : 'none';
      document.getElementById('proj-tab-variables-edit').style.display = 'none';
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
      history.replaceState(null, '', url);
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
    projCsSort = { key: 'category', asc: true };
    projCsFilterName = '';
    projCsCategories.clear();
    projCsSubcategories.clear();
    projCsReviewStatuses.clear();
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
    if (tr.long_description) {
      sec.innerHTML = App.renderMarkdown(tr.long_description);
    } else {
      sec.innerHTML = '<p style="color:var(--text-muted); font-style:italic">' + App.i18n('No description') + '</p>';
    }
  }

  // ==================== EDIT MODE ====================
  function enterEditMode() {
    if (!selectedProject) return;
    editMode = true;
    var tr = App.tProj(selectedProject);
    editLongDesc = tr.long_description || '';
    editConceptSets = App.getProjectConceptSetEntries(selectedProject).map(function(e) {
      return { id: e.id, version: e.version };
    });

    updateEditButtons();

    // Populate editor
    document.getElementById('proj-edit-long-desc').value = editLongDesc;
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
    selectedProject.translations[App.lang].long_description = editLongDesc;
    selectedProject.conceptSets = editConceptSets.map(function(e) {
      return { id: e.id, version: e.version };
    });
    delete selectedProject.conceptSetIds;
    selectedProject.modifiedDate = new Date().toISOString().split('T')[0];
    App.updateProject(selectedProject);

    exitEditMode();

    // Refresh read views
    renderContextReadMode();
    var tr = App.tProj(selectedProject);
    document.getElementById('proj-detail-meta').innerHTML =
      '<span class="badge badge-count"><i class="fas fa-list"></i> ' + App.getProjectConceptSetEntries(selectedProject).length + ' ' + App.i18n('concept sets') + '</span>' +
      '<span style="color:var(--text-muted); font-size:13px"><i class="fas fa-user"></i> ' + App.escapeHtml(selectedProject.createdBy || '') + ' <i class="fas fa-calendar-alt" style="margin-left:8px"></i> ' + App.escapeHtml(App.formatDate(selectedProject.createdDate) || '') + '</span>';
    populateProjColumnFilters();
    renderProjectCSTable();
    renderProjectCards();

    App.showToast(App.i18n('Project saved.'), 'success');
  }

  // ==================== MARKDOWN PREVIEW ====================
  function updateLongDescPreview() {
    var val = document.getElementById('proj-edit-long-desc').value;
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
    editConceptSets.forEach(function(e) { idSet[e.id] = true; });

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
    var allCS = App.getCSData();
    var idSet = {};
    editConceptSets.forEach(function(e) { idSet[e.id] = true; });

    // Left table: concept sets in the project (right pane in UI)
    var leftData = allCS.filter(function(d) { return idSet[d.id]; });
    if (projEditFilterCategories.size > 0) leftData = leftData.filter(function(d) { return projEditFilterCategories.has(d.category); });
    if (projEditFilterSubcategories.size > 0) leftData = leftData.filter(function(d) { return projEditFilterSubcategories.has(d.subcategory); });
    if (projEditFilterReviewStatuses.size > 0) leftData = leftData.filter(function(d) { return projEditFilterReviewStatuses.has(d.reviewStatus); });
    if (projEditFilterName) {
      var q = projEditFilterName.toLowerCase();
      leftData = leftData.filter(function(d) {
        var text = d.name.toLowerCase();
        var ti = 0;
        for (var qi = 0; qi < q.length; qi++) {
          var ch = q[qi];
          while (ti < text.length && text[ti] !== ch) ti++;
          if (ti >= text.length) return false;
          ti++;
        }
        return true;
      });
    }
    leftData.sort(function(a, b) { return (a.category + a.subcategory + a.name).localeCompare(b.category + b.subcategory + b.name); });

    var leftTbody = document.getElementById('proj-cs-edit-left-tbody');
    var pinnedById = {};
    editConceptSets.forEach(function(e) { pinnedById[e.id] = e.version; });
    leftTbody.innerHTML = leftData.map(function(d) {
      var pinned = pinnedById[d.id] || '';
      return '<tr>' +
        '<td><button class="proj-cs-remove-btn" data-id="' + d.id + '" title="Remove"><i class="fas fa-minus-circle"></i></button></td>' +
        '<td><span class="badge badge-category">' + App.escapeHtml(d.category) + '</span></td>' +
        '<td><span class="badge badge-subcategory">' + App.escapeHtml(d.subcategory) + '</span></td>' +
        '<td data-tooltip="' + App.escapeHtml(d.name) + '">' + App.escapeHtml(d.name) + '</td>' +
        '<td class="proj-proj-col-review" style="white-space:nowrap">' + App.statusBadge(d.reviewStatus) + '</td>' +
        '<td class="proj-proj-col-version" style="white-space:nowrap; font-family:monospace; font-size:12px">' + App.escapeHtml(pinned) + '</td>' +
        '</tr>';
    }).join('');
    applyCSEditColVis('proj-proj', projColVis);

    document.getElementById('proj-cs-edit-count').textContent = '(' + editConceptSets.length + ')';

    // Right table: available concept sets (not in project, left pane in UI)
    var rightData = allCS.filter(function(d) { return !idSet[d.id]; });
    if (availFilterCategories.size > 0) rightData = rightData.filter(function(d) { return availFilterCategories.has(d.category); });
    if (availFilterSubcategories.size > 0) rightData = rightData.filter(function(d) { return availFilterSubcategories.has(d.subcategory); });
    if (availFilterReviewStatuses.size > 0) rightData = rightData.filter(function(d) { return availFilterReviewStatuses.has(d.reviewStatus); });
    if (availFilterName) {
      var q = availFilterName.toLowerCase();
      rightData = rightData.filter(function(d) {
        var text = d.name.toLowerCase();
        var ti = 0;
        for (var qi = 0; qi < q.length; qi++) {
          var ch = q[qi];
          while (ti < text.length && text[ti] !== ch) ti++;
          if (ti >= text.length) return false;
          ti++;
        }
        return true;
      });
    }
    rightData.sort(function(a, b) { return (a.category + a.subcategory + a.name).localeCompare(b.category + b.subcategory + b.name); });

    var rightTbody = document.getElementById('proj-cs-edit-right-tbody');
    rightTbody.innerHTML = rightData.map(function(d) {
      return '<tr>' +
        '<td><span class="badge badge-category">' + App.escapeHtml(d.category) + '</span></td>' +
        '<td><span class="badge badge-subcategory">' + App.escapeHtml(d.subcategory) + '</span></td>' +
        '<td data-tooltip="' + App.escapeHtml(d.name) + '">' + App.escapeHtml(d.name) + '</td>' +
        '<td class="proj-avail-col-review" style="white-space:nowrap">' + App.statusBadge(d.reviewStatus) + '</td>' +
        '<td class="proj-avail-col-version" style="white-space:nowrap; font-family:monospace; font-size:12px">' + App.escapeHtml(d.version) + '</td>' +
        '<td><button class="proj-cs-add-btn" data-id="' + d.id + '" title="Add"><i class="fas fa-plus-circle"></i></button></td>' +
        '</tr>';
    }).join('');
    applyCSEditColVis('proj-avail', availColVis);
  }

  function applyCSEditColVis(prefix, state) {
    ['review', 'version'].forEach(function(col) {
      var vis = state[col];
      var els = document.querySelectorAll('.' + prefix + '-col-' + col);
      els.forEach(function(el) { el.style.display = vis ? '' : 'none'; });
    });
  }

  function addCSToProject(csId) {
    if (editConceptSets.some(function(e) { return e.id === csId; })) return;
    editConceptSets.push({ id: csId, version: App.getLatestVersion(csId) });
    populateCSEditFilters();
    renderCSEditTables();
  }

  function removeCSFromProject(csId) {
    editConceptSets = editConceptSets.filter(function(e) { return e.id !== csId; });
    populateCSEditFilters();
    renderCSEditTables();
  }

  // ==================== READ-MODE CS TABLE ====================
  function getProjectCSData() {
    if (!selectedProject) return [];
    var entries = App.getProjectConceptSetEntries(selectedProject);
    var pinnedById = {};
    entries.forEach(function(e) { pinnedById[e.id] = e.version || ''; });
    var ids = new Set(Object.keys(pinnedById).map(function(k) { return parseInt(k); }));
    return App.getCSData().filter(function(d) { return ids.has(d.id); }).map(function(d) {
      var pinned = pinnedById[d.id] || '';
      var latest = d.version || '';
      d.pinnedVersion = pinned;
      d.latestVersion = latest;
      d.outdated = pinned && latest && pinned !== latest;
      return d;
    });
  }

  function hasOutdatedConceptSets() {
    if (!selectedProject) return false;
    return getProjectCSData().some(function(d) { return d.outdated; });
  }

  function populateProjColumnFilters(skipId) {
    var data = getProjectCSData();
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

    if (projCsCategories.size > 0) data = data.filter(function(d) { return projCsCategories.has(d.category); });
    if (projCsSubcategories.size > 0) data = data.filter(function(d) { return projCsSubcategories.has(d.subcategory); });
    if (projCsReviewStatuses.size > 0) data = data.filter(function(d) { return projCsReviewStatuses.has(d.reviewStatus); });
    if (projCsFilterName) {
      var q = projCsFilterName.toLowerCase();
      data = data.filter(function(d) {
        var text = d.name.toLowerCase();
        var ti = 0;
        for (var qi = 0; qi < q.length; qi++) {
          var ch = q[qi];
          while (ti < text.length && text[ti] !== ch) ti++;
          if (ti >= text.length) return false;
          ti++;
        }
        return true;
      });
    }

    data.sort(function(a, b) {
      var va = (a[projCsSort.key] || '').toString().toLowerCase();
      var vb = (b[projCsSort.key] || '').toString().toLowerCase();
      if (va < vb) return projCsSort.asc ? -1 : 1;
      if (va > vb) return projCsSort.asc ? 1 : -1;
      return 0;
    });

    var tbody = document.getElementById('proj-cs-tbody');
    tbody.innerHTML = data.map(function(d) {
      var statusCell, actionCell;
      if (!d.pinnedVersion) {
        statusCell = '<span style="color:var(--text-muted); font-size:12px">' + App.i18n('No version') + '</span>';
        actionCell = '';
      } else if (d.outdated) {
        statusCell = '<span class="badge" style="background:#fef3c7; color:#92400e"><i class="fas fa-exclamation-triangle"></i> ' + App.i18n('Outdated') + '</span>';
        actionCell = '<button class="proj-cs-update-btn" data-id="' + d.id + '" title="' + App.escapeHtml(App.i18n('Update to latest')) + '"><i class="fas fa-arrow-up"></i> ' + App.i18n('Update') + '</button>';
      } else {
        statusCell = '<span class="badge" style="background:#dcfce7; color:#166534"><i class="fas fa-check"></i> ' + App.i18n('Up to date') + '</span>';
        actionCell = '';
      }
      return '<tr data-id="' + d.id + '" data-pinned="' + App.escapeHtml(d.pinnedVersion) + '" style="cursor:pointer">' +
        '<td><span class="badge badge-category">' + App.escapeHtml(d.category) + '</span></td>' +
        '<td><span class="badge badge-subcategory">' + App.escapeHtml(d.subcategory) + '</span></td>' +
        '<td data-tooltip="' + App.escapeHtml(d.name) + '"><strong>' + App.escapeHtml(d.name) + '</strong></td>' +
        '<td class="desc-truncated"' + (d.description ? ' data-tooltip="' + App.escapeHtml(d.description) + '"' : '') + '>' + App.escapeHtml(d.description) + '</td>' +
        '<td style="white-space:nowrap">' + App.statusBadge(d.reviewStatus) + '</td>' +
        '<td style="white-space:nowrap; font-family:monospace; font-size:12px">' + App.escapeHtml(d.pinnedVersion) + '</td>' +
        '<td style="white-space:nowrap; font-family:monospace; font-size:12px' + (d.outdated ? '; font-weight:bold' : '') + '">' + App.escapeHtml(d.latestVersion) + '</td>' +
        '<td style="white-space:nowrap">' + statusCell + '</td>' +
        '<td style="white-space:nowrap">' + actionCell + '</td>' +
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
  function updatePinnedVersion(csId) {
    if (!selectedProject) return;
    var entries = App.getProjectConceptSetEntries(selectedProject).map(function(e) {
      return { id: e.id, version: e.version };
    });
    var latest = App.getLatestVersion(csId);
    if (!latest) return;
    var changed = false;
    entries.forEach(function(e) {
      if (e.id === csId && e.version !== latest) { e.version = latest; changed = true; }
    });
    if (!changed) return;
    selectedProject.conceptSets = entries;
    delete selectedProject.conceptSetIds;
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
    var entries = App.getProjectConceptSetEntries(selectedProject).map(function(e) {
      return { id: e.id, version: e.version };
    });
    entries.forEach(function(e) {
      if (outdatedIds.indexOf(e.id) >= 0) {
        var latest = App.getLatestVersion(e.id);
        if (latest) e.version = latest;
      }
    });
    selectedProject.conceptSets = entries;
    delete selectedProject.conceptSetIds;
    selectedProject.modifiedDate = new Date().toISOString().split('T')[0];
    App.updateProject(selectedProject);
    populateProjColumnFilters();
    renderProjectCSTable();
    App.showToast(App.i18n('Updated {n} concept set(s) to latest version.').replace('{n}', outdatedIds.length), 'success');
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

    // Project back button
    document.getElementById('proj-back').addEventListener('click', function() {
      history.back();
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
      // Update button: bump pinned version to latest, in-place
      var updateBtn = e.target.closest('.proj-cs-update-btn');
      if (updateBtn) {
        e.stopPropagation();
        updatePinnedVersion(parseInt(updateBtn.dataset.id));
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
      renderProjectCSTable();
    });

    // Project CS name filter
    document.getElementById('proj-filter-name').addEventListener('input', function(e) {
      projCsFilterName = e.target.value;
      renderProjectCSTable();
    });

    // CSV export for project concepts
    document.getElementById('proj-export-csv').addEventListener('click', function() {
      if (!selectedProject) return;
      var entries = App.getProjectConceptSetEntries(selectedProject);
      var rows = [];
      rows.push(['concept_set_id', 'concept_set_name', 'concept_set_category', 'concept_set_subcategory',
        'concept_id', 'concept_name', 'domain_id', 'vocabulary_id', 'concept_class_id', 'concept_code',
        'standard_concept', 'invalid_reason', 'valid_start_date', 'valid_end_date',
        'is_excluded', 'include_descendants', 'include_mapped'].join(','));

      entries.map(function(e) {
        return App.getConceptSet(e.id, e.version);
      }).filter(function(cs) { return cs; }).forEach(function(cs) {
        var tr = App.t(cs);
        var csName = (tr.name || cs.name || '').replace(/"/g, '""');
        var csCat = (tr.category || '').replace(/"/g, '""');
        var csSub = (tr.subcategory || '').replace(/"/g, '""');
        var items = (cs.expression && cs.expression.items) || [];
        items.forEach(function(item) {
          var c = item.concept;
          rows.push([
            cs.id,
            '"' + csName + '"',
            '"' + csCat + '"',
            '"' + csSub + '"',
            c.conceptId,
            '"' + (c.conceptName || '').replace(/"/g, '""') + '"',
            '"' + (c.domainId || '') + '"',
            '"' + (c.vocabularyId || '') + '"',
            '"' + (c.conceptClassId || '') + '"',
            '"' + (c.conceptCode || '') + '"',
            '"' + (c.standardConcept || '') + '"',
            '"' + (c.invalidReasonCaption || '') + '"',
            '"' + (c.validStartDate || '') + '"',
            '"' + (c.validEndDate || '') + '"',
            item.isExcluded ? 'TRUE' : 'FALSE',
            item.includeDescendants ? 'TRUE' : 'FALSE',
            item.includeMapped ? 'TRUE' : 'FALSE'
          ].join(','));
        });
      });

      var csv = rows.join('\n');
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
        fileDesc: App.i18n('Download as ' + selectedProject.id + '.json'),
        githubUrl: App.githubEdit('projects/' + selectedProject.id + '.json')
      });
    });

    // ==================== EDIT MODE EVENTS ====================
    document.getElementById('proj-edit-btn').addEventListener('click', enterEditMode);
    document.getElementById('proj-edit-cancel-btn').addEventListener('click', cancelEdit);
    document.getElementById('proj-edit-save-btn').addEventListener('click', saveEdit);

    // Markdown editors — live preview
    document.getElementById('proj-edit-long-desc').addEventListener('input', updateLongDescPreview);
    document.getElementById('proj-edit-long-desc').addEventListener('keydown', function(e) {
      if ((e.metaKey || e.ctrlKey) && e.key === 's') {
        e.preventDefault();
        saveEdit();
      }
    });

    // CS edit name filters
    document.getElementById('proj-avail-filter-name').addEventListener('input', function(e) {
      availFilterName = e.target.value;
      renderCSEditTables();
    });
    document.getElementById('proj-proj-filter-name').addEventListener('input', function(e) {
      projEditFilterName = e.target.value;
      renderCSEditTables();
    });

    // CS edit add/remove buttons (delegated)
    document.getElementById('proj-cs-edit-left-tbody').addEventListener('click', function(e) {
      var btn = e.target.closest('.proj-cs-remove-btn');
      if (!btn) return;
      removeCSFromProject(parseInt(btn.dataset.id));
    });
    document.getElementById('proj-cs-edit-right-tbody').addEventListener('click', function(e) {
      var btn = e.target.closest('.proj-cs-add-btn');
      if (!btn) return;
      addCSToProject(parseInt(btn.dataset.id));
    });

    // CS edit column visibility dropdowns
    function buildCSEditColDropdown(ddId, state) {
      var dd = document.getElementById(ddId);
      dd.innerHTML =
        '<label><input type="checkbox" data-col="review"' + (state.review ? ' checked' : '') + '> ' + App.escapeHtml(App.i18n('Review')) + '</label>' +
        '<label><input type="checkbox" data-col="version"' + (state.version ? ' checked' : '') + '> ' + App.escapeHtml(App.i18n('Version')) + '</label>';
    }
    function wireColVis(btnId, ddId, state, classPrefix) {
      buildCSEditColDropdown(ddId, state);
      document.getElementById(btnId).addEventListener('click', function(e) {
        e.stopPropagation();
        var dd = document.getElementById(ddId);
        dd.style.display = dd.style.display === 'none' ? '' : 'none';
      });
      document.getElementById(ddId).addEventListener('change', function(e) {
        var cb = e.target;
        if (!cb.dataset.col) return;
        state[cb.dataset.col] = cb.checked;
        applyCSEditColVis(classPrefix, state);
      });
    }
    wireColVis('proj-avail-col-vis-btn', 'proj-avail-col-vis-dropdown', availColVis, 'proj-avail');
    wireColVis('proj-proj-col-vis-btn', 'proj-proj-col-vis-dropdown', projColVis, 'proj-proj');
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
    closeAllMenus();
  }

  function onLanguageChange() {
    if (!initialized) return;
    renderProjectCards();
    if (selectedProject) showProjectDetail(selectedProject.id);
  }

  return {
    show: show,
    hide: hide,
    onLanguageChange: onLanguageChange
  };
})();
