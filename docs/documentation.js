// documentation.js — Documentation page module
var DocumentationPage = (function() {
  'use strict';

  var initialized = false;
  var currentSection = 'introduction';

  function isDev() {
    var h = window.location.hostname;
    return h === 'localhost' || h === '127.0.0.1' || h === '';
  }

  // ==================== SIDEBAR STRUCTURE ====================

  function sections() {
    var en = App.lang === 'en';
    return [
      {
        title: en ? 'Overview' : 'Pr\u00e9sentation',
        items: [
          { id: 'introduction', label: 'Introduction' },
          { id: 'getting-started', label: en ? 'Getting Started' : 'Prise en main' }
        ]
      },
      {
        title: en ? 'Data Dictionary' : 'Dictionnaire de donn\u00e9es',
        items: [
          { id: 'what-are-concept-sets', label: en ? 'What are Concept Sets?' : 'Les jeux de concepts' },
          { id: 'browsing', label: en ? 'Browsing Concept Sets' : 'Parcourir les jeux de concepts' },
          { id: 'concept-set-details', label: en ? 'Concept Set Details' : 'D\u00e9tails d\u2019un jeu de concepts' },
          { id: 'editing-concept-sets', label: en ? 'Editing Concept Sets' : 'Modifier un jeu de concepts', draft: true },
          { id: 'reviewing', label: en ? 'Reviewing & GitHub' : 'Relecture & GitHub', draft: true },
          { id: 'exporting', label: en ? 'Exporting' : 'Exporter', draft: true }
        ]
      },
      {
        title: en ? 'Projects' : 'Projets',
        items: [
          { id: 'projects', label: en ? 'Managing Projects' : 'G\u00e9rer les projets', draft: true }
        ]
      },
      {
        title: en ? 'Mapping Recommendations' : 'Recommandations',
        items: [
          { id: 'mapping-recommendations', label: en ? 'Mapping Recommendations' : 'Recommandations de mapping', draft: true }
        ]
      },
      {
        title: en ? 'Settings' : 'Param\u00e8tres',
        items: [
          { id: 'ohdsi-vocabularies', label: en ? 'OHDSI Vocabularies' : 'Vocabulaires OHDSI', draft: true },
          { id: 'dictionary-settings', label: en ? 'Dictionary Settings' : 'Param\u00e8tres du dictionnaire', draft: true }
        ]
      }
    ];
  }

  // ==================== CONTENT REGISTRY ====================

  function content() {
    var en = App.lang === 'en';
    return {
      'introduction':         en ? introductionEN()         : introductionFR(),
      'getting-started':      en ? gettingStartedEN()       : gettingStartedFR(),
      'what-are-concept-sets':en ? whatAreConceptSetsEN()    : whatAreConceptSetsFR(),
      'browsing':             en ? browsingEN()              : browsingFR(),
      'concept-set-details':  en ? conceptSetDetailsEN()     : conceptSetDetailsFR(),
      'editing-concept-sets': en ? editingConceptSetsEN()    : editingConceptSetsFR(),
      'reviewing':            en ? reviewingEN()             : reviewingFR(),
      'exporting':            en ? exportingEN()             : exportingFR(),
      'projects':             en ? projectsEN()              : projectsFR(),
      'mapping-recommendations': en ? mappingEN()            : mappingFR(),
      'ohdsi-vocabularies':   en ? ohdsiVocabEN()            : ohdsiVocabFR(),
      'dictionary-settings':  en ? dictSettingsEN()          : dictSettingsFR()
    };
  }

  // ==================== HTML HELPERS ====================

  function featureCard(icon, title, desc) {
    return '<div class="doc-feature-card">'
      + '<div class="doc-feature-icon"><i class="fas ' + icon + '"></i></div>'
      + '<h4>' + title + '</h4>'
      + '<p>' + desc + '</p></div>';
  }

  function audienceCard(icon, title, desc) {
    return '<div class="doc-audience-card">'
      + '<div class="doc-audience-icon"><i class="fas ' + icon + '"></i></div>'
      + '<h4>' + title + '</h4>'
      + '<p>' + desc + '</p></div>';
  }

  function infoBox(title, body, type) {
    return '<div class="doc-info-box doc-' + (type || 'info') + '">'
      + '<div class="doc-info-title">' + title + '</div>'
      + '<p>' + body + '</p></div>';
  }

  function profileMock(lang) {
    var en = lang === 'en';
    var idPrefix = 'doc-profile-' + lang;
    var authorTab = idPrefix + '-author-tab';
    var orgTab = idPrefix + '-org-tab';
    var authorPane = idPrefix + '-author-pane';
    var orgPane = idPrefix + '-org-pane';

    return '<div class="doc-mock-modal">'
      // Header
      + '<div class="modal-header">'
      + '<h3>' + (en ? 'Edit Profile' : 'Modifier le profil') + '</h3>'
      + '<span class="modal-close" style="cursor:default">&times;</span>'
      + '</div>'
      // Tabs
      + '<div class="profile-modal-tabs">'
      + '<button class="profile-modal-tab active" id="' + authorTab + '" onclick="'
      + 'document.getElementById(\'' + authorTab + '\').classList.add(\'active\');'
      + 'document.getElementById(\'' + orgTab + '\').classList.remove(\'active\');'
      + 'document.getElementById(\'' + authorPane + '\').style.display=\'\';'
      + 'document.getElementById(\'' + orgPane + '\').style.display=\'none\';'
      + '">'
      + '<i class="fas fa-user-circle"></i> ' + (en ? 'Author' : 'Auteur')
      + '</button>'
      + '<button class="profile-modal-tab" id="' + orgTab + '" onclick="'
      + 'document.getElementById(\'' + orgTab + '\').classList.add(\'active\');'
      + 'document.getElementById(\'' + authorTab + '\').classList.remove(\'active\');'
      + 'document.getElementById(\'' + orgPane + '\').style.display=\'\';'
      + 'document.getElementById(\'' + authorPane + '\').style.display=\'none\';'
      + '">'
      + '<i class="fas fa-building"></i> ' + 'Organisation'
      + '</button>'
      + '</div>'
      // Author pane
      + '<div class="modal-body" id="' + authorPane + '">'
      + '<div class="form-row">'
      + '<div class="form-group"><label>' + (en ? 'First Name *' : 'Pr\u00e9nom *') + '</label>'
      + '<input type="text" class="form-input" value="John" readonly></div>'
      + '<div class="form-group"><label>' + (en ? 'Last Name *' : 'Nom *') + '</label>'
      + '<input type="text" class="form-input" value="Doe" readonly></div>'
      + '</div>'
      + '<div class="form-row">'
      + '<div class="form-group"><label>' + (en ? 'Affiliation' : 'Affiliation') + '</label>'
      + '<input type="text" class="form-input" value="University Hospital" readonly></div>'
      + '<div class="form-group"><label>' + (en ? 'Profession' : 'Profession') + '</label>'
      + '<input type="text" class="form-input" value="Intensivist" readonly></div>'
      + '</div>'
      + '<div class="form-group"><label>ORCID</label>'
      + '<input type="text" class="form-input" value="0000-0001-2345-6789" readonly></div>'
      + '</div>'
      // Organization pane
      + '<div class="modal-body" id="' + orgPane + '" style="display:none">'
      + '<div class="form-group"><label>' + (en ? 'Organization Name *' : 'Nom de l\u2019organisation *') + '</label>'
      + '<input type="text" class="form-input" value="INDICATE Consortium" readonly></div>'
      + '<div class="form-group"><label>URL</label>'
      + '<input type="text" class="form-input" value="https://indicate-eu.org" readonly></div>'
      + '</div>'
      // Footer
      + '<div class="modal-footer">'
      + '<button class="btn-cancel" disabled>' + (en ? 'Cancel' : 'Annuler') + '</button>'
      + '<button class="btn-submit" disabled><i class="fas fa-check"></i> ' + (en ? 'Save' : 'Enregistrer') + '</button>'
      + '</div>'
      + '</div>';
  }

  function mockConceptSetTable(lang) {
    var en = lang === 'en';
    var rows = [
      { cat: en ? 'Vital Signs' : 'Signes vitaux', sub: en ? 'Haemodynamics' : 'H\u00e9modynamique', name: en ? 'Heart rate' : 'Fr\u00e9quence cardiaque', ver: '1.0.1', status: 'approved', statusLabel: en ? 'Approved' : 'Approuv\u00e9' },
      { cat: en ? 'Vital Signs' : 'Signes vitaux', sub: en ? 'Haemodynamics' : 'H\u00e9modynamique', name: en ? 'Systolic blood pressure' : 'Pression art\u00e9rielle systolique', ver: '1.0.0', status: 'pending_review', statusLabel: en ? 'Pending Review' : 'En attente' },
      { cat: en ? 'Laboratory' : 'Biologie', sub: en ? 'Chemistry' : 'Biochimie', name: en ? 'Serum Creatinine' : 'Cr\u00e9atinine s\u00e9rique', ver: '1.1.0', status: 'approved', statusLabel: en ? 'Approved' : 'Approuv\u00e9' },
      { cat: en ? 'Laboratory' : 'Biologie', sub: en ? 'Haematology' : 'H\u00e9matologie', name: en ? 'Haemoglobin' : 'H\u00e9moglobine', ver: '1.0.0', status: 'draft', statusLabel: en ? 'Draft' : 'Brouillon' },
      { cat: en ? 'Drugs' : 'M\u00e9dicaments', sub: en ? 'Vasopressors' : 'Vasopresseurs', name: en ? 'Norepinephrine' : 'Nor\u00e9pin\u00e9phrine', ver: '1.0.0', status: 'approved', statusLabel: en ? 'Approved' : 'Approuv\u00e9' }
    ];
    var fl = en ? 'Filter...' : 'Filtrer...';
    var html = '<div class="doc-mock-table"><table><thead><tr>'
      + '<th>' + (en ? 'Category' : 'Cat\u00e9gorie') + '</th>'
      + '<th>' + (en ? 'Subcategory' : 'Sous-cat\u00e9gorie') + '</th>'
      + '<th>' + (en ? 'Name' : 'Nom') + '</th>'
      + '<th>' + (en ? 'Version' : 'Version') + '</th>'
      + '<th>' + (en ? 'Status' : 'Statut') + '</th>'
      + '</tr><tr class="doc-mock-filter-row">'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '</tr></thead><tbody>';
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      html += '<tr>'
        + '<td><span class="badge badge-category">' + r.cat + '</span></td>'
        + '<td><span class="badge badge-subcategory">' + r.sub + '</span></td>'
        + '<td><strong>' + r.name + '</strong></td>'
        + '<td style="text-align:right">' + r.ver + '</td>'
        + '<td><span class="status-badge ' + r.status + '" style="cursor:default; font-size:11px; padding:2px 8px">' + r.statusLabel + '</span></td>'
        + '</tr>';
    }
    html += '</tbody></table></div>';
    return html;
  }

  function detailTabs(lang, activeTab) {
    var en = lang === 'en';
    var tabs = [
      { id: 'concepts', icon: 'fa-list', label: 'Concepts' },
      { id: 'comments', icon: 'fa-comment', label: en ? 'Comments' : 'Commentaires' },
      { id: 'statistics', icon: 'fa-chart-bar', label: en ? 'Statistics' : 'Statistiques' },
      { id: 'review', icon: 'fa-clipboard-check', label: en ? 'Review' : 'Relecture' }
    ];
    var html = '<div class="detail-header-tabs" style="justify-content:center; margin:16px 0 12px">';
    for (var i = 0; i < tabs.length; i++) {
      var t = tabs[i];
      html += '<button class="tab-btn-blue' + (t.id === activeTab ? ' active' : '') + '" style="cursor:default">'
        + '<i class="fas ' + t.icon + '"></i> ' + t.label + '</button>';
    }
    html += '</div>';
    return html;
  }

  function conceptModeToggle(lang, activeMode) {
    var en = lang === 'en';
    var resolved = en ? 'Resolved' : 'R\u00e9solus';
    var expression = 'Expression';
    return '<div style="margin:12px 0; display:flex; justify-content:center">'
      + '<div class="toggle-group">'
      + '<button class="toggle-btn' + (activeMode === 'resolved' ? ' active' : '') + '" style="cursor:default">' + resolved + '</button>'
      + '<button class="toggle-btn' + (activeMode === 'expression' ? ' active' : '') + '" style="cursor:default">' + expression + '</button>'
      + '</div></div>';
  }

  function mockExpressionTable(lang) {
    var en = lang === 'en';
    var flagYes = '<span class="flag-yes">Yes</span>';
    var flagNo = '<span class="flag-no">No</span>';
    var flagYesDanger = '<span class="flag-yes-danger">Yes</span>';
    var rows = [
      { vocab: 'LOINC', name: 'Heart rate', code: 'LP415670-1', domain: 'Measurement', std: 'C', excl: false, desc: true, map: true },
      { vocab: 'LOINC', name: 'Heart rate.beat-to-beat | Heart', code: 'LP415748-5', domain: 'Measurement', std: 'C', excl: false, desc: true, map: true },
      { vocab: 'SNOMED', name: 'Heart rate', code: '364075005', domain: 'Measurement', std: 'S', excl: false, desc: true, map: true },
      { vocab: 'SNOMED', name: 'Resting heart rate', code: '444981005', domain: 'Measurement', std: 'S', excl: false, desc: true, map: true },
      { vocab: 'SNOMED', name: 'Fetal heart rate', code: '249043002', domain: 'Measurement', std: 'S', excl: true, desc: true, map: true },
      { vocab: 'LOINC', name: 'Heart rate at First encounter', code: '69000-8', domain: 'Measurement', std: 'S', excl: true, desc: true, map: true }
    ];
    var stdBadge = function(s) {
      if (s === 'S') return '<span class="badge badge-standard">Standard</span>';
      return '<span class="badge badge-classification">Classification</span>';
    };
    var fl = en ? 'Filter...' : 'Filtrer...';
    var html = '<div class="doc-mock-table"><table><thead><tr>'
      + '<th>' + (en ? 'Vocabulary' : 'Vocabulaire') + '</th>'
      + '<th>' + (en ? 'Concept Name' : 'Nom du concept') + '</th>'
      + '<th>' + (en ? 'Domain' : 'Domaine') + '</th>'
      + '<th>Standard</th>'
      + '<th>' + (en ? 'Exclude' : 'Exclure') + '</th>'
      + '<th>Desc.</th>'
      + '<th>' + (en ? 'Mapped' : 'Mapp\u00e9') + '</th>'
      + '</tr><tr class="doc-mock-filter-row">'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '</tr></thead><tbody>';
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      html += '<tr>'
        + '<td>' + r.vocab + '</td>'
        + '<td>' + r.name + '</td>'
        + '<td>' + (en ? r.domain : 'Mesure') + '</td>'
        + '<td>' + stdBadge(r.std) + '</td>'
        + '<td class="td-center">' + (r.excl ? flagYesDanger : flagNo) + '</td>'
        + '<td class="td-center">' + (r.excl ? (r.desc ? flagYesDanger : flagNo) : (r.desc ? flagYes : flagNo)) + '</td>'
        + '<td class="td-center">' + (r.excl ? (r.map ? flagYesDanger : flagNo) : (r.map ? flagYes : flagNo)) + '</td>'
        + '</tr>';
    }
    html += '<tr><td colspan="7" style="text-align:center; color:var(--text-muted); font-size:12px; padding:8px">'
      + (en ? '... 38 items total' : '... 38 \u00e9l\u00e9ments au total')
      + '</td></tr>';
    html += '</tbody></table></div>';
    return html;
  }

  function mockResolvedTable(lang) {
    var en = lang === 'en';
    var rows = [
      { id: 3027018, vocab: 'LOINC', name: 'Heart rate', code: '8867-4', domain: 'Measurement', std: 'S' },
      { id: 36303943, vocab: 'LOINC', name: 'Heart rate --W exercise', code: '89273-7', domain: 'Measurement', std: 'S' },
      { id: 36305351, vocab: 'LOINC', name: 'Heart rate --during anesthesia', code: '89278-6', domain: 'Measurement', std: 'S' },
      { id: 3040891, vocab: 'LOINC', name: 'Heart rate --resting', code: '40443-4', domain: 'Measurement', std: 'S' },
      { id: 40771525, vocab: 'LOINC', name: 'Heart rate --sitting', code: '69001-6', domain: 'Measurement', std: 'S' },
      { id: 3001376, vocab: 'LOINC', name: 'Heart rate by Pulse oximetry', code: '8889-8', domain: 'Measurement', std: 'S' },
      { id: 40481601, vocab: 'SNOMED', name: 'Resting heart rate', code: '444981005', domain: 'Measurement', std: 'S' },
      { id: 35610095, vocab: 'SNOMED', name: 'Heart rate at cardiac apex', code: '429525003', domain: 'Measurement', std: 'S' }
    ];
    var fl = en ? 'Filter...' : 'Filtrer...';
    var html = '<div class="doc-mock-table"><table><thead><tr>'
      + '<th>' + (en ? 'Concept ID' : 'ID Concept') + '</th>'
      + '<th>' + (en ? 'Vocabulary' : 'Vocabulaire') + '</th>'
      + '<th>' + (en ? 'Concept Name' : 'Nom du concept') + '</th>'
      + '<th>' + (en ? 'Concept Code' : 'Code') + '</th>'
      + '<th>Standard</th>'
      + '</tr><tr class="doc-mock-filter-row">'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '<th><input type="text" class="form-input" placeholder="' + fl + '" readonly></th>'
      + '</tr></thead><tbody>';
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      html += '<tr>'
        + '<td>' + r.id + '</td>'
        + '<td>' + r.vocab + '</td>'
        + '<td>' + r.name + '</td>'
        + '<td>' + r.code + '</td>'
        + '<td><span class="badge badge-standard">Standard</span></td>'
        + '</tr>';
    }
    html += '<tr><td colspan="5" style="text-align:center; color:var(--text-muted); font-size:12px; padding:8px">'
      + (en ? '... 23 standard concepts resolved (63 total)' : '... 23 concepts standards r\u00e9solus (63 au total)')
      + '</td></tr>';
    html += '</tbody></table></div>';
    return html;
  }

  function mockReviewTable(lang) {
    var en = lang === 'en';
    var reviews = [
      {
        name: 'Jane Smith',
        date: '2026-03-15',
        status: 'approved',
        statusLabel: en ? 'Approved' : 'Approuv\u00e9',
        version: '1.0.1',
        comment: en
          ? 'Concept set is comprehensive. LOINC hierarchy coverage is good, and the exclusion of fetal heart rate concepts is appropriate for adult ICU use cases.'
          : 'Jeu de concepts complet. La couverture de la hi\u00e9rarchie LOINC est bonne, et l\u2019exclusion des concepts de fr\u00e9quence cardiaque f\u0153tale est pertinente pour les cas d\u2019utilisation en r\u00e9animation adulte.'
      },
      {
        name: 'Boris Delange',
        date: '2026-02-28',
        status: 'approved',
        statusLabel: en ? 'Approved' : 'Approuv\u00e9',
        version: '1.0.0',
        comment: en
          ? 'OK with initial concept set.'
          : 'OK avec le jeu de concepts initial.'
      },
      {
        name: 'John Doe',
        date: '2026-01-10',
        status: 'needs_revision',
        statusLabel: en ? 'Needs Revision' : '\u00c0 r\u00e9viser',
        version: '1.0.0',
        comment: en
          ? 'I would have removed concept "Heart rate \u2013\u2013W exercise" from the set, as exercise-related measurements are not relevant in the ICU context.'
          : 'J\u2019aurais retir\u00e9 le concept \u00ab Heart rate \u2013\u2013W exercise \u00bb du jeu, car les mesures li\u00e9es \u00e0 l\u2019exercice ne sont pas pertinentes en r\u00e9animation.'
      }
    ];

    // Panel header with count and buttons
    var html = '<div class="doc-mock-modal" style="max-width:100%">'
      + '<div style="display:flex; align-items:center; gap:8px; padding:12px 16px; border-bottom:1px solid var(--gray-200)">'
      + '<h3 style="margin:0; font-size:14px; font-weight:600">' + (en ? 'Reviews' : 'Relectures') + '</h3>'
      + '<span class="badge badge-count">' + reviews.length + '</span>'
      + '<span style="flex:1"></span>'
      + '<button class="tab-btn-green" style="cursor:default"><i class="fab fa-github"></i> '
      + (en ? 'Propose on GitHub' : 'Proposer sur GitHub') + '</button>'
      + '<button class="tab-btn-green" style="cursor:default"><i class="fas fa-plus"></i> '
      + (en ? 'Add Review' : 'Ajouter une relecture') + '</button>'
      + '</div>';

    // Table
    html += '<div style="padding:0"><table style="margin:0"><thead><tr>'
      + '<th style="width:18%">' + (en ? 'Reviewer' : 'Relecteur') + '</th>'
      + '<th style="width:12%">' + (en ? 'Date' : 'Date') + '</th>'
      + '<th style="width:12%" class="td-center">' + (en ? 'Status' : 'Statut') + '</th>'
      + '<th style="width:10%">' + (en ? 'Version' : 'Version') + '</th>'
      + '<th style="width:48%">' + (en ? 'Comments' : 'Commentaires') + '</th>'
      + '</tr></thead><tbody>';

    for (var i = 0; i < reviews.length; i++) {
      var r = reviews[i];
      html += '<tr style="cursor:default">'
        + '<td>' + r.name + '</td>'
        + '<td>' + r.date + '</td>'
        + '<td class="td-center"><span class="status-badge ' + r.status + '" style="cursor:default; font-size:11px; padding:2px 8px">' + r.statusLabel + '</span></td>'
        + '<td>' + r.version + '</td>'
        + '<td style="font-size:12px">' + r.comment + '</td>'
        + '</tr>';
    }

    html += '</tbody></table></div></div>';
    return html;
  }

  function docLink(sectionId, label) {
    return '<a href="#/documentation?section=' + sectionId + '">' + label + '</a>';
  }

  // ==================== ENGLISH CONTENT ====================

  function introductionEN() {
    return '<h1>Introduction</h1>'
      + '<p>The <strong>INDICATE Data Dictionary</strong> is a web application for browsing, reviewing, '
      + 'and contributing to a curated library of standardized clinical concept sets for intensive care. '
      + 'It is designed to help harmonize ICU data across European institutions using the OMOP Common Data Model.</p>'

      + infoBox('What is INDICATE?',
        '<a href="https://indicate-europe.eu/" target="_blank">INDICATE</a> is a European initiative '
        + 'launched in December 2024, co-funded by the EU Digital Europe Programme (Grant No. 101167778). '
        + 'It aims to build a federated infrastructure for secure, cross-border ICU data sharing across '
        + '15 data providers in 12 European countries.')

      + '<h2>Why a Data Dictionary?</h2>'
      + '<p>Even with standardized terminologies like LOINC and SNOMED CT, a single clinical idea (e.g. '
      + '"Heart Rate") can be represented by hundreds of distinct standard concepts, varying by measurement '
      + 'method, specimen type, or clinical context. Selecting appropriate concepts requires combined '
      + 'clinical, data science, and terminology expertise.</p>'
      + '<p>The INDICATE Data Dictionary addresses this by providing expert-curated '
      + '<strong>concept sets</strong> \u2014 reusable collections of OMOP vocabulary concepts that '
      + 'define clinically meaningful variables. It follows the '
      + '<a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">'
      + 'OHDSI Concept Set Specification</a>, ensuring interoperability with ATLAS and the broader OHDSI ecosystem.</p>'

      + '<h2>Key Features</h2>'
      + '<div class="doc-feature-grid">'
      + featureCard('fa-book', 'Concept Set Browser',
        'Browse concept sets organized by clinical category: vitals, labs, conditions, drugs, ventilation, and more.')
      + featureCard('fa-search', 'Concept Explorer',
        'Navigate inside each concept set, view individual concept details with links to ATHENA and FHIR, and explore vocabulary hierarchies interactively.')
      + featureCard('fa-comment-dots', 'Expert Guidance',
        'Each concept set includes expert comments (Markdown) with clinical context and ETL recommendations.')
      + featureCard('fa-chart-bar', 'Reference Statistics',
        'Expected distributions (histograms, percentiles) for data validation, with multiple profiles (Adult, Child, Newborn).')
      + featureCard('fa-user-check', 'Peer Review',
        'Submit reviews with status tracking, and propose changes on GitHub via pull requests.')
      + featureCard('fa-list-check', 'Projects',
        'Organize concept sets into research projects and export project-level concept lists as CSV.')
      + '</div>'

      + '<h2>Who is this for?</h2>'
      + '<div class="doc-audience-grid">'
      + audienceCard('fa-user-md', 'Clinicians & Researchers',
        'Provide expertise on concept definitions, review clinical relevance, and use curated concept sets for study design and cohort definition.')
      + audienceCard('fa-chart-line', 'Data Scientists',
        'Build ETL pipelines and federated queries with validated concept sets.')
      + audienceCard('fa-database', 'Data Engineers',
        'Map source data to OMOP CDM using recommended concept sets and unit conversions.')
      + '</div>'

      + '<h2>About the project</h2>'
      + '<p>Concept set definitions were developed through an iterative, consensus-building process. '
      + 'Use case leaders first identified the variables required for their clinical applications. '
      + 'These requirements were refined in bi-weekly interdisciplinary meetings bringing together '
      + 'clinical experts, data scientists, and interoperability specialists.</p>'
      + '<p>The library currently comprises over 330 concept sets organized into nine categories. '
      + 'All content is open source on '
      + '<a href="https://github.com/indicate-eu/data-dictionary-content" target="_blank">GitHub</a>. '
      + 'Learn more at <a href="https://indicate-europe.eu/" target="_blank">indicate-europe.eu</a>.</p>';
  }

  function gettingStartedEN() {
    return '<h1>Getting Started</h1>'
      + '<p>The application runs entirely in the browser \u2014 no installation or server required. '
      + 'Simply open the web page and start browsing.</p>'

      + '<h2>Quick Tour</h2>'
      + '<p>The navigation bar at the top provides access to the main sections:</p>'
      + '<ul>'
      + '<li><strong>Data Dictionary</strong> \u2014 Browse and search concept sets (' + docLink('browsing', 'details') + ')</li>'
      + '<li><strong>Mapping Recommendations</strong> \u2014 Guidance for mapping local variables (' + docLink('mapping-recommendations', 'details') + ')</li>'
      + '<li><strong>Projects</strong> \u2014 Group concept sets by research project (' + docLink('projects', 'details') + ')</li>'
      + '<li><strong>Documentation</strong> \u2014 This page</li>'
      + '</ul>'

      + '<h2>Optional: Import OHDSI Vocabularies</h2>'
      + '<p>For advanced features (concept search, descendant expansion, hierarchy visualization, '
      + 'concept set optimization), you can import OHDSI vocabulary files into a local DuckDB database '
      + 'that runs in the browser. See ' + docLink('ohdsi-vocabularies', 'OHDSI Vocabularies') + '.</p>'

      + '<h2>User Profile</h2>'
      + '<p>Click your name in the top-right corner to set your profile. '
      + 'This information is embedded in concept sets you create or review.</p>'
      + profileMock('en')

      + '<h2>Language</h2>'
      + '<p>Toggle between English and French using the <strong>EN</strong>/<strong>FR</strong> '
      + 'button in the header. Concept set names, categories, and descriptions are bilingual. '
      + 'Support for additional languages may be added in the future.</p>'

      + '<h2>Local Storage</h2>'
      + '<p>All your edits (concept sets, projects, reviews) are stored in your browser\'s local storage. '
      + 'They persist across sessions but are local to your browser. To share changes, use the '
      + docLink('reviewing', 'GitHub workflow') + '.</p>';
  }

  function whatAreConceptSetsEN() {
    return '<h1>What are Concept Sets?</h1>'

      + '<p>A <strong>concept set</strong> is a reusable collection of OMOP vocabulary concepts that '
      + 'defines a clinically meaningful variable (e.g., "Heart Rate", "Serum Creatinine", "Norepinephrine"). '
      + 'Rather than working with individual LOINC or SNOMED codes, researchers and data engineers work '
      + 'with concept sets that group related codes under intuitive clinical labels.</p>'

      + '<h2>The OHDSI Concept Set Specification</h2>'
      + '<p>Each concept set follows the '
      + '<a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">'
      + 'OHDSI Concept Set Specification</a>, the standard format used by ATLAS and the OHDSI ecosystem. '
      + 'A concept set expression is a list of items, where each item references an OMOP concept and has '
      + 'three boolean flags:</p>'
      + '<ul>'
      + '<li><strong>Exclude</strong> \u2014 Remove this concept (and optionally its descendants) from the set</li>'
      + '<li><strong>Descendants</strong> \u2014 Include all descendant concepts in the vocabulary hierarchy</li>'
      + '<li><strong>Mapped</strong> \u2014 Include concepts linked via "Maps to" relationships</li>'
      + '</ul>'

      + infoBox('Expression vs. Resolved',
        'The <strong>expression</strong> is what you author \u2014 a compact list of selected concepts with flags. '
        + 'The <strong>resolved set</strong> is the expanded result after applying descendants, mapped, and exclusion '
        + 'logic. For example, an expression with one LOINC classification concept + Descendants might resolve '
        + 'to dozens of specific measurement codes.')

      + '<h2>Extended Metadata</h2>'
      + '<p>Beyond the standard OHDSI specification, each concept set in the INDICATE library includes '
      + 'additional metadata:</p>'
      + '<ul>'
      + '<li><strong>Version</strong> \u2014 Semantic versioning (e.g. 1.0.0) with a version history log</li>'
      + '<li><strong>Review status</strong> \u2014 Draft, Pending Review, Approved, Needs Revision, or Deprecated</li>'
      + '<li><strong>Author info</strong> \u2014 Creator name, affiliation, profession, ORCID</li>'
      + '<li><strong>Translations</strong> \u2014 Multilingual name, category, and subcategory (currently English and French, extensible to other languages)</li>'
      + '<li><strong>Expert comments</strong> \u2014 Markdown field for clinical guidance and ETL recommendations</li>'
      + '<li><strong>Statistical profiles</strong> \u2014 Expected distributions for data validation</li>'
      + '<li><strong>Review history</strong> \u2014 Reviewer name, date, status, and comments for each review</li>'
      + '</ul>'

      + '<h2>Categories</h2>'
      + '<p>Concept sets are organized into nine clinical categories:</p>'
      + '<ul>'
      + '<li>Demographics & Encounters</li>'
      + '<li>Conditions (diagnoses)</li>'
      + '<li>Clinical Observations (assessment scales)</li>'
      + '<li>Vital Signs</li>'
      + '<li>Laboratory Measurements</li>'
      + '<li>Microbiology</li>'
      + '<li>Ventilation</li>'
      + '<li>Drugs</li>'
      + '<li>Procedures</li>'
      + '</ul>'

      + '<h2>Use Cases</h2>'
      + '<p>These curated, reviewed, and versioned concept sets can be used for:</p>'
      + '<ul>'
      + '<li><strong>Cohort definition</strong> \u2014 As building blocks in ATLAS or custom queries</li>'
      + '<li><strong>ETL development</strong> \u2014 To prioritize and validate concept mappings</li>'
      + '<li><strong>Study feasibility</strong> \u2014 To evaluate data availability across a federated network</li>'
      + '</ul>';
  }

  function browsingEN() {
    return '<h1>Browsing Concept Sets</h1>'
      + '<p>The <strong>Data Dictionary</strong> page displays all concept sets in a searchable, filterable table.</p>'

      + '<h2>Category Badges</h2>'
      + '<p>At the top of the page, badges show each category with its concept set count. '
      + 'Click a badge to filter the table to that category. Click again to remove the filter. '
      + 'Multiple categories can be selected simultaneously.</p>'
      + '<div class="category-badges" style="justify-content:center; margin:12px 0">'
      + '<span class="category-badge">Vital Signs <span class="count">10</span></span>'
      + '<span class="category-badge active">Laboratory <span class="count">76</span></span>'
      + '<span class="category-badge">Drugs <span class="count">112</span></span>'
      + '<span class="category-badge">Ventilation <span class="count">26</span></span>'
      + '</div>'

      + '<h2>Searching & Filtering</h2>'
      + '<p>Each column header has a filter. Most columns use exact matching, but the '
      + '<strong>Name</strong> column uses <strong>fuzzy search</strong> \u2014 for example, '
      + 'typing "hart rate" will still find "Heart rate".</p>'
      + '<p>Additional multi-select dropdowns let you filter by:</p>'
      + '<ul>'
      + '<li><strong>Category</strong> \u2014 Same as clicking badges, with item counts</li>'
      + '<li><strong>Subcategory</strong> \u2014 Dynamically populated based on selected categories</li>'
      + '<li><strong>Review Status</strong> \u2014 Filter by Draft, Approved, Pending Review, etc.</li>'
      + '</ul>'

      + '<h2>Table</h2>'
      + '<p>Click any column header to sort. Click any row to open the '
      + docLink('concept-set-details', 'detail view') + '.</p>'
      + mockConceptSetTable('en');
  }

  function conceptSetDetailsEN() {
    return '<h1>Concept Set Details</h1>'
      + '<p>The detail view shows everything about a concept set, organized in four tabs: <strong>Concepts</strong>, <strong>Comments</strong>, <strong>Statistics</strong>, and <strong>Review</strong>.</p>'

      + '<h2>Concepts Tab</h2>'
      + detailTabs('en', 'concepts')
      + '<p>This tab has two modes, toggled with a switch: <strong>Expression</strong> and <strong>Resolved</strong>.</p>'

      + '<h3>Expression Mode</h3>'
      + conceptModeToggle('en', 'expression')
      + '<p>Shows the concept set expression \u2014 the authored items with their flags.</p>'
      + '<p>Each row shows Vocabulary, Concept Name, Concept Code, Domain, Concept Class, '
      + 'Standard status, and three boolean flags: <strong>Exclude</strong>, '
      + '<strong>Descendants</strong>, and <strong>Mapped</strong>.</p>'
      + '<p>These flags control how the expression is resolved into the final set of concepts. '
      + 'See ' + docLink('editing-concept-sets', 'Editing Concept Sets') + ' for detailed explanations.</p>'
      + '<p>Use the column filters (vocabulary, domain, standard, fuzzy name search) to navigate large expressions.</p>'
      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + 'Example: Heart rate concept set expression.'
      + '</p>'
      + mockExpressionTable('en')

      + '<h3>Resolved Mode</h3>'
      + conceptModeToggle('en', 'resolved')
      + '<p>Shows the expanded result after applying all expression logic. This is the actual set of '
      + 'OMOP concepts that would be used in a query. Columns include Concept ID, Vocabulary, Name, '
      + 'Code, Domain, Standard, and Concept Class.</p>'
      + '<p>If an OHDSI vocabulary database is loaded (see ' + docLink('ohdsi-vocabularies', 'OHDSI Vocabularies') + '), '
      + 'resolution is computed live in the browser. Otherwise, pre-computed resolved sets from the '
      + 'repository are used.</p>'
      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + (App.lang === 'en'
        ? 'Example: Heart rate resolved set \u2014 the actual standard OMOP concepts after expansion.'
        : 'Exemple\u00a0: jeu r\u00e9solu Fr\u00e9quence cardiaque \u2014 les concepts OMOP standards apr\u00e8s expansion.')
      + '</p>'
      + mockResolvedTable(App.lang)

      + '<h3>Concept Detail Panel</h3>'
      + '<p>Click any concept row to display a detail panel on the right with:</p>'
      + '<ul>'
      + '<li>Full concept metadata (vocabulary, domain, class, validity, standard status)</li>'
      + '<li>Links to <a href="https://athena.ohdsi.org/" target="_blank">ATHENA</a> and '
      + '<a href="https://tx.fhir.org/r4/" target="_blank">FHIR Terminology Server</a></li>'
      + '<li>Interactive hierarchy graph (ancestors, descendants, related concepts) using vis.js</li>'
      + '</ul>'

      + '<h2>Comments Tab</h2>'
      + detailTabs('en', 'comments')
      + '<p>Displays expert guidance in Markdown. Comments typically describe:</p>'
      + '<ul>'
      + '<li>The clinical meaning and context of the concept set</li>'
      + '<li>Which concepts to prefer in specific scenarios</li>'
      + '<li>Common pitfalls during ETL</li>'
      + '<li>Differences between similar concepts across vocabularies</li>'
      + '</ul>'
      + '<p>In edit mode, a dual-pane editor with live Markdown preview is available.</p>'
      + '<p>For broader recommendations that apply across multiple concept sets (e.g. general ETL guidance, '
      + 'mapping strategies), see the ' + docLink('mapping-recommendations', 'Mapping Recommendations') + ' page.</p>'

      + '<h2>Statistics Tab</h2>'
      + detailTabs('en', 'statistics')
      + infoBox('Work in Progress',
        'This feature is still under discussion and has not yet been implemented in practice. '
        + 'The format and content of statistical profiles may evolve.', 'warning')
      + '<p>Shows expected data distributions to help validate your data during ETL:</p>'
      + '<ul>'
      + '<li><strong>Numeric data</strong> \u2014 Min, P5, P25 (Q1), Median, Mean, P75 (Q3), P95, Max, SD, CV</li>'
      + '<li><strong>Histograms</strong> \u2014 Horizontal bar charts of the value distribution</li>'
      + '<li><strong>Categorical data</strong> \u2014 Categories with counts and percentages</li>'
      + '<li><strong>Multiple profiles</strong> \u2014 e.g. Adult, Child, Newborn with different reference ranges</li>'
      + '<li><strong>Measurement frequency</strong> \u2014 Typical recording interval (hourly, daily, etc.)</li>'
      + '</ul>'

      + '<h2>Review Tab</h2>'
      + detailTabs('en', 'review')
      + '<p>Displays the review history for this concept set. Each review records the reviewer, date, '
      + 'status, version reviewed, and comments.</p>'
      + mockReviewTable('en')
      + '<p>See ' + docLink('reviewing', 'Reviewing & GitHub') + ' for the full workflow on submitting '
      + 'reviews and proposing changes on GitHub.</p>'

      + '<h2>Header Metadata</h2>'
      + '<p>The detail header shows:</p>'
      + '<ul>'
      + '<li><strong>Version badge</strong> \u2014 Click to view the version history log</li>'
      + '<li><strong>Review status badge</strong> \u2014 Click to change status (in edit mode)</li>'
      + '<li><strong>View JSON</strong> link \u2014 Opens the raw JSON file on GitHub</li>'
      + '</ul>';
  }

  function editingConceptSetsEN() {
    return '<h1>Editing Concept Sets</h1>'
      + '<p>Click <strong>Edit page</strong> in the toolbar to enter edit mode. '
      + 'Changes are saved to your browser\'s local storage.</p>'

      + '<h2>List View Edit Mode</h2>'
      + '<ul>'
      + '<li><strong>Add a concept set</strong> \u2014 Click the + button to create a new concept set</li>'
      + '<li><strong>Select & delete</strong> \u2014 Use checkboxes to select concept sets, then delete in bulk</li>'
      + '<li><strong>Inline edit</strong> \u2014 Double-click on Category, Subcategory, or Name cells to edit directly</li>'
      + '</ul>'

      + '<h2>Editing the Expression</h2>'
      + '<p>In the Concepts tab (Expression mode), edit mode enables:</p>'

      + '<h3>Adding Concepts</h3>'
      + '<p>Click <strong>Add Concepts</strong> to open a modal with two tabs:</p>'
      + '<ul>'
      + '<li><strong>OHDSI search</strong> \u2014 Search the local OHDSI vocabulary database by name, '
      + 'concept ID, or code. Requires ' + docLink('ohdsi-vocabularies', 'importing vocabularies') + ' first. '
      + 'Filter results by vocabulary, domain, concept class, standard status, and validity.</li>'
      + '<li><strong>Custom concept</strong> \u2014 Create non-OMOP concepts (ID \u2265 2,100,000,000) '
      + 'when no standard concept exists. Use sparingly \u2014 custom concepts break interoperability.</li>'
      + '</ul>'
      + '<p>For each concept, set the Exclude, Descendants, and Mapped flags before adding.</p>'

      + '<h3>Import JSON</h3>'
      + '<p>Click <strong>Import JSON</strong> to paste an ATLAS-format or INDICATE-format concept set. '
      + 'The importer accepts both UPPERCASE (ATLAS) and camelCase (INDICATE) field names, '
      + 'deduplicates by concept ID, and reports added/skipped counts.</p>'

      + '<h3>Expression Flags</h3>'
      + '<p>Each concept in the expression has three flags that you can toggle directly in the table. '
      + 'These flags follow the '
      + '<a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">'
      + 'OHDSI Concept Set Specification</a>:</p>'

      + '<p><strong>Descendants</strong> \u2014 When checked, all descendant concepts in the '
      + 'vocabulary hierarchy are automatically included. OMOP vocabularies organize concepts '
      + 'in hierarchical trees using "Is a" / "Subsumes" relationships (stored in the '
      + 'CONCEPT_ANCESTOR table). For example, the LOINC hierarchy concept "Heart rate" has dozens '
      + 'of descendants like "Heart rate \u2013\u2013resting", "Heart rate \u2013\u2013sitting", '
      + '"Heart rate by Pulse oximetry", etc. Checking Descendants on a parent concept captures '
      + 'all of them without listing each one individually.</p>'

      + '<p><strong>Mapped</strong> \u2014 When checked, non-standard concepts that are linked to the '
      + 'selected concept via "Maps to" / "Mapped from" relationships are also included. '
      + 'In the OMOP vocabulary, each clinical idea has one designated <strong>Standard</strong> concept '
      + '(marked "S"). Other vocabulary codes representing the same idea are <strong>non-standard</strong> '
      + 'and are linked to the Standard concept via "Maps to". For example, SNOMED "Heart rate" '
      + '(concept ID 4239408, non-standard) maps to LOINC "Heart rate" (concept ID 3027018, Standard). '
      + 'Checking Mapped ensures that source codes from other vocabularies are captured alongside the '
      + 'standard concept.</p>'

      + '<p><strong>Exclude</strong> \u2014 When checked, this concept is removed from the resolved set. '
      + 'If Descendants is also checked, all its descendant concepts are excluded too. This allows you to '
      + 'include a broad parent concept with its descendants, then selectively exclude specific branches. '
      + 'For example, in the Heart rate concept set, "Fetal heart rate" is excluded with Descendants to '
      + 'remove fetal-specific measurements from the set.</p>'

      + infoBox('Resolution Algorithm',
        'The concept set is resolved in two phases: (1) build the <strong>inclusion set</strong> from '
        + 'all items where Exclude is unchecked, expanding via Descendants and Mapped as configured; '
        + '(2) build the <strong>exclusion set</strong> from items where Exclude is checked, with the '
        + 'same expansion logic; (3) the final result is <strong>inclusion set minus exclusion set</strong>.')

      + '<h3>Deleting Concepts</h3>'
      + '<p>Use the delete icon on each row, or select multiple rows and click Delete Selected.</p>'

      + '<h3>Optimizing the Expression</h3>'
      + '<p>Click <strong>Optimize</strong> to simplify the expression using vocabulary hierarchy analysis '
      + '(requires an OHDSI vocabulary database). The optimizer:</p>'
      + '<ul>'
      + '<li>Removes descendants already covered by a parent\'s "Include Descendants" flag (top-down)</li>'
      + '<li>Removes parent items that don\'t broaden scope (bottom-up)</li>'
      + '<li>Shows a before/after comparison with the items that would be removed or added</li>'
      + '<li>Warns if the optimization changes the resolved set</li>'
      + '</ul>'

      + '<h2>Editing Comments</h2>'
      + '<p>In the Comments tab, edit mode opens an ACE editor with Markdown syntax highlighting '
      + 'and a live preview panel. Use Cmd/Ctrl+S to save. Comments are stored per language.</p>'

      + '<h2>Editing Statistics</h2>'
      + '<p>In the Statistics tab, edit mode opens a JSON editor. A template with the expected '
      + 'structure is provided. You can define numeric data (min, max, mean, median, SD, percentiles, '
      + 'histogram), categorical data, measurement frequency, and multiple population profiles.</p>'

      + '<h2>Version & Status</h2>'
      + '<p>When saving changes, you can update the version (suggested: patch increment) and add '
      + 'a version summary. The review status can be changed via the status badge in the header.</p>';
  }

  function reviewingEN() {
    return '<h1>Reviewing & Proposing on GitHub</h1>'
      + '<p>The INDICATE Data Dictionary uses a GitHub-based workflow for contributing changes. '
      + 'All content is stored as JSON files in the '
      + '<a href="https://github.com/indicate-eu/data-dictionary-content" target="_blank">'
      + 'indicate-eu/data-dictionary-content</a> repository.</p>'

      + '<h2>Submitting a Review</h2>'
      + '<ol>'
      + '<li>Open a concept set and go to the <strong>Review</strong> tab</li>'
      + '<li>Click <strong>Add Review</strong></li>'
      + '<li>Select a review status (Approved, Needs Revision, etc.)</li>'
      + '<li>Write your comments (Markdown supported)</li>'
      + '<li>Submit \u2014 your review is stored in the session</li>'
      + '</ol>'

      + '<h2>Proposing Changes on GitHub</h2>'
      + '<p>After submitting a review or editing a concept set, a <strong>Propose on GitHub</strong> '
      + 'button appears. Clicking it:</p>'
      + '<ol>'
      + '<li>Copies the full updated concept set JSON to your clipboard</li>'
      + '<li>Opens the GitHub file editor for that specific file</li>'
      + '<li>You paste the JSON, commit to a new branch, and open a pull request</li>'
      + '</ol>'

      + infoBox('No GitHub Account?',
        'You can still browse and use the dictionary locally. The GitHub workflow is only needed '
        + 'to contribute changes back to the shared library.')

      + '<h2>What Can You Contribute?</h2>'
      + '<ul>'
      + '<li><strong>New concept sets</strong> \u2014 For clinical variables not yet covered</li>'
      + '<li><strong>Concept additions/removals</strong> \u2014 Improve existing concept set expressions</li>'
      + '<li><strong>Expert comments</strong> \u2014 Clinical guidance for ETL and mapping</li>'
      + '<li><strong>Statistical data</strong> \u2014 Reference distributions for data validation</li>'
      + '<li><strong>Reviews</strong> \u2014 Approve or request revision of concept sets</li>'
      + '<li><strong>Translations</strong> \u2014 Improve French translations</li>'
      + '<li><strong>Bug reports</strong> \u2014 '
      + '<a href="https://github.com/indicate-eu/data-dictionary-content/issues" target="_blank">Open an issue</a></li>'
      + '</ul>'

      + '<h2>File Structure on GitHub</h2>'
      + '<ul>'
      + '<li><code>concept_sets/{id}.json</code> \u2014 One file per concept set</li>'
      + '<li><code>projects/{id}.json</code> \u2014 One file per project</li>'
      + '<li><code>mapping_recommendations/mapping_recommendations.json</code> \u2014 All mapping recommendations</li>'
      + '<li><code>units/unit_conversions.csv</code> \u2014 Unit conversion factors</li>'
      + '<li><code>units/recommended_units.csv</code> \u2014 Recommended units per concept</li>'
      + '</ul>';
  }

  function exportingEN() {
    return '<h1>Exporting</h1>'

      + '<h2>Single Concept Set</h2>'
      + '<p>From the detail view, click <strong>Export</strong> to open the export modal with three options:</p>'
      + '<ul>'
      + '<li><strong>GitHub</strong> \u2014 Copies JSON to clipboard and opens the GitHub file editor</li>'
      + '<li><strong>Clipboard</strong> \u2014 Copies the JSON to your clipboard</li>'
      + '<li><strong>Download</strong> \u2014 Downloads the JSON file</li>'
      + '</ul>'
      + '<p>Two formats are available:</p>'
      + '<ul>'
      + '<li><strong>INDICATE format</strong> \u2014 The native format with all metadata (camelCase fields)</li>'
      + '<li><strong>ATLAS format</strong> \u2014 Compatible with OHDSI ATLAS (UPPERCASE fields)</li>'
      + '</ul>'

      + '<h2>Bulk Export</h2>'
      + '<p>Use the <strong>Export All</strong> button in the list view to export all concept sets or '
      + 'a specific category as a single JSON file.</p>'

      + '<h2>Project CSV Export</h2>'
      + '<p>From a project\'s detail view (Concept Sets tab), click the CSV export button to download '
      + 'all concepts from the project\'s concept sets. The CSV includes concept set IDs, names, categories, '
      + 'and all OMOP concept details \u2014 useful for analysis pipelines.</p>';
  }

  function projectsEN() {
    return '<h1>Managing Projects</h1>'
      + '<p>The <strong>Projects</strong> page lets you organize concept sets into research projects. '
      + 'A project can be a clinical study, a machine learning pipeline, a dashboard, or any data-driven initiative.</p>'

      + '<h2>Projects List</h2>'
      + '<p>Projects are displayed as cards showing name, description, concept set count, author, and date. '
      + 'Use the search field to filter by name or description.</p>'

      + '<h2>Creating a Project</h2>'
      + '<p>In edit mode, click <strong>Add Project</strong>. Provide a name and short description '
      + '(bilingual EN/FR). The author is pre-filled from your profile.</p>'

      + '<h2>Project Detail View</h2>'
      + '<p>Click a project card to open its detail view with two tabs:</p>'

      + '<h3>Context Tab</h3>'
      + '<p>A Markdown-formatted long description with live preview in edit mode. '
      + 'Bilingual editing (EN/FR side by side).</p>'

      + '<h3>Concept Sets Tab</h3>'
      + '<p>In read mode, shows a sortable, filterable table of the project\'s concept sets. '
      + 'Click a row to navigate to that concept set.</p>'
      + '<p>In edit mode, a dual-panel interface lets you:</p>'
      + '<ul>'
      + '<li><strong>Left panel</strong> \u2014 Available concept sets (not yet in the project)</li>'
      + '<li><strong>Right panel</strong> \u2014 Concept sets assigned to the project</li>'
      + '<li>Use the add/remove buttons to move concept sets between panels</li>'
      + '<li>Filter both panels by category, subcategory, or name</li>'
      + '</ul>'

      + '<h3>CSV Export</h3>'
      + '<p>In the Concept Sets tab (read mode), click the CSV button to download all OMOP concepts '
      + 'from the project\'s concept sets, including expression flags.</p>'

      + infoBox('Best Practice',
        'Include all concept sets needed for your analysis, even those only used for adjustment or '
        + 'stratification. This ensures complete data collection from the start.');
  }

  function mappingEN() {
    return '<h1>Mapping Recommendations</h1>'
      + '<p>The <strong>Mapping Recommendations</strong> page provides expert-curated guidance for '
      + 'mapping common local ICU variables to OMOP standard concepts.</p>'

      + '<h2>What are Mapping Recommendations?</h2>'
      + '<p>During an ETL process to convert local clinical data to the OMOP CDM, deciding how to map '
      + 'each local variable to standard concepts is one of the most challenging steps. Mapping recommendations '
      + 'provide structured guidance for common variables found in ICU databases.</p>'

      + '<h2>Viewing</h2>'
      + '<p>The content is rendered as Markdown, allowing rich formatting with tables, links, and structured guidance.</p>'

      + '<h2>Editing</h2>'
      + '<p>In edit mode, an ACE editor with Markdown syntax highlighting opens alongside a live preview panel. '
      + 'Content is bilingual \u2014 switching language saves the current text and loads the other language.</p>'

      + '<h2>Exporting</h2>'
      + '<p>Use the Export button to copy the recommendations as JSON, download the file, or open the '
      + 'GitHub editor to propose changes.</p>';
  }

  function ohdsiVocabEN() {
    return '<h1>OHDSI Vocabularies</h1>'
      + '<p>The application can import OHDSI vocabulary files into a <strong>DuckDB database that runs '
      + 'entirely in your browser</strong>. This enables powerful features without requiring any server.</p>'

      + '<h2>What it Enables</h2>'
      + '<ul>'
      + '<li><strong>Concept search</strong> \u2014 Search OMOP concepts by name, ID, or code when adding concepts to expressions</li>'
      + '<li><strong>Live resolution</strong> \u2014 Resolve concept set expressions in real-time (expand descendants and mapped concepts)</li>'
      + '<li><strong>Hierarchy visualization</strong> \u2014 Interactive graphs of concept ancestors, descendants, and relationships</li>'
      + '<li><strong>Expression optimization</strong> \u2014 Simplify expressions using vocabulary hierarchy analysis</li>'
      + '<li><strong>SQL queries</strong> \u2014 Query the vocabulary database directly in the Dev Tools SQL editor</li>'
      + '</ul>'

      + '<h2>How to Import</h2>'
      + '<ol>'
      + '<li>Download vocabulary files from <a href="https://athena.ohdsi.org/" target="_blank">ATHENA</a> (CSV format)</li>'
      + '<li>Go to <strong>Settings</strong> (gear icon) \u2192 <strong>General Settings</strong></li>'
      + '<li>Click <strong>Select Vocabulary Folder</strong> and choose the folder containing the vocabulary CSV files</li>'
      + '<li>Wait for the import to complete \u2014 a progress bar shows per-file status</li>'
      + '</ol>'
      + '<p>The import reads CONCEPT.csv, CONCEPT_RELATIONSHIP.csv, CONCEPT_ANCESTOR.csv, and related files, '
      + 'indexes them in DuckDB, and saves the database to browser storage.</p>'

      + infoBox('Browser Compatibility',
        'Chrome and Edge provide the best experience with persistent folder access. '
        + 'On Firefox and Safari, you may need to re-select the vocabulary folder each visit.')

      + '<h2>Re-importing and Deleting</h2>'
      + '<p>Use <strong>Re-import Vocabularies</strong> to update after downloading new vocabulary files. '
      + 'Use <strong>Delete Database</strong> to remove the local vocabulary database.</p>'

      + '<h2>Dev Tools: SQL Editor</h2>'
      + '<p>In Settings \u2192 Dev Tools, a SQL editor lets you query the vocabulary database directly. '
      + 'Pre-built example queries are provided. The Schema/ERD tab shows the database structure.</p>';
  }

  function dictSettingsEN() {
    return '<h1>Dictionary Settings</h1>'
      + '<p>Access via Settings (gear icon) \u2192 Dictionary Settings.</p>'

      + '<h2>Unit Conversions</h2>'
      + '<p>Manage conversion factors between measurement units. The table shows source and target '
      + 'concepts with their units and conversion factors.</p>'
      + '<ul>'
      + '<li><strong>Add</strong> \u2014 Create new conversions with source/target concept IDs, unit names, and factors</li>'
      + '<li><strong>Edit</strong> \u2014 Click a conversion factor to edit it inline</li>'
      + '<li><strong>Test</strong> \u2014 Open a calculator to verify the conversion (supports bidirectional testing)</li>'
      + '<li><strong>Delete</strong> \u2014 Remove a conversion with confirmation</li>'
      + '<li><strong>Export</strong> \u2014 Download all conversions as JSON</li>'
      + '</ul>'

      + '<h2>Recommended Units</h2>'
      + '<p>Define the recommended unit for each measurement concept. This helps ensure consistent '
      + 'unit usage across the dictionary.</p>'
      + '<ul>'
      + '<li><strong>Add</strong> \u2014 Associate a concept with its recommended unit (concept ID, name, code)</li>'
      + '<li><strong>Delete</strong> \u2014 Remove a recommendation</li>'
      + '<li><strong>Export</strong> \u2014 Download as JSON</li>'
      + '<li><strong>Search</strong> \u2014 Fuzzy search across all fields</li>'
      + '</ul>'

      + infoBox('Vocabulary Enrichment',
        'If an OHDSI vocabulary database is loaded, concept names are automatically '
        + 'looked up from the database when adding unit conversions or recommended units.');
  }

  // ==================== FRENCH CONTENT ====================

  function introductionFR() {
    return '<h1>Introduction</h1>'
      + '<p>Le <strong>Dictionnaire de Donn\u00e9es INDICATE</strong> est une application web permettant '
      + 'de parcourir, relire et contribuer \u00e0 une biblioth\u00e8que de jeux de concepts cliniques '
      + 'standardis\u00e9s pour la r\u00e9animation. Il utilise le mod\u00e8le OMOP CDM pour harmoniser '
      + 'les donn\u00e9es de soins intensifs \u00e0 travers les institutions europ\u00e9ennes.</p>'

      + infoBox('Qu\u2019est-ce qu\u2019INDICATE ?',
        '<a href="https://indicate-europe.eu/" target="_blank">INDICATE</a> est une initiative '
        + 'europ\u00e9enne lanc\u00e9e en d\u00e9cembre 2024, cofinanc\u00e9e par le programme Europe '
        + 'Num\u00e9rique de l\u2019UE (Convention n\u00b0 101167778). Le projet vise \u00e0 construire '
        + 'une infrastructure f\u00e9d\u00e9r\u00e9e pour le partage s\u00e9curis\u00e9 de donn\u00e9es '
        + 'de r\u00e9animation \u00e0 travers 15 fournisseurs dans 12 pays.')

      + '<h2>Pourquoi un dictionnaire de donn\u00e9es ?</h2>'
      + '<p>M\u00eame avec des terminologies standardis\u00e9es comme LOINC et SNOMED CT, une seule '
      + 'id\u00e9e clinique (ex. \u00ab Fr\u00e9quence cardiaque \u00bb) peut \u00eatre repr\u00e9sent\u00e9e '
      + 'par des centaines de concepts standards distincts. Le dictionnaire fournit des '
      + '<strong>jeux de concepts</strong> expertis\u00e9s, conformes \u00e0 la '
      + '<a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">'
      + 'Sp\u00e9cification OHDSI des Concept Sets</a>.</p>'

      + '<h2>Fonctionnalit\u00e9s principales</h2>'
      + '<div class="doc-feature-grid">'
      + featureCard('fa-book', 'Navigateur de jeux de concepts',
        'Parcourez les jeux de concepts par cat\u00e9gorie clinique\u00a0: signes vitaux, biologie, pathologies, m\u00e9dicaments, ventilation, etc.')
      + featureCard('fa-search', 'Explorateur de concepts',
        'Naviguez dans chaque jeu de concepts, consultez les d\u00e9tails de chaque concept avec des liens vers ATHENA et FHIR, et explorez les hi\u00e9rarchies de vocabulaires.')
      + featureCard('fa-comment-dots', 'Recommandations d\u2019experts',
        'Chaque jeu de concepts inclut des commentaires cliniques en Markdown pour guider l\u2019ETL.')
      + featureCard('fa-chart-bar', 'Statistiques de r\u00e9f\u00e9rence',
        'Distributions attendues (histogrammes, percentiles) pour la validation des donn\u00e9es.')
      + featureCard('fa-user-check', 'Relecture par les pairs',
        'Soumettez des relectures avec suivi de statut et proposez des modifications via GitHub.')
      + featureCard('fa-list-check', 'Projets',
        'Organisez les jeux de concepts en projets de recherche et exportez les listes en CSV.')
      + '</div>'

      + '<h2>\u00c0 qui s\u2019adresse cette application ?</h2>'
      + '<div class="doc-audience-grid">'
      + audienceCard('fa-user-md', 'Cliniciens & Chercheurs',
        'Apportez votre expertise sur les d\u00e9finitions des concepts, relisez leur pertinence, et utilisez les jeux de concepts pour la conception d\u2019\u00e9tudes et la d\u00e9finition de cohortes.')
      + audienceCard('fa-chart-line', 'Data Scientists',
        'Construisez des pipelines ETL et des requ\u00eates f\u00e9d\u00e9r\u00e9es avec des jeux valid\u00e9s.')
      + audienceCard('fa-database', 'Ing\u00e9nieurs de donn\u00e9es',
        'Mappez vos donn\u00e9es sources vers l\u2019OMOP CDM avec les jeux recommand\u00e9s.')
      + '</div>'

      + '<h2>\u00c0 propos du projet</h2>'
      + '<p>Les d\u00e9finitions ont \u00e9t\u00e9 d\u00e9velopp\u00e9es par un processus it\u00e9ratif '
      + 'de consensus, lors de r\u00e9unions bimensuelles r\u00e9unissant experts cliniques, data scientists '
      + 'et sp\u00e9cialistes d\u2019interop\u00e9rabilit\u00e9. La biblioth\u00e8que comprend plus de '
      + '330 jeux de concepts en neuf cat\u00e9gories. Tout le contenu est open source sur '
      + '<a href="https://github.com/indicate-eu/data-dictionary-content" target="_blank">GitHub</a>.</p>';
  }

  function gettingStartedFR() {
    return '<h1>Prise en main</h1>'
      + '<p>L\u2019application fonctionne enti\u00e8rement dans le navigateur \u2014 aucune installation requise.</p>'

      + '<h2>Visite rapide</h2>'
      + '<ul>'
      + '<li><strong>Dictionnaire de donn\u00e9es</strong> \u2014 Parcourir les jeux de concepts (' + docLink('browsing', 'd\u00e9tails') + ')</li>'
      + '<li><strong>Recommandations de mapping</strong> \u2014 Guide de mapping (' + docLink('mapping-recommendations', 'd\u00e9tails') + ')</li>'
      + '<li><strong>Projets</strong> \u2014 Grouper les jeux par projet (' + docLink('projects', 'd\u00e9tails') + ')</li>'
      + '<li><strong>Documentation</strong> \u2014 Cette page</li>'
      + '</ul>'

      + '<h2>Optionnel\u00a0: Importer les vocabulaires OHDSI</h2>'
      + '<p>Pour les fonctionnalit\u00e9s avanc\u00e9es (recherche de concepts, expansion des descendants, '
      + 'graphe hi\u00e9rarchique, optimisation), importez les fichiers OHDSI dans une base DuckDB locale. '
      + 'Voir ' + docLink('ohdsi-vocabularies', 'Vocabulaires OHDSI') + '.</p>'

      + '<h2>Profil utilisateur</h2>'
      + '<p>Cliquez sur votre nom en haut \u00e0 droite pour configurer votre profil. '
      + 'Ces informations sont int\u00e9gr\u00e9es aux jeux de concepts que vous cr\u00e9ez ou relisez.</p>'
      + profileMock('fr')

      + '<h2>Langue</h2>'
      + '<p>Basculez entre anglais et fran\u00e7ais avec le bouton <strong>EN</strong>/<strong>FR</strong>. '
      + 'Les noms, cat\u00e9gories et descriptions des jeux de concepts sont bilingues. '
      + 'Le support d\u2019autres langues pourra \u00eatre ajout\u00e9 \u00e0 l\u2019avenir.</p>'

      + '<h2>Stockage local</h2>'
      + '<p>Toutes vos modifications sont stock\u00e9es dans le navigateur (localStorage). '
      + 'Pour partager des modifications, utilisez le ' + docLink('reviewing', 'workflow GitHub') + '.</p>';
  }

  function whatAreConceptSetsFR() {
    return '<h1>Les jeux de concepts</h1>'

      + '<p>Un <strong>jeu de concepts</strong> (concept set) est une collection r\u00e9utilisable '
      + 'de concepts OMOP d\u00e9finissant une variable clinique (ex. \u00ab Fr\u00e9quence cardiaque \u00bb, '
      + '\u00ab Cr\u00e9atinine s\u00e9rique \u00bb). Plut\u00f4t que de manipuler des codes LOINC ou SNOMED '
      + 'individuels, on travaille avec des jeux qui regroupent les codes sous des \u00e9tiquettes cliniques.</p>'

      + '<h2>La Sp\u00e9cification OHDSI</h2>'
      + '<p>Chaque jeu suit la '
      + '<a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">'
      + 'Sp\u00e9cification OHDSI des Concept Sets</a>. Une expression est une liste d\u2019\u00e9l\u00e9ments, '
      + 'chacun r\u00e9f\u00e9ren\u00e7ant un concept OMOP avec trois options\u00a0:</p>'
      + '<ul>'
      + '<li><strong>Exclure</strong> \u2014 Retirer ce concept du jeu</li>'
      + '<li><strong>Descendants</strong> \u2014 Inclure tous les descendants hi\u00e9rarchiques</li>'
      + '<li><strong>Mapp\u00e9</strong> \u2014 Inclure les concepts li\u00e9s par des relations \u00ab Maps to \u00bb</li>'
      + '</ul>'

      + infoBox('Expression vs. R\u00e9solus',
        'L\u2019<strong>expression</strong> est ce que vous r\u00e9digez \u2014 une liste compacte. '
        + 'Le <strong>jeu r\u00e9solu</strong> est le r\u00e9sultat apr\u00e8s expansion des descendants et exclusions.')

      + '<h2>M\u00e9tadonn\u00e9es \u00e9tendues</h2>'
      + '<ul>'
      + '<li><strong>Version</strong> \u2014 Versioning s\u00e9mantique avec historique</li>'
      + '<li><strong>Statut de relecture</strong> \u2014 Brouillon, En attente, Approuv\u00e9, \u00c0 r\u00e9viser, Obsol\u00e8te</li>'
      + '<li><strong>Auteur</strong> \u2014 Nom, affiliation, profession, ORCID</li>'
      + '<li><strong>Traductions</strong> \u2014 Noms et cat\u00e9gories multilingues (actuellement anglais et fran\u00e7ais, extensible \u00e0 d\u2019autres langues)</li>'
      + '<li><strong>Commentaires d\u2019experts</strong> \u2014 Champ Markdown pour recommandations</li>'
      + '<li><strong>Profils statistiques</strong> \u2014 Distributions pour la validation</li>'
      + '<li><strong>Historique de relectures</strong> \u2014 Nom, date, statut et commentaires</li>'
      + '</ul>'

      + '<h2>Cat\u00e9gories</h2>'
      + '<ul>'
      + '<li>D\u00e9mographie & Rencontres</li>'
      + '<li>Pathologies</li>'
      + '<li>Observations cliniques (\u00e9chelles)</li>'
      + '<li>Signes vitaux</li>'
      + '<li>Biologie</li>'
      + '<li>Microbiologie</li>'
      + '<li>Ventilation</li>'
      + '<li>M\u00e9dicaments</li>'
      + '<li>Proc\u00e9dures</li>'
      + '</ul>';
  }

  function browsingFR() {
    return '<h1>Parcourir les jeux de concepts</h1>'
      + '<p>La page <strong>Dictionnaire de donn\u00e9es</strong> affiche tous les jeux dans un tableau filtrable.</p>'

      + '<h2>Badges de cat\u00e9gorie</h2>'
      + '<p>En haut de page, des badges indiquent chaque cat\u00e9gorie avec son nombre de jeux. '
      + 'Cliquez pour filtrer, re-cliquez pour retirer le filtre. S\u00e9lection multiple possible.</p>'
      + '<div class="category-badges" style="justify-content:center; margin:12px 0">'
      + '<span class="category-badge">Signes vitaux <span class="count">10</span></span>'
      + '<span class="category-badge active">Biologie <span class="count">76</span></span>'
      + '<span class="category-badge">M\u00e9dicaments <span class="count">112</span></span>'
      + '<span class="category-badge">Ventilation <span class="count">26</span></span>'
      + '</div>'

      + '<h2>Recherche & Filtres</h2>'
      + '<p>Chaque en-t\u00eate de colonne dispose d\u2019un filtre. La plupart utilisent une '
      + 'correspondance exacte, mais la colonne <strong>Nom</strong> utilise une '
      + '<strong>recherche floue</strong> \u2014 par exemple, \u00ab hart rate \u00bb trouvera '
      + '\u00ab Heart rate \u00bb.</p>'
      + '<p>Des menus d\u00e9roulants multi-s\u00e9lection permettent aussi de filtrer par\u00a0:</p>'
      + '<ul>'
      + '<li><strong>Cat\u00e9gorie</strong> \u2014 Comme les badges, avec compteurs</li>'
      + '<li><strong>Sous-cat\u00e9gorie</strong> \u2014 Adapt\u00e9e aux cat\u00e9gories s\u00e9lectionn\u00e9es</li>'
      + '<li><strong>Statut de relecture</strong> \u2014 Brouillon, Approuv\u00e9, etc.</li>'
      + '</ul>'

      + '<h2>Tableau</h2>'
      + '<p>Cliquez sur un en-t\u00eate de colonne pour trier. Cliquez sur une ligne pour ouvrir la '
      + docLink('concept-set-details', 'vue d\u00e9taill\u00e9e') + '.</p>'
      + mockConceptSetTable('fr');
  }

  function conceptSetDetailsFR() {
    return '<h1>D\u00e9tails d\u2019un jeu de concepts</h1>'
      + '<p>La vue d\u00e9taill\u00e9e pr\u00e9sente toutes les informations, organis\u00e9es en quatre onglets\u00a0: <strong>Concepts</strong>, <strong>Commentaires</strong>, <strong>Statistiques</strong> et <strong>Relecture</strong>.</p>'

      + '<h2>Onglet Concepts</h2>'
      + detailTabs('fr', 'concepts')
      + '<p>Deux modes, accessibles via un commutateur\u00a0: <strong>Expression</strong> et <strong>R\u00e9solus</strong>.</p>'

      + '<h3>Mode Expression</h3>'
      + conceptModeToggle('fr', 'expression')
      + '<p>Affiche les \u00e9l\u00e9ments de l\u2019expression avec leurs options\u00a0: '
      + '<strong>Exclure</strong>, <strong>Descendants</strong> et <strong>Mapp\u00e9</strong>. '
      + 'Ces options contr\u00f4lent la r\u00e9solution du jeu de concepts. '
      + 'Voir ' + docLink('editing-concept-sets', 'Modifier un jeu de concepts') + ' pour les explications d\u00e9taill\u00e9es.</p>'
      + '<p>Filtres par vocabulaire, domaine, standard et recherche floue par nom.</p>'
      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + 'Exemple\u00a0: expression du jeu de concepts Fr\u00e9quence cardiaque.</p>'
      + mockExpressionTable('fr')

      + '<h3>Mode R\u00e9solus</h3>'
      + conceptModeToggle('fr', 'resolved')
      + '<p>Affiche le r\u00e9sultat apr\u00e8s expansion. Si une base de vocabulaires est charg\u00e9e '
      + '(voir ' + docLink('ohdsi-vocabularies', 'Vocabulaires OHDSI') + '), la r\u00e9solution se fait en temps r\u00e9el.</p>'
      + '<p style="font-size:12px; color:var(--text-muted); margin-bottom:4px"><i class="fas fa-info-circle"></i> '
      + 'Exemple\u00a0: jeu r\u00e9solu Fr\u00e9quence cardiaque \u2014 les concepts OMOP standards apr\u00e8s expansion.</p>'
      + mockResolvedTable('fr')

      + '<h3>Panneau de d\u00e9tail concept</h3>'
      + '<p>Cliquez sur un concept pour voir ses m\u00e9tadonn\u00e9es, liens ATHENA et FHIR, et un graphe '
      + 'hi\u00e9rarchique interactif.</p>'

      + '<h2>Onglet Commentaires</h2>'
      + detailTabs('fr', 'comments')
      + '<p>Recommandations d\u2019experts en Markdown. \u00c9diteur avec aper\u00e7u en direct en mode \u00e9dition.</p>'
      + '<p>Pour les recommandations plus g\u00e9n\u00e9rales concernant plusieurs jeux de concepts '
      + '(strat\u00e9gies de mapping, bonnes pratiques ETL), consultez la page '
      + docLink('mapping-recommendations', 'Recommandations de mapping') + '.</p>'

      + '<h2>Onglet Statistiques</h2>'
      + detailTabs('fr', 'statistics')
      + infoBox('En cours de d\u00e9veloppement',
        'Cette fonctionnalit\u00e9 est encore en discussion et n\u2019a pas encore \u00e9t\u00e9 '
        + 'mise en \u0153uvre en pratique. Le format et le contenu des profils statistiques pourront \u00e9voluer.', 'warning')
      + '<ul>'
      + '<li><strong>Donn\u00e9es num\u00e9riques</strong> \u2014 Min, P5, Q1, M\u00e9diane, Moyenne, Q3, P95, Max, \u00c9T, CV</li>'
      + '<li><strong>Histogrammes</strong></li>'
      + '<li><strong>Donn\u00e9es cat\u00e9gorielles</strong></li>'
      + '<li><strong>Profils multiples</strong> (Adulte, Enfant, Nouveau-n\u00e9)</li>'
      + '</ul>'

      + '<h2>Onglet Relecture</h2>'
      + detailTabs('fr', 'review')
      + '<p>Affiche l\u2019historique des relectures pour ce jeu de concepts. Chaque relecture enregistre '
      + 'le relecteur, la date, le statut, la version relue et les commentaires.</p>'
      + mockReviewTable('fr')
      + '<p>Voir ' + docLink('reviewing', 'Relecture & GitHub') + ' pour le workflow complet de soumission '
      + 'de relectures et de proposition de modifications sur GitHub.</p>'

      + '<h2>En-t\u00eate</h2>'
      + '<ul>'
      + '<li><strong>Badge de version</strong> \u2014 Cliquez pour l\u2019historique</li>'
      + '<li><strong>Badge de statut</strong> \u2014 Modifiable en mode \u00e9dition</li>'
      + '<li><strong>Voir JSON</strong> \u2014 Lien vers le fichier brut sur GitHub</li>'
      + '</ul>';
  }

  function editingConceptSetsFR() {
    return '<h1>Modifier un jeu de concepts</h1>'
      + '<p>Cliquez sur le bouton <strong>Modifier</strong> (ic\u00f4ne crayon) pour entrer en mode \u00e9dition.</p>'

      + '<h2>Mode \u00e9dition de la liste</h2>'
      + '<ul>'
      + '<li><strong>Ajouter</strong> \u2014 Bouton + pour cr\u00e9er un nouveau jeu</li>'
      + '<li><strong>S\u00e9lection & suppression</strong> \u2014 Cases \u00e0 cocher pour op\u00e9rations groupées</li>'
      + '<li><strong>\u00c9dition inline</strong> \u2014 Double-clic sur Cat\u00e9gorie, Sous-cat\u00e9gorie ou Nom</li>'
      + '</ul>'

      + '<h2>Modifier l\u2019expression</h2>'

      + '<h3>Ajouter des concepts</h3>'
      + '<ul>'
      + '<li><strong>Recherche OHDSI</strong> \u2014 Par nom, ID ou code. N\u00e9cessite l\u2019'
      + docLink('ohdsi-vocabularies', 'import des vocabulaires') + '.</li>'
      + '<li><strong>Concept personnalis\u00e9</strong> \u2014 Pour les concepts sans \u00e9quivalent OMOP (ID \u2265 2,1 milliards). \u00c0 \u00e9viter.</li>'
      + '</ul>'

      + '<h3>Importer un JSON</h3>'
      + '<p>Collez un jeu de concepts au format ATLAS ou INDICATE. D\u00e9duplication automatique.</p>'

      + '<h3>Options de l\u2019expression</h3>'
      + '<p>Chaque concept de l\u2019expression a trois options que vous pouvez basculer directement dans '
      + 'le tableau. Ces options suivent la '
      + '<a href="https://ohdsi.github.io/TAB/Concept-Set-Specification.html" target="_blank">'
      + 'Sp\u00e9cification OHDSI des Concept Sets</a>\u00a0:</p>'

      + '<p><strong>Descendants</strong> \u2014 Inclut automatiquement tous les concepts descendants dans la '
      + 'hi\u00e9rarchie du vocabulaire (relations \u00ab Is a \u00bb / \u00ab Subsumes \u00bb, stock\u00e9es '
      + 'dans la table CONCEPT_ANCESTOR). Par exemple, le concept hi\u00e9rarchique LOINC '
      + '\u00ab Heart rate \u00bb a des dizaines de descendants comme \u00ab Heart rate \u2013\u2013resting \u00bb, '
      + '\u00ab Heart rate \u2013\u2013sitting \u00bb, \u00ab Heart rate by Pulse oximetry \u00bb, etc.</p>'

      + '<p><strong>Mapp\u00e9</strong> \u2014 Inclut les concepts non standards li\u00e9s par des relations '
      + '\u00ab Maps to \u00bb / \u00ab Mapped from \u00bb. Dans le vocabulaire OMOP, chaque id\u00e9e '
      + 'clinique a un seul concept d\u00e9sign\u00e9 <strong>Standard</strong> (marqu\u00e9 \u00ab S \u00bb). '
      + 'Les autres codes repr\u00e9sentant la m\u00eame id\u00e9e sont <strong>non standards</strong> et '
      + 'li\u00e9s au concept Standard via \u00ab Maps to \u00bb. Par exemple, SNOMED \u00ab Heart rate \u00bb '
      + '(ID 4239408, non standard) mappe vers LOINC \u00ab Heart rate \u00bb (ID 3027018, Standard).</p>'

      + '<p><strong>Exclure</strong> \u2014 Retire ce concept du jeu r\u00e9solu. Si Descendants est aussi '
      + 'coch\u00e9, tous ses descendants sont \u00e9galement exclus. Cela permet d\u2019inclure un concept '
      + 'parent large avec ses descendants, puis d\u2019exclure s\u00e9lectivement certaines branches. '
      + 'Par exemple, dans le jeu Fr\u00e9quence cardiaque, \u00ab Fetal heart rate \u00bb est exclu avec '
      + 'Descendants pour retirer les mesures sp\u00e9cifiques au f\u0153tus.</p>'

      + infoBox('Algorithme de r\u00e9solution',
        'Le jeu est r\u00e9solu en deux phases\u00a0: (1) construire l\u2019<strong>ensemble d\u2019inclusion</strong> '
        + '\u00e0 partir des \u00e9l\u00e9ments non exclus, en \u00e9tendant via Descendants et Mapp\u00e9\u00a0; '
        + '(2) construire l\u2019<strong>ensemble d\u2019exclusion</strong> avec la m\u00eame logique\u00a0; '
        + '(3) le r\u00e9sultat final est <strong>inclusion moins exclusion</strong>.')

      + '<h3>Optimiser l\u2019expression</h3>'
      + '<p>Le bouton <strong>Optimiser</strong> simplifie l\u2019expression en analysant la hi\u00e9rarchie '
      + '(n\u00e9cessite une base de vocabulaires).</p>'

      + '<h2>Modifier les commentaires</h2>'
      + '<p>\u00c9diteur Markdown avec aper\u00e7u en direct. Contenu stock\u00e9 par langue.</p>'

      + '<h2>Modifier les statistiques</h2>'
      + '<p>\u00c9diteur JSON avec un mod\u00e8le de structure attendue.</p>'

      + '<h2>Version & Statut</h2>'
      + '<p>Lors de la sauvegarde, mettez \u00e0 jour la version et ajoutez un r\u00e9sum\u00e9.</p>';
  }

  function reviewingFR() {
    return '<h1>Relecture & GitHub</h1>'
      + '<p>Le dictionnaire utilise un workflow GitHub. Tout le contenu est stock\u00e9 en JSON dans le '
      + 'd\u00e9p\u00f4t <a href="https://github.com/indicate-eu/data-dictionary-content" target="_blank">'
      + 'indicate-eu/data-dictionary-content</a>.</p>'

      + '<h2>Soumettre une relecture</h2>'
      + '<ol>'
      + '<li>Ouvrez un jeu de concepts, onglet <strong>Relecture</strong></li>'
      + '<li>Cliquez <strong>Ajouter une relecture</strong></li>'
      + '<li>Choisissez un statut et r\u00e9digez vos commentaires</li>'
      + '<li>Soumettez</li>'
      + '</ol>'

      + '<h2>Proposer sur GitHub</h2>'
      + '<ol>'
      + '<li>Le JSON mis \u00e0 jour est copi\u00e9 dans votre presse-papiers</li>'
      + '<li>L\u2019\u00e9diteur GitHub s\u2019ouvre automatiquement</li>'
      + '<li>Collez, committez sur une nouvelle branche et ouvrez une pull request</li>'
      + '</ol>'

      + '<h2>Que pouvez-vous contribuer ?</h2>'
      + '<ul>'
      + '<li>Nouveaux jeux de concepts</li>'
      + '<li>Ajout/suppression de concepts dans les expressions</li>'
      + '<li>Commentaires d\u2019experts</li>'
      + '<li>Donn\u00e9es statistiques</li>'
      + '<li>Relectures</li>'
      + '<li>Traductions fran\u00e7aises</li>'
      + '<li><a href="https://github.com/indicate-eu/data-dictionary-content/issues" target="_blank">Signaler des bugs</a></li>'
      + '</ul>';
  }

  function exportingFR() {
    return '<h1>Exporter</h1>'

      + '<h2>Jeu de concepts individuel</h2>'
      + '<p>Depuis la vue d\u00e9taill\u00e9e, cliquez <strong>Exporter</strong>\u00a0:</p>'
      + '<ul>'
      + '<li><strong>GitHub</strong> \u2014 Copie le JSON et ouvre l\u2019\u00e9diteur GitHub</li>'
      + '<li><strong>Presse-papiers</strong> \u2014 Copie le JSON</li>'
      + '<li><strong>T\u00e9l\u00e9charger</strong> \u2014 T\u00e9l\u00e9charge le fichier JSON</li>'
      + '</ul>'
      + '<p>Deux formats\u00a0: INDICATE (natif, camelCase) ou ATLAS (MAJUSCULES).</p>'

      + '<h2>Export groupé</h2>'
      + '<p>Le bouton <strong>Tout exporter</strong> dans la liste permet d\u2019exporter tous les jeux '
      + 'ou une cat\u00e9gorie sp\u00e9cifique.</p>'

      + '<h2>Export CSV projet</h2>'
      + '<p>Depuis la vue d\u00e9taill\u00e9e d\u2019un projet (onglet Jeux de concepts), exportez tous '
      + 'les concepts en CSV.</p>';
  }

  function projectsFR() {
    return '<h1>G\u00e9rer les projets</h1>'
      + '<p>La page <strong>Projets</strong> permet d\u2019organiser les jeux de concepts en projets de recherche.</p>'

      + '<h2>Liste des projets</h2>'
      + '<p>Cartes avec nom, description, nombre de jeux, auteur et date. Recherche par nom ou description.</p>'

      + '<h2>Cr\u00e9er un projet</h2>'
      + '<p>En mode \u00e9dition, cliquez <strong>Ajouter un projet</strong>. Nom et description bilingues (EN/FR).</p>'

      + '<h2>Vue d\u00e9taill\u00e9e</h2>'

      + '<h3>Onglet Contexte</h3>'
      + '<p>Description longue en Markdown, \u00e9dition bilingue c\u00f4te \u00e0 c\u00f4te.</p>'

      + '<h3>Onglet Jeux de concepts</h3>'
      + '<p>En lecture\u00a0: tableau triable et filtrable des jeux du projet. Cliquez pour naviguer vers un jeu.</p>'
      + '<p>En \u00e9dition\u00a0: double panneau pour ajouter/retirer des jeux.</p>'

      + '<h3>Export CSV</h3>'
      + '<p>T\u00e9l\u00e9chargez tous les concepts OMOP du projet avec les options de l\u2019expression.</p>'

      + infoBox('Bonne pratique',
        'Incluez tous les jeux n\u00e9cessaires \u00e0 votre analyse, m\u00eame ceux utilis\u00e9s '
        + 'uniquement pour l\u2019ajustement ou la stratification.');
  }

  function mappingFR() {
    return '<h1>Recommandations de mapping</h1>'
      + '<p>La page <strong>Recommandations de mapping</strong> fournit des recommandations expertis\u00e9es '
      + 'pour mapper les variables cliniques locales vers les concepts OMOP standards.</p>'

      + '<h2>Contenu</h2>'
      + '<p>Le contenu est rendu en Markdown avec mise en forme riche (tableaux, liens, listes).</p>'

      + '<h2>\u00c9dition</h2>'
      + '<p>En mode \u00e9dition, \u00e9diteur Markdown avec aper\u00e7u en direct. Contenu bilingue.</p>'

      + '<h2>Export</h2>'
      + '<p>Copiez le JSON, t\u00e9l\u00e9chargez ou ouvrez l\u2019\u00e9diteur GitHub pour proposer des modifications.</p>';
  }

  function ohdsiVocabFR() {
    return '<h1>Vocabulaires OHDSI</h1>'
      + '<p>L\u2019application peut importer des fichiers de vocabulaires OHDSI dans une <strong>base DuckDB '
      + 'qui fonctionne enti\u00e8rement dans votre navigateur</strong>.</p>'

      + '<h2>Ce que \u00e7a permet</h2>'
      + '<ul>'
      + '<li><strong>Recherche de concepts</strong> \u2014 Par nom, ID ou code lors de l\u2019ajout de concepts</li>'
      + '<li><strong>R\u00e9solution en direct</strong> \u2014 Expansion des descendants et concepts mapp\u00e9s en temps r\u00e9el</li>'
      + '<li><strong>Graphe hi\u00e9rarchique</strong> \u2014 Visualisation interactive des relations entre concepts</li>'
      + '<li><strong>Optimisation</strong> \u2014 Simplification des expressions par analyse hi\u00e9rarchique</li>'
      + '<li><strong>Requ\u00eates SQL</strong> \u2014 \u00c9diteur SQL dans les Outils de d\u00e9veloppement</li>'
      + '</ul>'

      + '<h2>Comment importer</h2>'
      + '<ol>'
      + '<li>T\u00e9l\u00e9chargez les vocabulaires depuis <a href="https://athena.ohdsi.org/" target="_blank">ATHENA</a> (format CSV)</li>'
      + '<li>Allez dans <strong>Param\u00e8tres</strong> (engrenage) \u2192 <strong>Param\u00e8tres g\u00e9n\u00e9raux</strong></li>'
      + '<li>Cliquez <strong>S\u00e9lectionner le dossier</strong> et choisissez le dossier des fichiers CSV</li>'
      + '<li>Attendez la fin de l\u2019import \u2014 une barre de progression indique l\u2019\u00e9tat</li>'
      + '</ol>'

      + infoBox('Compatibilit\u00e9 navigateur',
        'Chrome et Edge offrent la meilleure exp\u00e9rience avec un acc\u00e8s persistant. '
        + 'Sur Firefox et Safari, il faudra peut-\u00eatre res\u00e9lectionner le dossier \u00e0 chaque visite.')

      + '<h2>Reimporter et supprimer</h2>'
      + '<p>Utilisez <strong>R\u00e9importer</strong> apr\u00e8s une mise \u00e0 jour des vocabulaires. '
      + '<strong>Supprimer la base</strong> pour retirer la base locale.</p>';
  }

  function dictSettingsFR() {
    return '<h1>Param\u00e8tres du dictionnaire</h1>'
      + '<p>Acc\u00e8s via Param\u00e8tres (engrenage) \u2192 Param\u00e8tres du dictionnaire.</p>'

      + '<h2>Conversions d\u2019unit\u00e9s</h2>'
      + '<p>G\u00e9rez les facteurs de conversion entre unit\u00e9s de mesure.</p>'
      + '<ul>'
      + '<li><strong>Ajouter</strong> \u2014 Source, cible, facteur de conversion</li>'
      + '<li><strong>Modifier</strong> \u2014 Cliquez sur le facteur pour l\u2019\u00e9diter en ligne</li>'
      + '<li><strong>Tester</strong> \u2014 Calculatrice bidirectionnelle</li>'
      + '<li><strong>Supprimer</strong> et <strong>Exporter</strong> en JSON</li>'
      + '</ul>'

      + '<h2>Unit\u00e9s recommand\u00e9es</h2>'
      + '<p>D\u00e9finissez l\u2019unit\u00e9 recommand\u00e9e par concept de mesure.</p>'
      + '<ul>'
      + '<li><strong>Ajouter</strong> \u2014 Concept ID, nom, code, unit\u00e9</li>'
      + '<li><strong>Supprimer</strong> et <strong>Exporter</strong> en JSON</li>'
      + '<li><strong>Recherche</strong> floue sur tous les champs</li>'
      + '</ul>'

      + infoBox('Enrichissement vocabulaire',
        'Si une base OHDSI est charg\u00e9e, les noms de concepts sont automatiquement compl\u00e9t\u00e9s.');
  }

  // ==================== RENDERING ====================

  function renderSidebar() {
    var secs = sections();
    var dev = isDev();
    var html = '';
    for (var i = 0; i < secs.length; i++) {
      var sec = secs[i];
      // In prod, skip entire section if all items are draft
      var visibleItems = sec.items.filter(function(item) { return dev || !item.draft; });
      if (visibleItems.length === 0) continue;
      html += '<div class="doc-sidebar-section">';
      html += '<div class="doc-sidebar-title">' + App.escapeHtml(sec.title) + '</div>';
      html += '<ul class="doc-sidebar-nav">';
      for (var j = 0; j < sec.items.length; j++) {
        var item = sec.items[j];
        if (!dev && item.draft) continue;
        var cls = item.id === currentSection ? 'active' : '';
        if (item.draft) cls += (cls ? ' ' : '') + 'doc-draft';
        var clsAttr = cls ? ' class="' + cls + '"' : '';
        html += '<li><a href="#/documentation?section=' + item.id + '"' + clsAttr + ' data-doc-section="' + item.id + '">'
          + App.escapeHtml(item.label)
          + (item.draft ? ' <span class="doc-draft-badge">draft</span>' : '')
          + '</a></li>';
      }
      html += '</ul></div>';
    }
    document.getElementById('doc-sidebar').innerHTML = html;
  }

  function isSectionDraft(sectionId) {
    var secs = sections();
    for (var i = 0; i < secs.length; i++) {
      for (var j = 0; j < secs[i].items.length; j++) {
        if (secs[i].items[j].id === sectionId) return !!secs[i].items[j].draft;
      }
    }
    return false;
  }

  function draftPlaceholder() {
    var en = App.lang === 'en';
    return '<div class="doc-draft-placeholder">'
      + '<i class="fas fa-hard-hat"></i>'
      + '<h2>' + (en ? 'Under Construction' : 'En construction') + '</h2>'
      + '<p>' + (en
        ? 'This section is currently being written. Check back soon!'
        : 'Cette section est en cours de r\u00e9daction. Revenez bient\u00f4t\u00a0!')
      + '</p></div>';
  }

  function renderContent() {
    var c = content();
    var section = c[currentSection];
    if (!section) {
      currentSection = 'introduction';
      section = c['introduction'];
    }
    // In prod, show placeholder for draft sections
    if (!isDev() && isSectionDraft(currentSection)) {
      document.getElementById('doc-content-inner').innerHTML = draftPlaceholder();
    } else {
      document.getElementById('doc-content-inner').innerHTML = section;
    }
  }

  function renderAll() {
    renderSidebar();
    renderContent();
  }

  // ==================== EVENTS ====================

  function initEvents() {
    // Sidebar clicks use href hash links, handled by the router calling show()
  }

  function navigateTo(id) {
    Router.navigate('/documentation', { section: id });
  }

  // ==================== LIFECYCLE ====================

  function init() {
    if (initialized) return;
    initialized = true;
    initEvents();
  }

  function show(query) {
    init();
    var newSection = (query && query.section) || 'introduction';
    var changed = newSection !== currentSection;
    currentSection = newSection;
    renderAll();
    if (changed) {
      var el = document.getElementById('doc-content');
      if (el) el.scrollTop = 0;
    }
  }

  function hide() {}

  function onLanguageChange() {
    if (!initialized) return;
    renderAll();
  }

  return {
    show: show,
    hide: hide,
    onLanguageChange: onLanguageChange,
    navigateTo: navigateTo
  };
})();
