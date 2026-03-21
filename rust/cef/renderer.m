// wick-renderer: Minimal CEF offscreen renderer.
// Takes a URL as argv[1], renders via Chromium, outputs rendered HTML to stdout.
// Separate process from wick — avoids embedding CEF's message loop in Rust async.

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

static void CEF_CALLBACK visitor_visit(cef_string_visitor_t* self,
                                        const cef_string_t* string) {
    (void)self;
    if (string && string->str) {
        cef_string_utf8_t utf8 = {};
        cef_string_utf16_to_utf8(string->str, string->length, &utf8);
        fwrite(utf8.str, 1, utf8.length, stdout);
        cef_string_utf8_clear(&utf8);
    }
    fflush(stdout);
    cef_quit_message_loop();
}

static cef_string_visitor_t g_html_visitor;

// ── Load handler — extracts HTML when page finishes loading ───

static void CEF_CALLBACK on_loading_state_change(
    cef_load_handler_t* self, cef_browser_t* browser,
    int isLoading, int canGoBack, int canGoForward) {
    (void)self; (void)canGoBack; (void)canGoForward;
    if (!isLoading && browser) {
        cef_frame_t* frame = browser->get_main_frame(browser);
        if (frame) {
            frame->get_source(frame, &g_html_visitor);
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
    (void)errorText; (void)failedUrl;
    fprintf(stderr, "wick-renderer: load error %d\n", errorCode);
    cef_quit_message_loop();
}

static cef_load_handler_t g_load_handler;

// ── Render handler (required for OSR, minimal no-op) ──────────

static void CEF_CALLBACK get_view_rect(cef_render_handler_t* self,
    cef_browser_t* browser, cef_rect_t* rect) {
    (void)self; (void)browser;
    rect->x = 0; rect->y = 0; rect->width = 1; rect->height = 1;
}

static void CEF_CALLBACK on_paint(cef_render_handler_t* self,
    cef_browser_t* browser, cef_paint_element_type_t type,
    size_t dirtyRectsCount, const cef_rect_t* dirtyRects,
    const void* buffer, int width, int height) {
    (void)self; (void)browser; (void)type;
    (void)dirtyRectsCount; (void)dirtyRects;
    (void)buffer; (void)width; (void)height;
}

static int CEF_CALLBACK get_screen_info(cef_render_handler_t* self,
    cef_browser_t* browser, cef_screen_info_t* screen_info) {
    (void)self; (void)browser; (void)screen_info;
    return 0;
}

static cef_render_handler_t g_render_handler;

// ── Life span handler ─────────────────────────────────────────

static void CEF_CALLBACK on_after_created(cef_life_span_handler_t* self,
    cef_browser_t* browser) {
    (void)self;
    g_browser = browser;
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

static cef_life_span_handler_t g_life_span_handler;

// ── Client ────────────────────────────────────────────────────

static cef_life_span_handler_t* CEF_CALLBACK get_life_span_handler(cef_client_t* self) {
    (void)self; return &g_life_span_handler;
}
static cef_load_handler_t* CEF_CALLBACK get_load_handler(cef_client_t* self) {
    (void)self; return &g_load_handler;
}
static cef_render_handler_t* CEF_CALLBACK get_render_handler(cef_client_t* self) {
    (void)self; return &g_render_handler;
}

static cef_client_t g_client;

// ── Main ──────────────────────────────────────────────────────

int main(int argc, char* argv[]) {
    char exe_buf[4096];
    uint32_t exe_buf_size = sizeof(exe_buf);
    _NSGetExecutablePath(exe_buf, &exe_buf_size);

    // Inject CEF flags (multi-process mode, GPU disabled for headless)
    int new_argc = argc + 2;
    char** new_argv = malloc(sizeof(char*) * (new_argc + 1));
    for (int i = 0; i < argc; i++) new_argv[i] = argv[i];
    new_argv[argc] = "--disable-gpu";
    new_argv[argc + 1] = "--disable-gpu-compositing";
    new_argv[new_argc] = NULL;

    // Must call cef_api_hash first to configure the API version tables.
    cef_api_hash(CEF_API_VERSION, 0);

    cef_main_args_t main_args = { .argc = new_argc, .argv = new_argv };
    int exit_code = cef_execute_process(&main_args, NULL, NULL);
    if (exit_code >= 0) return exit_code;

    if (argc < 2) {
        fprintf(stderr, "Usage: wick-renderer <url>\n");
        return 1;
    }

    // macOS requires NSApplication before CEF browser creation
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    }

    // Initialize all handler structs
    init_base(&g_html_visitor.base, sizeof(cef_string_visitor_t));
    g_html_visitor.visit = visitor_visit;

    init_base(&g_load_handler.base, sizeof(cef_load_handler_t));
    g_load_handler.on_loading_state_change = on_loading_state_change;
    g_load_handler.on_load_start = on_load_start;
    g_load_handler.on_load_end = on_load_end;
    g_load_handler.on_load_error = on_load_error;

    init_base(&g_render_handler.base, sizeof(cef_render_handler_t));
    g_render_handler.get_view_rect = get_view_rect;
    g_render_handler.on_paint = on_paint;
    g_render_handler.get_screen_info = get_screen_info;

    init_base(&g_life_span_handler.base, sizeof(cef_life_span_handler_t));
    g_life_span_handler.on_after_created = on_after_created;
    g_life_span_handler.do_close = do_close;
    g_life_span_handler.on_before_close = on_before_close;

    init_base(&g_client.base, sizeof(cef_client_t));
    g_client.get_life_span_handler = get_life_span_handler;
    g_client.get_load_handler = get_load_handler;
    g_client.get_render_handler = get_render_handler;

    // CEF settings
    cef_settings_t settings = {};
    settings.size = sizeof(cef_settings_t);
    settings.windowless_rendering_enabled = 1;
    settings.no_sandbox = 1;
    settings.log_severity = LOGSEVERITY_ERROR;

    // Standard macOS .app bundle layout: Frameworks/ is at Contents/Frameworks/
    // which is @executable_path/../Frameworks/ (exe is in Contents/MacOS/)
    char* exe_dir = dirname(exe_buf);
    char fw_dir[4096];
    snprintf(fw_dir, sizeof(fw_dir), "%s/../Frameworks/Chromium Embedded Framework.framework",
             exe_dir);
    cef_string_utf8_to_utf16(fw_dir, strlen(fw_dir), &settings.framework_dir_path);

    // Helper binary in standard bundle location
    char helper_path[4096];
    snprintf(helper_path, sizeof(helper_path),
             "%s/../Frameworks/wick Helper.app/Contents/MacOS/wick Helper",
             exe_dir);
    char helper_real[4096];
    if (realpath(helper_path, helper_real)) {
        cef_string_utf8_to_utf16(helper_real, strlen(helper_real),
                                  &settings.browser_subprocess_path);
    } else {
        fprintf(stderr, "wick-renderer: helper not found at %s\n", helper_path);
        return 1;
    }

    // Set main_bundle_path to the .app bundle containing this binary.
    // CEF uses this for Mach port rendezvous registration on macOS.
    char bundle_path[4096];
    snprintf(bundle_path, sizeof(bundle_path), "%s/../..", exe_dir);
    char bundle_real[4096];
    if (realpath(bundle_path, bundle_real)) {
        cef_string_utf8_to_utf16(bundle_real, strlen(bundle_real),
                                  &settings.main_bundle_path);
    }

    char cache_path[4096];
    snprintf(cache_path, sizeof(cache_path), "%s/.wick/cef-cache-%d",
             getenv("HOME") ? getenv("HOME") : "/tmp", getpid());
    cef_string_utf8_to_utf16(cache_path, strlen(cache_path), &settings.root_cache_path);

    if (!cef_initialize(&main_args, &settings, NULL, NULL)) {
        fprintf(stderr, "wick-renderer: cef_initialize failed\n");
        return 1;
    }

    // Create offscreen browser and navigate
    cef_window_info_t window_info = {};
    window_info.size = sizeof(cef_window_info_t);
    window_info.windowless_rendering_enabled = 1;
    window_info.hidden = 1;

    cef_browser_settings_t browser_settings = {};
    browser_settings.size = sizeof(cef_browser_settings_t);
    browser_settings.windowless_frame_rate = 1;

    cef_string_t cef_url = {};
    cef_string_utf8_to_utf16(argv[1], strlen(argv[1]), &cef_url);

    cef_browser_host_create_browser_sync(
        &window_info, &g_client, &cef_url, &browser_settings, NULL, NULL);
    cef_string_clear(&cef_url);

    // Run until page is loaded and HTML is extracted
    cef_run_message_loop();

    cef_shutdown();

    // Clean up the per-process cache directory
    char rm_cmd[4096];
    snprintf(rm_cmd, sizeof(rm_cmd), "%s/.wick/cef-cache-%d",
             getenv("HOME") ? getenv("HOME") : "/tmp", getpid());
    // Best-effort recursive delete
    char rm_full[4200];
    snprintf(rm_full, sizeof(rm_full), "rm -rf '%s'", rm_cmd);
    system(rm_full);

    free(new_argv);
    return 0;
}
