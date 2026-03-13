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
  var projCsFilterReviewStatus = new Set();

  // ==================== EDIT MODE STATE ====================
  var editMode = false;
  var editDescription = '';
  var editJustification = '';
  var editConceptSetIds = []; // working copy of concept set IDs
  var currentTab = 'context';

  // CS edit table filter state (available = right panel, project = left panel)
  var availFilterCategories = new Set();
  var availFilterSubcategories = new Set();
  var availFilterName = '';
  var projEditFilterCategories = new Set();
  var projEditFilterSubcategories = new Set();
  var projEditFilterName = '';

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
      var name = (p.name || '').toLowerCase();
      var desc = (p.description || '').toLowerCase();
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
      var csCount = (p.conceptSetIds || []).length;
      return '<div class="project-card" data-id="' + p.id + '">' +
        '<button class="project-card-menu-btn" data-menu-id="' + p.id + '" title="Actions"><i class="fas fa-ellipsis-v"></i></button>' +
        '<div class="project-card-menu" id="proj-card-menu-' + p.id + '">' +
          '<button class="project-card-menu-item" data-action="edit" data-id="' + p.id + '"><i class="fas fa-pen"></i> Edit</button>' +
          '<button class="project-card-menu-item danger" data-action="delete" data-id="' + p.id + '"><i class="fas fa-trash"></i> Delete</button>' +
        '</div>' +
        '<h3>' + App.escapeHtml(p.name) + '</h3>' +
        '<p>' + App.escapeHtml(p.description || 'No description') + '</p>' +
        '<div class="project-card-footer">' +
          '<span><i class="fas fa-list"></i> ' + csCount + ' concept sets</span>' +
          '<span><i class="fas fa-user"></i> ' + App.escapeHtml(p.createdBy || '') + '</span>' +
          '<span><i class="fas fa-calendar-alt"></i> ' + App.escapeHtml(p.createdDate || '') + '</span>' +
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
    document.getElementById('proj-modal-title').innerHTML = '<i class="fas fa-plus"></i> New Project';
    document.getElementById('proj-modal-submit').innerHTML = '<i class="fas fa-plus"></i> Create';
    document.getElementById('proj-modal-name').value = '';
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
    document.getElementById('proj-modal-title').innerHTML = '<i class="fas fa-pen"></i> Edit Project';
    document.getElementById('proj-modal-submit').innerHTML = '<i class="fas fa-save"></i> Save';
    document.getElementById('proj-modal-name').value = proj.name || '';
    document.getElementById('proj-modal-author').value = proj.createdBy || '';
    document.getElementById('proj-modal').style.display = '';
    document.getElementById('proj-modal-name').focus();
  }

  function closeCreateModal() {
    document.getElementById('proj-modal').style.display = 'none';
  }

  function submitModal() {
    var name = document.getElementById('proj-modal-name').value.trim();
    var author = document.getElementById('proj-modal-author').value.trim();
    if (!name) { App.showToast('Project name is required.', 'error'); return; }

    if (modalEditingId != null) {
      // Edit existing project
      var proj = App.projects.find(function(p) { return p.id === modalEditingId; });
      if (!proj) return;
      proj.name = name;
      proj.createdBy = author;
      proj.modifiedDate = new Date().toISOString().split('T')[0];
      App.updateProject(proj);
      closeCreateModal();
      renderProjectCards();
      if (selectedProject && selectedProject.id === modalEditingId) {
        showProjectDetail(modalEditingId);
      }
      App.showToast('Project "' + name + '" updated.', 'success');
    } else {
      // Create new project
      var today = new Date().toISOString().split('T')[0];
      var proj = {
        id: App.nextProjectId(),
        name: name,
        description: '',
        justification: '',
        bibliography: null,
        createdBy: author,
        createdDate: today,
        modifiedDate: today,
        conceptSetIds: []
      };
      App.addProject(proj);
      closeCreateModal();
      renderProjectCards();
      showProjectDetail(proj.id);
      App.showToast('Project "' + name + '" created.', 'success');
    }
  }

  // ==================== DELETE ====================
  function openDeleteModal(id) {
    var proj = App.projects.find(function(p) { return p.id === id; });
    if (!proj) return;
    deleteTargetId = id;
    document.getElementById('proj-delete-name').textContent = proj.name;
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
    if (proj) name = proj.name;
    App.deleteProject(deleteTargetId);
    closeDeleteModal();
    if (selectedProject && selectedProject.id === deleteTargetId) {
      hideProjectDetail();
    }
    renderProjectCards();
    App.showToast('Project "' + name + '" deleted.', 'success');
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

    if (selectedProject) {
      var url = '#/projects?id=' + selectedProject.id;
      if (tabName !== 'context') url += '&tab=' + tabName;
      history.replaceState(null, '', url);
    }
  }

  function updateEditButtons() {
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

    document.getElementById('proj-list-view').classList.add('hidden');
    document.getElementById('proj-detail-view').classList.add('active');

    document.getElementById('proj-detail-title').textContent = proj.name;
    document.getElementById('proj-detail-meta').innerHTML =
      '<span class="badge badge-count"><i class="fas fa-list"></i> ' + (proj.conceptSetIds || []).length + ' concept sets</span>' +
      '<span style="color:var(--text-muted); font-size:13px"><i class="fas fa-user"></i> ' + App.escapeHtml(proj.createdBy || '') + ' <i class="fas fa-calendar-alt" style="margin-left:8px"></i> ' + App.escapeHtml(proj.createdDate || '') + '</span>';

    // Context tab (read mode)
    renderContextReadMode();

    // Reset filters
    projCsSort = { key: 'category', asc: true };
    projCsFilterName = '';
    projCsCategories.clear();
    projCsSubcategories.clear();
    projCsFilterReviewStatus.clear();
    document.getElementById('proj-filter-name').value = '';
    populateProjColumnFilters();
    renderProjectCSTable();

    // Reset to context tab
    switchProjectTab('context');
  }

  function renderContextReadMode() {
    if (!selectedProject) return;
    var proj = selectedProject;

    var descSec = document.getElementById('proj-description-section');
    descSec.innerHTML = '<h4>Description</h4>' + (proj.description ? App.renderMarkdown(proj.description) : '<p style="color:var(--text-muted); font-style:italic">No description</p>');

    var justSec = document.getElementById('proj-justification-section');
    if (proj.justification) {
      justSec.innerHTML = '<h4>Justification</h4>' + App.renderMarkdown(proj.justification);
      justSec.style.display = '';
    } else {
      justSec.innerHTML = '<h4>Justification</h4><p style="color:var(--text-muted); font-style:italic">No justification</p>';
      justSec.style.display = '';
    }

    var bibSec = document.getElementById('proj-bibliography-section');
    if (proj.bibliography) {
      bibSec.innerHTML = '<h4>Bibliography</h4><p>' + App.escapeHtml(
        Array.isArray(proj.bibliography) ? proj.bibliography.join('\n') : proj.bibliography
      ) + '</p>';
      bibSec.style.display = '';
    } else {
      bibSec.style.display = 'none';
    }
  }

  // ==================== EDIT MODE ====================
  function enterEditMode() {
    if (!selectedProject) return;
    editMode = true;
    editDescription = selectedProject.description || '';
    editJustification = selectedProject.justification || '';
    editConceptSetIds = (selectedProject.conceptSetIds || []).slice();

    updateEditButtons();

    // Populate editors
    document.getElementById('proj-edit-description').value = editDescription;
    document.getElementById('proj-edit-justification').value = editJustification;
    updateDescriptionPreview();
    updateJustificationPreview();

    // Reset CS edit filters
    availFilterCategories.clear();
    availFilterSubcategories.clear();
    availFilterName = '';
    projEditFilterCategories.clear();
    projEditFilterSubcategories.clear();
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
    selectedProject.description = editDescription;
    selectedProject.justification = editJustification;
    selectedProject.conceptSetIds = editConceptSetIds.slice();
    selectedProject.modifiedDate = new Date().toISOString().split('T')[0];
    App.updateProject(selectedProject);

    exitEditMode();

    // Refresh read views
    renderContextReadMode();
    document.getElementById('proj-detail-meta').innerHTML =
      '<span class="badge badge-count"><i class="fas fa-list"></i> ' + (selectedProject.conceptSetIds || []).length + ' concept sets</span>' +
      '<span style="color:var(--text-muted); font-size:13px"><i class="fas fa-user"></i> ' + App.escapeHtml(selectedProject.createdBy || '') + ' <i class="fas fa-calendar-alt" style="margin-left:8px"></i> ' + App.escapeHtml(selectedProject.createdDate || '') + '</span>';
    populateProjColumnFilters();
    renderProjectCSTable();
    renderProjectCards();

    App.showToast('Project saved.', 'success');
  }

  // ==================== MARKDOWN PREVIEW ====================
  function updateDescriptionPreview() {
    var val = document.getElementById('proj-edit-description').value;
    editDescription = val;
    var preview = document.getElementById('proj-edit-description-preview');
    if (val.trim()) {
      preview.innerHTML = App.renderMarkdown(val);
    } else {
      preview.innerHTML = '<span class="md-preview-empty">Preview will appear here...</span>';
    }
  }

  function updateJustificationPreview() {
    var val = document.getElementById('proj-edit-justification').value;
    editJustification = val;
    var preview = document.getElementById('proj-edit-justification-preview');
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
    editConceptSetIds.forEach(function(id) { idSet[id] = true; });

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
  }

  // ==================== CS EDIT TABLES ====================
  function renderCSEditTables() {
    var allCS = App.getCSData();
    var idSet = {};
    editConceptSetIds.forEach(function(id) { idSet[id] = true; });

    // Left table: concept sets in the project (right pane in UI)
    var leftData = allCS.filter(function(d) { return idSet[d.id]; });
    if (projEditFilterCategories.size > 0) leftData = leftData.filter(function(d) { return projEditFilterCategories.has(d.category); });
    if (projEditFilterSubcategories.size > 0) leftData = leftData.filter(function(d) { return projEditFilterSubcategories.has(d.subcategory); });
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
    leftTbody.innerHTML = leftData.map(function(d) {
      return '<tr>' +
        '<td><button class="proj-cs-remove-btn" data-id="' + d.id + '" title="Remove"><i class="fas fa-minus-circle"></i></button></td>' +
        '<td><span class="badge badge-category">' + App.escapeHtml(d.category) + '</span></td>' +
        '<td><span class="badge badge-subcategory">' + App.escapeHtml(d.subcategory) + '</span></td>' +
        '<td>' + App.escapeHtml(d.name) + '</td>' +
        '</tr>';
    }).join('');

    document.getElementById('proj-cs-edit-count').textContent = '(' + editConceptSetIds.length + ')';

    // Right table: available concept sets (not in project, left pane in UI)
    var rightData = allCS.filter(function(d) { return !idSet[d.id]; });
    if (availFilterCategories.size > 0) rightData = rightData.filter(function(d) { return availFilterCategories.has(d.category); });
    if (availFilterSubcategories.size > 0) rightData = rightData.filter(function(d) { return availFilterSubcategories.has(d.subcategory); });
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
        '<td>' + App.escapeHtml(d.name) + '</td>' +
        '<td><button class="proj-cs-add-btn" data-id="' + d.id + '" title="Add"><i class="fas fa-plus-circle"></i></button></td>' +
        '</tr>';
    }).join('');
  }

  function addCSToProject(csId) {
    if (editConceptSetIds.indexOf(csId) >= 0) return;
    editConceptSetIds.push(csId);
    populateCSEditFilters();
    renderCSEditTables();
  }

  function removeCSFromProject(csId) {
    editConceptSetIds = editConceptSetIds.filter(function(id) { return id !== csId; });
    populateCSEditFilters();
    renderCSEditTables();
  }

  // ==================== READ-MODE CS TABLE ====================
  function getProjectCSData() {
    if (!selectedProject) return [];
    var ids = new Set(selectedProject.conceptSetIds || []);
    return App.getCSData().filter(function(d) { return ids.has(d.id); });
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

    var statuses = [...new Set(data.map(function(d) { return d.reviewStatus; }))].filter(Boolean).sort();

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

    var statusLabelMap = {};
    statuses.forEach(function(s) { statusLabelMap[s] = App.statusLabelsMap[s] || s; });
    if (skipId !== 'proj-filter-reviewStatus') {
      App.buildMultiSelectDropdown('proj-filter-reviewStatus', statuses, projCsFilterReviewStatus, function() {
        renderProjectCSTable();
      }, statusLabelMap);
    } else {
      App.updateMsToggleLabel('proj-filter-reviewStatus', projCsFilterReviewStatus);
    }
  }

  function renderProjectCSTable() {
    if (!selectedProject) return;
    var data = getProjectCSData();

    if (projCsCategories.size > 0) data = data.filter(function(d) { return projCsCategories.has(d.category); });
    if (projCsSubcategories.size > 0) data = data.filter(function(d) { return projCsSubcategories.has(d.subcategory); });
    if (projCsFilterReviewStatus.size > 0) data = data.filter(function(d) { return projCsFilterReviewStatus.has(d.reviewStatus); });
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
      return '<tr data-id="' + d.id + '" style="cursor:pointer">' +
        '<td><span class="badge badge-category">' + App.escapeHtml(d.category) + '</span></td>' +
        '<td><span class="badge badge-subcategory">' + App.escapeHtml(d.subcategory) + '</span></td>' +
        '<td><strong>' + App.escapeHtml(d.name) + '</strong></td>' +
        '<td class="desc-truncated">' + App.escapeHtml(d.description) + '</td>' +
        '<td class="td-center">' + App.statusBadge(d.reviewStatus) + '</td>' +
        '<td class="td-center">' + App.escapeHtml(d.version) + '</td>' +
        '</tr>';
    }).join('');

    // Sort indicators
    document.querySelectorAll('#proj-cs-table thead th').forEach(function(th) {
      th.classList.toggle('sorted', th.dataset.sort === projCsSort.key);
      var icon = th.querySelector('.sort-icon');
      if (icon) icon.textContent = (th.dataset.sort === projCsSort.key && !projCsSort.asc) ? '\u25BC' : '\u25B2';
    });
  }

  function hideProjectDetail() {
    if (editMode) exitEditMode();
    document.getElementById('proj-detail-view').classList.remove('active');
    document.getElementById('proj-list-view').classList.remove('hidden');
    selectedProject = null;
    history.replaceState(null, '', '#/projects');
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
      showProjectDetail(parseInt(card.dataset.id));
    });

    // Close menus on outside click
    document.addEventListener('click', function() { closeAllMenus(); });

    // Project back button
    document.getElementById('proj-back').addEventListener('click', hideProjectDetail);

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
      var tr = e.target.closest('tr[data-id]');
      if (!tr) return;
      Router.navigate('/concept-sets', { id: tr.dataset.id });
    });

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
      var ids = new Set(selectedProject.conceptSetIds || []);
      var rows = [];
      rows.push(['concept_set_id', 'concept_set_name', 'concept_set_category', 'concept_set_subcategory',
        'concept_id', 'concept_name', 'domain_id', 'vocabulary_id', 'concept_class_id', 'concept_code',
        'standard_concept', 'invalid_reason', 'valid_start_date', 'valid_end_date',
        'is_excluded', 'include_descendants', 'include_mapped'].join(','));

      App.conceptSets.filter(function(cs) { return ids.has(cs.id); }).forEach(function(cs) {
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
      a.download = (selectedProject.name || 'project').replace(/[^a-zA-Z0-9]/g, '_') + '_concepts.csv';
      a.click();
      URL.revokeObjectURL(url);
    });

    // ==================== EDIT MODE EVENTS ====================
    document.getElementById('proj-edit-btn').addEventListener('click', enterEditMode);
    document.getElementById('proj-edit-cancel-btn').addEventListener('click', cancelEdit);
    document.getElementById('proj-edit-save-btn').addEventListener('click', saveEdit);

    // Markdown editors — live preview
    document.getElementById('proj-edit-description').addEventListener('input', updateDescriptionPreview);
    document.getElementById('proj-edit-justification').addEventListener('input', updateJustificationPreview);

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
