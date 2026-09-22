#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

bool rapfi_is_available(void);

bool rapfi_choose_move(
    const int16_t *rows,
    const int16_t *columns,
    const int8_t *stones,
    int32_t moveCount,
    int32_t sideToMove,
    int32_t timeLimitMs,
    int32_t strengthLevel,
    int32_t *outRow,
    int32_t *outColumn
);

void rapfi_cancel(void);

#ifdef __cplusplus
}
#endif
