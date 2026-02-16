// shared.js — expose window.App for use by page-specific scripts
var App = (function() {
  'use strict';

  // ==================== STATE ====================
  var conceptSets = [];
  var projects = [];
  var unitConversions = [];
  var recommendedUnits = [];
  var etlGuidelines = '';
  var lang = localStorage.getItem('indicate_lang') || 'en';
  var resolvedIndex = {}; // conceptSetId -> resolvedConcepts[]
  var sessionReviews = JSON.parse(localStorage.getItem('indicate_reviews') || '{}');

  // ==================== DATA LOADING ====================
  function loadData(callback) {
    conceptSets = DATA.conceptSets || [];
    projects = DATA.projects || [];
    unitConversions = DATA.unitConversions || [];
    recommendedUnits = DATA.recommendedUnits || [];
    etlGuidelines = DATA.etlGuidelines || '';
    var resolved = DATA.resolvedConceptSets || [];
    resolved.forEach(function(r) {
      resolvedIndex[r.conceptSetId] = r.resolvedConcepts || [];
    });
    document.getElementById('loading').classList.add('hidden');
    if (callback) callback();
  }

  // ==================== HELPERS ====================
  function t(cs) {
    var tr = cs.metadata && cs.metadata.translations;
    return (tr && tr[lang]) || (tr && tr.en) || {};
  }

  function escapeHtml(s) {
    if (!s) return '';
    return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  var toastIcons = { error: 'fa-circle-exclamation', success: 'fa-circle-check', warning: 'fa-triangle-exclamation', info: 'fa-circle-info' };
  function showToast(message, type, duration) {
    type = type || 'info';
    duration = duration || 3000;
    var container = document.getElementById('toast-container');
    var toast = document.createElement('div');
    toast.className = 'toast toast-' + type;
    toast.innerHTML = '<i class="fas ' + (toastIcons[type] || toastIcons.info) + '"></i><span>' + escapeHtml(message) + '</span>';
    container.appendChild(toast);
    setTimeout(function() {
      toast.classList.add('toast-fade-out');
      setTimeout(function() { toast.remove(); }, 300);
    }, duration);
  }

  function renderMarkdown(s) {
    if (!s) return '';
    var html = escapeHtml(s);
    html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    var blocks = html.split(/\n\n+/);
    return blocks.map(function(block) {
      var lines = block.split('\n');
      var isList = lines.every(function(l) { return l.trim() === '' || l.trim().startsWith('- '); });
      if (isList) {
        var items = lines.filter(function(l) { return l.trim().startsWith('- '); }).map(function(l) { return '<li>' + l.trim().substring(2) + '</li>'; });
        return '<ul style="margin:8px 0 8px 20px; line-height:1.8">' + items.join('') + '</ul>';
      }
      return '<p>' + block.replace(/\n/g, '<br>') + '</p>';
    }).join('');
  }

  function fuzzyMatch(text, query) {
    text = text.toLowerCase();
    query = query.toLowerCase();
    if (text.includes(query)) return 0;
    var ti = 0, qi = 0, score = 0, lastMatch = -1;
    while (ti < text.length && qi < query.length) {
      if (text[ti] === query[qi]) {
        score += (ti - (lastMatch + 1));
        lastMatch = ti;
        qi++;
      }
      ti++;
    }
    return qi === query.length ? score + 1 : -1;
  }

  function fuzzyFilter(items, query, getTexts) {
    if (!query) return items;
    var q = query.toLowerCase().trim();
    var results = [];
    for (var i = 0; i < items.length; i++) {
      var texts = getTexts(items[i]);
      var bestScore = -1;
      for (var j = 0; j < texts.length; j++) {
        var s = fuzzyMatch(texts[j] || '', q);
        if (s >= 0 && (bestScore < 0 || s < bestScore)) bestScore = s;
      }
      if (bestScore >= 0) results.push({ item: items[i], score: bestScore });
    }
    results.sort(function(a, b) { return a.score - b.score; });
    return results.map(function(r) { return r.item; });
  }

  var statusLabelsMap = { draft: 'Draft', pending_review: 'Pending Review', approved: 'Approved', needs_revision: 'Needs Revision', deprecated: 'Deprecated' };

  function statusBadge(status) {
    if (!status) status = 'draft';
    return '<span class="status-badge ' + escapeHtml(status) + '">' + escapeHtml(statusLabelsMap[status] || status) + '</span>';
  }

  function truncate(s, n) {
    if (!s) return '';
    return s.length > n ? s.substring(0, n) + '...' : s;
  }

  function standardBadge(concept) {
    var sc = concept.standardConcept;
    if (sc === 'S') return '<span class="badge badge-standard">Standard</span>';
    if (sc === 'C') return '<span class="badge badge-classification">Classification</span>';
    return '<span class="badge badge-non-standard">Non-standard</span>';
  }

  function validBadge(concept) {
    var v = concept.invalidReasonCaption;
    if (v === 'Valid') return '<span class="badge badge-valid">Valid</span>';
    return '<span class="badge badge-invalid">' + escapeHtml(v) + '</span>';
  }

  // ==================== MULTI-SELECT DROPDOWN ====================
  function buildMultiSelectDropdown(containerId, values, selectedSet, onChange, labelMap) {
    var container = document.getElementById(containerId);
    if (!container) return;
    function getLabel(v) { return labelMap ? (labelMap[v] || v) : v; }
    function toggleLabel() {
      if (selectedSet.size === 0) return 'All';
      if (selectedSet.size === 1) return escapeHtml(getLabel([...selectedSet][0]));
      return selectedSet.size + ' selected';
    }
    container.innerHTML =
      '<div class="ms-toggle" tabindex="0">' + toggleLabel() + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i></div>' +
      '<div class="ms-dropdown" style="display:none">' +
        values.map(function(v) {
          return '<label class="ms-option"><input type="checkbox" value="' + escapeHtml(v) + '"' + (selectedSet.has(v) ? ' checked' : '') + '> ' + escapeHtml(getLabel(v) || '(empty)') + '</label>';
        }).join('') +
      '</div>';
    var toggle = container.querySelector('.ms-toggle');
    var dropdown = container.querySelector('.ms-dropdown');
    toggle.addEventListener('click', function(e) {
      e.stopPropagation();
      document.querySelectorAll('.ms-dropdown').forEach(function(d) { if (d !== dropdown) d.style.display = 'none'; });
      dropdown.style.display = dropdown.style.display === 'none' ? '' : 'none';
    });
    dropdown.addEventListener('change', function(e) {
      var cb = e.target;
      if (cb.checked) selectedSet.add(cb.value); else selectedSet.delete(cb.value);
      toggle.innerHTML = toggleLabel() + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i>';
      onChange();
    });
  }

  function updateMsToggleLabel(containerId, selectedSet) {
    var container = document.getElementById(containerId);
    if (!container) return;
    var toggle = container.querySelector('.ms-toggle');
    if (toggle) {
      toggle.innerHTML = (selectedSet.size === 0 ? 'All' : selectedSet.size === 1 ? escapeHtml([...selectedSet][0]) : selectedSet.size + ' selected') + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i>';
    }
  }

  // ==================== USER PROFILE ====================
  function getUserProfile() {
    try { return JSON.parse(localStorage.getItem('indicate_reviewer') || '{}'); } catch(e) { return {}; }
  }

  function saveUserProfile(profile) {
    try { localStorage.setItem('indicate_reviewer', JSON.stringify(profile)); } catch(e) {}
    updateUserBadge();
  }

  function updateUserBadge() {
    var p = getUserProfile();
    var name = ((p.firstName || '') + ' ' + (p.lastName || '')).trim();
    var el = document.getElementById('user-badge-name');
    if (el) el.textContent = name || 'Guest';
  }

  function getKnownAuthors() {
    var seen = {};
    var authors = [];
    conceptSets.forEach(function(cs) {
      var d = cs.metadata && cs.metadata.createdByDetails;
      if (!d || !d.firstName || !d.lastName) return;
      var key = (d.firstName + ' ' + d.lastName).toLowerCase();
      if (seen[key]) return;
      seen[key] = true;
      authors.push({ firstName: d.firstName, lastName: d.lastName, affiliation: d.affiliation || '', profession: d.profession || '', orcid: d.orcid || '' });
    });
    authors.sort(function(a, b) { return (a.lastName + a.firstName).localeCompare(b.lastName + b.firstName); });
    return authors;
  }

  function populateAuthorSelect(currentProfile) {
    var select = document.getElementById('profile-select-author');
    if (!select) return;
    var authors = getKnownAuthors();
    select.innerHTML = '<option value="">— Custom —</option>';
    authors.forEach(function(a, i) {
      var opt = document.createElement('option');
      opt.value = i;
      opt.textContent = a.firstName + ' ' + a.lastName + (a.affiliation ? ' — ' + a.affiliation : '');
      select.appendChild(opt);
    });
    if (currentProfile && currentProfile.firstName && currentProfile.lastName) {
      var key = (currentProfile.firstName + ' ' + currentProfile.lastName).toLowerCase();
      authors.forEach(function(a, i) {
        if ((a.firstName + ' ' + a.lastName).toLowerCase() === key) select.value = i;
      });
    }
    select._authors = authors;
  }

  function openProfileModal() {
    var p = getUserProfile();
    populateAuthorSelect(p);
    document.getElementById('profile-firstName').value = p.firstName || '';
    document.getElementById('profile-lastName').value = p.lastName || '';
    document.getElementById('profile-affiliation').value = p.affiliation || '';
    document.getElementById('profile-profession').value = p.profession || '';
    document.getElementById('profile-orcid').value = p.orcid || '';
    document.getElementById('profile-modal').style.display = '';
  }

  function closeProfileModal() {
    document.getElementById('profile-modal').style.display = 'none';
  }

  function saveProfileFromModal() {
    var firstName = document.getElementById('profile-firstName').value.trim();
    var lastName = document.getElementById('profile-lastName').value.trim();
    if (!firstName || !lastName) {
      showToast('First name and last name are required.', 'error');
      return;
    }
    saveUserProfile({
      firstName: firstName,
      lastName: lastName,
      affiliation: document.getElementById('profile-affiliation').value.trim(),
      profession: document.getElementById('profile-profession').value.trim(),
      orcid: document.getElementById('profile-orcid').value.trim()
    });
    closeProfileModal();
  }

  // ==================== SHARED EVENTS ====================
  function initSharedEvents() {
    // Language toggle
    var langBtn = document.getElementById('lang-toggle');
    if (langBtn) {
      langBtn.textContent = lang.toUpperCase();
      langBtn.addEventListener('click', function() {
        lang = lang === 'en' ? 'fr' : 'en';
        localStorage.setItem('indicate_lang', lang);
        langBtn.textContent = lang.toUpperCase();
        if (typeof onLanguageChange === 'function') onLanguageChange();
      });
    }

    // User profile modal events
    var userBadge = document.getElementById('user-badge');
    if (userBadge) userBadge.addEventListener('click', openProfileModal);

    var profileClose = document.getElementById('profile-modal-close');
    if (profileClose) profileClose.addEventListener('click', closeProfileModal);

    var profileCancel = document.getElementById('profile-cancel');
    if (profileCancel) profileCancel.addEventListener('click', closeProfileModal);

    var profileSave = document.getElementById('profile-save');
    if (profileSave) profileSave.addEventListener('click', saveProfileFromModal);

    var profileSelect = document.getElementById('profile-select-author');
    if (profileSelect) {
      profileSelect.addEventListener('change', function() {
        var select = this;
        var authors = select._authors;
        if (select.value === '' || !authors) return;
        var a = authors[parseInt(select.value)];
        if (!a) return;
        document.getElementById('profile-firstName').value = a.firstName;
        document.getElementById('profile-lastName').value = a.lastName;
        document.getElementById('profile-affiliation').value = a.affiliation;
        document.getElementById('profile-profession').value = a.profession;
        document.getElementById('profile-orcid').value = a.orcid;
      });
    }

    var profileModal = document.getElementById('profile-modal');
    if (profileModal) {
      profileModal.addEventListener('click', function(e) {
        if (e.target === profileModal) closeProfileModal();
      });
    }

    // Reset cache
    var resetBtn = document.getElementById('reset-cache-btn');
    if (resetBtn) {
      resetBtn.addEventListener('click', function() {
        document.getElementById('confirm-reset-modal').style.display = '';
      });
    }
    var confirmResetClose = document.getElementById('confirm-reset-close');
    if (confirmResetClose) {
      confirmResetClose.addEventListener('click', function() {
        document.getElementById('confirm-reset-modal').style.display = 'none';
      });
    }
    var confirmResetCancel = document.getElementById('confirm-reset-cancel');
    if (confirmResetCancel) {
      confirmResetCancel.addEventListener('click', function() {
        document.getElementById('confirm-reset-modal').style.display = 'none';
      });
    }
    var confirmResetOk = document.getElementById('confirm-reset-ok');
    if (confirmResetOk) {
      confirmResetOk.addEventListener('click', function() {
        localStorage.clear();
        window.location.reload();
      });
    }
    var confirmResetModal = document.getElementById('confirm-reset-modal');
    if (confirmResetModal) {
      confirmResetModal.addEventListener('click', function(e) {
        if (e.target === this) this.style.display = 'none';
      });
    }

    // Settings dropdown
    var navSettingsBtn = document.getElementById('nav-settings-btn');
    var navSettingsMenu = document.getElementById('nav-settings-menu');
    if (navSettingsBtn && navSettingsMenu) {
      navSettingsBtn.addEventListener('click', function(e) {
        e.stopPropagation();
        navSettingsMenu.style.display = navSettingsMenu.style.display === 'none' ? '' : 'none';
      });
    }

    // Close multi-select dropdowns and nav dropdown on outside click
    document.addEventListener('click', function(e) {
      if (!e.target.closest('.ms-container')) {
        document.querySelectorAll('.ms-dropdown').forEach(function(d) { d.style.display = 'none'; });
      }
      if (!e.target.closest('.nav-dropdown')) {
        var menu = document.getElementById('nav-settings-menu');
        if (menu) menu.style.display = 'none';
      }
    });

    // Header logo/title click -> go home
    var headerLeft = document.querySelector('.header-left');
    if (headerLeft && headerLeft.tagName !== 'A') {
      headerLeft.addEventListener('click', function() {
        window.location.href = 'index.html';
      });
    }
  }

  // ==================== GETCSDATA ====================
  function getCSData() {
    return conceptSets.map(function(cs) {
      var tr = t(cs);
      return {
        id: cs.id,
        name: tr.name || cs.name,
        category: tr.category || '',
        subcategory: tr.subcategory || '',
        description: cs.description || '',
        reviewStatus: cs.reviewStatus || 'draft',
        version: cs.version || '',
        concepts: (cs.expression && cs.expression.items) ? cs.expression.items.length : 0,
        modified: cs.modifiedDate || cs.createdDate || '',
        raw: cs
      };
    });
  }

  // ==================== PUBLIC API ====================
  return {
    // State getters/setters
    get conceptSets() { return conceptSets; },
    get projects() { return projects; },
    get unitConversions() { return unitConversions; },
    get recommendedUnits() { return recommendedUnits; },
    get etlGuidelines() { return etlGuidelines; },
    get lang() { return lang; },
    set lang(v) { lang = v; },
    get resolvedIndex() { return resolvedIndex; },
    get sessionReviews() { return sessionReviews; },
    set sessionReviews(v) { sessionReviews = v; localStorage.setItem('indicate_reviews', JSON.stringify(v)); },
    saveSessionReviews: function() { localStorage.setItem('indicate_reviews', JSON.stringify(sessionReviews)); },
    get statusLabelsMap() { return statusLabelsMap; },

    // Functions
    loadData: loadData,
    t: t,
    escapeHtml: escapeHtml,
    showToast: showToast,
    renderMarkdown: renderMarkdown,
    fuzzyMatch: fuzzyMatch,
    fuzzyFilter: fuzzyFilter,
    statusBadge: statusBadge,
    truncate: truncate,
    standardBadge: standardBadge,
    validBadge: validBadge,
    buildMultiSelectDropdown: buildMultiSelectDropdown,
    updateMsToggleLabel: updateMsToggleLabel,
    getUserProfile: getUserProfile,
    saveUserProfile: saveUserProfile,
    updateUserBadge: updateUserBadge,
    getKnownAuthors: getKnownAuthors,
    openProfileModal: openProfileModal,
    closeProfileModal: closeProfileModal,
    initSharedEvents: initSharedEvents,
    getCSData: getCSData
  };
})();
