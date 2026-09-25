/* Amortable service worker — network-first so the app self-updates online, cache fallback offline. */
var CACHE = "amortable-v1";
var SHELL = ["/", "/index.html", "/simple/", "/simple/index.html",
  "/manifest.webmanifest", "/icon-180.png", "/icon-192.png", "/icon-512.png", "/favicon-64.png"];

self.addEventListener("install", function(e){
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then(function(c){ return Promise.all(SHELL.map(function(u){ return c.add(u).catch(function(){}); })); }));
});

self.addEventListener("activate", function(e){
  e.waitUntil(caches.keys().then(function(keys){ return Promise.all(keys.filter(function(k){return k!==CACHE;}).map(function(k){return caches.delete(k);})); }).then(function(){ return self.clients.claim(); }));
});

self.addEventListener("fetch", function(e){
  var req = e.request;
  if(req.method !== "GET" || new URL(req.url).origin !== self.location.origin) return;
  e.respondWith(
    fetch(req).then(function(res){
      var copy = res.clone();
      caches.open(CACHE).then(function(c){ c.put(req, copy); });
      return res;
    }).catch(function(){
      return caches.match(req).then(function(r){ return r || caches.match("/index.html"); });
    })
  );
});
