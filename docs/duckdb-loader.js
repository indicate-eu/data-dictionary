/**
 * DuckDB-WASM Vocabulary Loader
 *
 * Loads OHDSI Athena vocabulary CSV files into an in-memory DuckDB database.
 * Files are NOT copied into browser memory — DuckDB reads them on demand
 * via FileSystemFileHandle (BROWSER_FILEREADER protocol).
 *
 * Chrome/Edge: showDirectoryPicker() → zero-copy streaming from disk
 * Firefox: <input webkitdirectory> fallback (files loaded into memory)
 *
 * FileSystemFileHandles are stored in IndexedDB so that on future visits,
 * the user only needs to re-grant permission (no re-import needed).
 *
 * DuckDB-WASM is loaded lazily via dynamic import() on first use.
 * Requires HTTP/HTTPS (won't work from file://).
 *
 * Exposes window.VocabDB for use by other scripts.
 */
(function () {
  'use strict';

  var DUCKDB_ESM_URL = 'https://cdn.jsdelivr.net/npm/@duckdb/duckdb-wasm@1.29.0/+esm';

  var REQUIRED_FILES = [
    'CONCEPT.csv',
    'CONCEPT_ANCESTOR.csv',
    'CONCEPT_RELATIONSHIP.csv',
    'CONCEPT_SYNONYM.csv',
    'RELATIONSHIP.csv',
    'VOCABULARY.csv',
    'DOMAIN.csv',
    'CONCEPT_CLASS.csv'
  ];
  var OPTIONAL_FILES = ['DRUG_STRENGTH.csv'];

  var duckdbLib = null;
  var db = null;
  var conn = null;

  /* ── helpers ──────────────────────────────────────────── */

  function tableName(csvFilename) {
    return csvFilename.replace('.csv', '').toLowerCase();
  }

  /* ── IndexedDB for file handle persistence ──────────── */

  function openHandleDB() {
    return new Promise(function (resolve, reject) {
      var req = indexedDB.open('vocab_handles', 3);
      req.onupgradeneeded = function () {
        var idb = req.result;
        if (!idb.objectStoreNames.contains('handles')) {
          idb.createObjectStore('handles');
        }
        if (!idb.objectStoreNames.contains('file_handles')) {
          idb.createObjectStore('file_handles');
        }
        if (!idb.objectStoreNames.contains('db_buffer')) {
          idb.createObjectStore('db_buffer');
        }
      };
      req.onsuccess = function () { resolve(req.result); };
      req.onerror = function () { reject(req.error); };
    });
  }

  function storeDirectoryHandle(handle) {
    return openHandleDB().then(function (idb) {
      return new Promise(function (resolve, reject) {
        var tx = idb.transaction('handles', 'readwrite');
        tx.objectStore('handles').put(handle, 'vocab_dir');
        tx.oncomplete = function () { resolve(); };
        tx.onerror = function () { reject(tx.error); };
      });
    });
  }

  function getStoredDirectoryHandle() {
    return openHandleDB().then(function (idb) {
      return new Promise(function (resolve, reject) {
        var tx = idb.transaction('handles', 'readonly');
        var req = tx.objectStore('handles').get('vocab_dir');
        req.onsuccess = function () { resolve(req.result || null); };
        req.onerror = function () { reject(req.error); };
      });
    });
  }

  /** Store individual FileSystemFileHandles keyed by CSV filename */
  function storeFileHandles(fileHandlesMap) {
    return openHandleDB().then(function (idb) {
      return new Promise(function (resolve, reject) {
        var tx = idb.transaction('file_handles', 'readwrite');
        var store = tx.objectStore('file_handles');
        var names = Object.keys(fileHandlesMap);
        for (var i = 0; i < names.length; i++) {
          store.put(fileHandlesMap[names[i]], names[i]);
        }
        tx.oncomplete = function () { resolve(); };
        tx.onerror = function () { reject(tx.error); };
      });
    });
  }

  /** Retrieve all stored FileSystemFileHandles */
  function getStoredFileHandles() {
    return openHandleDB().then(function (idb) {
      return new Promise(function (resolve, reject) {
        var tx = idb.transaction('file_handles', 'readonly');
        var store = tx.objectStore('file_handles');
        var result = {};
        var cursorReq = store.openCursor();
        cursorReq.onsuccess = function () {
          var cursor = cursorReq.result;
          if (cursor) {
            result[cursor.key] = cursor.value;
            cursor.continue();
          } else {
            resolve(result);
          }
        };
        cursorReq.onerror = function () { reject(cursorReq.error); };
      });
    });
  }

  function clearAllHandles() {
    return openHandleDB().then(function (idb) {
      return new Promise(function (resolve, reject) {
        var stores = ['handles', 'file_handles', 'db_buffer'];
        var tx = idb.transaction(stores, 'readwrite');
        stores.forEach(function (s) { tx.objectStore(s).clear(); });
        tx.oncomplete = function () { resolve(); };
        tx.onerror = function () { reject(tx.error); };
      });
    });
  }

  /* ── IndexedDB: persist DuckDB buffer ──────────────────── */

  function storeDbBuffer(buffer) {
    return openHandleDB().then(function (idb) {
      return new Promise(function (resolve, reject) {
        var tx = idb.transaction('db_buffer', 'readwrite');
        tx.objectStore('db_buffer').put(buffer, 'vocab_db');
        tx.oncomplete = function () { resolve(); };
        tx.onerror = function () { reject(tx.error); };
      });
    });
  }

  function getStoredDbBuffer() {
    return openHandleDB().then(function (idb) {
      return new Promise(function (resolve, reject) {
        var tx = idb.transaction('db_buffer', 'readonly');
        var req = tx.objectStore('db_buffer').get('vocab_db');
        req.onsuccess = function () { resolve(req.result || null); };
        req.onerror = function () { reject(req.error); };
      });
    });
  }

  /* ── DuckDB lazy loading + init ────────────────────── */

  function loadDuckDBLib() {
    if (duckdbLib) return Promise.resolve(duckdbLib);

    if (window.location.protocol === 'file:') {
      return Promise.reject(new Error(
        'DuckDB-WASM requires HTTP/HTTPS. Please serve this page with a local server: python3 -m http.server 8000 --directory docs'
      ));
    }

    return import(DUCKDB_ESM_URL).then(function (mod) {
      duckdbLib = mod;
      return duckdbLib;
    });
  }

  var EXPORT_PATH = '/export';

  function initDuckDB() {
    if (db && conn) return Promise.resolve(db);

    return loadDuckDBLib().then(function (lib) {
      var bundles = lib.getJsDelivrBundles();
      return lib.selectBundle(bundles);
    }).then(function (bundle) {
      var logger = new duckdbLib.ConsoleLogger();
      var workerUrl = URL.createObjectURL(
        new Blob(['importScripts("' + bundle.mainWorker + '");'], { type: 'text/javascript' })
      );
      var worker = new Worker(workerUrl);
      var asyncDb = new duckdbLib.AsyncDuckDB(logger, worker);
      return asyncDb.instantiate(bundle.mainModule).then(function () {
        URL.revokeObjectURL(workerUrl);
        return asyncDb;
      });
    }).then(function (asyncDb) {
      return asyncDb.open({ path: ':memory:' }).then(function () {
        db = asyncDb;
        return db;
      });
    }).then(function () {
      return db.connect();
    }).then(function (c) {
      conn = c;
      return db;
    });
  }

  /* ── Persist / restore DB via EXPORT/IMPORT DATABASE ───── */

  /**
   * Export all tables to Parquet in DuckDB's virtual FS,
   * then copy those files to IndexedDB for persistence.
   */
  function exportDbToIndexedDB() {
    if (!db || !conn) return Promise.resolve();
    return conn.query("EXPORT DATABASE '" + EXPORT_PATH + "' (FORMAT PARQUET)")
      .then(function () {
        /* Build the list of exported files: schema.sql + one .parquet per table */
        var allFiles = REQUIRED_FILES.concat(OPTIONAL_FILES);
        var exportedFiles = [EXPORT_PATH + '/schema.sql', EXPORT_PATH + '/load.sql'];
        allFiles.forEach(function (f) {
          exportedFiles.push(EXPORT_PATH + '/' + tableName(f) + '.parquet');
        });
        /* Copy each file to a buffer (skip missing optional files) */
        var buffers = {};
        var chain = Promise.resolve();
        exportedFiles.forEach(function (fpath) {
          chain = chain.then(function () {
            return db.copyFileToBuffer(fpath).then(function (buf) {
              buffers[fpath] = buf;
            }).catch(function () { /* skip missing */ });
          });
        });
        return chain.then(function () { return buffers; });
      })
      .then(function (buffers) {
        return storeDbBuffer(buffers);
      })
      .catch(function (err) {
        console.warn('Could not persist DB to IndexedDB:', err.message);
      });
  }

  /**
   * Restore DB from stored Parquet buffers via IMPORT DATABASE.
   * Returns true if successful.
   */
  function loadFromStoredBuffer() {
    return getStoredDbBuffer().then(function (buffers) {
      if (!buffers || typeof buffers !== 'object') return false;
      var files = Object.keys(buffers);
      if (files.length === 0) return false;

      return initDuckDB().then(function () {
        /* Register each exported file in DuckDB's virtual FS */
        var chain = Promise.resolve();
        files.forEach(function (fpath) {
          chain = chain.then(function () {
            return db.registerFileBuffer(fpath, new Uint8Array(buffers[fpath]));
          });
        });
        return chain;
      }).then(function () {
        return conn.query("IMPORT DATABASE '" + EXPORT_PATH + "'");
      }).then(function () {
        return true;
      });
    }).catch(function (err) {
      console.warn('Could not restore DB from IndexedDB:', err.message);
      return false;
    });
  }

  /* ── Status check ────────────────────────────────────── */

  function isDatabaseReady() {
    if (!conn) return Promise.resolve(false);
    return conn.query("SELECT table_name FROM information_schema.tables WHERE table_schema='main'")
      .then(function (result) {
        var tables = resultToArray(result).map(function (r) { return r.table_name; });
        var required = REQUIRED_FILES.map(function (f) { return tableName(f); });
        var missing = required.filter(function (t) {
          return tables.indexOf(t) === -1;
        });
        return missing.length === 0;
      })
      .catch(function () { return false; });
  }

  /* ── Arrow result → JS objects ───────────────────────── */

  function resultToArray(result) {
    var rows = [];
    var numCols = result.schema.fields.length;
    var cols = [];
    for (var c = 0; c < numCols; c++) {
      cols.push({ name: result.schema.fields[c].name, data: result.getChildAt(c) });
    }
    for (var r = 0; r < result.numRows; r++) {
      var row = {};
      for (var c2 = 0; c2 < numCols; c2++) {
        row[cols[c2].name] = cols[c2].data.get(r);
      }
      rows.push(row);
    }
    return rows;
  }

  /* ── Register file handles with DuckDB ────────────────── */

  /**
   * Register CSV file handles with DuckDB using BROWSER_FILEREADER.
   * This is zero-copy: DuckDB streams data on demand, files are NOT
   * loaded entirely into memory.
   */
  function registerFileHandlesWithDuckDB(fileHandlesMap) {
    var chain = Promise.resolve();
    var names = Object.keys(fileHandlesMap);
    names.forEach(function (name) {
      chain = chain.then(function () {
        return fileHandlesMap[name].getFile().then(function (file) {
          return db.registerFileHandle(
            name,
            file,
            duckdbLib.DuckDBDataProtocol.BROWSER_FILEREADER,
            true /* directIO */
          );
        });
      });
    });
    return chain;
  }

  /* ── Resolved concept IDs (for filtering large tables) ── */

  var resolvedConceptIds = null;

  function loadResolvedConceptIds() {
    if (resolvedConceptIds) return Promise.resolve(resolvedConceptIds);
    return fetch('resolved_concept_ids.json')
      .then(function (r) { return r.json(); })
      .then(function (ids) { resolvedConceptIds = ids; return ids; })
      .catch(function () { resolvedConceptIds = []; return []; });
  }

  /* ── Vocabularies to keep for concept table ───────────── */

  var CONCEPT_VOCABULARIES = ['SNOMED', 'LOINC', 'RxNorm', 'RxNorm Extension', 'UCUM', 'ICD10', 'ICD10CM'];

  /* ── Import: create materialized tables with filtering ── */

  var READ_CSV_OPTS = "delim='\\t', header=true, quote='', auto_detect=true, sample_size=100000";

  /**
   * Tables that need filtering by resolved concept IDs.
   * The filter SQL uses a temp table of IDs for efficient joining.
   */
  var FILTERED_TABLES = {
    'CONCEPT_ANCESTOR.csv': function () {
      return 'CREATE TABLE concept_ancestor AS ' +
        'SELECT ca.* FROM read_csv(\'CONCEPT_ANCESTOR.csv\', ' + READ_CSV_OPTS + ') ca ' +
        'WHERE ca.ancestor_concept_id IN (SELECT id FROM _filter_ids) ' +
        'OR ca.descendant_concept_id IN (SELECT id FROM _filter_ids)';
    },
    'CONCEPT_RELATIONSHIP.csv': function () {
      return 'CREATE TABLE concept_relationship AS ' +
        'SELECT cr.* FROM read_csv(\'CONCEPT_RELATIONSHIP.csv\', ' + READ_CSV_OPTS + ') cr ' +
        'WHERE cr.concept_id_1 IN (SELECT id FROM _filter_ids) ' +
        'OR cr.concept_id_2 IN (SELECT id FROM _filter_ids)';
    },
    'CONCEPT_SYNONYM.csv': function () {
      return 'CREATE TABLE concept_synonym AS ' +
        'SELECT cs.* FROM read_csv(\'CONCEPT_SYNONYM.csv\', ' + READ_CSV_OPTS + ') cs ' +
        'WHERE cs.concept_id IN (SELECT id FROM _filter_ids)';
    },
    'CONCEPT.csv': function () {
      var vocabList = CONCEPT_VOCABULARIES.map(function (v) { return "'" + v + "'"; }).join(',');
      return 'CREATE TABLE concept AS ' +
        'SELECT * FROM read_csv(\'CONCEPT.csv\', ' + READ_CSV_OPTS + ') ' +
        'WHERE vocabulary_id IN (' + vocabList + ')';
    }
  };

  /**
   * Indexes to create after tables are materialized.
   * Matches the Shiny app (fct_duckdb.R).
   */
  var INDEXES = [
    'CREATE INDEX idx_concept_id ON concept(concept_id)',
    'CREATE INDEX idx_concept_vocab ON concept(vocabulary_id)',
    'CREATE INDEX idx_ancestor ON concept_ancestor(ancestor_concept_id)',
    'CREATE INDEX idx_descendant ON concept_ancestor(descendant_concept_id)',
    'CREATE INDEX idx_concept_rel_1 ON concept_relationship(concept_id_1)',
    'CREATE INDEX idx_concept_rel_2 ON concept_relationship(concept_id_2)',
    'CREATE INDEX idx_synonym_cid ON concept_synonym(concept_id)'
  ];

  function createTablesFromFiles(fileNames, onProgress) {
    var done = 0;
    // +1 for indexing step, +1 for filter IDs setup
    var total = fileNames.length + 2;
    var importChain = Promise.resolve();

    // Step 0: Load resolved concept IDs and create temp filter table
    importChain = importChain.then(function () {
      onProgress({ file: null, table: null, step: 'filter_ids', done: 0, total: total });
      return loadResolvedConceptIds().then(function (ids) {
        if (ids.length === 0) return;
        // Create a temp table with the IDs for efficient filtering
        var batchSize = 500;
        var chain = conn.query('CREATE TEMP TABLE _filter_ids (id INTEGER)');
        for (var i = 0; i < ids.length; i += batchSize) {
          (function (batch) {
            chain = chain.then(function () {
              return conn.query('INSERT INTO _filter_ids VALUES ' +
                batch.map(function (id) { return '(' + id + ')'; }).join(','));
            });
          })(ids.slice(i, i + batchSize));
        }
        return chain.then(function () {
          return conn.query('CREATE INDEX idx_filter ON _filter_ids(id)');
        });
      }).then(function () {
        done++;
        onProgress({ file: null, table: null, step: 'filter_ids_done', done: done, total: total });
      });
    });

    // Step 1: Import each file as a materialized table
    fileNames.forEach(function (name) {
      importChain = importChain.then(function () {
        var tbl = tableName(name);
        onProgress({ file: name, table: tbl, step: 'importing', done: done, total: total });

        var dropSql = 'DROP TABLE IF EXISTS ' + tbl + '; DROP VIEW IF EXISTS ' + tbl;

        var createSql;
        if (FILTERED_TABLES[name]) {
          createSql = FILTERED_TABLES[name]();
        } else {
          // Small reference tables: import in full
          createSql = 'CREATE TABLE ' + tbl + ' AS SELECT * FROM read_csv(\'' + name + '\', ' + READ_CSV_OPTS + ')';
        }

        return conn.query(dropSql).then(function () {
          return conn.query(createSql);
        }).then(function () {
          done++;
          onProgress({ file: name, table: tbl, step: 'done', done: done, total: total });
        });
      });
    });

    // Step 2: Create indexes
    importChain = importChain.then(function () {
      onProgress({ file: null, table: null, step: 'indexing', done: done, total: total });
      var indexChain = Promise.resolve();
      INDEXES.forEach(function (sql) {
        indexChain = indexChain.then(function () {
          return conn.query(sql).catch(function () { /* ignore if table missing */ });
        });
      });
      return indexChain.then(function () {
        // Clean up filter table
        return conn.query('DROP TABLE IF EXISTS _filter_ids').catch(function () {});
      }).then(function () {
        done++;
        onProgress({ file: null, table: null, step: 'indexing_done', done: done, total: total });
      });
    });

    return importChain.then(function () { return total; });
  }

  /* ── Import from directory handle (Chrome/Edge) ──────── */

  function importFromDirectory(dirHandle, onProgress) {
    onProgress = onProgress || function () {};

    var fileHandlesMap = {};
    var validationChain = Promise.resolve();

    REQUIRED_FILES.forEach(function (name) {
      validationChain = validationChain.then(function () {
        return dirHandle.getFileHandle(name).then(function (fh) {
          fileHandlesMap[name] = fh;
        });
      });
    });

    OPTIONAL_FILES.forEach(function (name) {
      validationChain = validationChain.then(function () {
        return dirHandle.getFileHandle(name).then(function (fh) {
          fileHandlesMap[name] = fh;
        }).catch(function () { /* optional */ });
      });
    });

    return validationChain
      .then(function () {
        return initDuckDB();
      })
      .then(function () {
        /* Register file handles — zero-copy, DuckDB streams on demand */
        return registerFileHandlesWithDuckDB(fileHandlesMap);
      })
      .then(function () {
        return createTablesFromFiles(Object.keys(fileHandlesMap), onProgress);
      })
      .then(function (total) {
        onProgress({ file: null, table: null, step: 'persisting', done: total, total: total });
        /* Persist DB buffer + file handles to IndexedDB */
        return exportDbToIndexedDB()
          .then(function () {
            return storeDirectoryHandle(dirHandle).catch(function () {});
          })
          .then(function () {
            return storeFileHandles(fileHandlesMap).catch(function () {});
          })
          .then(function () {
            onProgress({ file: null, table: null, step: 'complete', done: total, total: total });
          });
      });
  }

  /* ── Import from FileList (Firefox fallback) ─────────── */

  function importFromFiles(fileList, onProgress) {
    onProgress = onProgress || function () {};

    var fileMap = {};
    for (var i = 0; i < fileList.length; i++) {
      var f = fileList[i];
      var name = f.name;
      if (REQUIRED_FILES.indexOf(name) !== -1 || OPTIONAL_FILES.indexOf(name) !== -1) {
        fileMap[name] = f;
      }
    }

    var missing = REQUIRED_FILES.filter(function (n) { return !fileMap[n]; });
    if (missing.length > 0) {
      return Promise.reject(new Error('Missing required files: ' + missing.join(', ')));
    }

    var filesToImport = Object.keys(fileMap);
    var total = filesToImport.length;
    var done = 0;

    return initDuckDB().then(function () {
      /* Firefox: register File objects via BROWSER_FILEREADER (still zero-copy) */
      var regChain = Promise.resolve();
      filesToImport.forEach(function (name) {
        regChain = regChain.then(function () {
          return db.registerFileHandle(
            name,
            fileMap[name],
            duckdbLib.DuckDBDataProtocol.BROWSER_FILEREADER,
            true
          );
        });
      });
      return regChain;
    }).then(function () {
      return createTablesFromFiles(filesToImport, onProgress);
    }).then(function (total) {
      onProgress({ file: null, table: null, step: 'persisting', done: total, total: total });
      return exportDbToIndexedDB().then(function () {
        onProgress({ file: null, table: null, step: 'complete', done: total, total: total });
      });
    });
  }

  /* ── Restore from stored data (future sessions) ─────── */

  /**
   * Try to restore the database. Strategy:
   * 1. Try IndexedDB buffer (works on all browsers, instant)
   * 2. Fall back to stored FileSystemFileHandles (Chrome/Edge only, re-imports from CSV)
   */
  function remountFromStoredHandles() {
    /* Strategy 1: IndexedDB buffer (all browsers) */
    return loadFromStoredBuffer().then(function (success) {
      if (success) return true;

      /* Strategy 2: FileSystemFileHandles (Chrome/Edge) */
      return getStoredFileHandles().then(function (handles) {
        var names = Object.keys(handles);
        if (names.length === 0) return false;

        var required = REQUIRED_FILES.map(function (f) { return f; });
        var missing = required.filter(function (n) { return !handles[n]; });
        if (missing.length > 0) return false;

        var permChain = Promise.resolve(true);
        names.forEach(function (name) {
          permChain = permChain.then(function (allGranted) {
            if (!allGranted) return false;
            return handles[name].queryPermission({ mode: 'read' }).then(function (status) {
              if (status === 'granted') return true;
              if (status === 'prompt') {
                return handles[name].requestPermission({ mode: 'read' }).then(function (result) {
                  return result === 'granted';
                });
              }
              return false;
            });
          });
        });

        return permChain.then(function (allGranted) {
          if (!allGranted) return false;
          return registerFileHandlesWithDuckDB(handles).then(function () {
            return createTablesFromFiles(names, function () {}).then(function () {
              /* Persist the buffer for next time */
              return exportDbToIndexedDB().then(function () { return true; });
            });
          });
        });
      });
    }).catch(function () {
      return false;
    });
  }

  /* ── Stats ───────────────────────────────────────────── */

  function getStats() {
    if (!conn) return Promise.resolve(null);
    return conn.query("SELECT table_name, table_type FROM information_schema.tables WHERE table_schema='main'")
      .then(function (result) {
        var rows = resultToArray(result);
        var stats = {};
        for (var i = 0; i < rows.length; i++) {
          stats[rows[i].table_name] = rows[i].table_type; /* 'VIEW' or 'BASE TABLE' */
        }
        return stats;
      });
  }

  /* ── Query ───────────────────────────────────────────── */

  function query(sql) {
    if (!conn) return Promise.reject(new Error('Database not initialized'));
    return conn.query(sql).then(function (result) {
      return resultToArray(result);
    });
  }

  /* ── Lookup concepts ─────────────────────────────────── */

  function lookupConcepts(conceptIds) {
    if (!conn || !conceptIds || conceptIds.length === 0) return Promise.resolve([]);
    var idList = conceptIds.join(',');
    return query(
      "SELECT concept_id, concept_name, vocabulary_id, domain_id, concept_class_id, concept_code, standard_concept " +
      "FROM concept WHERE concept_id IN (" + idList + ")"
    );
  }

  /* ── Delete database ─────────────────────────────────── */

  function deleteDatabase() {
    var chain = Promise.resolve();
    if (conn) {
      chain = chain.then(function () {
        return conn.close().then(function () { conn = null; });
      });
    }
    if (db) {
      chain = chain.then(function () {
        return db.terminate().then(function () { db = null; });
      });
    }
    chain = chain.then(function () {
      return clearAllHandles().catch(function () {});
    });
    return chain;
  }

  /* ── Public API ──────────────────────────────────────── */

  window.VocabDB = {
    REQUIRED_FILES: REQUIRED_FILES,
    OPTIONAL_FILES: OPTIONAL_FILES,
    initDuckDB: initDuckDB,
    isDatabaseReady: isDatabaseReady,
    importFromDirectory: importFromDirectory,
    importFromFiles: importFromFiles,
    remountFromStoredHandles: remountFromStoredHandles,
    getStoredFileHandles: getStoredFileHandles,
    getStats: getStats,
    query: query,
    lookupConcepts: lookupConcepts,
    deleteDatabase: deleteDatabase,
    getStoredDirectoryHandle: getStoredDirectoryHandle,
    storeDirectoryHandle: storeDirectoryHandle,
    tableName: tableName
  };
})();
