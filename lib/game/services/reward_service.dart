/// The seam where a rewarded ad ("watch ad -> go back 3 turns") will live later.
///
/// The prototype intentionally ships no ad SDK, so [MockRewardService] grants
/// every request and the Second Chance mechanic can be played and tested end to
/// end today.
abstract class RewardService {
  /// Asks the player to earn a second chance.
  ///
  /// Returns `true` when the reward was granted.
  Future<bool> requestSecondChance();
}

/// Grants every request.
///
/// Replace this with an ad backed implementation (for example Google Mobile Ads)
/// when monetisation is added - nothing else in the game has to change.
class MockRewardService implements RewardService {
  const MockRewardService();

  @override
  Future<bool> requestSecondChance() async => true;
}
