// projects.js — Projects page logic
(function() {
  'use strict';

  var selectedProject = null;

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

  // ==================== PROJECT DETAIL ====================
  function showProjectDetail(id) {
    var proj = App.projects.find(function(p) { return p.id === id; });
    if (!proj) return;
    selectedProject = proj;

    document.getElementById('proj-list-view').classList.add('hidden');
    document.getElementById('proj-detail-view').classList.add('active');

    document.getElementById('proj-detail-title').textContent = proj.name;
    document.getElementById('proj-detail-meta').innerHTML =
      '<span class="badge badge-count"><i class="fas fa-list"></i> ' + (proj.conceptSetIds || []).length + ' concept sets</span>' +
      '<span style="color:var(--text-muted); font-size:13px"><i class="fas fa-user"></i> ' + App.escapeHtml(proj.createdBy || '') + ' <i class="fas fa-calendar-alt" style="margin-left:8px"></i> ' + App.escapeHtml(proj.createdDate || '') + '</span>';

    // Context tab
    var descSec = document.getElementById('proj-description-section');
    descSec.innerHTML = '<h4>Description</h4><p>' + App.escapeHtml(proj.description || 'No description') + '</p>';

    var justSec = document.getElementById('proj-justification-section');
    if (proj.justification) {
      justSec.innerHTML = '<h4>Justification</h4>' + App.renderMarkdown(proj.justification);
      justSec.style.display = '';
    } else {
      justSec.style.display = 'none';
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

    renderProjectCSTable();

    // Reset to context tab
    document.querySelectorAll('#proj-tabs .panel-tab').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.tab === 'context');
    });
    document.getElementById('proj-tab-context').style.display = '';
    document.getElementById('proj-tab-variables').style.display = 'none';
  }

  function renderProjectCSTable() {
    if (!selectedProject) return;
    var ids = new Set(selectedProject.conceptSetIds || []);
    var csData = App.getCSData().filter(function(d) { return ids.has(d.id); });
    var filter = document.getElementById('proj-cs-search').value.toLowerCase();
    var filtered = filter ? csData.filter(function(d) {
      return d.name.toLowerCase().includes(filter) ||
        d.category.toLowerCase().includes(filter) ||
        d.subcategory.toLowerCase().includes(filter);
    }) : csData;

    filtered.sort(function(a, b) {
      var ca = a.category.localeCompare(b.category);
      if (ca !== 0) return ca;
      return a.name.localeCompare(b.name);
    });

    document.getElementById('proj-cs-count').textContent = filtered.length;
    var tbody = document.getElementById('proj-cs-tbody');
    tbody.innerHTML = filtered.map(function(d) {
      return '<tr data-id="' + d.id + '" style="cursor:pointer">' +
        '<td><span class="badge badge-category">' + App.escapeHtml(d.category) + '</span></td>' +
        '<td><span class="badge badge-subcategory">' + App.escapeHtml(d.subcategory) + '</span></td>' +
        '<td><strong>' + App.escapeHtml(d.name) + '</strong></td>' +
        '<td class="desc-truncated">' + App.escapeHtml(d.description) + '</td>' +
        '<td class="td-center">' + App.statusBadge(d.reviewStatus) + '</td>' +
        '<td class="td-center">' + App.escapeHtml(d.version) + '</td>' +
        '</tr>';
    }).join('');
  }

  function hideProjectDetail() {
    document.getElementById('proj-detail-view').classList.remove('active');
    document.getElementById('proj-list-view').classList.remove('hidden');
    selectedProject = null;
  }

  // ==================== LANGUAGE CHANGE ====================
  window.onLanguageChange = function() {
    renderProjectCards();
    if (selectedProject) showProjectDetail(selectedProject.id);
  };

  // ==================== EVENTS ====================
  function initEvents() {
    // Project card click
    document.getElementById('proj-cards').addEventListener('click', function(e) {
      var card = e.target.closest('.project-card[data-id]');
      if (!card) return;
      showProjectDetail(parseInt(card.dataset.id));
    });

    // Project back button
    document.getElementById('proj-back').addEventListener('click', hideProjectDetail);

    // Project search
    document.getElementById('proj-search').addEventListener('input', renderProjectCards);

    // Project tabs
    document.getElementById('proj-tabs').addEventListener('click', function(e) {
      var tab = e.target.closest('.panel-tab');
      if (!tab) return;
      document.querySelectorAll('#proj-tabs .panel-tab').forEach(function(b) { b.classList.remove('active'); });
      tab.classList.add('active');
      document.getElementById('proj-tab-context').style.display = tab.dataset.tab === 'context' ? '' : 'none';
      document.getElementById('proj-tab-variables').style.display = tab.dataset.tab === 'variables' ? '' : 'none';
    });

    // Project concept set click -> navigate to Data Dictionary page
    document.getElementById('proj-cs-tbody').addEventListener('click', function(e) {
      var tr = e.target.closest('tr[data-id]');
      if (!tr) return;
      window.location.href = 'index.html?cs=' + tr.dataset.id;
    });

    // Project concept set search
    document.getElementById('proj-cs-search').addEventListener('input', renderProjectCSTable);

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

    // Keyboard: Escape
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') {
        if (document.getElementById('confirm-reset-modal').style.display !== 'none') {
          document.getElementById('confirm-reset-modal').style.display = 'none';
        } else if (document.getElementById('profile-modal').style.display !== 'none') {
          App.closeProfileModal();
        } else if (selectedProject) {
          hideProjectDetail();
        }
      }
    });
  }

  // ==================== INIT ====================
  App.updateUserBadge();
  App.initSharedEvents();
  initEvents();
  App.loadData(renderProjectCards);
})();
