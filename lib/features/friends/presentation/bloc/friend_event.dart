abstract class FriendEvent {
  const FriendEvent();
}

class LoadFriends extends FriendEvent {
  final bool forceRefresh;
  
  const LoadFriends({this.forceRefresh = false});
}
