import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_sensei/features/friends/data/models/user_model.dart';
import 'package:study_sensei/features/friends/data/models/friend_request_model.dart';
import 'package:study_sensei/features/friends/domain/repositories/friend_repository.dart';

class FriendRepositoryImpl implements FriendRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FriendRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<List<UserModel>> searchUsers(String query) async {
    print('Searching users with query: $query');
    if (query.isEmpty) return [];
    
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      print('No current user ID found');
      return [];
    }
    
    // Convert query to lowercase for case-insensitive search
    final searchQuery = query.trim().toLowerCase();
    
    try {
      // First, try searching by name (case-insensitive)
      final nameQuery = _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: searchQuery)
          .where('name', isLessThanOrEqualTo: '$searchQuery\uf8ff')
          .limit(10);
      
      // Then try searching by email (case-insensitive)
      final emailQuery = _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: searchQuery)
          .where('email', isLessThanOrEqualTo: '$searchQuery\uf8ff')
          .limit(10);
      
      // Execute queries in parallel
      final results = await Future.wait([
        nameQuery.get(),
        emailQuery.get(),
      ]);
      
      // Combine and deduplicate results
      final users = <String, UserModel>{};
      
      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          // Skip current user from search results
          if (doc.id != currentUserId) {
            try {
              final userData = doc.data();
              print('Found user: ${userData['name'] ?? 'No name'} (${doc.id})');
              users[doc.id] = UserModel.fromMap(doc.id, userData);
            } catch (e) {
              print('Error parsing user ${doc.id}: $e');
            }
          }
        }
      }
      
      print('Found ${users.length} users matching "$searchQuery"');
      return users.values.toList();
    } catch (e, stackTrace) {
      print('Error searching users: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  @override
  String? getCurrentUserId() => _auth.currentUser?.uid;

  @override
  Future<void> sendFriendRequest(String recipientId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not authenticated');
    
    if (currentUserId == recipientId) {
      throw Exception('Cannot send friend request to yourself');
    }
    
    // Check if request already exists
    final existingRequest = await _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: currentUserId)
        .where('toUserId', isEqualTo: recipientId)
        .limit(1)
        .get();
    
    if (existingRequest.docs.isNotEmpty) {
      throw Exception('Friend request already sent');
    }
    
    // Create new friend request
    await _firestore.collection('friend_requests').add({
      'fromUserId': currentUserId,
      'toUserId': recipientId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<FriendRequestModel>> getFriendRequests() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      final requests = <FriendRequestModel>[];
      
      for (final doc in querySnapshot.docs) {
        // Get sender's details
        final senderDoc = await _firestore.collection('users').doc(doc['fromUserId']).get();
        if (senderDoc.exists) {
          requests.add(FriendRequestModel.fromMap(
            doc.id,
            {
              ...doc.data(),
              'senderName': senderDoc['name'] ?? 'Unknown',
              'senderEmail': senderDoc['email'] ?? '',
            },
          ));
        }
      }
      
      return requests;
    } catch (e) {
      print('Error getting friend requests: $e');
      return [];
    }
  }

  @override
  Future<void> respondToFriendRequest({
    required String requestId,
    required bool isAccepted,
    required String senderId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not authenticated');

    final batch = _firestore.batch();
    final requestRef = _firestore.collection('friend_requests').doc(requestId);
    
    // Update the request status
    batch.update(requestRef, {
      'status': isAccepted ? 'accepted' : 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    if (isAccepted) {
      // Add each user to the other's friends list
      final userFriendsRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(senderId);
          
      final senderFriendsRef = _firestore
          .collection('users')
          .doc(senderId)
          .collection('friends')
          .doc(currentUserId);

      batch.set(userFriendsRef, {
        'friendId': senderId,
        'since': FieldValue.serverTimestamp(),
      });
      
      batch.set(senderFriendsRef, {
        'friendId': currentUserId,
        'since': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  @override
  Future<List<UserModel>> getFriends() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    try {
      // Get friend references
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .get();

      // Get friend details in parallel
      final friendFutures = friendsSnapshot.docs.map((doc) async {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(doc['friendId'] as String)
              .get();
          
          if (userDoc.exists) {
            return UserModel.fromMap(userDoc.id, userDoc.data()!);
          }
          return null;
        } catch (e) {
          print('Error fetching friend ${doc.id}: $e');
          return null;
        }
      }).toList();

      // Wait for all friend details to load
      final friends = await Future.wait(friendFutures);
      
      // Remove any null values and return
      return friends.whereType<UserModel>().toList();
    } catch (e) {
      print('Error getting friends: $e');
      return [];
    }
  }

  @override
  Future<void> removeFriend(String friendId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not authenticated');

    final batch = _firestore.batch();
    
    // Remove from current user's friends
    batch.delete(
      _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friendId),
    );
    
    // Remove from friend's friends
    batch.delete(
      _firestore
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc(currentUserId),
    );
    
    await batch.commit();
  }

  @override
  Future<bool> hasPendingRequest(String userId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;
    
    final snapshot = await _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: currentUserId)
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }

  @override
  Future<bool> isFriend(String userId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;
    
    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(userId)
        .get();
    
    return doc.exists;
  }
}
