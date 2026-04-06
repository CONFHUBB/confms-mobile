---
name: gamification-patterns
description: >
  When implementing gamification features in the Mathiq app. Use this skill when working on
  the gacha/treasure chest system, daily streak tracking, hearts/lives system,
  XP and token economy, leaderboards, arena battles, or achievement badges.
  Also trigger when the user mentions rewards, engagement loops, or
  optimistic UI updates for virtual currency.
---

# Gamification Patterns

## When to use

- Implementing or modifying the gacha (treasure chest) system
- Working with streak logic (daily counting, expiry, protection)
- Managing hearts/lives, XP, or token economy
- Building reward flows and celebration UI
- Arena/battle features

## Core Currency System

The app tracks three currencies per child profile via `SessionStore.currentChild`:

| Currency | Purpose | Earned By | Spent On |
|---|---|---|---|
| **XP** | Experience points, leveling | Completing stages, bonus for full completion | Nothing (display only) |
| **Tokens** | Premium currency | Completing stages | Gacha spins (cost: `GachaService.spinCost`) |
| **Hearts** | Lives for practice | Time-based regen, purchases | Lost on wrong answers in practice mode |

### Optimistic Token Updates

When spending tokens (gacha), update the UI immediately and refund on error:

```dart
// 1. Deduct immediately
_sessionStore.updateChildStats(
  tokens: currentTokens - GachaService.spinCost,
);

try {
  // 2. Call API
  final reward = await _gachaService.spinGacha(childId);
} catch (e) {
  // 3. Refund on error
  _sessionStore.updateChildStats(
    tokens: currentTokens, // restore original
  );
}
```

## Gacha System (GachaStore)

The treasure chest has a state machine:

```
ChestState.closed → ChestState.opening → ChestState.opened
     ↑                                         |
     └─────────── resetChest() ←──── claimReward()
```

Key patterns:
- **Pre-roll**: The reward is determined on first tap (API call happens at `tapCount == 0`)
- **Animation sequence**: closed → shaking → opening → opened (with delays)
- **Gacha Ticket check**: Inventory check before token deduction — tickets override token cost
- **Balance refresh**: Call `refreshBalance()` when entering gacha screen to sync with backend

## Streak System (StreakStore)

The streak uses calendar-day logic (not hours):

```dart
// Normalize dates to midnight for comparison
DateTime _normalizeToDay(DateTime date) {
  final localDate = date.toLocal();
  return DateTime(localDate.year, localDate.month, localDate.day);
}
```

| Days since last update | Action |
|---|---|
| 0 (same day) | Do nothing — already counted |
| 1 (consecutive) | Increment streak |
| ≥ 2 (missed day) | Reset to 0, then increment to 1 |

Key patterns:
- **`ensureTodayStreak(profileId)`** — main entry point called after stage completion
- **`wasStreakUpdatedThisSession`** — flag to show streak animation only once
- **`checkStreakExpiry`** — called on app open to show expired streak state
- **Backend safety**: If API says "already updated", treat as success (not error)

## Hearts/Lives System

Theory stages: No heart counter during lecture, hearts appear during theory questions.
Practice/Mixed stages: Hearts counter always visible.

Hearts are decremented on wrong answers (frontend) and synced via the `update` API.

## XP & Completion Flow

After stage submission (`StudyStageStore.submitStage`):
1. Call Study API → get `xpEarned`, `tokensEarned`, `bonusFullyCompletedXp`
2. Update streak → `ensureTodayStreak`
3. Merge into `CompletionData` → drives the success dialog UI

```dart
completionResult = CompletionData(
  isPassed: apiResult.isPassed,
  earnedXp: apiResult.xpEarned,
  earnedTokens: apiResult.tokensEarned,
  bonusXp: apiResult.bonusFullyCompletedXp,
  currentStreak: currentStreak,
  isStreakJustIncremented: wasJustUpdated,
);
```

## Achievement Badges (Real-time)

Badges are awarded via WebSocket (`SocketService`):

```dart
_socketService.on('badge.awarded', (data) {
  // Show badge notification overlay
});
```

## Animation & Sound

- Use `confetti` package for celebration effects
- Use `audioplayers` for sound effects on correct/wrong answers
- Use `lottie` for animated characters and rewards
- Use `flutter_animate` for micro-interactions
