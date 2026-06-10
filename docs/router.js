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
        // A malformed percent-escape must not break navigation — skip the pair.
        try {
          if (kv[0]) query[decodeURIComponent(kv[0])] = decodeURIComponent(kv[1] || '');
        } catch (e) {}
      });
    }
    return { path: path, query: query };
  }

  function register(path, handler) {
    routes[path] = handler;
  }

  // Read the currently-active lang from the URL (?lang=fr) so we can preserve
  // it across navigations without depending on App being initialized yet.
  function currentLangFromUrl() {
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
      } catch (e) {}
    }
    return null;
  }

  function navigate(path, query) {
    var merged = {};
    if (query) {
      var qkeys = Object.keys(query);
      for (var i = 0; i < qkeys.length; i++) merged[qkeys[i]] = query[qkeys[i]];
    }
    // Preserve the active language across navigations. `lang=en` is the default
    // and stays implicit — only `lang=fr` is materialised in the URL.
    if (merged.lang == null) {
      var l = currentLangFromUrl();
      if (l === 'fr') merged.lang = 'fr';
    }
    if (merged.lang === 'en') delete merged.lang;
    var hash = path;
    var mkeys = Object.keys(merged);
    if (mkeys.length > 0) {
      hash += '?' + mkeys.map(function (k) {
        return encodeURIComponent(k) + '=' + encodeURIComponent(merged[k]);
      }).join('&');
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
  function replaceState(url, langAlreadyHandled) {
    // Preserve ?lang=fr if the caller dropped it. Callers pass raw hash strings
    // (e.g. "#/mapping?tab=recommendations") and shouldn't have to know about
    // the lang query param. Callers that DO manage the lang param themselves
    // (e.g. the language toggle, which deliberately removes lang when switching
    // back to English) pass langAlreadyHandled=true so we don't second-guess them.
    var l = currentLangFromUrl();
    if (!langAlreadyHandled && l === 'fr' && url && url.indexOf('lang=') === -1) {
      var hashIdx = url.indexOf('#');
      if (hashIdx !== -1) {
        var prefix = url.substring(0, hashIdx);
        var hashPart = url.substring(hashIdx + 1);
        var sep = hashPart.indexOf('?') === -1 ? '?' : '&';
        url = prefix + '#' + hashPart + sep + 'lang=fr';
      }
    }
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
