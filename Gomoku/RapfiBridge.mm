#include "RapfiBridge.h"

#include "config.h"
#include "game/board.h"
#include "search/searchcommon.h"
#include "search/searchengine.h"
#include "search/searcher.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <mutex>
#include <sstream>

namespace {

std::once_flag initFlag;
std::mutex searchMutex;
std::atomic_bool rapfiReady {false};
std::atomic_bool cancelRequested {false};

void initializeRapfi()
{
    std::call_once(initFlag, [] {
        // Keep the embedded engine deterministic and quiet. The app already runs
        // the search from a detached Swift task, so one native search thread is
        // sufficient and avoids competing thread pools on iPhone/iPad.
        Config::GeneralCfg.messageMode = MsgMode::NONE;
        Config::GeneralCfg.defaultThreadNum = 1;

        std::istringstream configStream(Config::InternalConfig);
        if (!Config::loadConfig(configStream))
            return;

        Config::GeneralCfg.messageMode = MsgMode::NONE;

        // A 16 MiB transposition table is a deliberate mobile-sized ceiling.
        // The table persists between moves while per-game search state is reset.
        Search::Engine.searcher()->setMemoryLimit(16 * 1024);
        Search::Engine.clear(true);
        rapfiReady.store(true, std::memory_order_release);
    });
}

bool validCoordinate(int row, int column)
{
    return row >= 0 && row < 15 && column >= 0 && column < 15;
}

}  // namespace

bool rapfi_is_available(void)
{
    try {
        initializeRapfi();
        return rapfiReady.load(std::memory_order_acquire);
    }
    catch (...) {
        return false;
    }
}

bool rapfi_choose_move(
    const int16_t *rows,
    const int16_t *columns,
    const int8_t *stones,
    int32_t moveCount,
    int32_t sideToMove,
    int32_t timeLimitMs,
    int32_t strengthLevel,
    int32_t *outRow,
    int32_t *outColumn)
{
    if (!outRow || !outColumn || moveCount < 0 || moveCount > 225)
        return false;
    if (moveCount > 0 && (!rows || !columns || !stones))
        return false;
    if (sideToMove != 1 && sideToMove != 2)
        return false;

    try {
        cancelRequested.store(false, std::memory_order_release);
        initializeRapfi();
        if (!rapfiReady.load(std::memory_order_acquire)
            || cancelRequested.load(std::memory_order_acquire))
            return false;

        std::lock_guard<std::mutex> guard(searchMutex);
        if (cancelRequested.load(std::memory_order_acquire))
            return false;

        Board board(15);
        board.newGame(RENJU);

        for (int32_t i = 0; i < moveCount; ++i) {
            const int row = rows[i];
            const int column = columns[i];
            if (!validCoordinate(row, column))
                return false;

            // Swift Stone raw values are empty=0, black=1, white=2.
            // Free-opening Renju must alternate from Black.
            const int8_t expectedStone = (i % 2 == 0) ? 1 : 2;
            if (stones[i] != expectedStone)
                return false;

            const Pos pos(column, row);
            if (board.get(pos) != EMPTY)
                return false;
            board.move(RENJU, pos);
        }

        const int32_t expectedSide = (moveCount % 2 == 0) ? 1 : 2;
        if (sideToMove != expectedSide)
            return false;

        Search::Engine.clear(false);

        Search::SearchOptions options;
        options.rule = {Rule::RENJU, GameRule::FREEOPEN};
        options.disableOpeningQuery = true;
        options.infoMode = Search::SearchOptions::INFO_NONE;
        options.multiPV = 1;
        options.strengthLevel = static_cast<uint16_t>(std::clamp(strengthLevel, 0, 100));
        options.setTimeControl(std::max<int32_t>(50, timeLimitMs), 0);

        if (cancelRequested.load(std::memory_order_acquire))
            return false;

        Search::Engine.startThinking(board, options);
        Search::Engine.waitForIdle();

        if (cancelRequested.load(std::memory_order_acquire))
            return false;

        const Pos bestMove = Search::Engine.ctx.bestMove;
        if (!bestMove.isInBoard(15, 15))
            return false;

        *outRow = bestMove.y();
        *outColumn = bestMove.x();
        return true;
    }
    catch (...) {
        return false;
    }
}

void rapfi_cancel(void)
{
    cancelRequested.store(true, std::memory_order_release);
    if (rapfiReady.load(std::memory_order_acquire))
        Search::Engine.stopThinking();
}
