// wick Helper: CEF subprocess entry point with Chrome API stealth patches.
//
// This binary handles renderer, GPU, and other CEF subprocess types.
// For renderer subprocesses, it injects JavaScript in OnContextCreated
// to make CEF indistinguishable from real Chrome at the JS API level.

#include <stdio.h>
#include <string.h>

#import <Cocoa/Cocoa.h>

#include "include/capi/cef_app_capi.h"
#include "include/capi/cef_render_process_handler_capi.h"
#include "include/cef_api_hash.h"

// ── Ref counting ──────────────────────────────────────────────

static void CEF_CALLBACK add_ref(cef_base_ref_counted_t* s) { (void)s; }
static int CEF_CALLBACK release_fn(cef_base_ref_counted_t* s) { (void)s; return 1; }
static int CEF_CALLBACK has_one(cef_base_ref_counted_t* s) { (void)s; return 1; }
static int CEF_CALLBACK has_any(cef_base_ref_counted_t* s) { (void)s; return 1; }

static void init_base(cef_base_ref_counted_t* base, size_t size) {
    base->size = size;
    base->add_ref = add_ref;
    base->release = release_fn;
    base->has_one_ref = has_one;
    base->has_at_least_one_ref = has_any;
}

// ── Stealth JavaScript ────────────────────────────────────────
// Injected via OnContextCreated BEFORE any page scripts execute.
// Makes CEF's JS environment match real Chrome's.

static const char* STEALTH_JS =
    // 1. chrome.runtime (most important — Cloudflare checks this)
    "if (!window.chrome) window.chrome = {};"
    "if (!window.chrome.runtime) {"
    "  window.chrome.runtime = {"
    "    OnInstalledReason: {"
    "      CHROME_UPDATE: 'chrome_update',"
    "      INSTALL: 'install',"
    "      SHARED_MODULE_UPDATE: 'shared_module_update',"
    "      UPDATE: 'update'"
    "    },"
    "    OnRestartRequiredReason: {"
    "      APP_UPDATE: 'app_update',"
    "      OS_UPDATE: 'os_update',"
    "      PERIODIC: 'periodic'"
    "    },"
    "    PlatformArch: {"
    "      ARM: 'arm',"
    "      ARM64: 'arm64',"
    "      MIPS: 'mips',"
    "      MIPS64: 'mips64',"
    "      X86_32: 'x86-32',"
    "      X86_64: 'x86-64'"
    "    },"
    "    PlatformOs: {"
    "      ANDROID: 'android',"
    "      CROS: 'cros',"
    "      LINUX: 'linux',"
    "      MAC: 'mac',"
    "      OPENBSD: 'openbsd',"
    "      WIN: 'win'"
    "    },"
    "    RequestUpdateCheckStatus: {"
    "      NO_UPDATE: 'no_update',"
    "      THROTTLED: 'throttled',"
    "      UPDATE_AVAILABLE: 'update_available'"
    "    },"
    "    connect: function() { return { onDisconnect: { addListener: function() {} }, onMessage: { addListener: function() {} }, postMessage: function() {} }; },"
    "    sendMessage: function() {},"
    "    id: undefined"
    "  };"
    "}"

    // 2. navigator.plugins (Cloudflare, Akamai check this)
    "Object.defineProperty(navigator, 'plugins', {"
    "  get: function() {"
    "    var p = ["
    "      {name:'Chrome PDF Plugin',filename:'internal-pdf-viewer',description:'Portable Document Format',length:1,0:{type:'application/x-google-chrome-pdf',suffixes:'pdf',description:'Portable Document Format',enabledPlugin:null}},"
    "      {name:'Chrome PDF Viewer',filename:'mhjfbmdgcfjbbpaeojofohoefgiehjai',description:'',length:1,0:{type:'application/pdf',suffixes:'pdf',description:'',enabledPlugin:null}},"
    "      {name:'Native Client',filename:'internal-nacl-plugin',description:'',length:2,0:{type:'application/x-nacl',suffixes:'',description:'Native Client Executable',enabledPlugin:null},1:{type:'application/x-pnacl',suffixes:'',description:'Portable Native Client Executable',enabledPlugin:null}}"
    "    ];"
    "    p.item = function(i) { return this[i] || null; };"
    "    p.namedItem = function(n) { for(var i=0;i<this.length;i++) if(this[i].name===n) return this[i]; return null; };"
    "    p.refresh = function() {};"
    "    return p;"
    "  }"
    "});"

    // 3. navigator.mimeTypes (must match plugins)
    "Object.defineProperty(navigator, 'mimeTypes', {"
    "  get: function() {"
    "    var m = ["
    "      {type:'application/pdf',suffixes:'pdf',description:'',enabledPlugin:{name:'Chrome PDF Viewer'}},"
    "      {type:'application/x-google-chrome-pdf',suffixes:'pdf',description:'Portable Document Format',enabledPlugin:{name:'Chrome PDF Plugin'}},"
    "      {type:'application/x-nacl',suffixes:'',description:'Native Client Executable',enabledPlugin:{name:'Native Client'}},"
    "      {type:'application/x-pnacl',suffixes:'',description:'Portable Native Client Executable',enabledPlugin:{name:'Native Client'}}"
    "    ];"
    "    m.item = function(i) { return this[i] || null; };"
    "    m.namedItem = function(n) { for(var i=0;i<this.length;i++) if(this[i].type===n) return this[i]; return null; };"
    "    return m;"
    "  }"
    "});"

    // 4. chrome.csi and chrome.loadTimes (legacy APIs, some bots check)
    "window.chrome.csi = function() {"
    "  return {startE: Date.now(), onloadT: Date.now(), pageT: Date.now()/1000, tran: 15};"
    "};"
    "window.chrome.loadTimes = function() {"
    "  return {"
    "    get requestTime() { return Date.now()/1000; },"
    "    get startLoadTime() { return Date.now()/1000; },"
    "    get commitLoadTime() { return Date.now()/1000; },"
    "    get finishDocumentLoadTime() { return Date.now()/1000; },"
    "    get finishLoadTime() { return Date.now()/1000; },"
    "    get firstPaintTime() { return Date.now()/1000; },"
    "    get firstPaintAfterLoadTime() { return 0; },"
    "    get navigationType() { return 'Other'; },"
    "    get wasFetchedViaSpdy() { return true; },"
    "    get wasNpnNegotiated() { return true; },"
    "    get npnNegotiatedProtocol() { return 'h2'; },"
    "    get wasAlternateProtocolAvailable() { return false; },"
    "    get connectionInfo() { return 'h2'; }"
    "  };"
    "};"

    // 5. Permissions API consistency
    "(function() {"
    "  var origQuery = navigator.permissions && navigator.permissions.query;"
    "  if (origQuery) {"
    "    navigator.permissions.query = function(desc) {"
    "      if (desc && desc.name === 'notifications') {"
    "        return Promise.resolve({state: Notification.permission, onchange: null});"
    "      }"
    "      return origQuery.apply(this, arguments);"
    "    };"
    "  }"
    "})();"

    // 6. Ensure webdriver is false (CEF doesn't set it, but double-check)
    "Object.defineProperty(navigator, 'webdriver', {"
    "  get: function() { return false; }"
    "});"

    // 7. window.outerWidth/outerHeight for offscreen mode
    "if (window.outerWidth === 0) {"
    "  Object.defineProperty(window, 'outerWidth', {get: function() { return 1920; }});"
    "  Object.defineProperty(window, 'outerHeight', {get: function() { return 1080; }});"
    "}"
;

// ── Render process handler ────────────────────────────────────

static void CEF_CALLBACK on_context_created(
    cef_render_process_handler_t* self,
    cef_browser_t* browser,
    cef_frame_t* frame,
    struct _cef_v8_context_t* context) {
    (void)self; (void)browser; (void)context;

    // Inject stealth JS before any page script runs
    if (frame) {
        cef_string_t code = {};
        cef_string_utf8_to_utf16(STEALTH_JS, strlen(STEALTH_JS), &code);
        cef_string_t url = {};
        cef_string_utf8_to_utf16("", 0, &url);
        frame->execute_java_script(frame, &code, &url, 0);
        cef_string_clear(&code);
        cef_string_clear(&url);
    }
}

static cef_render_process_handler_t g_render_process_handler;

// ── App handler ───────────────────────────────────────────────

static cef_render_process_handler_t* CEF_CALLBACK get_render_process_handler(
    cef_app_t* self) {
    (void)self;
    return &g_render_process_handler;
}

static cef_app_t g_app;

// ── Main ──────────────────────────────────────────────────────

int main(int argc, char* argv[]) {
    @autoreleasepool {
        cef_api_hash(CEF_API_VERSION, 0);

        // Initialize the render process handler (stealth patches)
        init_base(&g_render_process_handler.base,
                   sizeof(cef_render_process_handler_t));
        g_render_process_handler.on_context_created = on_context_created;

        // Initialize the app handler
        init_base(&g_app.base, sizeof(cef_app_t));
        g_app.get_render_process_handler = get_render_process_handler;

        cef_main_args_t main_args = { .argc = argc, .argv = argv };
        int exit_code = cef_execute_process(&main_args, &g_app, NULL);
        return exit_code;
    }
}
