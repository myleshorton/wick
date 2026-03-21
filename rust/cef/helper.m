// wick Helper: CEF subprocess entry point.
// This binary handles renderer, GPU, and other CEF subprocess types.
// CEF determines the type from --type= command-line arguments.

#include <stdio.h>
#import <Cocoa/Cocoa.h>

#include "include/capi/cef_app_capi.h"
#include "include/cef_api_hash.h"

int main(int argc, char* argv[]) {
    @autoreleasepool {
        // Must configure API version before any CEF call
        cef_api_hash(CEF_API_VERSION, 0);

        cef_main_args_t main_args = { .argc = argc, .argv = argv };
        int exit_code = cef_execute_process(&main_args, NULL, NULL);
        return exit_code;
    }
}
