// Stub for Cronet_CreateCertVerifierWithPublicKeySHA256 which exists in the
// cronet-go Go bindings but was not included in the prebuilt static library.
// This function is never called by Wick — it's only needed to satisfy the linker.

#include <stddef.h>
#include <stdint.h>

void* Cronet_CreateCertVerifierWithPublicKeySHA256(
    const uint8_t** hashes,
    size_t hash_count) {
    (void)hashes;
    (void)hash_count;
    return NULL;
}
