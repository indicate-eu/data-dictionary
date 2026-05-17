/**
 * Hash-based SPA Router
 * Routes: #/concept-sets, #/mapping, #/projects, #/settings, #/dev-tools, #/documentation
 * Legacy alias: #/mapping-recommendations → #/mapping?tab=recommendations
 * Supports query params: #/concept-sets?id=123, #/projects?id=1
 */
var Router = (function () {
  'use strict';

  var routes = {};
  var currentRoute = null;

  function parseHash() {
    var hash = window.location.hash.slice(1) || '/concept-sets';
    var qIdx = hash.indexOf('?');
    var path = qIdx === -1 ? hash : hash.substring(0, qIdx);
    var query = {};
    if (qIdx !== -1) {
      hash.substring(qIdx + 1).split('&').forEach(function (pair) {
        var kv = pair.split('=');
        if (kv[0]) query[decodeURIComponent(kv[0])] = decodeURIComponent(kv[1] || '');
      });
    }
    return { path: path, query: query };
  }

  function register(path, handler) {
    routes[path] = handler;
  }

  function navigate(path, query) {
    var hash = path;
    if (query) {
      var keys = Object.keys(query);
      if (keys.length > 0) {
        hash += '?' + keys.map(function (k) {
          return encodeURIComponent(k) + '=' + encodeURIComponent(query[k]);
        }).join('&');
      }
    }
    window.location.hash = hash;
  }

  function handleHashChange() {
    var parsed = parseHash();
    var handler = routes[parsed.path];
    if (handler) {
      currentRoute = parsed;
      handler(parsed.path, parsed.query);
    } else {
      navigate('/concept-sets');
    }
  }

  function init() {
    window.addEventListener('hashchange', handleHashChange);
    handleHashChange();
  }

  // Rewrite the URL without triggering the router (same semantics as
  // history.replaceState on the hash) but notify listeners that the hash
  // changed in-place. Used by pages that mutate query string state without
  // wanting a full navigation — keeps per-page hash tracking in sync.
  var hashReplaceListeners = [];
  function replaceState(url) {
    history.replaceState(null, '', url);
    hashReplaceListeners.forEach(function (cb) { try { cb(url); } catch (e) {} });
  }
  function onHashReplaced(cb) { hashReplaceListeners.push(cb); }

  return {
    register: register,
    navigate: navigate,
    replaceState: replaceState,
    onHashReplaced: onHashReplaced,
    init: init,
    getCurrentRoute: function () { return currentRoute; },
    parseHash: parseHash
  };
})();
