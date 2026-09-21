import base64
import json
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = 'http://127.0.0.1:8189'
PROJECT = 'demo-dojo-notifications'
ROOT = f'/v1/projects/{PROJECT}/databases/(default)/documents'


def token(uid):
    def encode(value):
        return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip('=')
    return encode({'alg': 'none', 'typ': 'JWT'}) + '.' + encode({
        'sub': uid, 'user_id': uid, 'aud': PROJECT,
        'iss': f'https://securetoken.google.com/{PROJECT}',
        'iat': int(time.time()), 'exp': int(time.time()) + 3600,
    }) + '.'


def call(path, data=None, auth='owner', method='POST'):
    request = urllib.request.Request(BASE + path, method=method,
        data=None if data is None else json.dumps(data).encode(),
        headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + auth})
    try:
        with urllib.request.urlopen(request) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code


def value(item):
    if isinstance(item, str): return {'stringValue': item}
    if isinstance(item, list): return {'arrayValue': {'values': [value(entry) for entry in item]}}
    if item is None: return {'nullValue': None}
    raise ValueError('unsupported fixture')


def write(path, fields, uid=None, timestamp=None):
    document = f'projects/{PROJECT}/databases/(default)/documents/{path}'
    operation = {'update': {'name': document, 'fields': {key: value(item) for key, item in fields.items()}}}
    if timestamp:
        operation['updateTransforms'] = [{'fieldPath': timestamp, 'setToServerValue': 'REQUEST_TIME'}]
    return call(ROOT + ':commit', {'writes': [operation]}, token(uid) if uid else 'owner')


rules = Path('firestore.rules').read_text()
assert call(f'/emulator/v1/projects/{PROJECT}/databases/(default)/documents', method='DELETE') == 200
assert call(f'/emulator/v1/projects/{PROJECT}:securityRules', {'rules': {'files': [{'name': 'firestore.rules', 'content': rules}]}}, method='PUT') == 200
assert write('groups/dojo', {'memberIds': ['alice', 'bob'], 'adminIds': ['alice'], 'createdBy': 'alice'}) == 200
assert write('users/alice', {'name': 'Alice'}) == 200
assert write('users/alice/friends/bob', {'friendId': 'bob'}) == 200
assert write('users/alice/private/push', {'tokens': ['device-one', 'device-two']}, 'alice', 'updatedAt') == 200
assert call(ROOT + '/users/alice/private/push', auth=token('alice'), method='GET') == 200
assert call(ROOT + '/users/alice/private/push', auth=token('bob'), method='GET') == 403
assert write('users/alice/private/push', {'tokens': ['attacker']}, 'bob', 'updatedAt') == 403
assert write('users/alice', {'fcmToken': 'public-token'}, 'alice') == 403
assert write('_dojoNotificationEvents/forged', {'createdAt': 'fake'}, 'alice') == 403

message = {'groupId': 'dojo', 'senderId': 'alice', 'senderName': 'Alice', 'senderPhotoUrl': None, 'text': 'hello', 'editedAt': None}
assert write('groups/dojo/messages/message', message, 'alice', 'sentAt') == 200
assert call(ROOT + '/groups/dojo/messages/message', auth=token('bob'), method='GET') == 200
assert write('groups/dojo/messages/spoof', message, 'bob', 'sentAt') == 403
reply = {**message, 'senderId': 'bob', 'replyToMessageId': 'message', 'replyPreview': 'hello'}
assert write('groups/dojo/messages/reply', reply, 'bob', 'sentAt') == 200
assert write('groups/dojo/messages/outsider', {**message, 'senderId': 'outsider'}, 'outsider', 'sentAt') == 403
announcement = {'createdBy': 'alice', 'title': 'Exam', 'body': 'Tomorrow'}
assert write('groups/dojo/announcements/notice', announcement, 'alice', 'createdAt') == 200
assert write('groups/dojo/announcements/forged', {**announcement, 'createdBy': 'bob'}, 'bob', 'createdAt') == 403
assert call(ROOT + '/groups/dojo/announcements/notice', auth=token('bob'), method='GET') == 200
assert write('groups/dojo/pins/pin', {'type': 'message', 'targetId': 'message', 'pinnedBy': 'alice'}, 'alice', 'createdAt') == 200
assert call(ROOT + '/groups/dojo/pins/pin', auth=token('bob'), method='GET') == 200
assert write('groups/dojo', {'memberIds': ['alice', 'bob'], 'adminIds': ['outsider'], 'createdBy': 'alice'}) == 200
assert write('groups/dojo/announcements/owner', announcement, 'alice', 'createdAt') == 200
assert write('groups/dojo/announcements/stale-admin', {**announcement, 'createdBy': 'outsider'}, 'outsider', 'createdAt') == 403
print('Notification privacy, messaging, replies, announcements and pins: 24 assertions passed.')
