import 'package:study_sensei/features/friends/data/models/user_model.dart';
import 'package:study_sensei/features/friends/data/models/friend_request_model.dart';

abstract class FriendRepository {
  // Search for users by name or UID
  Future<List<UserModel>> searchUsers(String query);
  
  // Get current user's ID
  String? getCurrentUserId();
  
  // Send a friend request
  Future<void> sendFriendRequest(String recipientId);
  
  // Check if a friend request exists between two users
  Future<bool> hasPendingRequest(String userId);
  
  // Check if users are already friends
  Future<bool> isFriend(String userId);
  
  // Get all friend requests for current user
  Future<List<FriendRequestModel>> getFriendRequests();
  
  // Respond to a friend request
  Future<void> respondToFriendRequest({
    required String requestId,
    required bool isAccepted,
    required String senderId,
  });
  
  // Get list of friends
  Future<List<UserModel>> getFriends();
  
  // Remove a friend
  Future<void> removeFriend(String friendId);
}
