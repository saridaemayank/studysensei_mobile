"""Run from repo root against the Firestore emulator on 127.0.0.1:8189.
Uses only the synthetic demo-dojo-rules project; never production credentials.
"""
import json,base64,time,urllib.request,urllib.error
base='http://127.0.0.1:8189';project='demo-dojo-rules'
def call(path,data,token='owner',method='POST'):
 req=urllib.request.Request(base+path,data=json.dumps(data).encode(),headers={'Content-Type':'application/json', **({'Authorization':'Bearer '+token} if token else {})},method=method)
 try:
  with urllib.request.urlopen(req) as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
def enc(x):return base64.urlsafe_b64encode(json.dumps(x).encode()).decode().rstrip('=')
token=enc({'alg':'none','typ':'JWT'})+'.'+enc({'sub':'alice','user_id':'alice','aud':project,'iss':'https://securetoken.google.com/'+project,'iat':int(time.time()),'exp':int(time.time())+3600,'firebase':{'sign_in_provider':'custom'}})+'.'
rules=open('firestore.rules').read()
print('rules',call('/emulator/v1/projects/'+project+':securityRules',{'rules':{'files':[{'name':'firestore.rules','content':rules}]}},method='PUT')[0])
path='/v1/projects/'+project+'/databases/(default)/documents'
print('seed',call(path+'/groups/member',{'fields':{'memberIds':{'arrayValue':{'values':[{'stringValue':'alice'}]}},'isPublic':{'booleanValue':False}}},method='PATCH')[0])
query={'structuredQuery':{'from':[{'collectionId':'groups'}],'where':{'fieldFilter':{'field':{'fieldPath':'memberIds'},'op':'ARRAY_CONTAINS','value':{'stringValue':'alice'}}}}}
status,body=call(path+':runQuery',query,token)
print('member query',status,body if status!=200 else 'allowed')
assert status == 200, 'Member query must succeed'
query['structuredQuery']['where']['fieldFilter']['value']['stringValue']='bob'
assert call(path+':runQuery',query,token)[0] == 403, 'Other membership query must be denied'
assert call(path+':runQuery',{'structuredQuery':{'from':[{'collectionId':'groups'}]}},token)[0] == 403, 'Unfiltered listing must be denied'
query['structuredQuery']['where']['fieldFilter']={'field':{'fieldPath':'isPublic'},'op':'EQUAL','value':{'booleanValue':True}}
assert call(path+':runQuery',query,token)[0] == 200, 'Public query must succeed'
print('seed legacy',call(path+'/groups/legacy',{'fields':{'memberIds':{'arrayValue':{'values':[{'stringValue':'alice'}]}}}},method='PATCH')[0])
query['structuredQuery']['where']['fieldFilter']={'field':{'fieldPath':'memberIds'},'op':'ARRAY_CONTAINS','value':{'stringValue':'alice'}}
assert call(path+':runQuery',query,token)[0] == 200, 'Legacy member group must be readable'
assert call(path+':runQuery',query,'')[0] in (401, 403), 'Anonymous query must be denied'
print('All six Dojos rule assertions passed.')
