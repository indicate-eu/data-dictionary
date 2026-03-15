// etl-guidelines.js — ETL Guidelines page module (view + edit)
var EtlGuidelinesPage = (function() {
  'use strict';

  var initialized = false;
  var editor = null;
  var editing = false;

  function getContent() {
    return App.etlGuidelines || '';
  }

  function renderView() {
    var container = document.getElementById('etl-view-content');
    if (!container) return;
    var md = getContent();
    if (!md.trim()) {
      container.innerHTML = '<div class="markdown-preview-placeholder">' +
        App.escapeHtml(App.i18n('No ETL guidelines available.')) + '</div>';
    } else {
      container.innerHTML = marked.parse(md);
    }
  }

  function enterEditMode() {
    editing = true;
    document.getElementById('etl-page-edit-btn').style.display = 'none';
    document.getElementById('etl-page-cancel-btn').style.display = '';
    document.getElementById('etl-page-save-btn').style.display = '';
    document.getElementById('etl-view-container').style.display = 'none';
    document.getElementById('etl-edit-container').style.display = 'block';

    if (!editor) {
      editor = ace.edit('etl-page-ace-editor');
      editor.setTheme('ace/theme/chrome');
      editor.session.setMode('ace/mode/markdown');
      editor.setFontSize(13);
      editor.setShowPrintMargin(false);
      editor.session.setUseWrapMode(true);
      editor.session.on('change', function() {
        var md = editor.getValue();
        var preview = document.getElementById('etl-page-preview');
        if (!md.trim()) {
          preview.innerHTML = '<div class="markdown-preview-placeholder">Preview will appear here...</div>';
        } else {
          preview.innerHTML = marked.parse(md);
        }
      });
    }
    editor.setValue(getContent(), -1);
    editor.resize();
    // Trigger initial preview
    var initMd = editor.getValue();
    var preview = document.getElementById('etl-page-preview');
    if (initMd.trim()) {
      preview.innerHTML = marked.parse(initMd);
    } else {
      preview.innerHTML = '<div class="markdown-preview-placeholder">Preview will appear here...</div>';
    }
  }

  function exitEditMode() {
    editing = false;
    document.getElementById('etl-page-edit-btn').style.display = '';
    document.getElementById('etl-page-cancel-btn').style.display = 'none';
    document.getElementById('etl-page-save-btn').style.display = 'none';
    document.getElementById('etl-view-container').style.display = '';
    document.getElementById('etl-edit-container').style.display = 'none';
  }

  function save() {
    if (!editor) return;
    App.etlGuidelines = editor.getValue();
    renderView();
    exitEditMode();
    App.showToast(App.i18n('ETL guidelines saved.'), 'success');
  }

  function cancel() {
    exitEditMode();
  }

  function exportEtl() {
    var content = editing && editor ? editor.getValue() : getContent();
    App.openExportModal({
      content: content,
      filename: 'etl_guidelines.md',
      type: 'text/markdown',
      clipboardDesc: 'Copy Markdown content to clipboard',
      fileDesc: 'Download as etl_guidelines.md'
    });
  }

  function initEvents() {
    document.getElementById('etl-page-export-btn').addEventListener('click', exportEtl);
    document.getElementById('etl-page-edit-btn').addEventListener('click', enterEditMode);
    document.getElementById('etl-page-cancel-btn').addEventListener('click', cancel);
    document.getElementById('etl-page-save-btn').addEventListener('click', save);
  }

  function show() {
    if (!initialized) {
      initialized = true;
      initEvents();
    }
    if (!editing) {
      renderView();
    } else if (editor) {
      editor.resize();
    }
  }

  function hide() {}

  return {
    show: show,
    hide: hide
  };
})();
