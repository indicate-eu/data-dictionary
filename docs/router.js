/**
 * Hash-based SPA Router
 * Routes: #/concept-sets, #/etl-guidelines, #/projects, #/settings, #/general-settings, #/dev-tools
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

  return {
    register: register,
    navigate: navigate,
    init: init,
    getCurrentRoute: function () { return currentRoute; },
    parseHash: parseHash
  };
})();
