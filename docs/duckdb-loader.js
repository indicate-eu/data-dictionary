/**
 * DuckDB-WASM Vocabulary Loader
 *
 * Loads OHDSI Athena vocabulary files (CSV or Parquet) into an in-memory
 * DuckDB database. Strategy:
 *   - CONCEPT: loaded in full (~4M rows, ~4 MB in DuckDB)
 *   - CONCEPT_ANCESTOR: only direct edges (min_levels_of_separation=1,
 *     ~7.8M rows, ~7 MB). Hierarchy is rebuilt via recursive CTE at query time.
 *   - CONCEPT_RELATIONSHIP, CONCEPT_SYNONYM: filtered by resolved concept IDs
 *   - Small reference tables: loaded in full
 *
 * Tables are indexed and persisted to IndexedDB via EXPORT/IMPORT DATABASE.
 *
 * Chrome/Edge: showDirectoryPicker() + stored FileSystemFileHandles
 * Firefox: <input webkitdirectory> fallback (must re-select each visit)
 *
 * Exposes window.VocabDB for use by other scripts.
 */
(function () {
  'use strict';

  var DUCKDB_ESM_URL = 'https://cdn.jsdelivr.net/npm/@duckdb/duckdb-wasm@1.29.0/+esm';

  var REQUIRED_TABLES = ['CONCEPT', 'CONCEPT_ANCESTOR', 'CONCEPT_RELATIONSHIP', 'CONCEPT_SYNONYM', 'RELATIONSHIP', 'VOCABULARY', 'DOMAIN', 'CONCEPT_CLASS'];
  var OPTIONAL_TABLES = ['DRUG_STRENGTH'];

  var REQUIRED_CSV  = REQUIRED_TABLES.map(function (t) { return t + '.csv'; });
  var OPTIONAL_CSV  = OPTIONAL_TABLES.map(function (t) { return t + '.csv'; });
  var REQUIRED_PARQUET = REQUIRED_TABLES.map(function (t) { return t + '.parquet'; });
  var OPTIONAL_PARQUET = OPTIONAL_TABLES.map(function (t) { return t + '.parquet'; });

  var duckdbLib = null;
  var db = null;
  var conn = null;
  var importMode = null; /* 'filtered' — set during import */

  /* ── helpers ──────────────────────────────────────────── */

  function tableName(filename) {
    return filename.replace(/\.(csv|parquet)$/i, '').toLowerCase();
  }

  function isParquetFile(filename) {
    return /\.parquet$/i.test(filename);
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

  /** Store individual FileSystemFileHandles keyed by filename */
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

  function exportDbToIndexedDB() {
    if (!db || !conn) return Promise.resolve();
    return conn.query("EXPORT DATABASE '" + EXPORT_PATH + "' (FORMAT PARQUET)")
      .then(function () {
        var allTables = REQUIRED_TABLES.concat(OPTIONAL_TABLES);
        var exportedFiles = [EXPORT_PATH + '/schema.sql', EXPORT_PATH + '/load.sql'];
        allTables.forEach(function (t) {
          exportedFiles.push(EXPORT_PATH + '/' + t.toLowerCase() + '.parquet');
        });
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

  function loadFromStoredBuffer() {
    return getStoredDbBuffer().then(function (buffers) {
      if (!buffers || typeof buffers !== 'object') return false;
      var files = Object.keys(buffers);
      if (files.length === 0) return false;

      // Validate: must contain schema.sql and at least one .parquet file
      var hasSchema = files.some(function (f) { return f.indexOf('schema.sql') !== -1; });
      var hasParquet = files.some(function (f) { return /\.parquet$/.test(f); });
      if (!hasSchema || !hasParquet) {
        console.warn('Stored DB buffer is invalid (missing schema or parquet files), clearing...');
        return clearAllHandles().then(function () { return false; });
      }

      // Validate: parquet buffers must have non-trivial size
      var hasValidData = files.some(function (f) {
        return /\.parquet$/.test(f) && buffers[f] && buffers[f].byteLength > 100;
      });
      if (!hasValidData) {
        console.warn('Stored DB buffer contains empty parquet files, clearing...');
        return clearAllHandles().then(function () { return false; });
      }

      return initDuckDB().then(function () {
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
      return clearAllHandles().then(function () { return false; }).catch(function () { return false; });
    });
  }

  /* ── Status check ────────────────────────────────────── */

  function isDatabaseReady() {
    if (!conn) return Promise.resolve(false);
    return conn.query("SELECT table_name FROM information_schema.tables WHERE table_schema='main'")
      .then(function (result) {
        var tables = resultToArray(result).map(function (r) { return r.table_name; });
        var required = REQUIRED_TABLES.map(function (t) { return t.toLowerCase(); });
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

  /* ── Read source SQL (CSV or Parquet) ────────────────── */

  var READ_CSV_OPTS = "delim='\\t', header=true, quote='', auto_detect=true, sample_size=100000";

  function readSourceSql(filename) {
    if (isParquetFile(filename)) {
      return "read_parquet('" + filename + "')";
    }
    return "read_csv('" + filename + "', " + READ_CSV_OPTS + ")";
  }

  /* ── Filtered SQL for large tables ───────────────────── */

  function getFilteredSql(name) {
    var src = readSourceSql(name);
    var tbl = tableName(name);

    if (tbl === 'concept_ancestor') {
      // Only direct parent-child edges — hierarchy rebuilt via recursive CTE
      return 'CREATE TABLE concept_ancestor AS ' +
        'SELECT ca.ancestor_concept_id, ca.descendant_concept_id FROM ' + src + ' ca ' +
        'WHERE ca.min_levels_of_separation = 1';
    }
    if (tbl === 'concept_relationship') {
      return 'CREATE TABLE concept_relationship AS ' +
        'SELECT cr.* FROM ' + src + ' cr ' +
        'WHERE cr.concept_id_1 IN (SELECT id FROM _filter_ids) ' +
        'OR cr.concept_id_2 IN (SELECT id FROM _filter_ids)';
    }
    if (tbl === 'concept_synonym') {
      return 'CREATE TABLE concept_synonym AS ' +
        'SELECT cs.* FROM ' + src + ' cs ' +
        'WHERE cs.concept_id IN (SELECT id FROM _filter_ids)';
    }
    if (tbl === 'concept') {
      // Full concept table — small in DuckDB columnar format (~4 MB for 4M rows)
      return 'CREATE TABLE concept AS SELECT * FROM ' + src;
    }

    // Small reference tables: import in full
    return 'CREATE TABLE ' + tbl + ' AS SELECT * FROM ' + src;
  }

  /* ── Import: create materialized tables with filtering ── */

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
    // +1 for filter IDs setup, +1 for indexing
    var total = fileNames.length + 2;
    var chain = Promise.resolve();

    // Step 0: Load resolved concept IDs and create temp filter table
    chain = chain.then(function () {
      onProgress({ file: null, table: null, step: 'filter_ids', done: 0, total: total });
      return loadResolvedConceptIds().then(function (ids) {
        if (ids.length === 0) return;
        var batchSize = 500;
        var idChain = conn.query('CREATE TEMP TABLE _filter_ids (id INTEGER)');
        for (var i = 0; i < ids.length; i += batchSize) {
          (function (batch) {
            idChain = idChain.then(function () {
              return conn.query('INSERT INTO _filter_ids VALUES ' +
                batch.map(function (id) { return '(' + id + ')'; }).join(','));
            });
          })(ids.slice(i, i + batchSize));
        }
        return idChain.then(function () {
          return conn.query('CREATE INDEX idx_filter ON _filter_ids(id)');
        });
      }).then(function () {
        done++;
        onProgress({ file: null, table: null, step: 'filter_ids_done', done: done, total: total });
      });
    });

    // Step 1: Import each file as a materialized table
    fileNames.forEach(function (name) {
      chain = chain.then(function () {
        var tbl = tableName(name);
        onProgress({ file: name, table: tbl, step: 'importing', done: done, total: total });

        var dropSql = 'DROP TABLE IF EXISTS ' + tbl + '; DROP VIEW IF EXISTS ' + tbl;
        var createSql = getFilteredSql(name);

        return conn.query(dropSql).then(function () {
          return conn.query(createSql);
        }).then(function () {
          done++;
          onProgress({ file: name, table: tbl, step: 'done', done: done, total: total });
        }).catch(function (err) {
          console.warn('Skipping ' + name + ': ' + err.message);
          done++;
          onProgress({ file: name, table: tbl, step: 'error', done: done, total: total });
        });
      });
    });

    // Step 2: Create indexes
    chain = chain.then(function () {
      onProgress({ file: null, table: null, step: 'indexing', done: done, total: total });
      var indexChain = Promise.resolve();
      INDEXES.forEach(function (sql) {
        indexChain = indexChain.then(function () {
          return conn.query(sql).catch(function () { /* ignore if table missing */ });
        });
      });
      return indexChain.then(function () {
        return conn.query('DROP TABLE IF EXISTS _filter_ids').catch(function () {});
      }).then(function () {
        done++;
        onProgress({ file: null, table: null, step: 'indexing_done', done: done, total: total });
      });
    });

    return chain.then(function () { return total; });
  }

  /* ── Detect files in directory (Parquet preferred, CSV fallback) ── */

  function detectAndCollectFiles(dirHandle) {
    var fileHandlesMap = {};
    var chain = Promise.resolve();

    // Try Parquet first, then CSV for each required table
    REQUIRED_TABLES.forEach(function (tbl) {
      chain = chain.then(function () {
        var parquetName = tbl + '.parquet';
        var csvName = tbl + '.csv';
        return dirHandle.getFileHandle(parquetName).then(function (fh) {
          fileHandlesMap[parquetName] = fh;
        }).catch(function () {
          return dirHandle.getFileHandle(csvName).then(function (fh) {
            fileHandlesMap[csvName] = fh;
          });
        });
      });
    });

    // Optional tables: try Parquet first, then CSV
    OPTIONAL_TABLES.forEach(function (tbl) {
      chain = chain.then(function () {
        var parquetName = tbl + '.parquet';
        var csvName = tbl + '.csv';
        return dirHandle.getFileHandle(parquetName).then(function (fh) {
          fileHandlesMap[parquetName] = fh;
        }).catch(function () {
          return dirHandle.getFileHandle(csvName).then(function (fh) {
            fileHandlesMap[csvName] = fh;
          }).catch(function () { /* optional */ });
        });
      });
    });

    return chain.then(function () { return fileHandlesMap; });
  }

  /* ── Import from directory handle (Chrome/Edge) ──────── */

  function importFromDirectory(dirHandle, onProgress) {
    onProgress = onProgress || function () {};

    return detectAndCollectFiles(dirHandle)
      .then(function (fileHandlesMap) {
        return initDuckDB().then(function () {
          return registerFileHandlesWithDuckDB(fileHandlesMap);
        }).then(function () {
          return createTablesFromFiles(Object.keys(fileHandlesMap), onProgress);
        }).then(function (total) {
          onProgress({ file: null, table: null, step: 'persisting', done: total, total: total });
          return exportDbToIndexedDB()
            .then(function () {
              return storeDirectoryHandle(dirHandle).catch(function () {});
            })
            .then(function () {
              return storeFileHandles(fileHandlesMap).catch(function () {});
            })
            .then(function () {
              importMode = 'filtered';
              onProgress({ file: null, table: null, step: 'complete', done: total, total: total });
            });
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
      if (REQUIRED_CSV.indexOf(name) !== -1 || OPTIONAL_CSV.indexOf(name) !== -1 ||
          REQUIRED_PARQUET.indexOf(name) !== -1 || OPTIONAL_PARQUET.indexOf(name) !== -1) {
        // Prefer Parquet over CSV for same table
        var tbl = tableName(name);
        var existing = fileMap[tbl];
        if (!existing || isParquetFile(name)) {
          fileMap[tbl] = { name: name, file: f };
        }
      }
    }

    // Check required tables
    var missingTables = REQUIRED_TABLES.filter(function (t) { return !fileMap[t.toLowerCase()]; });
    if (missingTables.length > 0) {
      return Promise.reject(new Error('Missing required files: ' + missingTables.join(', ')));
    }

    var filesToImport = [];
    var keys = Object.keys(fileMap);
    keys.forEach(function (k) { filesToImport.push(fileMap[k]); });

    return initDuckDB().then(function () {
      var regChain = Promise.resolve();
      filesToImport.forEach(function (entry) {
        regChain = regChain.then(function () {
          return db.registerFileHandle(
            entry.name,
            entry.file,
            duckdbLib.DuckDBDataProtocol.BROWSER_FILEREADER,
            true
          );
        });
      });
      return regChain;
    }).then(function () {
      var fileNames = filesToImport.map(function (e) { return e.name; });
      return createTablesFromFiles(fileNames, onProgress);
    }).then(function (total) {
      onProgress({ file: null, table: null, step: 'persisting', done: total, total: total });
      importMode = 'filtered';
      return exportDbToIndexedDB().then(function () {
        onProgress({ file: null, table: null, step: 'complete', done: total, total: total });
      });
    });
  }

  /* ── Restore from stored data (future sessions) ─────── */

  function remountFromStoredHandles() {
    /* Strategy 1: IndexedDB buffer (all browsers) */
    return loadFromStoredBuffer().then(function (success) {
      if (success) {
        importMode = 'filtered';
        return true;
      }

      /* Strategy 2: FileSystemFileHandles (Chrome/Edge) — re-import from source */
      return getStoredFileHandles().then(function (handles) {
        var names = Object.keys(handles);
        if (names.length === 0) return false;

        // Check we have all required tables (CSV or Parquet)
        var tablesCovered = {};
        names.forEach(function (n) { tablesCovered[tableName(n)] = true; });
        var requiredLower = REQUIRED_TABLES.map(function (t) { return t.toLowerCase(); });
        var missing = requiredLower.filter(function (t) { return !tablesCovered[t]; });
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

          // Filter to relevant files only
          var relevantHandles = {};
          names.forEach(function (n) {
            var tbl = tableName(n);
            var isRequired = REQUIRED_TABLES.some(function (t) { return t.toLowerCase() === tbl; });
            var isOptional = OPTIONAL_TABLES.some(function (t) { return t.toLowerCase() === tbl; });
            if (isRequired || isOptional) relevantHandles[n] = handles[n];
          });
          var relevantNames = Object.keys(relevantHandles);

          return registerFileHandlesWithDuckDB(relevantHandles).then(function () {
            return createTablesFromFiles(relevantNames, function () {}).then(function () {
              importMode = 'filtered';
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
          stats[rows[i].table_name] = rows[i].table_type;
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
      importMode = null;
      return clearAllHandles().catch(function () {});
    });
    return chain;
  }

  /* ── Public API ──────────────────────────────────────── */

  window.VocabDB = {
    REQUIRED_TABLES: REQUIRED_TABLES,
    OPTIONAL_TABLES: OPTIONAL_TABLES,
    REQUIRED_PARQUET: REQUIRED_PARQUET,
    OPTIONAL_PARQUET: OPTIONAL_PARQUET,
    getImportMode: function () { return importMode; },
    /** Synchronous: is there an active DuckDB connection? Says nothing about
     *  whether REQUIRED_TABLES are loaded — use isDatabaseReady() (Promise)
     *  for the full readiness check. */
    hasConnection: function () { return !!conn; },
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
