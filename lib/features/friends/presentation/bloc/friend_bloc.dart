import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_sensei/features/friends/data/models/friend_model.dart';
import 'friend_event.dart';
import 'friend_state.dart';

class FriendBloc extends Bloc<FriendEvent, FriendState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _friendsSubscription;

  FriendBloc() : super(FriendInitial()) {
    on<LoadFriends>(_onLoadFriends);
    on<_FriendsUpdated>(_onFriendsUpdated);
  }

  Future<void> _onLoadFriends(
    LoadFriends event,
    Emitter<FriendState> emit,
  ) async {
    try {
      print('Starting to load friends...');
      emit(FriendLoadInProgress());

      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        print('User not authenticated');
        emit(const FriendOperationFailure('User not authenticated'));
        return;
      }

      // First, check if we have a cached list of friends
      if (state is FriendsLoadSuccess && event.forceRefresh == false) {
        print('Using cached friends list');
        return;
      }

      print('Fetching friends list from Firestore...');
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .get(const GetOptions(source: Source.serverAndCache));

      print('Found ${friendsSnapshot.docs.length} friend references');
      if (friendsSnapshot.docs.isEmpty) {
        print('No friends found, returning empty list');
        emit(const FriendsLoadSuccess([]));
        return;
      }

      // Fetch the actual user data for each friend
      final friendIds = friendsSnapshot.docs.map((doc) => doc.id).toList();
      print('Fetching data for friends: $friendIds');

      final friendsData = await Future.wait(
        friendIds.map(
          (friendId) => _firestore
              .collection('users')
              .doc(friendId)
              .get(const GetOptions(source: Source.serverAndCache)),
        ),
      );

      final friends = friendsData.where((doc) => doc.exists).map((doc) {
        final data = doc.data() ?? {};
        final friend = Friend(
          id: doc.id,
          name: data['displayName'] ??
              data['email']?.toString().split('@').first ??
              'Unknown',
          email: data['email']?.toString() ?? '',
          photoUrl: data['photoURL']?.toString(),
        );
        print(
          'Created friend: ${friend.id} - ${friend.name} (${friend.email})',
        );
        return friend;
      }).toList();

      print('Successfully loaded ${friends.length} friends');
      emit(FriendsLoadSuccess(friends));

      // Set up real-time updates
      _friendsSubscription?.cancel();
      _friendsSubscription = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .snapshots()
          .listen(
        (_) {
          // Force refresh from server when friends list changes
          add(const LoadFriends(forceRefresh: true));
        },
        onError: (error, stackTrace) {
          if (error is FirebaseException && error.code == 'permission-denied') {
            print(
              'FriendBloc listener permission denied. Waiting for access to be restored.',
            );
            return;
          }
          print('Error listening to friends updates: $error\n$stackTrace');
        },
      );
    } catch (e, stackTrace) {
      print('Error loading friends: $e\n$stackTrace');
      // If we have cached data, keep showing it even if refresh fails
      if (state is! FriendsLoadSuccess) {
        emit(FriendOperationFailure('Failed to load friends: ${e.toString()}'));
      }
    }
  }

  void _onFriendsUpdated(_FriendsUpdated event, Emitter<FriendState> emit) {
    emit(FriendsLoadSuccess(event.friends));
  }

  @override
  Future<void> close() {
    _friendsSubscription?.cancel();
    return super.close();
  }
}

// Internal event to update state when friends list changes
class _FriendsUpdated extends FriendEvent {
  final List<Friend> friends;

  const _FriendsUpdated(this.friends);
}
