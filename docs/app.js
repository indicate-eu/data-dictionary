// shared.js — expose window.App for use by page-specific scripts
var App = (function() {
  'use strict';

  // App identity — the master upstream app, NOT the fork's dictionary.
  // These are intentionally not configurable: forks ride on this app version.
  // The dictionary's own identity (title, branding, organization) lives in config.json.
  var APP_NAME = 'INDICATE Data Dictionary';
  var APP_VERSION = '1.2.4';
  var APP_GITHUB_URL = 'https://github.com/indicate-eu/data-dictionary';

  // Config injected by build.py from config.json (root). Branding, GitHub repo of the fork, etc.
  var config = (typeof DATA !== 'undefined' && DATA.config) ? DATA.config : {};

  // Full URL of THIS dictionary's repo (the fork's own repo), e.g.
  // "https://github.com/indicate-eu/data-dictionary". Used to stamp metadata.sourceRepo
  // and origin.repo so provenance survives a copy to another repo. config.github may
  // carry either an `upstream` URL (…\.git) or an owner/repo `repo` slug; normalize both.
  function getConfigRepoUrl() {
    var gh = config.github || {};
    if (gh.upstream) return String(gh.upstream).replace(/\.git$/, '');
    if (gh.repo) return 'https://github.com/' + gh.repo;
    return '';
  }

  // ==================== STATE ====================
  var conceptSets = [];
  var projects = [];
  var unitConversions = [];
  var recommendedUnits = [];
  var mappingRecommendations = {};

  // localStorage may hold corrupted JSON (interrupted writes, manual edits) and
  // setItem can throw QuotaExceededError; neither must crash the module load —
  // an exception here would leave `App` undefined and brick the whole SPA.
  function safeParse(key, fallback) {
    try {
      var raw = localStorage.getItem(key);
      return raw == null ? fallback : JSON.parse(raw);
    } catch (e) {
      console.error('Ignoring corrupted localStorage value for ' + key + ':', e);
      return fallback;
    }
  }
  function safeSet(key, value) {
    try {
      localStorage.setItem(key, value);
      return true;
    } catch (e) {
      console.error('Failed to write localStorage key ' + key + ':', e);
      showToast(i18n('Saving locally failed (storage may be full). Your latest change may be lost on reload.'), 'error', 6000);
      return false;
    }
  }

  // Lang resolution order: URL (?lang=fr) → localStorage → 'en'. URL wins so
  // shared links open in the intended language even if the recipient previously
  // chose the other one in this browser.
  var lang = (function() {
    var fromUrl = (function() {
      var hash = window.location.hash || '';
      var qIdx = hash.indexOf('?');
      if (qIdx === -1) return null;
      var pairs = hash.substring(qIdx + 1).split('&');
      for (var i = 0; i < pairs.length; i++) {
        var kv = pairs[i].split('=');
        try {
          if (decodeURIComponent(kv[0]) === 'lang') {
            var v = decodeURIComponent(kv[1] || '');
            if (v === 'en' || v === 'fr') return v;
          }
        } catch (e) { /* malformed percent-encoding in a shared link — skip the pair */ }
      }
      return null;
    })();
    if (fromUrl) {
      localStorage.setItem('indicate_lang', fromUrl);
      return fromUrl;
    }
    return localStorage.getItem('indicate_lang') || 'en';
  })();
  var resolvedIndex = {}; // conceptSetId -> resolvedConcepts[]
  var resolvedDeferred = {}; // conceptSetId -> { count, promise? }
  var sessionReviews = safeParse('indicate_reviews', {});
  var languageChangeCallbacks = [];
  var beforeNavigateCallbacks = [];
  var homeCallbacks = [];
  var userConceptSets = safeParse('indicate_user_cs', []);
  var userProjects = safeParse('indicate_user_proj', []);
  // Mapping projects: local-only workspaces (a centre's source-to-concept-map +
  // eligibility evaluation against INDICATE projects). Stored only in
  // localStorage — they may contain centre-specific data and are never proposed
  // back to the repo.
  var mappingProjects = safeParse('indicate_mapping_projects', []);
  var modifiedCsIds = new Set(safeParse('indicate_modified_cs_ids', []));
  var modifiedProjIds = new Set(safeParse('indicate_modified_proj_ids', []));

  // Migrate legacy localStorage projects to the current schema:
  //  - very old flat format (name/description/justification) → translations
  //  - intermediate snake_case (short_description/long_description) → camelCase
  //  - group `name: {en,fr}` → group `translations: {en:{name}, fr:{name}}`
  (function migrateProjects() {
    var migrated = false;
    function camelizeTr(tr) {
      if (!tr || typeof tr !== 'object') return;
      Object.keys(tr).forEach(function(l) {
        var t = tr[l];
        if (!t || typeof t !== 'object') return;
        if ('short_description' in t) { t.shortDescription = t.short_description; delete t.short_description; migrated = true; }
        if ('long_description' in t) { t.longDescription = t.long_description; delete t.long_description; migrated = true; }
      });
    }
    userProjects.forEach(function(p) {
      if (!p.translations) {
        p.translations = {
          en: {
            name: p.name || '',
            shortDescription: p.description || '',
            longDescription: p.justification || ''
          },
          fr: { name: '', shortDescription: '', longDescription: '' }
        };
        delete p.name;
        delete p.description;
        delete p.justification;
        delete p.bibliography;
        migrated = true;
      } else {
        camelizeTr(p.translations);
      }
      (p.groups || []).forEach(function(g) {
        if (!g.translations && 'name' in g) {
          var nm = g.name;
          if (nm && typeof nm === 'object') {
            g.translations = { en: { name: nm.en || '' }, fr: { name: nm.fr || '' } };
          } else {
            g.translations = { en: { name: nm || '' }, fr: { name: nm || '' } };
          }
          delete g.name;
          migrated = true;
        }
      });
    });
    if (migrated) safeSet('indicate_user_proj', JSON.stringify(userProjects));
  })();

  // ==================== DATA LOADING ====================
  function loadData(callback) {
    reloadMergedData();
    unitConversions = DATA.unitConversions || [];
    recommendedUnits = DATA.recommendedUnits || [];
    mappingRecommendations = safeParse('indicate_user_mapping', null) || (DATA.mappingRecommendations || {});
    var resolved = DATA.resolvedConceptSets || [];
    resolved.forEach(function(r) {
      if (r.resolvedDeferred) {
        resolvedDeferred[r.conceptSetId] = { count: r.resolvedCount || 0 };
      } else {
        resolvedIndex[r.conceptSetId] = r.resolvedConcepts || [];
      }
    });
    document.getElementById('loading').classList.add('hidden');
    if (callback) callback();
  }

  // ==================== DATA UPDATE / MERGE ====================

  /** Build a fingerprint map: { id: "modifiedDate|version" } for each concept set in DATA */
  function buildCsFingerprints() {
    var fp = {};
    (DATA.conceptSets || []).forEach(function(cs) {
      fp[cs.id] = (cs.modifiedDate || '') + '|' + (cs.version || '');
    });
    return fp;
  }

  function saveCsFingerprints(fp) {
    localStorage.setItem('indicate_cs_fingerprints', JSON.stringify(fp));
  }

  // Merge repo data with local overrides: user-modified items replace the repo
  // version, hidden ones are excluded. Shared by loadData and the update flow.
  function reloadMergedData() {
    var hiddenIds = safeParse('indicate_hidden_cs', []);
    var hiddenSet = {};
    hiddenIds.forEach(function(id) { hiddenSet[id] = true; });
    var userIdSet = {};
    userConceptSets.forEach(function(cs) { userIdSet[cs.id] = true; });
    var repoCS = (DATA.conceptSets || []).filter(function(cs) { return !hiddenSet[cs.id] && !userIdSet[cs.id]; });
    conceptSets = repoCS.concat(userConceptSets);
    // Normalize metadata to the cross-repo-sharing schema (org → created/current,
    // default sourceRepo). Idempotent; covers both repo and user sets.
    conceptSets.forEach(normalizeConceptSetMeta);

    var hiddenProjIds = safeParse('indicate_hidden_proj', []);
    var hiddenProjSet = {};
    hiddenProjIds.forEach(function(id) { hiddenProjSet[id] = true; });
    var userProjIdSet = {};
    userProjects.forEach(function(p) { userProjIdSet[p.id] = true; });
    var repoProj = (DATA.projects || []).filter(function(p) { return !hiddenProjSet[p.id] && !userProjIdSet[p.id]; });
    projects = repoProj.concat(userProjects);
  }

  /**
   * Compare old fingerprints (stored) with new DATA to find what changed remotely.
   * Returns { remoteChanged: [{id, name, oldVersion, newVersion, oldDate, newDate}], newlyAdded: [...] }
   */
  function detectRemoteChanges(oldFingerprints) {
    var changes = { remoteChanged: [], newlyAdded: [] };
    var newFp = buildCsFingerprints();
    var remoteById = {};
    (DATA.conceptSets || []).forEach(function(cs) { remoteById[cs.id] = cs; });

    Object.keys(newFp).forEach(function(idStr) {
      var id = parseInt(idStr);
      var cs = remoteById[id];
      if (!cs) return;
      var csName = (cs.metadata && cs.metadata.translations && cs.metadata.translations[lang])
        ? cs.metadata.translations[lang].name : cs.name || '';
      if (!oldFingerprints[idStr]) {
        // New concept set added to repo
        changes.newlyAdded.push({ id: id, name: csName, version: cs.version || '?' });
      } else if (oldFingerprints[idStr] !== newFp[idStr]) {
        // Changed remotely
        var oldParts = oldFingerprints[idStr].split('|');
        changes.remoteChanged.push({
          id: id,
          name: csName,
          oldDate: oldParts[0] || '?',
          newDate: cs.modifiedDate || '?',
          oldVersion: oldParts[1] || '?',
          newVersion: cs.version || '?'
        });
      }
    });
    return changes;
  }

  /**
   * Compute merge for user-modified concept sets.
   * Returns { autoUpdated: [ids], conflicts: [{id, local, remote}], kept: [ids] }
   */
  function computeMerge() {
    var remoteById = {};
    (DATA.conceptSets || []).forEach(function(cs) { remoteById[cs.id] = cs; });

    var result = { autoUpdated: [], conflicts: [], kept: [] };

    userConceptSets.forEach(function(cs) {
      if (!remoteById[cs.id]) {
        // Locally created — keep
        result.kept.push(cs.id);
      } else if (modifiedCsIds.has(cs.id)) {
        // Modified locally AND exists in remote — conflict
        result.conflicts.push({ id: cs.id, local: cs, remote: remoteById[cs.id] });
      } else {
        // In user CS but not marked as modified — stale override, update silently
        result.autoUpdated.push(cs.id);
      }
    });

    return result;
  }

  function applySilentMerge(autoUpdatedIds) {
    var removeIds = {};
    autoUpdatedIds.forEach(function(id) { removeIds[id] = true; });
    userConceptSets = userConceptSets.filter(function(cs) { return !removeIds[cs.id]; });
    autoUpdatedIds.forEach(function(id) { modifiedCsIds.delete(id); });
    saveUserConceptSets();
    saveModifiedCsIds();
  }

  function showUpdateModal(changes, merge, newVersion, newHash) {
    var body = document.getElementById('data-update-body');
    if (!body) return;

    var hasConflicts = merge.conflicts.length > 0;
    var hasChanges = changes.remoteChanged.length > 0 || changes.newlyAdded.length > 0;

    // Header message
    var html = '';
    if (hasConflicts) {
      html += '<p style="margin-bottom:12px">' +
        i18n('New data has been published. Some concept sets you modified locally have also changed remotely.') + '</p>';
    } else {
      html += '<p style="margin-bottom:12px">' +
        i18n('The data dictionary has been updated.') + '</p>';
    }

    // Remote changes list (collapsible)
    if (hasChanges) {
      var totalChanges = changes.remoteChanged.length + changes.newlyAdded.length;
      html += '<details style="margin-bottom:12px">' +
        '<summary style="cursor:pointer; font-size:13px; font-weight:600; color:var(--primary); margin-bottom:6px">' +
        '<i class="fas fa-list"></i> ' + totalChanges + ' ' + i18n('concept set(s) changed remotely') + '</summary>';
      html += '<table class="table" style="font-size:12px; margin-top:4px"><thead><tr>' +
        '<th>ID</th><th>' + i18n('Name') + '</th><th>' + i18n('Version') + '</th><th>' + i18n('Modified') + '</th>' +
        '</tr></thead><tbody>';

      changes.remoteChanged.forEach(function(c) {
        html += '<tr>' +
          '<td>' + c.id + '</td>' +
          '<td>' + escapeHtml(c.name) + '</td>' +
          '<td>' + escapeHtml(c.oldVersion) + ' → ' + escapeHtml(c.newVersion) + '</td>' +
          '<td>' + escapeHtml(c.oldDate) + ' → ' + escapeHtml(c.newDate) + '</td>' +
          '</tr>';
      });
      changes.newlyAdded.forEach(function(c) {
        html += '<tr>' +
          '<td>' + c.id + '</td>' +
          '<td>' + escapeHtml(c.name) + '</td>' +
          '<td>' + escapeHtml(c.version) + '</td>' +
          '<td><span style="color:var(--accent-green); font-weight:600">' + i18n('New') + '</span></td>' +
          '</tr>';
      });

      html += '</tbody></table></details>';
    }

    // Conflicts table (if any)
    if (hasConflicts) {
      html += '<h4 style="font-size:13px; font-weight:600; margin:12px 0 6px">' + i18n('Conflicts') + '</h4>';
      html += '<p style="font-size:12px; color:var(--text-muted); margin-bottom:8px">' +
        i18n('These concept sets were modified both locally and remotely. Choose which version to keep:') + '</p>';
      if (merge.conflicts.length > 1) {
        html += '<div style="display:flex; gap:8px; margin-bottom:8px">' +
          '<button type="button" class="btn-cancel" id="merge-all-local" style="font-size:12px; padding:4px 10px">' + i18n('Keep all local') + '</button>' +
          '<button type="button" class="btn-cancel" id="merge-all-remote" style="font-size:12px; padding:4px 10px">' + i18n('Keep all remote') + '</button>' +
          '</div>';
      }
      html += '<table class="table" style="font-size:12px"><thead><tr>' +
        '<th>ID</th><th>' + i18n('Name') + '</th><th>' + i18n('Local') + '</th><th>' + i18n('Remote') + '</th><th>' + i18n('Keep') + '</th>' +
        '</tr></thead><tbody>';

      merge.conflicts.forEach(function(c) {
        var localName = t(c.local).name || c.local.name || '';
        html += '<tr>' +
          '<td>' + c.id + '</td>' +
          '<td>' + escapeHtml(localName) + '</td>' +
          '<td>' + escapeHtml(c.local.modifiedDate || '?') + '</td>' +
          '<td>' + escapeHtml(c.remote.modifiedDate || '?') + '</td>' +
          '<td style="white-space:nowrap">' +
            '<label style="margin-right:8px"><input type="radio" name="merge-' + c.id + '" value="local"> ' + i18n('Local') + '</label>' +
            '<label><input type="radio" name="merge-' + c.id + '" value="remote" checked> ' + i18n('Remote') + '</label>' +
          '</td></tr>';
      });

      html += '</tbody></table>';
    }

    body.innerHTML = html;

    // "Keep all local" / "Keep all remote" buttons
    var allLocalBtn = document.getElementById('merge-all-local');
    var allRemoteBtn = document.getElementById('merge-all-remote');
    if (allLocalBtn) {
      allLocalBtn.addEventListener('click', function() {
        body.querySelectorAll('input[type="radio"][value="local"]').forEach(function(r) { r.checked = true; });
      });
    }
    if (allRemoteBtn) {
      allRemoteBtn.addEventListener('click', function() {
        body.querySelectorAll('input[type="radio"][value="remote"]').forEach(function(r) { r.checked = true; });
      });
    }

    // Update button label based on whether there are conflicts
    var applyBtn = document.getElementById('data-update-apply');
    if (applyBtn) {
      var btnLabel = applyBtn.querySelector('span');
      if (btnLabel) btnLabel.textContent = hasConflicts ? i18n('Apply Updates') : i18n('OK');
    }

    document.getElementById('data-update-modal').style.display = '';

    // Store pending merge info for the apply handler
    pendingMerge = { merge: merge, newVersion: newVersion, newHash: newHash };
  }

  // Pending merge info between showUpdateModal and applyMergeDecisions
  var pendingMerge = null;

  function applyMergeDecisions() {
    var pending = pendingMerge;
    if (!pending) return;
    var merge = pending.merge;

    // Apply silent updates
    applySilentMerge(merge.autoUpdated);

    // Process conflict resolutions
    merge.conflicts.forEach(function(c) {
      var radios = document.querySelectorAll('input[name="merge-' + c.id + '"]');
      var choice = 'remote';
      radios.forEach(function(r) { if (r.checked) choice = r.value; });
      if (choice === 'remote') {
        userConceptSets = userConceptSets.filter(function(cs) { return cs.id !== c.id; });
        modifiedCsIds.delete(c.id);
      }
    });

    saveUserConceptSets();
    saveModifiedCsIds();
    localStorage.setItem('indicate_data_version', pending.newVersion);
    localStorage.setItem('indicate_data_hash', pending.newHash);
    saveCsFingerprints(buildCsFingerprints());
    reloadMergedData();

    document.getElementById('data-update-modal').style.display = 'none';
    pendingMerge = null;

    showToast(i18n('Data updated successfully'), 'success');
    // Trigger re-render on page modules
    languageChangeCallbacks.forEach(function(cb) { cb(); });
  }

  function checkForDataUpdate() {
    var currentVersion = DATA.dataVersion || null;
    var currentHash = DATA.dataHash || null;
    var lastKnownHash = localStorage.getItem('indicate_data_hash');

    // First visit — store version + fingerprints, no merge needed
    if (!lastKnownHash) {
      localStorage.setItem('indicate_data_version', currentVersion);
      localStorage.setItem('indicate_data_hash', currentHash);
      saveCsFingerprints(buildCsFingerprints());
      return;
    }

    // No content change (hash matches)
    if (currentHash && currentHash === lastKnownHash) {
      localStorage.setItem('indicate_data_version', currentVersion);
      return;
    }

    // Data changed — detect remote changes and compute merge
    var oldFingerprints = safeParse('indicate_cs_fingerprints', {});
    var changes = detectRemoteChanges(oldFingerprints);
    var merge = computeMerge();

    // Remove conflict and auto-updated IDs from the "changed remotely" list to avoid duplicates
    var excludeFromChanges = {};
    merge.conflicts.forEach(function(c) { excludeFromChanges[c.id] = true; });
    merge.autoUpdated.forEach(function(id) { excludeFromChanges[id] = true; });
    changes.remoteChanged = changes.remoteChanged.filter(function(c) { return !excludeFromChanges[c.id]; });
    changes.newlyAdded = changes.newlyAdded.filter(function(c) { return !excludeFromChanges[c.id]; });

    var hasConflicts = merge.conflicts.length > 0;
    var hasChanges = changes.remoteChanged.length > 0 || changes.newlyAdded.length > 0;

    if (!hasConflicts && !hasChanges && merge.autoUpdated.length === 0) {
      // Hash changed but nothing meaningful changed (e.g. rebuild without content changes)
      localStorage.setItem('indicate_data_version', currentVersion);
      localStorage.setItem('indicate_data_hash', currentHash);
      saveCsFingerprints(buildCsFingerprints());
      return;
    }

    // Always show modal so the user sees what changed
    showUpdateModal(changes, merge, currentVersion, currentHash);
  }

  // ==================== I18N DICTIONARY ====================
  var I18N = {
    // Navigation & Header
    'Data Dictionary':               { fr: 'Dictionnaire de données' },
    'Projects':                      { fr: 'Projets' },
    'Organization':                  { fr: 'Organisation' },
    'Guest':                         { fr: 'Invité' },
    'Reset':                         { fr: 'Réinitialiser' },
    'EN':                            { fr: 'EN' },
    'Dictionary Settings':           { fr: 'Paramètres du dictionnaire' },
    'Dev Tools':                     { fr: 'Outils de développement' },
    'Documentation':                 { fr: 'Documentation' },
    'Introduction':                  { fr: 'Introduction' },
    'Concept Sets':                  { fr: 'Jeux de concepts' },
    'Concept Set Details':           { fr: 'Détails d\'un jeu de concepts' },
    'Managing Projects':             { fr: 'Gestion des projets' },
    'Mapping Recommendations':       { fr: 'Recommandations de mapping' },
    'Concept Mapping':               { fr: 'Alignement de concepts' },
    'Settings':                      { fr: 'Paramètres' },
    'Getting Started':               { fr: 'Pour commencer' },
    'Features':                      { fr: 'Fonctionnalités' },
    'Contributing':                  { fr: 'Contribuer' },
    'Why a Data Dictionary?':        { fr: 'Pourquoi un dictionnaire de données ?' },
    'General Concepts Approach':     { fr: 'Approche par concepts généraux' },
    'Key Features':                  { fr: 'Fonctionnalités principales' },
    'Who is this for?':              { fr: 'À qui s\'adresse cette application ?' },
    'About the INDICATE Project':    { fr: 'À propos du projet INDICATE' },
    'Propose Changes on GitHub':     { fr: 'Proposer des modifications sur GitHub' },

    // Data update / merge
    'Data Update Available':         { fr: 'Mise \u00e0 jour disponible' },
    'Data updated successfully':     { fr: 'Donn\u00e9es mises \u00e0 jour avec succ\u00e8s' },
    'concept set(s) will be updated automatically': { fr: 'jeu(x) de concepts seront mis \u00e0 jour automatiquement' },
    'concept set(s) changed remotely': { fr: 'jeu(x) de concepts modifi\u00e9s \u00e0 distance' },
    'The data dictionary has been updated.': { fr: 'Le dictionnaire de donn\u00e9es a \u00e9t\u00e9 mis \u00e0 jour.' },
    'New data has been published. Some concept sets you modified locally have also changed remotely.':
      { fr: 'De nouvelles donn\u00e9es ont \u00e9t\u00e9 publi\u00e9es. Certains jeux de concepts que vous avez modifi\u00e9s localement ont aussi chang\u00e9 \u00e0 distance.' },
    'These concept sets were modified both locally and remotely. Choose which version to keep:':
      { fr: 'Ces jeux de concepts ont \u00e9t\u00e9 modifi\u00e9s \u00e0 la fois localement et \u00e0 distance. Choisissez la version \u00e0 conserver :' },
    'Conflicts':                     { fr: 'Conflits' },
    'Version':                       { fr: 'Version' },
    'Modified':                      { fr: 'Modifi\u00e9' },
    'New':                           { fr: 'Nouveau' },
    'Keep':                          { fr: 'Conserver' },
    'Keep all local':                { fr: 'Tout conserver en local' },
    'Keep all remote':               { fr: 'Tout conserver en distant' },
    'Local':                         { fr: 'Locale' },
    'Remote':                        { fr: 'Distante' },
    'Later':                         { fr: 'Plus tard' },
    'OK':                            { fr: 'OK' },
    'Apply Updates':                 { fr: 'Appliquer les mises \u00e0 jour' },

    // Common actions
    'Cancel':                        { fr: 'Annuler' },
    'Save':                          { fr: 'Enregistrer' },
    'Edit':                          { fr: 'Modifier' },
    'Delete':                        { fr: 'Supprimer' },
    'Back':                          { fr: 'Retour' },
    'Close':                         { fr: 'Fermer' },
    'Search':                        { fr: 'Rechercher' },
    'Export':                        { fr: 'Exporter' },
    'Create':                        { fr: 'Créer' },
    'Apply':                         { fr: 'Appliquer' },
    'Clear':                         { fr: 'Effacer' },
    'Submit':                        { fr: 'Soumettre' },
    'Filter...':                     { fr: 'Filtrer...' },
    'All':                           { fr: 'Tous' },
    'Loading...':                    { fr: 'Chargement...' },

    // Table headers
    'Category':                      { fr: 'Catégorie' },
    'Subcategory':                   { fr: 'Sous-catégorie' },
    'Name':                          { fr: 'Nom' },
    'Description':                   { fr: 'Description' },
    'Status':                        { fr: 'Statut' },
    'Concept ID':                    { fr: 'ID Concept' },
    'Vocabulary':                    { fr: 'Vocabulaire' },
    'Concept Name':                  { fr: 'Nom du concept' },
    'Concept Code':                  { fr: 'Code du concept' },
    'Domain':                        { fr: 'Domaine' },
    'Standard':                      { fr: 'Standard' },
    'Concept Class':                 { fr: 'Classe du concept' },
    'Date':                          { fr: 'Date' },
    'Reset to Template':             { fr: 'Réinitialiser le modèle' },

    // Status labels
    'Draft':                         { fr: 'Brouillon' },
    'Pending Review':                { fr: 'En attente de relecture' },
    'Approved':                      { fr: 'Approuvé' },
    'Needs Revision':                { fr: 'À réviser' },
    'Deprecated':                    { fr: 'Obsolète' },

    // Standard/Validity badges
    'Classification':                { fr: 'Classification' },
    'Non-standard':                  { fr: 'Non standard' },
    'Valid':                         { fr: 'Valide' },

    // Concept Sets page
    'Add Concept Set':               { fr: 'Ajouter un jeu de concepts' },
    'Select all':                    { fr: 'Tout sélectionner' },
    'Unselect all':                  { fr: 'Tout désélectionner' },
    'Delete selected':               { fr: 'Supprimer la sélection' },
    '0 selected':                    { fr: '0 sélectionné(s)' },
    'Concepts':                      { fr: 'Concepts' },
    'Comments':                      { fr: 'Commentaires' },
    'Statistics':                    { fr: 'Statistiques' },
    'Review':                        { fr: 'Relecture' },
    'Resolved':                      { fr: 'Résolus' },
    'Expression':                    { fr: 'Expression' },
    'Add Concepts':                  { fr: 'Ajouter des concepts' },
    'Add Concept':                   { fr: 'Ajouter le concept' },
    'Select':                        { fr: 'Sélectionner' },
    'Delete Selected':               { fr: 'Supprimer la sélection' },
    'Optimize':                      { fr: 'Optimiser' },
    'Columns':                       { fr: 'Colonnes' },
    'View JSON':                     { fr: 'Voir JSON' },
    'Exclude':                       { fr: 'Exclure' },
    'Descendants':                   { fr: 'Descendants' },
    'Mapped':                        { fr: 'Mappé' },

    // Concept detail
    'Excluded':                      { fr: 'Exclu' },
    'Mapped from':                   { fr: 'Mappé depuis' },
    'Maps to':                       { fr: 'Mappe vers' },

    // Distribution Statistics
    'Distribution Statistics':       { fr: 'Statistiques de distribution' },
    'Distribution Statistics (JSON)':{ fr: 'Statistiques de distribution (JSON)' },

    // Review tab
    'Reviews':                       { fr: 'Relectures' },
    'Add Review':                    { fr: 'Ajouter une relecture' },
    'Reviewer':                      { fr: 'Relecteur' },
    'No reviews yet. Click "Add Review" to submit the first review.': { fr: 'Aucune relecture. Cliquez sur « Ajouter une relecture » pour soumettre la première.' },

    // Comments
    'No description available':      { fr: 'Aucune description disponible' },
    'Editor':                        { fr: 'Éditeur' },
    'Preview':                       { fr: 'Aperçu' },
    'Preview will appear here...':   { fr: 'L\'aperçu apparaîtra ici...' },

    // Projects page
    'No description':                { fr: 'Pas de description' },
    'Actions':                       { fr: 'Actions' },
    'concept sets':                  { fr: 'jeux de concepts' },
    'AVAILABLE CONCEPT SETS':        { fr: 'JEUX DE CONCEPTS DISPONIBLES' },
    'PROJECT CONCEPT SETS':          { fr: 'JEUX DE CONCEPTS DU PROJET' },
    'Enter description (Markdown supported)...': { fr: 'Saisir la description (Markdown supporté)...' },
    'Enter justification (Markdown supported)...': { fr: 'Saisir la justification (Markdown supporté)...' },

    // Project modals
    'New Project':                   { fr: 'Nouveau projet' },
    'Edit Project':                  { fr: 'Modifier le projet' },
    'Delete Project':                { fr: 'Supprimer le projet' },
    'Project name':                  { fr: 'Nom du projet' },
    'Author name':                   { fr: 'Nom de l\'auteur' },
    'Name *':                        { fr: 'Nom *' },
    'Created By':                    { fr: 'Créé par' },
    'Are you sure you want to delete this project?': { fr: 'Êtes-vous sûr de vouloir supprimer ce projet ?' },
    'Add Project':                   { fr: 'Ajouter un projet' },
    'Search projects...':            { fr: 'Rechercher des projets...' },
    'Name (EN) *':                   { fr: 'Nom (EN) *' },
    'Name (FR)':                     { fr: 'Nom (FR)' },
    'Project name (English)':        { fr: 'Nom du projet (Anglais)' },
    'Project name (French)':         { fr: 'Nom du projet (Français)' },
    'Short description (EN)':        { fr: 'Description courte (EN)' },
    'Short description (FR)':        { fr: 'Description courte (FR)' },
    'Short description (English)':   { fr: 'Description courte (Anglais)' },
    'Short description (French)':    { fr: 'Description courte (Français)' },
    'Long description (EN)':         { fr: 'Description longue (EN)' },
    'Long description (FR)':         { fr: 'Description longue (FR)' },
    'Enter long description in English (Markdown supported)...': { fr: 'Saisir la description longue en anglais (Markdown supporté)...' },
    'Enter long description in French (Markdown supported)...': { fr: 'Saisir la description longue en français (Markdown supporté)...' },
    'Export CSV':                    { fr: 'Exporter CSV' },

    // Profile modal
    'Edit Profile':                  { fr: 'Modifier le profil' },
    'Select an existing author':     { fr: 'Sélectionner un auteur existant' },
    '— Custom —':                    { fr: '— Personnalisé —' },
    'First Name *':                  { fr: 'Prénom *' },
    'Last Name *':                   { fr: 'Nom *' },
    'Affiliation':                   { fr: 'Affiliation' },
    'Profession':                    { fr: 'Profession' },
    'ORCID':                         { fr: 'ORCID' },

    // Organization modal
    'Edit Organization':             { fr: 'Modifier l\'organisation' },
    'Organization Name *':           { fr: 'Nom de l\'organisation *' },
    'URL':                           { fr: 'URL' },

    // Reset modal
    'Reset local data':              { fr: 'Réinitialiser les données locales' },
    'This will clear your saved profile and all local data.': { fr: 'Ceci effacera votre profil enregistré et toutes les données locales.' },
    'This action cannot be undone.': { fr: 'Cette action est irréversible.' },

    // Export modal
    'Export Concept Set':            { fr: 'Exporter le jeu de concepts' },
    'Copy OHDSI JSON to Clipboard':  { fr: 'Copier le JSON OHDSI dans le presse-papiers' },
    'Copy the concept set in OHDSI-compliant JSON format to clipboard': { fr: 'Copier le jeu de concepts au format JSON OHDSI dans le presse-papiers' },
    'Download OHDSI JSON File':      { fr: 'Télécharger le fichier JSON OHDSI' },
    'Download the concept set as a JSON file following OHDSI specification': { fr: 'Télécharger le jeu de concepts au format JSON suivant la spécification OHDSI' },
    'Concept Set Specification':     { fr: 'Spécification du jeu de concepts' },
    'Full OHDSI format with metadata and translations': { fr: 'Format OHDSI complet avec métadonnées et traductions' },
    'ATLAS':                         { fr: 'ATLAS' },
    'ATLAS-compatible format (expression only)': { fr: 'Format compatible ATLAS (expression uniquement)' },
    'OMOP SQL Query':                { fr: 'Requête SQL OMOP' },
    'Copy OMOP SQL Query':           { fr: 'Copier la requête SQL OMOP' },
    'SQL query copied to clipboard!': { fr: 'Requête SQL copiée dans le presse-papiers !' },
    'SQL query to extract data from OMOP CDM tables, with unit conversions': { fr: 'Requête SQL pour extraire les données des tables OMOP CDM, avec conversions d\'unités' },

    // Bulk export modal
    'Export Concept Sets':           { fr: 'Exporter les jeux de concepts' },
    'Export All':                    { fr: 'Tout exporter' },
    'Download all concept sets as a single JSON file': { fr: 'Télécharger tous les jeux de concepts dans un seul fichier JSON' },
    'Export Selected':               { fr: 'Exporter la sélection' },
    'Download selected concept sets': { fr: 'Télécharger les jeux de concepts sélectionnés' },
    'Filter by Category':            { fr: 'Filtrer par catégorie' },
    'Export concept sets from a specific category': { fr: 'Exporter les jeux de concepts d\'une catégorie spécifique' },

    // New Concept Set modal
    'New Concept Set':               { fr: 'Nouveau jeu de concepts' },
    'e.g. Heart Rate':               { fr: 'ex. Fréquence cardiaque' },
    'Category *':                    { fr: 'Catégorie *' },
    'Select a category...':          { fr: 'Sélectionner une catégorie...' },
    'Select a subcategory...':       { fr: 'Sélectionner une sous-catégorie...' },
    'Brief description of the concept set...': { fr: 'Brève description du jeu de concepts...' },

    // Version modal
    'Message (optional)':            { fr: 'Message (optionnel)' },
    'Message':                       { fr: 'Message' },
    'Describe what changed...':      { fr: 'Décrivez les modifications...' },
    'Version History':               { fr: 'Historique des versions' },

    // Status modal
    'Change Status':                 { fr: 'Changer le statut' },

    // Import ATLAS JSON
    'Import ATLAS JSON':             { fr: 'Importer JSON ATLAS' },
    'Paste an ATLAS concept set expression JSON. Format: {"items": [...]}': { fr: 'Collez une expression JSON de jeu de concepts ATLAS. Format : {"items": [...]}' },

    // Optimize Expression
    'Optimize Expression':           { fr: 'Optimiser l\'expression' },
    'Analyzing hierarchy...':        { fr: 'Analyse de la hiérarchie...' },
    'Apply Optimization':            { fr: 'Appliquer l\'optimisation' },

    // Add Concepts modal
    'Load OHDSI vocabularies in Dictionary Settings to search concepts.': { fr: 'Chargez les vocabulaires OHDSI dans les Paramètres du dictionnaire pour rechercher des concepts.' },
    'Search concepts by name, code, or ID...': { fr: 'Rechercher des concepts par nom, code ou ID...' },
    'Filters':                       { fr: 'Filtres' },
    'Class':                         { fr: 'Classe' },
    'Valid only':                    { fr: 'Valides uniquement' },
    'Limit 10K':                     { fr: 'Limite 10K' },
    'Concept Details':               { fr: 'Détails du concept' },
    'Select a concept to view details': { fr: 'Sélectionnez un concept pour voir les détails' },
    'Hierarchy':                     { fr: 'Hiérarchie' },
    'Select a concept to view hierarchy': { fr: 'Sélectionnez un concept pour voir la hiérarchie' },
    'Multiple Selection':            { fr: 'Sélection multiple' },
    'This will load':                { fr: 'Cela va charger' },
    'concepts. This may be slow.':   { fr: 'concepts. Cela peut être lent.' },
    'Load all':                      { fr: 'Tout charger' },

    // Concept picker (Settings: Add Conversion / Add Recommended Unit)
    'Select a concept':              { fr: 'Sélectionner un concept' },
    'Select a unit':                 { fr: 'Sélectionner une unité' },
    'Select concept':                { fr: 'Sélectionner un concept' },
    'Select unit':                   { fr: 'Sélectionner une unité' },
    'No concept selected':           { fr: 'Aucun concept sélectionné' },
    'No unit selected':              { fr: 'Aucune unité sélectionnée' },
    'Concept *':                     { fr: 'Concept *' },
    'Source Unit *':                 { fr: 'Unité source *' },
    'Target Unit *':                 { fr: 'Unité cible *' },
    'Recommended Unit *':            { fr: 'Unité recommandée *' },
    'Clear all':                     { fr: 'Tout effacer' },
    'Remove filter':                 { fr: 'Retirer le filtre' },
    'Loading concepts...':           { fr: 'Chargement des concepts...' },
    'Delete this concept?':          { fr: 'Supprimer ce concept ?' },
    ' selected concepts':            { fr: ' concepts sélectionnés' },
    'Add':                           { fr: 'Ajouter' },
    'Edit':                          { fr: 'Modifier' },
    'Save':                          { fr: 'Enregistrer' },
    'Select all':                    { fr: 'Tout sélectionner' },
    'Unselect all':                  { fr: 'Tout désélectionner' },
    'Delete selected':              { fr: 'Supprimer la sélection' },
    'Unsaved changes':               { fr: 'Modifications non enregistrées' },
    'You have unsaved changes. Discard them and leave?': { fr: 'Vous avez des modifications non enregistrées. Les abandonner et quitter ?' },
    'Keep editing':                  { fr: 'Continuer l\'édition' },
    'Discard changes':               { fr: 'Abandonner les modifications' },
    'Edit Conversion':               { fr: 'Modifier la conversion' },
    'Edit Recommended Unit':         { fr: 'Modifier l\'unité recommandée' },
    'Save Changes':                  { fr: 'Enregistrer les modifications' },
    'target value = source value × factor + offset (offset is optional, default 0)': { fr: 'valeur cible = valeur source × facteur + offset (l\'offset est optionnel, 0 par défaut)' },

    // Confirm Delete
    'Confirm Delete':                { fr: 'Confirmer la suppression' },
    'This will only remove locally created concept sets. Repository concept sets cannot be deleted.': { fr: 'Seuls les jeux de concepts créés localement seront supprimés. Les jeux de concepts du dépôt ne peuvent pas être supprimés.' },
    'Create New Version':            { fr: 'Créer une nouvelle version' },
    'Import':                        { fr: 'Importer' },

    // Toast messages
    'Expression saved':              { fr: 'Expression enregistrée' },
    'Nothing to optimize':           { fr: 'Rien à optimiser' },
    'Comments saved':                { fr: 'Commentaires enregistrés' },
    'Statistics saved':              { fr: 'Statistiques enregistrées' },
    'Please paste JSON content.':    { fr: 'Veuillez coller du contenu JSON.' },
    'JSON must contain a non-empty "items" array.': { fr: 'Le JSON doit contenir un tableau "items" non vide.' },
    'Please set up your profile first (click on "Guest" in the header).': { fr: 'Veuillez d\'abord configurer votre profil (cliquez sur « Invité » dans l\'en-tête).' },
    'Please select a review status.': { fr: 'Veuillez sélectionner un statut de relecture.' },
    'Review comments are required.': { fr: 'Les commentaires de relecture sont requis.' },
    'Review submitted! Use "Propose on GitHub" to submit a pull request.': { fr: 'Relecture soumise ! Utilisez « Proposer sur GitHub » pour soumettre une pull request.' },
    'JSON copied to clipboard! Paste it in the GitHub editor.': { fr: 'JSON copié dans le presse-papiers ! Collez-le dans l\'éditeur GitHub.' },
    'Please enter a version number': { fr: 'Veuillez saisir un numéro de version' },
    'Copied to clipboard!':          { fr: 'Copié dans le presse-papiers !' },
    'Could not copy to clipboard. Try downloading the file instead.': { fr: 'Impossible de copier. Essayez de télécharger le fichier.' },
    'Changes saved':                 { fr: 'Modifications enregistrées' },
    'No concept sets selected.':     { fr: 'Aucun jeu de concepts sélectionné.' },
    'Name is required.':             { fr: 'Le nom est requis.' },
    'Category is required.':         { fr: 'La catégorie est requise.' },
    'First name and last name are required.': { fr: 'Le prénom et le nom sont requis.' },
    'Organization name is required.': { fr: 'Le nom de l\'organisation est requis.' },
    'Organization saved':            { fr: 'Organisation enregistrée' },
    'Project name is required.':     { fr: 'Le nom du projet est requis.' },
    'Project saved.':                { fr: 'Projet enregistré.' },
    'Optimization applied — review and save': { fr: 'Optimisation appliquée — vérifiez et enregistrez' },
    'Invalid JSON: ':                { fr: 'JSON invalide : ' },
    'Version updated to ':           { fr: 'Version mise à jour en ' },
    'Invalid version format — use X.Y.Z (e.g., 1.1.0).': { fr: 'Format de version invalide — utilisez X.Y.Z (ex. 1.1.0).' },
    'Status changed to ':            { fr: 'Statut changé en ' },
    'No concepts in this concept set': { fr: 'Aucun concept dans ce jeu de concepts' },
    'No concepts match the current filters.': { fr: 'Aucun concept ne correspond aux filtres actuels.' },
    'No description available for this concept set.': { fr: 'Aucune description disponible pour ce jeu de concepts.' },
    'No distribution statistics available for this concept set.': { fr: 'Aucune statistique de distribution disponible pour ce jeu de concepts.' },
    'Click <strong>Edit</strong> to add statistics, or compute them via the INDICATE Data Dictionary application.': { fr: 'Cliquez sur <strong>Modifier</strong> pour ajouter des statistiques, ou calculez-les via l\'application INDICATE Data Dictionary.' },
    'Loading vocabulary database...': { fr: 'Chargement de la base de vocabulaire...' },
    ' imported':                     { fr: ' importé(s)' },
    ' added':                        { fr: ' ajouté(s)' },
    ' skipped (duplicate or invalid)': { fr: ' ignoré(s) (doublon ou invalide)' },
    ' skipped (already in expression)': { fr: ' ignoré(s) (déjà dans l\'expression)' },
    ' concept set':                  { fr: ' jeu de concepts' },
    ' concept sets':                 { fr: ' jeux de concepts' },
    ' deleted.':                     { fr: ' supprimé(s).' },
    ' exported.':                    { fr: ' exporté(s).' },
    ' cannot be deleted.':           { fr: ' ne peut pas être supprimé(s).' },
    'Delete ':                       { fr: 'Supprimer ' },
    ' selected concept set':         { fr: ' jeu de concepts sélectionné' },
    ' selected concept sets':        { fr: ' jeux de concepts sélectionnés' },
    'Download ':                     { fr: 'Télécharger ' },
    'Concept set updated.':          { fr: 'Jeu de concepts mis à jour.' },
    'Concept set created.':          { fr: 'Jeu de concepts créé.' },
    'Project updated.':              { fr: 'Projet mis à jour.' },
    'Project created.':              { fr: 'Projet créé.' },
    'Project deleted.':              { fr: 'Projet supprimé.' },
    ' concept':                      { fr: ' concept' },
    ' concepts':                     { fr: ' concepts' },
    'repository ':                   { fr: 'du dépôt ' },

    // Settings
    'OHDSI Vocabularies':            { fr: 'Vocabulaires OHDSI' },
    'Saving locally failed (storage may be full). Your latest change may be lost on reload.': { fr: 'L\'enregistrement local a échoué (stockage plein ?). Votre dernière modification peut être perdue au rechargement.' },
    'Resolved concept data is not available for these versions, so the change list cannot be shown.': { fr: 'Les concepts résolus ne sont pas disponibles pour ces versions, la liste des changements ne peut pas être affichée.' },
    'Load a DuckDB (.duckdb) or SQLite (.sqlite / .db) database containing OMOP vocabulary tables.': { fr: 'Chargez une base de données DuckDB (.duckdb) ou SQLite (.sqlite / .db) contenant les tables de vocabulaire OMOP.' },
    'Load vocabulary database':      { fr: 'Charger la base de vocabulaire' },
    'No mapping recommendations available.': { fr: 'Aucune recommandation de mapping disponible.' },
    'Mapping recommendations saved.': { fr: 'Recommandations de mapping enregistrées.' },
    'Units':                         { fr: 'Unités' },
    'Recommended Units':             { fr: 'Unités recommandées' },
    'Unit Conversions':              { fr: 'Conversions d\'unités' },

    // Footer
    'Powered by':                    { fr: 'Propulsé par' },

    // Multi-select
    'selected':                      { fr: 'sélectionné(s)' },
    'Deselect all':                  { fr: 'Tout décocher' },

    // Review form
    'Submit Review':                 { fr: 'Soumettre la relecture' },
    'Propose on GitHub':             { fr: 'Proposer sur GitHub' },
    'Copy to clipboard and open GitHub editor': { fr: 'Copier dans le presse-papiers et ouvrir l\'éditeur GitHub' },
    'Download File':                 { fr: 'Télécharger le fichier' },
    'Copy to Clipboard':             { fr: 'Copier dans le presse-papiers' },
    'Export Mapping Recommendations': { fr: 'Exporter les Recommandations de Mapping' },
    'Export Project':                { fr: 'Exporter le Projet' },
    'Copy JSON to clipboard':        { fr: 'Copier le JSON dans le presse-papiers' },
    'Could not copy to clipboard.':  { fr: 'Impossible de copier dans le presse-papiers.' },
    '-- Select status --':           { fr: '-- Sélectionner un statut --' },
    'Status:':                       { fr: 'Statut :' },

    // Custom concepts
    'Custom Concept':                { fr: 'Concept personnalisé' },
    'Add Custom Concept':            { fr: 'Ajouter un concept personnalisé' },
    'Custom Concepts Added':         { fr: 'Concepts personnalisés ajoutés' },
    'No custom concepts added yet.': { fr: 'Aucun concept personnalisé ajouté.' },
    'Auto-assigned from 2,100,000,000': { fr: 'Auto-assigné à partir de 2 100 000 000' },
    'Enter concept name...':         { fr: 'Saisir le nom du concept...' },
    'Enter concept code (optional)...': { fr: 'Saisir le code du concept (optionnel)...' },
    'Custom concepts use the INDICATE vocabulary': { fr: 'Les concepts personnalisés utilisent le vocabulaire INDICATE' },
    '-- Select --':                  { fr: '-- Sélectionner --' },
    'Standard Concept':              { fr: 'Concept standard' },
    'Please enter a concept name.':  { fr: 'Veuillez saisir un nom de concept.' },
    'Please select a domain.':       { fr: 'Veuillez sélectionner un domaine.' },
    'Please select a concept class.': { fr: 'Veuillez sélectionner une classe.' },
    ' custom concept added':         { fr: ' concept personnalisé ajouté' },
    'Resolving concepts...':         { fr: 'Résolution des concepts...' },
    // Concept Mapping page
    'New mapping project':           { fr: 'Nouveau projet d\'alignement' },
    'Edit mapping project':          { fr: 'Modifier le projet d\'alignement' },
    'Mapping project created.':      { fr: 'Projet d\'alignement créé.' },
    'Mapping project updated.':      { fr: 'Projet d\'alignement mis à jour.' },
    'Mapping project deleted.':      { fr: 'Projet d\'alignement supprimé.' },
    'No mapping project yet. Create one to evaluate your eligibility to INDICATE projects.': { fr: 'Aucun projet d\'alignement pour le moment. Créez-en un pour évaluer votre éligibilité aux projets INDICATE.' },
    'No mapping project matches your search.': { fr: 'Aucun projet d\'alignement ne correspond à votre recherche.' },
    'No mapping data yet':           { fr: 'Aucune donnée d\'alignement pour le moment' },
    'No mapping data imported yet. Upload a CSV to populate this table.': { fr: 'Aucune donnée d\'alignement importée. Importez un CSV pour remplir ce tableau.' },
    'Untitled':                      { fr: 'Sans titre' },
    'mapped concepts':               { fr: 'concepts alignés' },
    'Mapped concepts':               { fr: 'Concepts alignés' },
    'Matched in dictionary':         { fr: 'Correspondances dans le dictionnaire' },
    'Eligible projects':             { fr: 'Projets éligibles' },
    'Eligibility per INDICATE project': { fr: 'Éligibilité par projet INDICATE' },
    'Import a CSV to see how your mapping covers each INDICATE project.': { fr: 'Importez un CSV pour voir comment votre alignement couvre chaque projet INDICATE.' },
    'No INDICATE projects to evaluate.': { fr: 'Aucun projet INDICATE à évaluer.' },
    'See coverage breakdown':        { fr: 'Voir le détail de la couverture' },
    'View coverage details':         { fr: 'Voir les détails de couverture' },
    'concept sets covered':          { fr: 'jeux de concepts couverts' },
    'Coverage:':                     { fr: 'Couverture :' },
    'Project score:':                { fr: 'Score du projet :' },
    'Project':                       { fr: 'Projet' },
    'Covered':                       { fr: 'Couvert' },
    'Not covered':                   { fr: 'Non couvert' },
    'All required':                  { fr: 'Tous requis' },
    'At least one':                  { fr: 'Au moins un' },
    'Optional':                      { fr: 'Optionnel' },
    'Yes':                           { fr: 'Oui' },
    'No':                            { fr: 'Non' },
    'Local concepts in this set':    { fr: 'Concepts locaux dans ce jeu' },
    'Resolved concepts in this set': { fr: 'Concepts résolus dans ce jeu' },
    'Other concepts in this set':    { fr: 'Autres concepts dans ce jeu' },
    'Not in vocabulary':             { fr: 'Absent du vocabulaire' },
    'in dictionary':                 { fr: 'dans le dictionnaire' },
    'local':                         { fr: 'local' },
    'other':                         { fr: 'autre' },
    'unique':                        { fr: 'uniques' },
    'unique concepts':               { fr: 'concepts uniques' },
    'Load OHDSI vocabularies to resolve': { fr: 'Chargez les vocabulaires OHDSI pour résoudre' },
    'Loading…':                      { fr: 'Chargement…' },
    'Select…':                       { fr: 'Sélectionner…' },
    'Download as mapping_recommendations.json': { fr: 'Télécharger en mapping_recommendations.json' },
    'Download as {file}':            { fr: 'Télécharger en {file}' },
    'A mapping project with this name already exists.': { fr: 'Un projet de mapping avec ce nom existe déjà.' },
    'A project with this name already exists.': { fr: 'Un projet avec ce nom existe déjà.' },
    'Click to view the full review':  { fr: 'Cliquez pour afficher la review complète' },
    'No comments in this review.':    { fr: 'Aucun commentaire dans cette review.' },
    'No reviews match the current filters.': { fr: 'Aucune review ne correspond aux filtres actuels.' },
    'The requested version {pinned} is not available (it was never published or snapshotted). The latest version is {latest}.': { fr: 'La version demandée {pinned} n\'est pas disponible (elle n\'a jamais été publiée ou snapshotée). La dernière version est {latest}.' },
    'This review targets the current version': { fr: 'Cette review porte sur la version en cours' },
    'This review targets an earlier version (current: {v}) — click to open it': { fr: 'Cette review porte sur une version antérieure (en cours : {v}) — cliquez pour l\'ouvrir' },
    'OMOP source_to_concept_map':    { fr: 'OMOP source_to_concept_map' },
    'Single-column concept_id list': { fr: 'Liste concept_id en une colonne' },
    'CSV with concept_id + source':  { fr: 'CSV avec concept_id + source' },
    'Imported {n} concepts.':        { fr: '{n} concepts importés.' },
    'rows with a valid concept_id':  { fr: 'lignes avec un concept_id valide' },
    'No valid concept_id rows found in the file.': { fr: 'Aucune ligne avec un concept_id valide trouvée dans le fichier.' },
    'Couldn\'t detect a usable concept_id column. Expected either an OMOP source_to_concept_map header, a concept_id column, or a single-column list of concept ids.': { fr: 'Impossible de détecter une colonne concept_id exploitable. Attendu : un en-tête OMOP source_to_concept_map, une colonne concept_id, ou une liste de concept ids en une seule colonne.' },
    'Failed to parse CSV: ':         { fr: 'Échec de l\'analyse du CSV : ' },
    'Failed to read the file.':      { fr: 'Échec de la lecture du fichier.' },
    'Showing the first 500 rows out of': { fr: 'Affichage des 500 premières lignes sur' },
    'shown':                         { fr: 'affichées' },

    // Concept detail — vocab tabs (Related / Hierarchy / Synonyms) & links
    'Related':                       { fr: 'Associés' },
    'Synonyms':                      { fr: 'Synonymes' },
    'No link available':             { fr: 'Aucun lien disponible' },
    'No link available (custom concept)': { fr: 'Aucun lien disponible (concept personnalisé)' },
    'No related concepts found.':    { fr: 'Aucun concept associé trouvé.' },
    'Error: ':                       { fr: 'Erreur : ' },
    'Relationship':                  { fr: 'Relation' },
    'of':                            { fr: 'sur' },
    'Load anyway':                   { fr: 'Charger quand même' },
    'This concept has':              { fr: 'Ce concept comporte' },
    'nodes in the hierarchy. Loading may be slow.': { fr: 'nœuds dans la hiérarchie. Le chargement peut être lent.' },
    'Concept not found in vocabulary database.': { fr: 'Concept introuvable dans la base de vocabulaire.' },
    'No hierarchy relationships found for this concept.': { fr: 'Aucune relation hiérarchique trouvée pour ce concept.' },
    'Back to previous concept':      { fr: 'Revenir au concept précédent' },
    'Zoom in':                       { fr: 'Zoom avant' },
    'Zoom out':                      { fr: 'Zoom arrière' },
    'Fit to view':                   { fr: 'Ajuster à la vue' },
    'Toggle fullscreen':             { fr: 'Basculer en plein écran' },
    'Exit fullscreen':               { fr: 'Quitter le plein écran' },
    'No synonyms found.':            { fr: 'Aucun synonyme trouvé.' },
    'Synonym':                       { fr: 'Synonyme' },
    'Language':                      { fr: 'Langue' },
    'Concept not found':             { fr: 'Concept introuvable' },
    'No hierarchy':                  { fr: 'Aucune hiérarchie' },
    'Numeric Summary':               { fr: 'Résumé numérique' },
    'Distribution':                  { fr: 'Distribution' },
    'Categories':                    { fr: 'Catégories' }
  };

  function i18n(key) {
    if (lang === 'en') return key;
    var entry = I18N[key];
    return (entry && entry[lang]) || key;
  }

  function formatDate(dateStr) {
    if (!dateStr) return '';
    // Input expected: YYYY-MM-DD
    var parts = dateStr.split('-');
    if (parts.length !== 3) return dateStr;
    if (lang === 'fr') return parts[2] + '/' + parts[1] + '/' + parts[0];
    return dateStr; // YYYY-MM-DD for EN
  }

  /** Translate all elements with data-i18n attributes */
  function translateDOM() {
    document.querySelectorAll('[data-i18n]').forEach(function(el) {
      el.textContent = i18n(el.getAttribute('data-i18n'));
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(function(el) {
      el.placeholder = i18n(el.getAttribute('data-i18n-placeholder'));
    });
    document.querySelectorAll('[data-i18n-title]').forEach(function(el) {
      el.title = i18n(el.getAttribute('data-i18n-title'));
    });
  }

  // ==================== HELPERS ====================
  function t(cs) {
    var tr = cs.metadata && cs.metadata.translations;
    return (tr && tr[lang]) || (tr && tr.en) || {};
  }

  function tProj(proj) {
    var tr = proj.translations;
    return (tr && tr[lang]) || (tr && tr.en) || {};
  }

  function tMappingProject(mp) {
    var tr = mp && mp.translations;
    return (tr && tr[lang]) || (tr && tr.en) || {};
  }

  function escapeHtml(s) {
    if (s == null) return '';
    if (typeof s !== 'string') s = String(s);
    return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
  }

  var toastIcons = { error: 'fa-circle-exclamation', success: 'fa-circle-check', warning: 'fa-triangle-exclamation', info: 'fa-circle-info' };
  function showToast(message, type, duration) {
    type = type || 'info';
    duration = duration || 3000;
    var container = document.getElementById('toast-container');
    var toast = document.createElement('div');
    toast.className = 'toast toast-' + type;
    toast.innerHTML = '<i class="fas ' + (toastIcons[type] || toastIcons.info) + '"></i><span>' + escapeHtml(message) + '</span><button class="toast-close" aria-label="Close">&times;</button>';
    container.appendChild(toast);
    var timer = setTimeout(function() { dismissToast(toast); }, duration);
    toast.querySelector('.toast-close').addEventListener('click', function() {
      clearTimeout(timer);
      dismissToast(toast);
    });
  }
  function dismissToast(toast) {
    if (toast.classList.contains('toast-fade-out')) return;
    toast.classList.add('toast-fade-out');
    setTimeout(function() { toast.remove(); }, 300);
  }

  function renderMarkdown(s) {
    if (!s) return '';
    if (typeof marked !== 'undefined' && marked.parse) {
      var renderer = new marked.Renderer();
      renderer.link = function(token) {
        var h = typeof token === 'object' ? token.href : token;
        var ti = typeof token === 'object' ? token.title : arguments[1];
        var tx = typeof token === 'object' ? token.text : arguments[2];
        if (h && !/^(https?:|mailto:|#)/i.test(String(h).trim())) h = '';
        var t = ti ? ' title="' + escapeHtml(ti) + '"' : '';
        return '<a href="' + escapeHtml(h) + '"' + t + ' target="_blank" rel="noopener noreferrer">' + escapeHtml(tx || '') + '</a>';
      };
      // Syntax-highlight fenced code blocks (e.g. ```sql) when highlight.js is loaded.
      renderer.code = function(token, infoString) {
        var code = typeof token === 'object' ? token.text : token;
        var lang = typeof token === 'object' ? token.lang : infoString;
        lang = (lang || '').match(/\S*/)[0];
        if (typeof hljs !== 'undefined' && lang && hljs.getLanguage(lang)) {
          try {
            var out = hljs.highlight(code, { language: lang, ignoreIllegals: true }).value;
            return '<pre><code class="hljs language-' + escapeHtml(lang) + '">' + out + '</code></pre>';
          } catch (e) { /* fall through to plain rendering */ }
        }
        return '<pre><code' + (lang ? ' class="language-' + escapeHtml(lang) + '"' : '') + '>' + escapeHtml(code) + '</code></pre>';
      };
      var html = marked.parse(s, { renderer: renderer });
      if (typeof DOMPurify !== 'undefined' && DOMPurify.sanitize) {
        html = DOMPurify.sanitize(html, { ADD_ATTR: ['target'] });
      }
      return html;
    }
    // Fallback if marked not loaded
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

  // Numeric-aware semantic version compare ("1.10.0" > "1.2.0"). Non-numeric
  // segments fall back to string comparison.
  function compareVersions(a, b) {
    var pa = String(a || '').split('.');
    var pb = String(b || '').split('.');
    var n = Math.max(pa.length, pb.length);
    for (var i = 0; i < n; i++) {
      var x = pa[i] || '0', y = pb[i] || '0';
      var nx = parseInt(x, 10), ny = parseInt(y, 10);
      if (!isNaN(nx) && !isNaN(ny)) {
        if (nx !== ny) return nx - ny;
      } else if (x !== y) {
        return x < y ? -1 : 1;
      }
    }
    return 0;
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

  function statusLabel(status) {
    return i18n(statusLabelsMap[status] || status);
  }

  function statusBadge(status) {
    if (!status) status = 'draft';
    return '<span class="status-badge ' + escapeHtml(status) + '">' + escapeHtml(statusLabel(status)) + '</span>';
  }

  function truncate(s, n) {
    if (!s) return '';
    return s.length > n ? s.substring(0, n) + '...' : s;
  }

  // Plain (translated) label for a concept's Standard flag — used both for the
  // badge text and as the data-tooltip on its cell, so a clipped badge can be
  // read in full on hover.
  function standardLabel(concept) {
    var sc = concept.standardConcept;
    return i18n(sc === 'S' ? 'Standard' : (sc === 'C' ? 'Classification' : 'Non-standard'));
  }
  function standardBadge(concept) {
    var sc = concept.standardConcept;
    if (sc === 'S') return '<span class="badge badge-standard">' + escapeHtml(i18n('Standard')) + '</span>';
    if (sc === 'C') return '<span class="badge badge-classification">' + escapeHtml(i18n('Classification')) + '</span>';
    return '<span class="badge badge-non-standard">' + escapeHtml(i18n('Non-standard')) + '</span>';
  }

  function validBadge(concept) {
    var v = concept.invalidReasonCaption;
    if (v === 'Valid') return '<span class="badge badge-valid">' + escapeHtml(i18n('Valid')) + '</span>';
    return '<span class="badge badge-invalid">' + escapeHtml(v) + '</span>';
  }

  // ==================== MULTI-SELECT DROPDOWN ====================
  function buildMultiSelectDropdown(containerId, values, selectedSet, onChange, labelMap) {
    var container = document.getElementById(containerId);
    if (!container) return;
    function getLabel(v) { return labelMap ? (labelMap[v] || v) : v; }
    function toggleLabel() {
      if (selectedSet.size === 0) return i18n('All');
      if (selectedSet.size === 1) return escapeHtml(getLabel([...selectedSet][0]));
      return selectedSet.size + ' ' + i18n('selected');
    }
    var showSearch = values.length > 10;
    container.innerHTML =
      '<div class="ms-toggle" tabindex="0">' + toggleLabel() + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i></div>' +
      '<div class="ms-dropdown" style="display:none">' +
        (showSearch ? '<div class="ms-search-wrap"><input type="text" class="ms-search" placeholder="' + escapeHtml(i18n('Search')) + '…"></div>' : '') +
        '<div class="ms-bulk-actions"><button type="button" class="ms-btn-all">' + escapeHtml(i18n('Select all')) + '</button><button type="button" class="ms-btn-none">' + escapeHtml(i18n('Deselect all')) + '</button></div>' +
        '<div class="ms-options">' +
          values.map(function(v) {
            return '<label class="ms-option"><input type="checkbox" value="' + escapeHtml(v) + '"' + (selectedSet.has(v) ? ' checked' : '') + '> ' + escapeHtml(getLabel(v) || '(empty)') + '</label>';
          }).join('') +
        '</div>' +
      '</div>';
    var toggle = container.querySelector('.ms-toggle');
    var dropdown = container.querySelector('.ms-dropdown');
    var searchInput = container.querySelector('.ms-search');
    var isInFilterRow = !!container.closest('.filter-row');
    toggle.addEventListener('click', function(e) {
      e.stopPropagation();
      document.querySelectorAll('.ms-dropdown').forEach(function(d) { if (d !== dropdown) d.style.display = 'none'; });
      var wasHidden = dropdown.style.display === 'none';
      if (wasHidden) {
        var trect = toggle.getBoundingClientRect();
        if (isInFilterRow) {
          dropdown.style.left = trect.left + 'px';
          dropdown.style.top = trect.bottom + 'px';
          dropdown.style.minWidth = Math.max(180, trect.width) + 'px';
        }
        // Clamp the dropdown so it never spills past the bottom of the viewport,
        // however short the window is. It opens below the toggle (top:100%), so
        // the room available is from the toggle's bottom to the window bottom,
        // minus a small margin. A CSS max-height can't know the toggle's runtime
        // position, so we set it here on open. Cleared on close so CSS caps win
        // again when there's plenty of room.
        var avail = Math.floor(window.innerHeight - trect.bottom - 12);
        dropdown.style.maxHeight = Math.max(160, avail) + 'px';
      } else {
        dropdown.style.maxHeight = '';
      }
      dropdown.style.display = wasHidden ? '' : 'none';
      if (wasHidden && searchInput) { searchInput.value = ''; searchInput.dispatchEvent(new Event('input')); searchInput.focus(); }
    });
    if (searchInput) {
      searchInput.addEventListener('input', function() {
        var q = searchInput.value.toLowerCase();
        container.querySelectorAll('.ms-option').forEach(function(opt) {
          var label = opt.textContent.toLowerCase();
          opt.style.display = label.indexOf(q) !== -1 ? '' : 'none';
        });
      });
      searchInput.addEventListener('click', function(e) { e.stopPropagation(); });
      searchInput.addEventListener('keydown', function(e) {
        if (e.key !== 'Enter') return;
        e.preventDefault();
        var visible = [].filter.call(container.querySelectorAll('.ms-option'), function(opt) {
          return opt.style.display !== 'none';
        });
        if (visible.length !== 1) return;
        var cb = visible[0].querySelector('input[type="checkbox"]');
        if (!cb) return;
        cb.checked = !cb.checked;
        cb.dispatchEvent(new Event('change', { bubbles: true }));
        dropdown.style.display = 'none';
        dropdown.style.maxHeight = '';
      });
    }
    var btnAll = dropdown.querySelector('.ms-btn-all');
    var btnNone = dropdown.querySelector('.ms-btn-none');
    function refreshCheckboxes() {
      dropdown.querySelectorAll('.ms-option input[type="checkbox"]').forEach(function(cb) {
        cb.checked = selectedSet.has(cb.value);
      });
      toggle.innerHTML = toggleLabel() + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i>';
      onChange();
    }
    btnAll.addEventListener('click', function(e) {
      e.stopPropagation();
      var visibleOptions = dropdown.querySelectorAll('.ms-option');
      visibleOptions.forEach(function(opt) {
        if (opt.style.display !== 'none') {
          var cb = opt.querySelector('input[type="checkbox"]');
          if (cb) selectedSet.add(cb.value);
        }
      });
      refreshCheckboxes();
    });
    btnNone.addEventListener('click', function(e) {
      e.stopPropagation();
      var visibleOptions = dropdown.querySelectorAll('.ms-option');
      visibleOptions.forEach(function(opt) {
        if (opt.style.display !== 'none') {
          var cb = opt.querySelector('input[type="checkbox"]');
          if (cb) selectedSet.delete(cb.value);
        }
      });
      refreshCheckboxes();
    });
    dropdown.addEventListener('change', function(e) {
      var cb = e.target;
      // The search input inside the dropdown also fires `change` on blur —
      // its undefined `checked` would silently deselect a same-named value.
      if (cb.type !== 'checkbox') return;
      if (cb.checked) selectedSet.add(cb.value); else selectedSet.delete(cb.value);
      toggle.innerHTML = toggleLabel() + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i>';
      onChange();
    });
  }

  function updateMsToggleLabel(containerId, selectedSet, labelMap) {
    var container = document.getElementById(containerId);
    if (!container) return;
    var toggle = container.querySelector('.ms-toggle');
    if (toggle) {
      function getLabel(v) { return labelMap ? (labelMap[v] || v) : v; }
      toggle.innerHTML = (selectedSet.size === 0 ? i18n('All') : selectedSet.size === 1 ? escapeHtml(getLabel([...selectedSet][0])) : selectedSet.size + ' ' + i18n('selected')) + ' <i class="fas fa-chevron-down" style="font-size:9px;margin-left:2px"></i>';
    }
  }

  /**
   * Shared project-card markup (Projects page + Mapping page).
   * opts: { id, menuIdPrefix, extraClass?, title, description?, footer: [{icon, text}] }
   * The card carries an Edit/Delete menu; click wiring stays page-local.
   */
  function projectCard(opts) {
    var id = escapeHtml(String(opts.id));
    return '<div class="project-card' + (opts.extraClass ? ' ' + opts.extraClass : '') + '" data-id="' + id + '">' +
      '<button class="project-card-menu-btn" data-menu-id="' + id + '" title="' + escapeHtml(i18n('Actions')) + '"><i class="fas fa-ellipsis-v"></i></button>' +
      '<div class="project-card-menu" id="' + opts.menuIdPrefix + id + '">' +
        '<button class="project-card-menu-item" data-action="edit" data-id="' + id + '"><i class="fas fa-pen"></i> ' + i18n('Edit') + '</button>' +
        '<button class="project-card-menu-item danger" data-action="delete" data-id="' + id + '"><i class="fas fa-trash"></i> ' + i18n('Delete') + '</button>' +
      '</div>' +
      '<h3>' + escapeHtml(opts.title || '') + '</h3>' +
      '<p title="' + escapeHtml(opts.description || '') + '">' + escapeHtml(opts.description || i18n('No description')) + '</p>' +
      '<div class="project-card-footer">' +
        (opts.footer || []).map(function(f) {
          return '<span><i class="fas ' + f.icon + '"></i> ' + escapeHtml(f.text) + '</span>';
        }).join('') +
      '</div>' +
    '</div>';
  }

  /**
   * Shared concept-list row (diff modal, mapping coverage modal): sign chip +
   * Athena link + name + vocabulary badge. opts: { sign, color, bg }.
   */
  function conceptListLine(c, opts) {
    var url = 'https://athena.ohdsi.org/search-terms/terms/' + c.conceptId;
    return '<li style="display:flex; align-items:center; gap:6px; padding:3px 0; font-size:13px">' +
      '<span style="display:inline-block; width:16px; text-align:center; font-weight:700; color:' + opts.color + '; background:' + opts.bg + '; border-radius:3px">' + opts.sign + '</span>' +
      '<a href="' + url + '" target="_blank" rel="noopener" style="font-family:monospace; font-size:12px; color:var(--text-muted)">' + c.conceptId + '</a>' +
      '<span style="flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap" title="' + escapeHtml(c.conceptName || '') + '">' + escapeHtml(c.conceptName || '') + '</span>' +
      '<span class="badge badge-vocab" style="font-size:11px">' + escapeHtml(c.vocabularyId || '') + '</span>' +
    '</li>';
  }

  /** Stamp modifiedDate (today) and modifiedBy (profile name, when set) on a concept set. */
  function stampModified(obj) {
    obj.modifiedDate = new Date().toISOString().slice(0, 10);
    var p = getUserProfile();
    var name = ((p.firstName || '') + ' ' + (p.lastName || '')).trim();
    if (name) obj.modifiedBy = name;
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
    if (el) el.textContent = name || i18n('Guest');
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
    select.innerHTML = '<option value="">' + escapeHtml(i18n('— Custom —')) + '</option>';
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
    // Organization fields
    var org = getOrganization() || detectDefaultOrganization() || {};
    document.getElementById('org-name').value = org.name || '';
    document.getElementById('org-url').value = org.url || '';
    // Reset to author tab
    var tabs = document.querySelectorAll('.profile-modal-tab');
    tabs.forEach(function(t) { t.classList.toggle('active', t.getAttribute('data-profile-tab') === 'author'); });
    document.getElementById('profile-tab-author').style.display = '';
    document.getElementById('profile-tab-organization').style.display = 'none';
    document.getElementById('profile-modal').style.display = '';
  }

  function closeProfileModal() {
    document.getElementById('profile-modal').style.display = 'none';
  }

  function saveProfileFromModal() {
    // Check which tab is active to validate accordingly
    var authorTabVisible = document.getElementById('profile-tab-author').style.display !== 'none';
    if (authorTabVisible) {
      var firstName = document.getElementById('profile-firstName').value.trim();
      var lastName = document.getElementById('profile-lastName').value.trim();
      if (!firstName || !lastName) {
        showToast(i18n('First name and last name are required.'), 'error');
        return;
      }
    }
    // Save author profile
    var firstName = document.getElementById('profile-firstName').value.trim();
    var lastName = document.getElementById('profile-lastName').value.trim();
    if (firstName && lastName) {
      saveUserProfile({
        firstName: firstName,
        lastName: lastName,
        affiliation: document.getElementById('profile-affiliation').value.trim(),
        profession: document.getElementById('profile-profession').value.trim(),
        orcid: document.getElementById('profile-orcid').value.trim()
      });
    }
    // Save organization
    var orgName = document.getElementById('org-name').value.trim();
    if (orgName) {
      saveOrganization({
        name: orgName,
        url: document.getElementById('org-url').value.trim()
      });
    }
    closeProfileModal();
  }

  // ==================== ORGANIZATION ====================
  function getOrganization() {
    try {
      var saved = JSON.parse(localStorage.getItem('indicate_organization') || 'null');
      if (saved) return saved;
      return detectDefaultOrganization();
    } catch(e) { return null; }
  }

  function saveOrganization(org) {
    try { localStorage.setItem('indicate_organization', JSON.stringify(org)); } catch(e) {}
  }

  function detectDefaultOrganization() {
    var orgs = {};
    conceptSets.forEach(function(cs) {
      var o = csCreatedOrg(cs);
      if (o && o.name) {
        var key = o.name.toLowerCase();
        if (!orgs[key]) orgs[key] = o;
      }
    });
    var keys = Object.keys(orgs);
    if (keys.length === 1) return orgs[keys[0]];
    return null;
  }

  // Read the creator org from a concept set, tolerating both the legacy flat
  // `organization: {name,url}` shape and the current `{created, current}` shape.
  function csCreatedOrg(cs) {
    var o = cs && cs.metadata && cs.metadata.organization;
    if (!o) return null;
    return o.created || o; // {created,current} → created; flat → itself
  }

  // Normalize a concept set's metadata in place to the cross-repo-sharing schema:
  //  - organization: flat {name,url} → {created, current} (both = the old value)
  //  - sourceRepo: default to this repo's URL when absent (so legacy/imported sets
  //    without it still carry a provenance pointer)
  // Idempotent; safe to run on every load. See ISSUE: cross-repo sharing.
  function normalizeConceptSetMeta(cs) {
    if (!cs || !cs.metadata) return cs;
    var m = cs.metadata;
    var o = m.organization;
    if (o && !('created' in o) && !('current' in o)) {
      // legacy flat {name,url} → split (creator and current owner both = original)
      m.organization = { created: { name: o.name || '', url: o.url || '' },
                         current: { name: o.name || '', url: o.url || '' } };
    } else if (o && ('created' in o) && !('current' in o)) {
      m.organization = { created: o.created, current: o.created };
    }
    if (m.sourceRepo == null) m.sourceRepo = getConfigRepoUrl();
    return cs;
  }

  // ==================== SHARED EXPORT ====================
  var pendingExport = null;

  function openExportModal(exportData) {
    pendingExport = exportData;
    var titleEl = document.getElementById('settings-export-title');
    titleEl.textContent = exportData.title || 'Export';
    document.getElementById('settings-export-clipboard-desc').textContent = exportData.clipboardDesc || 'Copy content to clipboard';
    document.getElementById('settings-export-file-desc').textContent = exportData.fileDesc || ('Download as ' + exportData.filename);
    var githubOption = document.getElementById('settings-export-github-option');
    githubOption.style.display = exportData.githubUrl ? '' : 'none';
    document.getElementById('settings-export-modal').style.display = 'flex';
  }

  function executeExport(method) {
    if (!pendingExport) return;
    if (method === 'github') {
      navigator.clipboard.writeText(pendingExport.content).then(function() {
        showToast(i18n('JSON copied to clipboard! Paste it in the GitHub editor.'), 'success', 5000);
      }).catch(function() {});
      window.open(pendingExport.githubUrl, '_blank');
    } else if (method === 'clipboard') {
      navigator.clipboard.writeText(pendingExport.content).then(function() {
        showToast(i18n('Copied to clipboard!'), 'success');
      }).catch(function() {
        showToast(i18n('Could not copy to clipboard.'), 'error');
      });
    } else {
      var blob = new Blob([pendingExport.content], { type: pendingExport.type });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      a.download = pendingExport.filename;
      a.click();
      // Deferred: revoking synchronously can abort the download in some browsers.
      setTimeout(function() { URL.revokeObjectURL(url); }, 0);
    }
    document.getElementById('settings-export-modal').style.display = 'none';
    pendingExport = null;
  }

  // Rewrite the current URL hash to reflect the active language as a query
  // param: `lang=fr` when French, removed entirely when English (default).
  // Other query params on the current route are preserved. Uses replaceState
  // so the change is not pushed onto the history stack and doesn't re-route.
  function updateLangInUrl() {
    var hash = window.location.hash || '';
    if (!hash) return;
    var qIdx = hash.indexOf('?');
    var path = qIdx === -1 ? hash : hash.substring(0, qIdx);
    var pairs = qIdx === -1 ? [] : hash.substring(qIdx + 1).split('&').filter(Boolean);
    var kept = [];
    for (var i = 0; i < pairs.length; i++) {
      var kv = pairs[i].split('=');
      if (decodeURIComponent(kv[0]) !== 'lang') kept.push(pairs[i]);
    }
    if (lang !== 'en') kept.unshift('lang=fr');
    var newHash = kept.length ? (path + '?' + kept.join('&')) : path;
    if (newHash === hash) return;
    var url = window.location.pathname + window.location.search + newHash;
    if (Router && Router.replaceState) {
      // langAlreadyHandled=true: newHash already encodes the active language
      // (lang=fr present, or deliberately absent for English). Without this,
      // replaceState would re-inject lang=fr from the stale current URL when
      // switching FR→EN, leaving the URL stuck on lang=fr.
      Router.replaceState(url, true);
    } else {
      history.replaceState(null, '', url);
    }
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
        updateLangInUrl();
        translateDOM();
        updateUserBadge();
        languageChangeCallbacks.forEach(function(cb) { cb(); });
      });
    }

    // User profile modal events (tabbed: author + organization)
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

    // Profile modal tab switching
    var profileTabBtns = document.querySelectorAll('.profile-modal-tab');
    profileTabBtns.forEach(function(btn) {
      btn.addEventListener('click', function() {
        var tab = btn.getAttribute('data-profile-tab');
        profileTabBtns.forEach(function(b) { b.classList.toggle('active', b === btn); });
        document.getElementById('profile-tab-author').style.display = (tab === 'author') ? '' : 'none';
        document.getElementById('profile-tab-organization').style.display = (tab === 'organization') ? '' : 'none';
      });
    });

    var profileModal = document.getElementById('profile-modal');
    if (profileModal) {
      profileModal.addEventListener('click', function(e) {
        if (e.target === profileModal) closeProfileModal();
      });
    }

    // Reset cache (now in settings dropdown)
    var resetLink = document.getElementById('reset-cache-link');
    if (resetLink) {
      resetLink.addEventListener('click', function(e) {
        e.preventDefault();
        // Close settings dropdown
        var menu = document.getElementById('nav-settings-menu');
        if (menu) menu.style.display = 'none';
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

    // Data update modal
    var dataUpdateApply = document.getElementById('data-update-apply');
    if (dataUpdateApply) {
      dataUpdateApply.addEventListener('click', applyMergeDecisions);
    }
    var dataUpdateLater = document.getElementById('data-update-later');
    if (dataUpdateLater) {
      dataUpdateLater.addEventListener('click', function() {
        document.getElementById('data-update-modal').style.display = 'none';
      });
    }
    var dataUpdateClose = document.getElementById('data-update-close');
    if (dataUpdateClose) {
      dataUpdateClose.addEventListener('click', function() {
        document.getElementById('data-update-modal').style.display = 'none';
      });
    }
    var dataUpdateModal = document.getElementById('data-update-modal');
    if (dataUpdateModal) {
      dataUpdateModal.addEventListener('click', function(e) {
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

    // Close multi-select, column-visibility and nav dropdowns on outside click
    document.addEventListener('click', function(e) {
      if (!e.target.closest('.ms-container')) {
        document.querySelectorAll('.ms-dropdown').forEach(function(d) { d.style.display = 'none'; });
      }
      if (!e.target.closest('.col-vis-dropdown')) {
        document.querySelectorAll('.col-vis-dropdown').forEach(function(d) { d.style.display = 'none'; });
      }
      if (!e.target.closest('.nav-dropdown')) {
        var menu = document.getElementById('nav-settings-menu');
        if (menu) menu.style.display = 'none';
      }
    });

    // Shared export modal
    var exportModal = document.getElementById('settings-export-modal');
    if (exportModal) {
      document.getElementById('settings-export-modal-close').addEventListener('click', function() {
        exportModal.style.display = 'none';
      });
      document.getElementById('settings-export-cancel').addEventListener('click', function() {
        exportModal.style.display = 'none';
      });
      exportModal.addEventListener('click', function(e) {
        if (e.target === exportModal) exportModal.style.display = 'none';
      });
      exportModal.querySelectorAll('.export-option').forEach(function(opt) {
        opt.addEventListener('click', function() {
          executeExport(opt.dataset.method);
        });
      });
    }

    // Header logo/title click -> go home (with unsaved-changes check)
    var headerLeft = document.querySelector('.header-left');
    if (headerLeft && headerLeft.tagName !== 'A') {
      headerLeft.addEventListener('click', function() {
        for (var i = 0; i < beforeNavigateCallbacks.length; i++) {
          if (beforeNavigateCallbacks[i]() === false) return;
        }
        // Navigate to concept sets list and force show even if already on that route
        var current = Router.getCurrentRoute();
        if (current && current.path === '/concept-sets' && !current.query.cs && !current.query.id) {
          // Already on list view, trigger homeCallbacks to close detail if open
          for (var j = 0; j < homeCallbacks.length; j++) homeCallbacks[j]();
        } else {
          Router.navigate('/concept-sets');
          // Also trigger homeCallbacks to ensure detail closes
          for (var j = 0; j < homeCallbacks.length; j++) homeCallbacks[j]();
        }
      });
    }
  }

  // ==================== USER CONCEPT SETS ====================
  function nextConceptSetId() {
    var maxId = 0;
    conceptSets.forEach(function(cs) { if (cs.id > maxId) maxId = cs.id; });
    var repoFloor = (DATA && DATA.nextConceptSetId) || 0;
    var localFloor = parseInt(localStorage.getItem('indicate_next_cs_id') || '0', 10);
    var next = Math.max(maxId + 1, repoFloor, localFloor);
    localStorage.setItem('indicate_next_cs_id', String(next + 1));
    return next;
  }

  function saveUserConceptSets() {
    safeSet('indicate_user_cs', JSON.stringify(userConceptSets));
  }

  function addConceptSet(cs) {
    conceptSets.push(cs);
    userConceptSets.push(cs);
    saveUserConceptSets();
  }

  function updateConceptSet(cs) {
    // Cross-repo sharing: editing here makes THIS repo/org the current maintainer.
    // Refresh sourceRepo to this repo and organization.current to my org; never
    // touch organization.created (authorship) or origin (frozen at import).
    normalizeConceptSetMeta(cs);
    if (cs.metadata) {
      cs.metadata.sourceRepo = getConfigRepoUrl();
      var myOrg = getOrganization();
      if (myOrg && myOrg.name) {
        if (!cs.metadata.organization) cs.metadata.organization = { created: myOrg, current: myOrg };
        else cs.metadata.organization.current = myOrg;
      }
    }
    for (var i = 0; i < conceptSets.length; i++) {
      if (conceptSets[i].id === cs.id) { conceptSets[i] = cs; break; }
    }
    // Promote to userConceptSets if not already there
    var found = false;
    for (var j = 0; j < userConceptSets.length; j++) {
      if (userConceptSets[j].id === cs.id) { userConceptSets[j] = cs; found = true; break; }
    }
    if (!found) userConceptSets.push(cs);
    saveUserConceptSets();
    // Track as locally modified if it's a repo concept set
    var isRepoCs = (DATA.conceptSets || []).some(function(rc) { return rc.id === cs.id; });
    if (isRepoCs) { modifiedCsIds.add(cs.id); saveModifiedCsIds(); }
  }

  function deleteConceptSets(ids) {
    var idSet = {};
    ids.forEach(function(id) { idSet[id] = true; });
    userConceptSets = userConceptSets.filter(function(cs) { return !idSet[cs.id]; });
    var before = conceptSets.length;
    conceptSets = conceptSets.filter(function(cs) { return !idSet[cs.id]; });
    var deleted = before - conceptSets.length;
    // Track deleted repo IDs so they stay hidden on reload. The hidden list only
    // ever filters repo sets, so locally-created ids are not added to it.
    var hidden = safeParse('indicate_hidden_cs', []);
    ids.forEach(function(id) {
      var isRepo = (DATA.conceptSets || []).some(function(rc) { return rc.id === id; });
      if (isRepo && hidden.indexOf(id) < 0) hidden.push(id);
    });
    safeSet('indicate_hidden_cs', JSON.stringify(hidden));
    saveUserConceptSets();
    return { deleted: deleted };
  }

  function isUserConceptSet(id) {
    return userConceptSets.some(function(cs) { return cs.id === id; });
  }

  function restoreConceptSets(allSnapshot, userSnapshot) {
    conceptSets.length = 0;
    allSnapshot.forEach(function(cs) { conceptSets.push(cs); });
    userConceptSets = userSnapshot;
    saveUserConceptSets();
  }

  // ==================== USER PROJECTS ====================
  function nextProjectId() {
    var maxId = 0;
    projects.forEach(function(p) { if (p.id > maxId) maxId = p.id; });
    var repoFloor = (DATA && DATA.nextProjectId) || 0;
    var localFloor = parseInt(localStorage.getItem('indicate_next_proj_id') || '0', 10);
    var next = Math.max(maxId + 1, repoFloor, localFloor);
    localStorage.setItem('indicate_next_proj_id', String(next + 1));
    return next;
  }

  function saveUserProjects() {
    safeSet('indicate_user_proj', JSON.stringify(userProjects));
  }

  function saveModifiedCsIds() {
    safeSet('indicate_modified_cs_ids', JSON.stringify(Array.from(modifiedCsIds)));
  }
  function saveModifiedProjIds() {
    safeSet('indicate_modified_proj_ids', JSON.stringify(Array.from(modifiedProjIds)));
  }

  function addProject(proj) {
    projects.push(proj);
    userProjects.push(proj);
    saveUserProjects();
  }

  function updateProject(proj) {
    for (var i = 0; i < projects.length; i++) {
      if (projects[i].id === proj.id) { projects[i] = proj; break; }
    }
    var found = false;
    for (var j = 0; j < userProjects.length; j++) {
      if (userProjects[j].id === proj.id) { userProjects[j] = proj; found = true; break; }
    }
    if (!found) userProjects.push(proj);
    saveUserProjects();
    var isRepoProj = (DATA.projects || []).some(function(rp) { return rp.id === proj.id; });
    if (isRepoProj) { modifiedProjIds.add(proj.id); saveModifiedProjIds(); }
  }

  function deleteProject(id) {
    userProjects = userProjects.filter(function(p) { return p.id !== id; });
    projects = projects.filter(function(p) { return p.id !== id; });
    var hidden = safeParse('indicate_hidden_proj', []);
    if (hidden.indexOf(id) < 0) hidden.push(id);
    safeSet('indicate_hidden_proj', JSON.stringify(hidden));
    saveUserProjects();
  }

  // ==================== MAPPING PROJECTS (localStorage only) ====================
  function saveMappingProjects() {
    safeSet('indicate_mapping_projects', JSON.stringify(mappingProjects));
  }
  function getMappingProjects() {
    return mappingProjects;
  }
  function getMappingProject(id) {
    for (var i = 0; i < mappingProjects.length; i++) {
      if (mappingProjects[i].id === id) return mappingProjects[i];
    }
    return null;
  }
  function addMappingProject(mp) {
    mappingProjects.push(mp);
    saveMappingProjects();
  }
  function updateMappingProject(mp) {
    var found = false;
    for (var i = 0; i < mappingProjects.length; i++) {
      if (mappingProjects[i].id === mp.id) { mappingProjects[i] = mp; found = true; break; }
    }
    if (!found) mappingProjects.push(mp);
    saveMappingProjects();
  }
  function deleteMappingProject(id) {
    mappingProjects = mappingProjects.filter(function(mp) { return mp.id !== id; });
    saveMappingProjects();
  }

  // ==================== VERSIONED CONCEPT SETS ====================
  /**
   * Return the concept set object for (id, version). If `version` is falsy or matches
   * the current source version, returns the live concept set from `conceptSets`.
   * Otherwise returns the snapshot from DATA.conceptSetVersions[id][version], or null.
   */
  function getConceptSet(id, version) {
    var live = conceptSets.find(function(cs) { return cs.id === id; });
    if (!version) return live || null;
    if (live && live.version === version) return live;
    var snaps = (DATA.conceptSetVersions || {})[String(id)];
    if (snaps && snaps[version]) return snaps[version];
    return null;
  }

  /**
   * Return the resolved concept list for (id, version). Falls back to current resolved
   * data when version matches latest or is omitted. Returns null if a versioned snapshot
   * is requested but missing.
   */
  function getResolvedConceptSet(id, version) {
    var live = conceptSets.find(function(cs) { return cs.id === id; });
    if (!version || (live && live.version === version)) {
      return resolvedIndex[id] || null;
    }
    var snaps = (DATA.resolvedConceptSetVersions || {})[String(id)];
    if (snaps && snaps[version]) return snaps[version].resolvedConcepts || [];
    return null;
  }

  /** Return the latest known version of concept set `id` (live or null). */
  function getLatestVersion(id) {
    var cs = conceptSets.find(function(c) { return c.id === id; });
    return cs ? (cs.version || '') : '';
  }

  // Group rule constants
  var GROUP_RULES = ['all_required', 'at_least_one', 'optional'];
  var DEFAULT_GROUP_RULE = 'all_required';

  /**
   * Return the flat list of {id, version} entries pinned by a project, traversing
   * groups when present. Falls back to the legacy flat `conceptSets` array, then
   * to the very old `conceptSetIds` array of bare ids.
   */
  function getProjectConceptSetEntries(proj) {
    if (!proj) return [];
    if (Array.isArray(proj.groups)) {
      var out = [];
      proj.groups.forEach(function(g) {
        if (g && Array.isArray(g.conceptSets)) {
          g.conceptSets.forEach(function(e) { out.push(e); });
        }
      });
      return out;
    }
    if (Array.isArray(proj.conceptSets)) return proj.conceptSets;
    if (Array.isArray(proj.conceptSetIds)) {
      return proj.conceptSetIds.map(function(id) {
        return { id: id, version: getLatestVersion(id) };
      });
    }
    return [];
  }

  /**
   * Return the groups of a project, normalizing legacy projects (flat `conceptSets`
   * or `conceptSetIds`) into a single synthetic "Default" group with rule
   * `all_required`. The returned array is always a live reference to `proj.groups`
   * when the project already uses the new format; for legacy projects it is a
   * freshly built array (not persisted back to `proj`).
   */
  function getProjectGroups(proj) {
    if (!proj) return [];
    if (Array.isArray(proj.groups)) return proj.groups;
    var entries = [];
    if (Array.isArray(proj.conceptSets)) {
      entries = proj.conceptSets.slice();
    } else if (Array.isArray(proj.conceptSetIds)) {
      entries = proj.conceptSetIds.map(function(id) {
        return { id: id, version: getLatestVersion(id) };
      });
    }
    return [{
      id: 'group-default',
      translations: { en: { name: 'Default' }, fr: { name: 'Par défaut' } },
      rule: DEFAULT_GROUP_RULE,
      conceptSets: entries
    }];
  }

  /**
   * Replace `proj.groups` with the provided groups array, removing any legacy
   * `conceptSets` / `conceptSetIds` fields so the project is canonicalized to
   * the new schema on save.
   */
  function setProjectGroups(proj, groups) {
    if (!proj) return;
    proj.groups = Array.isArray(groups) ? groups : [];
    delete proj.conceptSets;
    delete proj.conceptSetIds;
  }

  /** Translate a group's name, with sensible fallbacks.
   *  Reads the current language-first shape `group.translations.{lang}.name`,
   *  and falls back to the legacy shapes for localStorage projects created
   *  before the schema change: `group.name` as a {en,fr} object, or a bare string. */
  function getGroupName(group, l) {
    if (!group) return '';
    var key = l || lang;
    var tr = group.translations;
    if (tr) {
      return (tr[key] && tr[key].name) || (tr.en && tr.en.name) || (tr.fr && tr.fr.name) || '';
    }
    // Legacy fallbacks
    if (group.name && typeof group.name === 'object') {
      return group.name[key] || group.name.en || group.name.fr || '';
    }
    return group.name || '';
  }

  /** Generate a unique group id within the given project's existing groups. */
  function newGroupId(proj) {
    var existing = {};
    (proj && Array.isArray(proj.groups) ? proj.groups : []).forEach(function(g) {
      if (g && g.id) existing[g.id] = true;
    });
    var n = (proj && Array.isArray(proj.groups) ? proj.groups.length : 0) + 1;
    var id = 'group-' + n;
    while (existing[id]) { n += 1; id = 'group-' + n; }
    return id;
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
        description: tr.shortDescription || '',
        reviewStatus: (cs.metadata && cs.metadata.reviewStatus) || 'draft',
        version: cs.version || '',
        concepts: (cs.expression && cs.expression.items) ? cs.expression.items.length : 0,
        modified: cs.modifiedDate || cs.createdDate || '',
        raw: cs
      };
    });
  }

  // ==================== COLUMN RESIZE ====================
  /**
   * Make table columns resizable by adding drag handles to header cells.
   * Call once per table. Handles are added to the first <tr> in <thead>.
   * Widths are locked on first drag so hidden tables work correctly.
   * @param {string} tableId - the table element id
   */
  function initColResize(tableId, opts) {
    var table = document.getElementById(tableId);
    if (!table || table._colResizeInit) return;
    table._colResizeInit = true;
    // Marks the table as resizable so the faint column boundaries show (CSS),
    // independent of whether widths have been frozen yet (col-resizable).
    table.classList.add('has-col-resize');

    var headerRow = table.querySelector('thead tr');
    if (!headerRow) return;
    var ths = Array.prototype.slice.call(headerRow.querySelectorAll('th'));

    function lockWidths() {
      if (table.classList.contains('col-resizable')) return;
      // Measure the CURRENT rendered widths FIRST, while the table is still
      // table-layout:auto. Reading offsetWidth after switching to
      // table-layout:fixed would capture the post-relayout widths instead, so
      // every column would visibly jump the instant the user merely pressed on
      // a boundary (before any drag). Snapshot, then apply, then switch.
      var widths = ths.map(function(th) {
        // Hidden columns (offsetWidth 0) keep their inline width so revealing
        // them later restores the intended size — don't freeze them at 0.
        return (th.offsetParent === null || th.offsetWidth === 0) ? null : th.offsetWidth;
      });
      ths.forEach(function(th, i) {
        if (widths[i] != null) th.style.width = widths[i] + 'px';
      });
      table.classList.add('col-resizable');
    }

    // Optionally engage table-layout:fixed immediately (so cell-truncate takes effect
    // before the user drags). We add the `col-resizable` class but do NOT freeze
    // widths in px — the table keeps its inline %-based widths, which means the
    // table stays within its container and toggling columns redistributes width
    // proportionally rather than triggering horizontal scroll. The first drag will
    // call lockWidths() and switch to absolute px widths from there.
    if (opts && opts.lockNow) {
      table.classList.add('col-resizable');
    }

    // Measure the natural (unwrapped) text width of an element's content using a
    // canvas 2D context with the element's own font — fast and layout-free.
    // Adds the element's own horizontal padding + borders + letter-spacing so a
    // badge (e.g. category/subcategory pills, which have padding + border-radius)
    // is measured at its rendered width, not just its bare text — otherwise the
    // auto-fit comes out ~16px short and the badge gets clipped with an ellipsis.
    var _measureCanvas = null;
    function textWidth(el) {
      if (!el) return 0;
      var text = (el.textContent || '').trim();
      if (!text) return 0;
      var cs = getComputedStyle(el);
      var font = cs.fontWeight + ' ' + cs.fontSize + ' ' + cs.fontFamily;
      if (!_measureCanvas) _measureCanvas = document.createElement('canvas');
      var ctx = _measureCanvas.getContext('2d');
      ctx.font = font;
      var w = ctx.measureText(text).width;
      // letter-spacing applies between glyphs; canvas measureText ignores it.
      var ls = parseFloat(cs.letterSpacing);
      if (ls && text.length > 1) w += ls * (text.length - 1);
      // Box extras: the element's own padding + border on both sides.
      w += (parseFloat(cs.paddingLeft) || 0) + (parseFloat(cs.paddingRight) || 0)
         + (parseFloat(cs.borderLeftWidth) || 0) + (parseFloat(cs.borderRightWidth) || 0);
      return w;
    }

    // Minimum width a column may be shrunk TO when stealing space for an
    // auto-fit. Columns already narrower than this are never touched.
    var COL_MIN_W = 70;

    // Double-click a boundary → fit the LEFT column to its full content width.
    // Growth steals width from the columns to its right, each only down to
    // COL_MIN_W (and never from ones already below it). If the column has slack
    // (content narrower than current), it shrinks and hands the space back to
    // the immediate right neighbour. The table's total width never changes.
    function autoFitColumn(th, colIdx) {
      lockWidths();
      // Header label width: prefer the translatable label span; otherwise the th
      // itself (its sort-icon "▲" adds a few px — fine, never under-measures).
      var labelEl = th.querySelector('[data-i18n]') || th;
      var max = textWidth(labelEl);
      var rows = table.querySelectorAll('tbody tr');
      for (var r = 0; r < rows.length; r++) {
        var cell = rows[r].children[colIdx];
        if (!cell) continue;
        // Measure the single inner element (badge/span) so its own padding +
        // border is counted; fall back to the cell's text when it has no single
        // wrapper child. textWidth() already includes the measured element's
        // padding, so a badge no longer comes out short.
        var inner = cell.children.length === 1 ? cell.children[0] : cell;
        max = Math.max(max, textWidth(inner));
      }
      var pad = 24; // cell (td) horizontal padding (both sides) + a little slack
      var contentW = Math.ceil(max) + pad;   // width to show content in full
      var curW = th.offsetWidth;

      // Visible (non-hidden) columns to the right of this one.
      var rightThs = [];
      for (var i = colIdx + 1; i < ths.length; i++) {
        if (ths[i].offsetWidth > 0) rightThs.push(ths[i]);
      }

      if (contentW <= curW) {
        // Slack: shrink to fit content (floor at COL_MIN_W); give space to the
        // first right column so the table total stays constant.
        var shrunk = Math.max(COL_MIN_W, contentW);
        if (shrunk === curW) return;
        if (rightThs.length) rightThs[0].style.width = (rightThs[0].offsetWidth + (curW - shrunk)) + 'px';
        th.style.width = shrunk + 'px';
        return;
      }

      // Grow: how much can we reclaim from the right columns (each down to floor)?
      var want = contentW - curW;
      var available = 0;
      rightThs.forEach(function(t) { available += Math.max(0, t.offsetWidth - COL_MIN_W); });
      var steal = Math.min(want, available);
      if (steal <= 0) return; // no room to grow without violating the floor

      // Distribute the steal across right columns proportionally to their slack.
      // Track the actual total taken so the grown column matches exactly (no
      // rounding drift that would overflow the table).
      var remaining = steal;
      var taken = 0;
      for (var j = 0; j < rightThs.length && remaining > 0; j++) {
        var t = rightThs[j];
        var slack = Math.max(0, t.offsetWidth - COL_MIN_W);
        if (slack <= 0) continue;
        var take = (j === rightThs.length - 1) ? remaining : Math.min(slack, Math.round(steal * (slack / available)));
        take = Math.min(take, slack, remaining);
        t.style.width = (t.offsetWidth - take) + 'px';
        remaining -= take;
        taken += take;
      }
      th.style.width = (curW + taken) + 'px';
    }

    // Make the resize handle span the FULL header height (label + filter rows)
    // so its hover highlight is continuous across both rows, matching the
    // static boundary borders. The label th is position:relative; we extend the
    // absolutely-positioned handle down past the th by the header's extra height.
    var thead = table.querySelector('thead');
    function sizeHandles() {
      if (!thead) return;
      var headH = thead.getBoundingClientRect().height;
      // Table not laid out yet (e.g. in a hidden tab/detail view): bail rather
      // than freezing the handles at height 0 — which would leave the column
      // boundaries invisible until something else forced a reflow. A
      // ResizeObserver re-runs this the moment the thead gains real height.
      if (headH === 0) return;
      table.querySelectorAll('.col-resize-handle').forEach(function(h) {
        var thH = h.parentElement.getBoundingClientRect().height;
        // height = full thead, so the handle covers the filter row too.
        h.style.height = Math.max(thH, Math.round(headH)) + 'px';
      });
    }
    // Re-size the handles whenever the header's box changes — crucially, when
    // the table goes from hidden (height 0) to visible, so the boundary lines
    // appear as soon as the user opens the tab/detail without needing a manual
    // reflow (the "they show up only when I open devtools" symptom).
    if (thead && typeof ResizeObserver === 'function') {
      new ResizeObserver(sizeHandles).observe(thead);
    }

    // Add resize handles
    ths.forEach(function(th, idx) {
      if (idx === ths.length - 1) return; // skip last column
      var handle = document.createElement('div');
      handle.className = 'col-resize-handle';
      th.appendChild(handle);

      // Double-click the boundary → auto-fit the column to its left (this th).
      handle.addEventListener('dblclick', function(e) {
        e.preventDefault();
        e.stopPropagation();
        autoFitColumn(th, idx);
      });

      handle.addEventListener('mousedown', function(e) {
        e.preventDefault();
        e.stopPropagation();
        lockWidths();
        handle.classList.add('dragging');
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
        var MIN_W = 40;
        var startX = e.clientX;
        var startW = th.offsetWidth;
        // Resize against the nearest VISIBLE column to the right (skip hidden
        // ones, whose width is 0). The boundary only ever trades width between
        // these two columns, so the table's total width is conserved and it can
        // never grow past the container (which would push content off-screen).
        var nextTh = null;
        for (var k = idx + 1; k < ths.length; k++) {
          if (ths[k].offsetWidth > 0) { nextTh = ths[k]; break; }
        }
        var nextStartW = nextTh ? nextTh.offsetWidth : 0;

        function onMove(ev) {
          var dx = ev.clientX - startX;
          if (nextTh) {
            // Clamp dx so neither column drops below MIN_W. Growing th is paid
            // for entirely by shrinking nextTh — so dx can't exceed the slack
            // nextTh has above MIN_W, nor shrink th below MIN_W.
            dx = Math.min(dx, nextStartW - MIN_W);
            dx = Math.max(dx, MIN_W - startW);
            th.style.width = (startW + dx) + 'px';
            nextTh.style.width = (nextStartW - dx) + 'px';
          } else {
            // No column to the right to trade with: just respect the minimum.
            th.style.width = Math.max(MIN_W, startW + dx) + 'px';
          }
        }
        function onUp() {
          handle.classList.remove('dragging');
          document.body.style.cursor = '';
          document.body.style.userSelect = '';
          document.removeEventListener('mousemove', onMove);
          document.removeEventListener('mouseup', onUp);
          // Swallow the click that fires on the <th> right after mouseup,
          // otherwise the parent th's sort handler would trigger.
          var swallow = function(ev) {
            ev.stopPropagation();
            ev.preventDefault();
            window.removeEventListener('click', swallow, true);
          };
          window.addEventListener('click', swallow, true);
        }
        document.addEventListener('mousemove', onMove);
        document.addEventListener('mouseup', onUp);
      });
    });

    // Size handles to span both header rows. Defer one frame so the thead has
    // laid out (filter row may render after init), then keep it fresh on resize.
    if (typeof requestAnimationFrame === 'function') requestAnimationFrame(sizeHandles);
    else sizeHandles();
    window.addEventListener('resize', sizeHandles);
  }

  // ==================== PUBLIC API ====================
  return {
    APP_NAME: APP_NAME,
    APP_VERSION: APP_VERSION,
    APP_GITHUB_URL: APP_GITHUB_URL,
    // Provenance tag written to createdByTool / modifiedByTool, e.g.
    // "INDICATE Data Dictionary v1.2.1 (https://github.com/indicate-eu/data-dictionary)"
    toolTag: function() { return APP_NAME + ' v' + APP_VERSION + ' (' + APP_GITHUB_URL + ')'; },
    config: config,
    github: function(path) {
      var repo = (config.github && config.github.repo) || '';
      var branch = (config.github && config.github.branch) || 'main';
      var p = path || '';
      return 'https://github.com/' + repo + '/' + p.replace(/^\//, '').replace(/^edit\//, 'edit/' + branch + '/').replace(/^blob\//, 'blob/' + branch + '/');
    },
    githubEdit: function(filePath) {
      var repo = (config.github && config.github.repo) || '';
      var branch = (config.github && config.github.branch) || 'main';
      return 'https://github.com/' + repo + '/edit/' + branch + '/' + filePath.replace(/^\//, '');
    },
    githubBlob: function(filePath) {
      var repo = (config.github && config.github.repo) || '';
      var branch = (config.github && config.github.branch) || 'main';
      return 'https://github.com/' + repo + '/blob/' + branch + '/' + filePath.replace(/^\//, '');
    },
    // State getters/setters
    get conceptSets() { return conceptSets; },
    get projects() { return projects; },
    get unitConversions() { return unitConversions; },
    get recommendedUnits() { return recommendedUnits; },
    get mappingRecommendations() { return mappingRecommendations; },
    set mappingRecommendations(v) { mappingRecommendations = v; safeSet('indicate_user_mapping', JSON.stringify(v)); },
    getMappingContent: function(l) {
      var t = (mappingRecommendations || {}).translations || {};
      return (t[l || lang] || {}).content || '';
    },
    setMappingContent: function(content, l) {
      if (!mappingRecommendations) mappingRecommendations = {};
      if (!mappingRecommendations.translations) mappingRecommendations.translations = {};
      var key = l || lang;
      if (!mappingRecommendations.translations[key]) mappingRecommendations.translations[key] = {};
      mappingRecommendations.translations[key].content = content;
      safeSet('indicate_user_mapping', JSON.stringify(mappingRecommendations));
    },
    get lang() { return lang; },
    set lang(v) { lang = v; },
    get resolvedIndex() { return resolvedIndex; },
    get resolvedDeferred() { return resolvedDeferred; },
    fetchResolved: function(conceptSetId) {
      // Return cached if already loaded
      if (resolvedIndex[conceptSetId]) {
        return Promise.resolve(resolvedIndex[conceptSetId]);
      }
      // Return in-flight promise if already fetching
      var def = resolvedDeferred[conceptSetId];
      if (def && def.promise) return def.promise;
      if (!def) def = resolvedDeferred[conceptSetId] = { count: 0 };
      // Fetch from individual file
      var url = 'concept_sets_resolved/' + conceptSetId + '.json';
      var promise = fetch(url).then(function(resp) {
        if (!resp.ok) throw new Error('HTTP ' + resp.status);
        return resp.json();
      }).then(function(data) {
        var concepts = data.resolvedConcepts || [];
        resolvedIndex[conceptSetId] = concepts;
        return concepts;
      }).catch(function(err) {
        console.error('Failed to fetch resolved concepts for CS ' + conceptSetId + ':', err);
        return [];
      });
      if (def) def.promise = promise;
      return promise;
    },
    get sessionReviews() { return sessionReviews; },
    set sessionReviews(v) { sessionReviews = v; safeSet('indicate_reviews', JSON.stringify(v)); },
    saveSessionReviews: function() { safeSet('indicate_reviews', JSON.stringify(sessionReviews)); },
    get statusLabelsMap() { return statusLabelsMap; },

    // Functions
    loadData: loadData,
    checkForDataUpdate: checkForDataUpdate,
    t: t,
    tProj: tProj,
    tMappingProject: tMappingProject,
    escapeHtml: escapeHtml,
    showToast: showToast,
    renderMarkdown: renderMarkdown,
    fuzzyMatch: fuzzyMatch,
    fuzzyFilter: fuzzyFilter,
    compareVersions: compareVersions,
    stampModified: stampModified,
    projectCard: projectCard,
    conceptListLine: conceptListLine,
    statusBadge: statusBadge,
    truncate: truncate,
    standardBadge: standardBadge,
    standardLabel: standardLabel,
    validBadge: validBadge,
    buildMultiSelectDropdown: buildMultiSelectDropdown,
    updateMsToggleLabel: updateMsToggleLabel,
    getUserProfile: getUserProfile,
    saveUserProfile: saveUserProfile,
    updateUserBadge: updateUserBadge,
    getKnownAuthors: getKnownAuthors,
    openProfileModal: openProfileModal,
    closeProfileModal: closeProfileModal,
    getOrganization: getOrganization,
    getConfigRepoUrl: getConfigRepoUrl,
    csCreatedOrg: csCreatedOrg,
    normalizeConceptSetMeta: normalizeConceptSetMeta,
    openExportModal: openExportModal,
    initSharedEvents: initSharedEvents,
    getCSData: getCSData,
    getConceptSet: getConceptSet,
    getResolvedConceptSet: getResolvedConceptSet,
    getLatestVersion: getLatestVersion,
    getProjectConceptSetEntries: getProjectConceptSetEntries,
    getProjectGroups: getProjectGroups,
    setProjectGroups: setProjectGroups,
    getGroupName: getGroupName,
    newGroupId: newGroupId,
    GROUP_RULES: GROUP_RULES,
    DEFAULT_GROUP_RULE: DEFAULT_GROUP_RULE,
    onLanguageChange: function(cb) { languageChangeCallbacks.push(cb); },
    onBeforeNavigate: function(cb) { beforeNavigateCallbacks.push(cb); },
    onHome: function(cb) { homeCallbacks.push(cb); },
    nextConceptSetId: nextConceptSetId,
    addConceptSet: addConceptSet,
    updateConceptSet: updateConceptSet,
    deleteConceptSets: deleteConceptSets,
    isUserConceptSet: isUserConceptSet,
    saveUserConceptSets: saveUserConceptSets,
    restoreConceptSets: restoreConceptSets,
    initColResize: initColResize,
    nextProjectId: nextProjectId,
    addProject: addProject,
    updateProject: updateProject,
    deleteProject: deleteProject,
    getMappingProjects: getMappingProjects,
    getMappingProject: getMappingProject,
    addMappingProject: addMappingProject,
    updateMappingProject: updateMappingProject,
    deleteMappingProject: deleteMappingProject,
    i18n: i18n,
    formatDate: formatDate,
    translateDOM: translateDOM,
    statusLabel: statusLabel
  };
})();
