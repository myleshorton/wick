// wick-renderer: Minimal CEF offscreen renderer.
// Reads a URL from argv[1], renders the page, outputs the fully-rendered
// HTML to stdout, then exits.
//
// This is a separate process from the main wick binary. It avoids the
// complexity of embedding CEF's message loop inside the async Rust runtime.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libgen.h>
#include <mach-o/dyld.h>

#import <Cocoa/Cocoa.h>

#include "include/capi/cef_app_capi.h"
#include "include/capi/cef_browser_capi.h"
#include "include/capi/cef_client_capi.h"
#include "include/capi/cef_frame_capi.h"
#include "include/capi/cef_life_span_handler_capi.h"
#include "include/capi/cef_load_handler_capi.h"
#include "include/capi/cef_render_handler_capi.h"
#include "include/capi/cef_string_visitor_capi.h"

// ── Globals ────────────────────────────────────────────────────

static cef_browser_t* g_browser = NULL;
static int g_done = 0;

// ── Ref counting (dummy — all handlers are static/global) ─────

static void CEF_CALLBACK add_ref(cef_base_ref_counted_t* self) { (void)self; }
static int CEF_CALLBACK release(cef_base_ref_counted_t* self) { (void)self; return 1; }
static int CEF_CALLBACK has_one_ref(cef_base_ref_counted_t* self) { (void)self; return 1; }
static int CEF_CALLBACK has_at_least_one_ref(cef_base_ref_counted_t* self) { (void)self; return 1; }

static void init_base(cef_base_ref_counted_t* base, size_t size) {
    base->size = size;
    base->add_ref = add_ref;
    base->release = release;
    base->has_one_ref = has_one_ref;
    base->has_at_least_one_ref = has_at_least_one_ref;
}

// ── String visitor — receives the rendered HTML ───────────────

typedef struct {
    cef_string_visitor_t visitor;
} html_visitor_t;

static void CEF_CALLBACK visitor_visit(cef_string_visitor_t* self,
                                        const cef_string_t* string) {
    (void)self;
    fprintf(stderr, "DEBUG: visitor_visit called, string=%p\n", (void*)string);
    if (string && string->str) {
        // Convert UTF-16 to UTF-8 and write to stdout
        cef_string_utf8_t utf8 = {};
        cef_string_utf16_to_utf8(string->str, string->length, &utf8);
        fwrite(utf8.str, 1, utf8.length, stdout);
        cef_string_utf8_clear(&utf8);
    }
    fflush(stdout);
    g_done = 1;
    // Quit the message loop and NSApplication
    cef_quit_message_loop();
}

static html_visitor_t g_html_visitor;

// ── Load handler — detects page load completion ───────────────

typedef struct {
    cef_load_handler_t handler;
} my_load_handler_t;

static void CEF_CALLBACK on_loading_state_change(
    cef_load_handler_t* self, cef_browser_t* browser,
    int isLoading, int canGoBack, int canGoForward) {
    (void)self; (void)canGoBack; (void)canGoForward;
    fprintf(stderr, "DEBUG: on_loading_state_change isLoading=%d\n", isLoading);
    if (!isLoading && browser) {
        // Page finished loading — extract the source HTML
        cef_frame_t* frame = browser->get_main_frame(browser);
        fprintf(stderr, "DEBUG: got frame=%p\n", (void*)frame);
        if (frame) {
            frame->get_source(frame, &g_html_visitor.visitor);
            fprintf(stderr, "DEBUG: called get_source\n");
        }
    }
}

static void CEF_CALLBACK on_load_start(cef_load_handler_t* self,
    cef_browser_t* browser, cef_frame_t* frame, cef_transition_type_t tt) {
    (void)self; (void)browser; (void)frame; (void)tt;
}

static void CEF_CALLBACK on_load_end(cef_load_handler_t* self,
    cef_browser_t* browser, cef_frame_t* frame, int httpStatusCode) {
    (void)self; (void)browser; (void)frame; (void)httpStatusCode;
}

static void CEF_CALLBACK on_load_error(cef_load_handler_t* self,
    cef_browser_t* browser, cef_frame_t* frame,
    cef_errorcode_t errorCode, const cef_string_t* errorText,
    const cef_string_t* failedUrl) {
    (void)self; (void)browser; (void)frame;
    (void)errorCode; (void)errorText; (void)failedUrl;
    fprintf(stderr, "wick-renderer: load error %d\n", errorCode);
    g_done = 1;
}

static my_load_handler_t g_load_handler;

// ── Render handler (required for OSR, minimal impl) ───────────

typedef struct {
    cef_render_handler_t handler;
} my_render_handler_t;

static void CEF_CALLBACK get_view_rect(cef_render_handler_t* self,
    cef_browser_t* browser, cef_rect_t* rect) {
    (void)self; (void)browser;
    rect->x = 0;
    rect->y = 0;
    rect->width = 1;
    rect->height = 1;
}

static void CEF_CALLBACK on_paint(cef_render_handler_t* self,
    cef_browser_t* browser, cef_paint_element_type_t type,
    size_t dirtyRectsCount, const cef_rect_t* dirtyRects,
    const void* buffer, int width, int height) {
    (void)self; (void)browser; (void)type;
    (void)dirtyRectsCount; (void)dirtyRects;
    (void)buffer; (void)width; (void)height;
    // No-op: we don't need pixel output
}

static int CEF_CALLBACK get_screen_info(cef_render_handler_t* self,
    cef_browser_t* browser, cef_screen_info_t* screen_info) {
    (void)self; (void)browser; (void)screen_info;
    return 0;
}

static my_render_handler_t g_render_handler;

// ── Life span handler ─────────────────────────────────────────

typedef struct {
    cef_life_span_handler_t handler;
} my_life_span_handler_t;

static void CEF_CALLBACK on_after_created(cef_life_span_handler_t* self,
    cef_browser_t* browser) {
    (void)self;
    g_browser = browser;
    fprintf(stderr, "DEBUG: on_after_created browser=%p\n", (void*)browser);
}

static int CEF_CALLBACK do_close(cef_life_span_handler_t* self,
    cef_browser_t* browser) {
    (void)self; (void)browser;
    return 0;
}

static void CEF_CALLBACK on_before_close(cef_life_span_handler_t* self,
    cef_browser_t* browser) {
    (void)self; (void)browser;
    cef_quit_message_loop();
}

static my_life_span_handler_t g_life_span_handler;

// ── Client ────────────────────────────────────────────────────

typedef struct {
    cef_client_t client;
} my_client_t;

static cef_life_span_handler_t* CEF_CALLBACK get_life_span_handler(
    cef_client_t* self) {
    (void)self;
    return &g_life_span_handler.handler;
}

static cef_load_handler_t* CEF_CALLBACK get_load_handler(
    cef_client_t* self) {
    (void)self;
    return &g_load_handler.handler;
}

static cef_render_handler_t* CEF_CALLBACK get_render_handler(
    cef_client_t* self) {
    (void)self;
    return &g_render_handler.handler;
}

static my_client_t g_client;

// ── Main ──────────────────────────────────────────────────────

int main(int argc, char* argv[]) {
    // Resolve executable path (needed for framework_dir_path below)
    char exe_buf[4096];
    uint32_t exe_buf_size = sizeof(exe_buf);
    _NSGetExecutablePath(exe_buf, &exe_buf_size);

    // Build args with --single-process to avoid macOS helper app issues
    int new_argc = argc + 3;
    char** new_argv = malloc(sizeof(char*) * (new_argc + 1));
    for (int i = 0; i < argc; i++) new_argv[i] = argv[i];
    new_argv[argc] = "--single-process";
    new_argv[argc + 1] = "--disable-gpu";
    new_argv[argc + 2] = "--disable-gpu-compositing";
    new_argv[new_argc] = NULL;

    // Configure the CEF API version — must be called before any other CEF function.
    // cef_api_hash() sets the internal API version on first call.
    cef_api_hash(CEF_API_VERSION, 0);
    fprintf(stderr, "DEBUG: CEF API version configured: %d\n", cef_api_version());

    // CEF subprocess check — must be first
    cef_main_args_t main_args = { .argc = new_argc, .argv = new_argv };
    int exit_code = cef_execute_process(&main_args, NULL, NULL);
    if (exit_code >= 0) {
        return exit_code; // This is a subprocess, exit now
    }

    if (argc < 2) {
        fprintf(stderr, "Usage: wick-renderer <url>\n");
        return 1;
    }
    const char* url = argv[1];

    // macOS requires NSApplication before CEF can create browsers
    @autoreleasepool {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    }

    // Initialize handlers
    init_base(&g_html_visitor.visitor.base, sizeof(cef_string_visitor_t));
    g_html_visitor.visitor.visit = visitor_visit;

    init_base(&g_load_handler.handler.base, sizeof(cef_load_handler_t));
    g_load_handler.handler.on_loading_state_change = on_loading_state_change;
    g_load_handler.handler.on_load_start = on_load_start;
    g_load_handler.handler.on_load_end = on_load_end;
    g_load_handler.handler.on_load_error = on_load_error;

    init_base(&g_render_handler.handler.base, sizeof(cef_render_handler_t));
    g_render_handler.handler.get_view_rect = get_view_rect;
    g_render_handler.handler.on_paint = on_paint;
    g_render_handler.handler.get_screen_info = get_screen_info;

    init_base(&g_life_span_handler.handler.base, sizeof(cef_life_span_handler_t));
    g_life_span_handler.handler.on_after_created = on_after_created;
    g_life_span_handler.handler.do_close = do_close;
    g_life_span_handler.handler.on_before_close = on_before_close;

    init_base(&g_client.client.base, sizeof(cef_client_t));
    g_client.client.get_life_span_handler = get_life_span_handler;
    g_client.client.get_load_handler = get_load_handler;
    g_client.client.get_render_handler = get_render_handler;
    // All other get_*_handler pointers stay NULL (CEF checks before calling).
    // on_process_message_received must be set for single-process mode:
    g_client.client.on_process_message_received = NULL;

    // CEF settings
    cef_settings_t settings = {};
    settings.size = sizeof(cef_settings_t);
    settings.windowless_rendering_enabled = 1;
    settings.no_sandbox = 1;
    settings.log_severity = LOGSEVERITY_WARNING;

    // Tell CEF where to find the framework (needed for resource resolution on macOS)
    char fw_dir[4096];
    snprintf(fw_dir, sizeof(fw_dir),
             "%s/../Frameworks/Chromium Embedded Framework.framework",
             dirname(exe_buf));
    cef_string_utf8_to_utf16(fw_dir, strlen(fw_dir), &settings.framework_dir_path);

    // Use the same binary as subprocess (works on macOS with no_sandbox=1)
    char exe_real[4096];
    realpath(exe_buf, exe_real);
    cef_string_utf8_to_utf16(exe_real, strlen(exe_real),
                              &settings.browser_subprocess_path);

    // Use single-process mode to avoid macOS helper app requirements.
    // This runs browser, renderer, and GPU in one process.
    // NOT recommended for production but works for development/testing.
    settings.multi_threaded_message_loop = 0;

    // Set a cache path to avoid singleton warnings
    char cache_path[4096];
    snprintf(cache_path, sizeof(cache_path), "%s/.wick/cef-cache",
             getenv("HOME") ? getenv("HOME") : "/tmp");
    cef_string_utf8_to_utf16(cache_path, strlen(cache_path),
                              &settings.root_cache_path);

    // Initialize CEF
    fprintf(stderr, "DEBUG: calling cef_initialize...\n");
    int init_result = cef_initialize(&main_args, &settings, NULL, NULL);
    fprintf(stderr, "DEBUG: cef_initialize returned %d\n", init_result);
    if (!init_result) {
        fprintf(stderr, "wick-renderer: cef_initialize failed\n");
        return 1;
    }

    // Create browser
    cef_window_info_t window_info = {};
    window_info.size = sizeof(cef_window_info_t);
    window_info.windowless_rendering_enabled = 1;
    window_info.hidden = 1;

    cef_browser_settings_t browser_settings = {};
    browser_settings.size = sizeof(cef_browser_settings_t);
    browser_settings.windowless_frame_rate = 1;

    cef_string_t cef_url = {};
    cef_string_utf8_to_utf16(url, strlen(url), &cef_url);

    fprintf(stderr, "DEBUG: struct sizes: client=%zu, window_info=%zu, browser_settings=%zu\n",
            sizeof(cef_client_t), sizeof(cef_window_info_t), sizeof(cef_browser_settings_t));
    fprintf(stderr, "DEBUG: calling cef_browser_host_create_browser_sync...\n");
    cef_browser_t* browser = cef_browser_host_create_browser_sync(
        &window_info, &g_client.client, &cef_url, &browser_settings, NULL, NULL);
    fprintf(stderr, "DEBUG: cef_browser_host_create_browser_sync returned %p\n", (void*)browser);
    if (browser) {
        g_browser = browser;
    }
    cef_string_clear(&cef_url);

    fprintf(stderr, "DEBUG: entering message loop...\n");

    // CEF's message loop integrates with macOS's Cocoa run loop
    // (NSApplication was created above before cef_initialize)
    cef_run_message_loop();

    cef_shutdown();
    free(new_argv);
    return 0;
}
