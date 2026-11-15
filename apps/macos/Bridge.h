#ifndef FOLIO_BRIDGE_H
#define FOLIO_BRIDGE_H
#include <stddef.h>
#include <stdint.h>

char * _Nullable folio_call(const char * _Nonnull request);
void folio_free(char * _Nullable result);

typedef void (*FolioUIAction)(void * _Nonnull context, const uint8_t * _Nonnull bytes, size_t length);
void * _Nullable folio_ui_create(uint32_t region, void * _Nonnull context, FolioUIAction _Nonnull action);
void * _Nonnull folio_ui_view(void * _Nonnull handle);
void folio_ui_update(void * _Nonnull handle, const uint8_t * _Nonnull bytes, size_t length);
void folio_ui_destroy(void * _Nonnull handle);

#endif
