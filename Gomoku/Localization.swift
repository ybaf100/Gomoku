import Foundation

enum L10n {
    static func text(_ key: String, _ language: AppLanguage) -> String {
        let table = language == .korean ? korean : english
        return table[key] ?? english[key] ?? key
    }

    static func difficulty(_ difficulty: AIDifficulty, language: AppLanguage, adaptiveSkill: Int? = nil) -> String {
        switch difficulty {
        case .easy:
            return text("easy", language)
        case .normal:
            return text("normal", language)
        case .hard:
            return text("hard", language)
        case .adaptive:
            if let adaptiveSkill {
                return "\(text("adaptive", language)) · \(adaptiveSkill)/100"
            }
            return text("adaptive", language)
        }
    }

    static func timeControl(_ control: TimeControl, language: AppLanguage) -> String {
        switch control {
        case .fast: return text("fast", language)
        case .slow: return text("slow", language)
        case .unlimited: return text("unlimited", language)
        }
    }

    static func timeSubtitle(_ control: TimeControl, language: AppLanguage) -> String {
        switch control {
        case .fast: return text("threeMinutes", language)
        case .slow: return text("tenMinutes", language)
        case .unlimited: return text("noClock", language)
        }
    }

    static func stone(_ stone: Stone, language: AppLanguage) -> String {
        switch stone {
        case .black: return text("black", language)
        case .white: return text("white", language)
        case .empty: return "-"
        }
    }

    static func appearance(_ mode: AppearanceMode, language: AppLanguage) -> String {
        switch mode {
        case .system: return text("system", language)
        case .light: return text("light", language)
        case .dark: return text("dark", language)
        }
    }

    static func notice(_ notice: GameNotice, language: AppLanguage) -> String {
        switch notice {
        case .occupied:
            return text("occupied", language)
        case .selectMove:
            return text("selectMove", language)
        case .forbidden(let reason):
            let reasonText: String
            switch reason {
            case .overline: reasonText = text("overline", language)
            case .doubleFour: reasonText = text("doubleFour", language)
            case .doubleThree: reasonText = text("doubleThree", language)
            }
            return "\(text("forbidden", language)): \(reasonText)"
        }
    }

    static func result(_ result: GameResult, playerStone: Stone, language: AppLanguage) -> String {
        switch result {
        case .blackWin:
            return playerStone == .black ? text("youWin", language) : text("aiWins", language)
        case .whiteWin:
            return playerStone == .white ? text("youWin", language) : text("aiWins", language)
        case .blackTimeout:
            return playerStone == .black ? text("timeoutAIWins", language) : text("aiTimeoutYouWin", language)
        case .whiteTimeout:
            return playerStone == .white ? text("timeoutAIWins", language) : text("aiTimeoutYouWin", language)
        case .draw:
            return text("draw", language)
        }
    }

    static func recordResult(_ record: GameRecord, language: AppLanguage) -> String {
        if record.result == .draw {
            return text("draw", language)
        }
        return record.result.playerWon(playerStone: record.playerStone)
            ? text("win", language)
            : text("loss", language)
    }

    static func formattedDate(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static let korean: [String: String] = [
        "brandSubtitle": "한 수의 여유",
        "matchSubtitle": "나만의 작은 대국실",
        "quietPlay": "잠시, 오목 한 판",
        "heroTitle": "한 수,\n깊어지는 시간.",
        "heroTitleCompact": "한 수의 여유.",
        "heroBody": "서두르지 않아도 괜찮아요.\n당신의 속도로, 다음 한 수를 만나보세요.",
        "renju": "렌주룰",
        "offline": "오프라인",
        "newMatch": "새로운 대국",
        "firstMove": "먼저 둡니다",
        "secondMove": "AI가 먼저 둡니다",
        "startHint": "위치를 고르고, 착수 버튼으로 확정하세요.",
        "appSettings": "앱 설정",
        "settingsTitle": "나에게 맞는 분위기.",
        "settingsSubtitle": "편안한 화면과 익숙한 언어로 즐기세요.",
        "systemAppearanceHelp": "시스템을 선택하면 기기의 라이트·다크 모드와 자동 전환 일정을 따릅니다.",
        "effectiveAppearance": "현재 적용",
        "settingsSaved": "설정은 자동으로 저장됩니다.",
        "done": "완료",
        "backHome": "처음으로",
        "leaveGameTitle": "진행 중인 대국을 끝낼까요?",
        "leaveGameMessage": "완료하지 않은 대국은 기보에 저장되지 않습니다.",
        "thinkingHint": "AI가 다음 한 수를 고르고 있어요.",
        "activeTurn": "현재 차례",
        "recordSaved": "이번 대국이 기보에 저장되었습니다.",
        "historyTitle": "한 수씩, 다시.",
        "historySubtitle": "지난 대국을 천천히 돌아보세요.",
        "historyEmptyHelp": "첫 대국을 마치면 이곳에 수순이 저장됩니다.",
        "gamesCount": "판",
        "savedOnDevice": "이 기기에 저장됨",
        "moveProgress": "수순",
        "emptyPoint": "빈 자리",
        "appTitle": "오목",
        "subtitle": "렌주룰 · AI 대전 · 오프라인",
        "yourStone": "내 돌",
        "black": "흑",
        "white": "백",
        "aiDifficulty": "AI 난이도",
        "easy": "쉬움",
        "normal": "보통",
        "hard": "어려움",
        "adaptive": "지능형",
        "adaptiveDescription": "처음 50/100(보통)에서 시작하고, 매 경기 결과와 경기 길이에 따라 다음 판 AI 수준이 세밀하게 조정됩니다.",
        "adaptiveCurrent": "현재 지능형 수준",
        "timeControl": "시간 설정",
        "fast": "빠른 경기",
        "slow": "느린 경기",
        "unlimited": "무제한",
        "threeMinutes": "각 3분",
        "tenMinutes": "각 10분",
        "noClock": "시간 제한 없음",
        "startGame": "게임 시작",
        "history": "기보",
        "appearance": "화면 모드",
        "system": "시스템",
        "light": "라이트",
        "dark": "다크",
        "language": "언어",
        "yourTurn": "내 차례",
        "aiThinking": "AI 생각 중…",
        "aiTurn": "AI 차례",
        "you": "나",
        "ai": "AI",
        "setup": "설정",
        "newGame": "새 게임",
        "place": "착수",
        "validatingMove": "착수 확인 중…",
        "cancelSelection": "선택 취소",
        "tapToPreview": "빈 교차점을 눌러 착수 위치를 미리 확인하세요.",
        "selected": "선택",
        "occupied": "이미 돌이 놓인 자리입니다.",
        "selectMove": "먼저 빈 자리를 선택하세요.",
        "forbidden": "금수",
        "overline": "장목",
        "doubleFour": "44",
        "doubleThree": "33",
        "youWin": "승리",
        "aiWins": "AI 승리",
        "timeoutAIWins": "시간패 · AI 승리",
        "aiTimeoutYouWin": "AI 시간패 · 승리",
        "draw": "무승부",
        "playAgain": "다시 하기",
        "records": "이전 경기 기보",
        "noRecords": "저장된 기보가 없습니다.",
        "moves": "수",
        "replay": "기보 보기",
        "previous": "이전",
        "next": "다음",
        "first": "처음",
        "last": "마지막",
        "win": "승",
        "loss": "패",
        "adaptiveAdjusted": "다음 판 지능형 AI",
        "close": "닫기",
        "deleteAll": "전체 삭제",
        "confirmDeleteAll": "모든 기보를 삭제할까요?",
        "cancel": "취소",
        "delete": "삭제"
    ]

    private static let english: [String: String] = [
        "brandSubtitle": "A little room to think",
        "matchSubtitle": "Your quiet corner of play",
        "quietPlay": "A MOMENT TO PLAY",
        "heroTitle": "A little pause.\nA thoughtful move.",
        "heroTitleCompact": "A thoughtful move.",
        "heroBody": "Take your time.\nFind your next move, at your own pace.",
        "renju": "Renju",
        "offline": "Offline",
        "newMatch": "A new game",
        "firstMove": "You play first",
        "secondMove": "AI plays first",
        "startHint": "Choose a point, then confirm your move.",
        "appSettings": "Settings",
        "settingsTitle": "Make yourself at home.",
        "settingsSubtitle": "A comfortable look. A familiar language.",
        "systemAppearanceHelp": "System follows your device’s Light and Dark appearance, including its automatic schedule.",
        "effectiveAppearance": "Active appearance",
        "settingsSaved": "Your preferences are saved automatically.",
        "done": "Done",
        "backHome": "Back to home",
        "leaveGameTitle": "Leave this game?",
        "leaveGameMessage": "An unfinished game will not be saved to your records.",
        "thinkingHint": "AI is finding its next move.",
        "activeTurn": "Current turn",
        "recordSaved": "This game has been saved to your records.",
        "historyTitle": "Every move, revisited.",
        "historySubtitle": "Take a slower look at your past games.",
        "historyEmptyHelp": "Finish your first game to find its moves here.",
        "gamesCount": "games",
        "savedOnDevice": "Saved on this device",
        "moveProgress": "Moves",
        "emptyPoint": "Empty point",
        "appTitle": "Gomoku",
        "subtitle": "Renju · vs AI · Offline",
        "yourStone": "Your stone",
        "black": "Black",
        "white": "White",
        "aiDifficulty": "AI difficulty",
        "easy": "Easy",
        "normal": "Normal",
        "hard": "Hard",
        "adaptive": "Adaptive",
        "adaptiveDescription": "Starts at 50/100 (Normal) and adjusts the next game's AI strength in small steps based on each result and game length.",
        "adaptiveCurrent": "Current adaptive level",
        "timeControl": "Time control",
        "fast": "Fast",
        "slow": "Slow",
        "unlimited": "Unlimited",
        "threeMinutes": "3 min each",
        "tenMinutes": "10 min each",
        "noClock": "No clock",
        "startGame": "Start Game",
        "history": "Records",
        "appearance": "Appearance",
        "system": "System",
        "light": "Light",
        "dark": "Dark",
        "language": "Language",
        "yourTurn": "Your turn",
        "aiThinking": "AI is thinking…",
        "aiTurn": "AI turn",
        "you": "You",
        "ai": "AI",
        "setup": "Setup",
        "newGame": "New Game",
        "place": "Place",
        "validatingMove": "Checking move…",
        "cancelSelection": "Cancel selection",
        "tapToPreview": "Tap an empty intersection to preview your move.",
        "selected": "Selected",
        "occupied": "A stone is already on that point.",
        "selectMove": "Select an empty point first.",
        "forbidden": "Forbidden",
        "overline": "Overline",
        "doubleFour": "Double-four",
        "doubleThree": "Double-three",
        "youWin": "You win",
        "aiWins": "AI wins",
        "timeoutAIWins": "Time out · AI wins",
        "aiTimeoutYouWin": "AI timed out · You win",
        "draw": "Draw",
        "playAgain": "Play Again",
        "records": "Previous game records",
        "noRecords": "No saved game records.",
        "moves": "moves",
        "replay": "Replay",
        "previous": "Previous",
        "next": "Next",
        "first": "First",
        "last": "Last",
        "win": "Win",
        "loss": "Loss",
        "adaptiveAdjusted": "Next adaptive AI",
        "close": "Close",
        "deleteAll": "Delete All",
        "confirmDeleteAll": "Delete all saved game records?",
        "cancel": "Cancel",
        "delete": "Delete"
    ]
}
