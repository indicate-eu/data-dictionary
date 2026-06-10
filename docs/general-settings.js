/**
 * General Settings page module — OHDSI Vocabulary import via DuckDB-WASM
 */
var GeneralSettingsPage = (function () {
  'use strict';

  var initialized = false;

  /* ── DOM refs (set on init) ─────────────────────────── */
  var statusPanel, statusIcon, statusMsg;
  var btnSelectFolder, btnRegrant, btnDeleteDb, fileInput;
  var progressSection, progressLabel, progressPct, progressFill, fileListEl;
  var statsSection, statsGrid;
  var deleteModal, deleteModalClose, deleteModalCancel, deleteModalOk;
  var supportsDirectoryPicker = !!window.showDirectoryPicker;

  /* ── Status display helpers ────────────────────────── */

  function setStatus(type, msg) {
    statusPanel.className = 'vocab-status-panel vocab-status-' + type;
    var iconMap = {
      loading: 'fas fa-spinner fa-spin',
      ready:   'fas fa-check-circle',
      error:   'fas fa-times-circle',
      empty:   'fas fa-database'
    };
    statusIcon.innerHTML = '<i class="' + (iconMap[type] || iconMap.empty) + '"></i>';
    statusMsg.textContent = msg;
  }

  function showButtons(selectFolder, regrant, deleteDb) {
    btnSelectFolder.style.display = selectFolder ? '' : 'none';
    btnRegrant.style.display = regrant ? '' : 'none';
    btnDeleteDb.style.display = deleteDb ? '' : 'none';
  }

  /* ── Stats display ─────────────────────────────────── */

  function showStats(stats) {
    if (!stats) { statsSection.style.display = 'none'; return; }
    var html = '';
    var tables = Object.keys(stats).sort();
    for (var i = 0; i < tables.length; i++) {
      var name = tables[i];
      var label = App.escapeHtml(name);
      html += '<div class="vocab-stat-card">' +
        '<div class="vocab-stat-name">' + label + '</div>' +
        '<div class="vocab-stat-count"><i class="fas fa-check-circle" style="color:var(--success)"></i> Linked</div>' +
        '</div>';
    }
    statsGrid.innerHTML = html;
    statsSection.style.display = '';
  }

  /* ── Progress display ──────────────────────────────── */

  // The file list is built lazily, one entry per file as the import reaches it
  // (the importer decides which files are relevant, the UI just mirrors it).
  function updateFileStatus(filename, status) {
    var key = VocabDB.tableName(filename);
    var el = document.getElementById('file-' + key);
    if (!el) {
      el = document.createElement('div');
      el.id = 'file-' + key;
      el.innerHTML = '<i class="fas fa-clock vocab-file-icon"></i> <span class="vocab-file-name"></span>';
      el.querySelector('.vocab-file-name').textContent = filename;
      fileListEl.appendChild(el);
    }
    var iconClass = {
      pending:   'fas fa-clock',
      importing: 'fas fa-spinner fa-spin',
      done:      'fas fa-check-circle',
      error:     'fas fa-times-circle'
    };
    var colorClass = {
      pending:   '',
      importing: 'vocab-file-importing',
      done:      'vocab-file-done',
      error:     'vocab-file-error'
    };
    el.className = 'vocab-file-item ' + (colorClass[status] || '');
    var icon = el.querySelector('.vocab-file-icon');
    if (icon) icon.className = (iconClass[status] || iconClass.pending) + ' vocab-file-icon';
  }

  function onProgress(info) {
    if (info.step === 'filter_ids') {
      progressLabel.textContent = 'Preparing concept ID filters...';
    }
    if (info.step === 'importing' && info.file) {
      progressLabel.textContent = 'Importing ' + info.file + '...';
      updateFileStatus(info.file, 'importing');
    }
    if (info.step === 'done' && info.file) {
      updateFileStatus(info.file, 'done');
    }
    if (info.step === 'error' && info.file) {
      updateFileStatus(info.file, 'error');
    }
    if (info.step === 'indexing') {
      progressLabel.textContent = 'Creating indexes...';
    }
    if (info.step === 'persisting') {
      progressLabel.textContent = 'Saving database to browser storage...';
    }
    if (info.step === 'complete') {
      progressLabel.textContent = 'Import complete!';
    }
    // Update progress bar
    if (info.total > 0) {
      var pct = Math.round((info.done / info.total) * 100);
      progressFill.style.width = pct + '%';
      progressPct.textContent = pct + '%';
    }
  }

  /* ── Import flow ───────────────────────────────────── */

  function startImportFromDirectory(dirHandle) {
    setStatus('loading', 'Importing vocabulary files...');
    showButtons(false, false, false);
    progressSection.style.display = '';
    fileListEl.innerHTML = '';
    statsSection.style.display = 'none';

    VocabDB.importFromDirectory(dirHandle, function (info) {
      onProgress(info);
    })
      .then(function () {
        return checkDatabaseStatus();
      })
      .catch(function (err) {
        setStatus('error', 'Import failed: ' + err.message);
        showButtons(true, false, false);
        App.showToast('Import failed: ' + err.message, 'error');
      });
  }

  function startImportFromFiles(fileList) {
    setStatus('loading', 'Importing vocabulary files...');
    showButtons(false, false, false);
    progressSection.style.display = '';
    fileListEl.innerHTML = '';
    statsSection.style.display = 'none';

    VocabDB.importFromFiles(fileList, onProgress)
      .then(function () {
        return checkDatabaseStatus();
      })
      .catch(function (err) {
        setStatus('error', 'Import failed: ' + err.message);
        showButtons(true, false, false);
        App.showToast('Import failed: ' + err.message, 'error');
      });
  }

  /* ── Folder selection ──────────────────────────────── */

  function selectFolder() {
    if (supportsDirectoryPicker) {
      window.showDirectoryPicker({ mode: 'read' })
        .then(function (dirHandle) {
          startImportFromDirectory(dirHandle);
        })
        .catch(function (err) {
          if (err.name !== 'AbortError') {
            App.showToast('Folder selection failed: ' + err.message, 'error');
          }
        });
    } else {
      fileInput.click();
    }
  }

  /* ── Re-grant access (Chrome stored handle) ────────── */

  function regrantAccess() {
    VocabDB.getStoredDirectoryHandle()
      .then(function (handle) {
        if (!handle) {
          App.showToast('No stored folder handle found. Please select folder again.', 'error');
          showButtons(true, false, false);
          return;
        }
        return handle.requestPermission({ mode: 'read' }).then(function (perm) {
          if (perm === 'granted') {
            App.showToast('Access re-granted', 'success');
            checkDatabaseStatus();
          } else {
            App.showToast('Permission denied', 'error');
          }
        });
      })
      .catch(function (err) {
        App.showToast('Re-grant failed: ' + err.message, 'error');
      });
  }

  /* ── Delete database ───────────────────────────────── */

  function openDeleteModal() {
    deleteModal.style.display = 'flex';
  }
  function closeDeleteModal() {
    deleteModal.style.display = 'none';
  }

  /* ── Status check ──────────────────────────────────── */

  function showReadyState(stats) {
    var msg = 'Vocabulary database is loaded and ready.';
    setStatus('ready', msg);
    showButtons(true, false, true);
    btnSelectFolder.innerHTML = '<i class="fas fa-folder-open"></i> Re-import Vocabularies';
    progressSection.style.display = 'none';
    showStats(stats);
  }

  function showEmptyState() {
    setStatus('empty', 'No vocabulary database found. Select a folder to import OHDSI vocabulary files.');
    showButtons(true, false, false);
    btnSelectFolder.innerHTML = '<i class="fas fa-folder-open"></i> Select Vocabulary Folder';
    progressSection.style.display = 'none';
    showStats(null);
  }

  function checkDatabaseStatus() {
    if (window.location.protocol === 'file:') {
      setStatus('error', 'This page requires a local HTTP server. Run: python3 -m http.server 8000 --directory docs');
      showButtons(false, false, false);
      return Promise.resolve();
    }

    setStatus('loading', 'Loading DuckDB-WASM...');
    showButtons(false, false, false);

    return VocabDB.initDuckDB()
      .then(function () {
        return VocabDB.isDatabaseReady();
      })
      .then(function (ready) {
        if (ready) {
          return VocabDB.getStats().then(function (stats) {
            showReadyState(stats);
          });
        }

        setStatus('loading', 'Restoring database...');
        return VocabDB.remountFromStoredHandles().then(function (success) {
          if (success) {
            return VocabDB.getStats().then(function (stats) {
              showReadyState(stats);
            });
          }
          // A stored folder handle without restorable data usually means the
          // read permission lapsed — offer the Re-grant button.
          return VocabDB.getStoredDirectoryHandle().then(function (handle) {
            if (handle) {
              setStatus('empty', 'Vocabulary folder found, but access must be re-granted.');
              showButtons(true, true, false);
              progressSection.style.display = 'none';
              showStats(null);
            } else {
              showEmptyState();
            }
          }).catch(function () { showEmptyState(); });
        });
      })
      .catch(function (err) {
        showEmptyState();
        console.warn('DuckDB init:', err.message);
      });
  }

  /* ── Browser compatibility warning ──────────────────── */
  function showBrowserWarning() {
    var warningEl = document.getElementById('vocab-browser-warning');
    var msgEl = document.getElementById('vocab-browser-warning-msg');
    if (!warningEl || !msgEl) return;

    var ua = navigator.userAgent;
    var isFirefox = /Firefox\//i.test(ua);
    var isSafari = /Safari\//i.test(ua) && !/Chrome\//i.test(ua);

    if (isFirefox) {
      msgEl.textContent = 'Firefox: you will need to re-select the vocabulary folder each visit. For persistent access, use Chrome or Edge.';
      warningEl.style.display = '';
    } else if (isSafari) {
      msgEl.textContent = 'Safari has limited support for the File System Access API. Vocabulary features may not work correctly. Full support is available in Chrome and Edge.';
      warningEl.style.display = '';
    }
  }

  /* ── Event listeners ───────────────────────────────── */

  function initEvents() {
    btnSelectFolder.addEventListener('click', selectFolder);
    btnRegrant.addEventListener('click', regrantAccess);
    btnDeleteDb.addEventListener('click', openDeleteModal);

    fileInput.addEventListener('change', function () {
      if (fileInput.files && fileInput.files.length > 0) {
        // Copy, then reset the input so re-selecting the same folder after a
        // failure fires `change` again (clearing `value` empties the FileList).
        var files = Array.prototype.slice.call(fileInput.files);
        fileInput.value = '';
        startImportFromFiles(files);
      }
    });

    deleteModalClose.addEventListener('click', closeDeleteModal);
    deleteModalCancel.addEventListener('click', closeDeleteModal);
    deleteModal.addEventListener('click', function (e) {
      if (e.target === deleteModal) closeDeleteModal();
    });

    deleteModalOk.addEventListener('click', function () {
      closeDeleteModal();
      setStatus('loading', 'Deleting database...');
      showButtons(false, false, false);
      statsSection.style.display = 'none';
      progressSection.style.display = 'none';

      VocabDB.deleteDatabase()
        .then(function () {
          showEmptyState();
          App.showToast('Database deleted', 'success');
        })
        .catch(function (err) {
          setStatus('error', 'Delete failed: ' + err.message);
          showButtons(false, false, true);
        });
    });
  }

  /* ── Page module ───────────────────────────────────── */

  function init() {
    if (initialized) return;
    initialized = true;

    // Grab DOM refs
    statusPanel   = document.getElementById('vocab-status-panel');
    statusIcon    = document.getElementById('vocab-status-icon');
    statusMsg     = document.getElementById('vocab-status-msg');
    btnSelectFolder = document.getElementById('vocab-select-folder');
    btnRegrant      = document.getElementById('vocab-regrant');
    btnDeleteDb     = document.getElementById('vocab-delete-db');
    fileInput       = document.getElementById('vocab-file-input');
    progressSection = document.getElementById('vocab-progress-section');
    progressLabel   = document.getElementById('vocab-progress-label');
    progressPct     = document.getElementById('vocab-progress-pct');
    progressFill    = document.getElementById('vocab-progress-fill');
    fileListEl      = document.getElementById('vocab-file-list');
    statsSection = document.getElementById('vocab-stats-section');
    statsGrid    = document.getElementById('vocab-stats-grid');
    deleteModal      = document.getElementById('confirm-delete-db-modal');
    deleteModalClose = document.getElementById('confirm-delete-db-close');
    deleteModalCancel = document.getElementById('confirm-delete-db-cancel');
    deleteModalOk    = document.getElementById('confirm-delete-db-ok');

    initEvents();
    showBrowserWarning();
    checkDatabaseStatus();
  }

  function show() {
    init();
  }

  function hide() {
    // nothing to clean up
  }

  return {
    show: show,
    hide: hide
  };
})();

/* ── Parquet howto toggle (runs at script load, outside IIFE) ── */
(function () {
  var toggle = document.getElementById('vocab-parquet-howto-toggle');
  var howto = document.getElementById('vocab-parquet-howto');
  if (!toggle || !howto) return;

  toggle.addEventListener('click', function () {
    var visible = howto.style.display !== 'none';
    howto.style.display = visible ? 'none' : '';
    toggle.textContent = visible ? 'Show conversion instructions' : 'Hide instructions';
  });

  var tabs = howto.querySelectorAll('.vocab-code-tab');
  var blocks = howto.querySelectorAll('.vocab-code-block');
  tabs.forEach(function (tab) {
    tab.addEventListener('click', function () {
      var lang = tab.getAttribute('data-lang');
      tabs.forEach(function (t) {
        var active = t.getAttribute('data-lang') === lang;
        t.classList.toggle('active', active);
      });
      blocks.forEach(function (b) {
        b.style.display = b.getAttribute('data-lang') === lang ? '' : 'none';
      });
    });
  });

  howto.querySelectorAll('.vocab-code-copy').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var code = btn.closest('.vocab-code-block').querySelector('code');
      if (!code) return;
      navigator.clipboard.writeText(code.textContent).then(function () {
        var icon = btn.querySelector('i');
        icon.className = 'fas fa-check';
        setTimeout(function () { icon.className = 'fas fa-copy'; }, 1500);
      });
    });
  });
})();
