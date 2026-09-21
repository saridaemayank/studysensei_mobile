"""Run from repo root against the Firestore emulator on 127.0.0.1:8189.
Uses only the synthetic demo-dojo-rules project; never production credentials.
"""
import json, base64, os, time, urllib.request, urllib.error

base = 'http://' + os.environ.get('FIRESTORE_EMULATOR_HOST', '127.0.0.1:8189')
project = 'demo-dojo-rules'
path = f'/v1/projects/{project}/databases/(default)/documents'


def call(url_path, data=None, token='owner', method='POST'):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    body = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(
        base + url_path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, json.load(e)


def enc(x):
    return base64.urlsafe_b64encode(json.dumps(x).encode()).decode().rstrip('=')


def token_for(uid):
    return enc({'alg': 'none', 'typ': 'JWT'}) + '.' + enc({
        'sub': uid,
        'user_id': uid,
        'aud': project,
        'iss': 'https://securetoken.google.com/' + project,
        'iat': int(time.time()),
        'exp': int(time.time()) + 3600,
        'firebase': {'sign_in_provider': 'custom'},
    }) + '.'


alice = token_for('alice')
bob = token_for('bob')
rules = open('firestore.rules').read()
print('rules', call(
    '/emulator/v1/projects/' + project + ':securityRules',
    {'rules': {'files': [{'name': 'firestore.rules', 'content': rules}]}},
    method='PUT',
)[0])

print('seed', call(
    path + '/groups/physics',
    {
        'fields': {
            'createdBy': {'stringValue': 'alice'},
            'memberIds': {'arrayValue': {'values': [
                {'stringValue': 'alice'},
                {'stringValue': 'bob'},
            ]}},
            'adminIds': {'arrayValue': {'values': [{'stringValue': 'alice'}]}},
            'isPublic': {'booleanValue': False},
        }
    },
    method='PATCH',
)[0])


def resource_fields(uploaded_by='alice', storage_path=None):
    return {
        'name': {'stringValue': 'notes.pdf'},
        'storagePath': {
            'stringValue': storage_path or
            'dojos/physics/resources/notes1/notes.pdf'
        },
        'downloadUrl': {'stringValue': 'https://example.com/notes.pdf'},
        'mimeType': {'stringValue': 'application/pdf'},
        'extension': {'stringValue': 'pdf'},
        'sizeBytes': {'integerValue': '1024'},
        'uploadedBy': {'stringValue': uploaded_by},
        'uploadedByName': {'stringValue': 'Alice'},
        'originalFileName': {'stringValue': 'notes.pdf'},
    }


def commit_create(doc_id, fields, token):
    return call(
        f'/v1/projects/{project}/databases/(default)/documents:commit',
        {
            'writes': [{
                'update': {
                    'name': (
                        f'projects/{project}/databases/(default)/documents/'
                        f'groups/physics/resources/{doc_id}'
                    ),
                    'fields': fields,
                },
                'currentDocument': {'exists': False},
                'updateTransforms': [{
                    'fieldPath': 'createdAt',
                    'setToServerValue': 'REQUEST_TIME',
                }],
            }]
        },
        token=token,
    )


status, _ = commit_create('notes1', resource_fields(), alice)
assert status == 200, 'Member upload metadata must succeed'

status, _ = commit_create(
    'spoof', resource_fields(uploaded_by='bob'), alice)
assert status in (400, 403), 'Uploader ownership cannot be spoofed'

status, _ = commit_create('outsider', resource_fields(), token_for('eve'))
assert status in (400, 403), 'Non-member upload must be denied'

status, _ = commit_create('anon', resource_fields(), '')
assert status in (401, 403), 'Unauthenticated upload must be denied'

status, _ = call(
    path + '/groups/physics/resources/notes1',
    token=bob,
    method='GET',
)
assert status == 200, 'Member read must succeed'

status, _ = call(
    path + '/groups/physics/resources/notes1',
    {'fields': {'uploadedBy': {'stringValue': 'bob'}}},
    token=alice,
    method='PATCH',
)
assert status in (400, 403), 'Resource updates must be denied'

print('Dojo resource rule assertions passed.')
