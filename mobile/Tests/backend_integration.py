#!/usr/bin/env python3
"""Exercise real Auth/PostgREST and permissions in the local shared stack.
Creates disposable users; deletes them and their cascaded app data in finally.
Never runs against hosted Supabase.
"""
import concurrent.futures, datetime, json, subprocess, uuid, urllib.request, urllib.error
from pathlib import Path
shared=Path(__file__).resolve().parents[3]/'shared-database'
r=subprocess.run(['supabase','status','--workdir',str(shared),'--output','json'],capture_output=True,text=True,check=True)
config=json.loads(r.stdout); base=config['API_URL']; anon=config['ANON_KEY']; service=config['SERVICE_ROLE_KEY']
assert base.startswith(('http://127.0.0.1:','http://localhost:')), 'Local tests only'
created=[]
def request(path, token=None, method='GET', body=None, admin=False, representation=False):
 headers={'apikey': service if admin else anon,'Authorization':'Bearer '+(service if admin else token or anon),'Content-Type':'application/json'}
 if representation: headers['Prefer']='return=representation'
 req=urllib.request.Request(base+path,headers=headers,method=method,data=json.dumps(body).encode() if body is not None else None)
 try:
  with urllib.request.urlopen(req,timeout=20) as res:
   data=res.read(); return res.status,json.loads(data) if data else None
 except urllib.error.HTTPError as error:
  data=error.read(); return error.code,json.loads(data) if data else None

def user(label):
 email=f'trove-{label}-{uuid.uuid4().hex[:10]}@example.invalid'; password=uuid.uuid4().hex
 status,data=request('/auth/v1/admin/users',method='POST',body={'email':email,'password':password,'email_confirm':True,'user_metadata':{'display_name':label}},admin=True)
 assert status==200,(status,data)
 created.append(data['id'])
 status,data=request('/auth/v1/token?grant_type=password',method='POST',body={'email':email,'password':password})
 assert status==200,(status,data)
 return data['user']['id'],data['access_token']

def insert(table,token,body):
 status,data=request('/rest/v1/'+table,token,'POST',body,representation=True)
 assert status==201,(table,status,data)
 return data[0]

try:
 owner,ot=user('Owner'); guest,gt=user('Guest'); rival,rt=user('Rival'); outsider,xt=user('Outsider')
 status,_=request('/rest/v1/rpc/trove_ensure_profile',ot,'POST',{})
 assert status==204
 tomorrow=(datetime.date.today()+datetime.timedelta(days=3)).isoformat()
 past=(datetime.date.today()-datetime.timedelta(days=3)).isoformat()
 event=insert('events',ot,{'name':'Integration celebration','date':tomorrow,'owner_id':owner,'timezone':'America/Chicago'})
 assert len(event['sharing_code'])==6
 for uid,token in [(guest,gt),(rival,rt)]:
  status,data=request('/rest/v1/rpc/join_event_by_code',token,'POST',{'p_sharing_code':' '+event['sharing_code'].lower()+' ','p_user_id':uid})
  assert status==200 and data['success'],(status,data)
 status,_=request('/rest/v1/event_members',xt,'POST',{'event_id':event['id'],'user_id':outsider})
 assert status==403,'Direct membership must require the code'
 second=insert('events',ot,{'name':'Second celebration','date':tomorrow,'owner_id':owner,'timezone':'America/Chicago'})
 wish=insert('lists',ot,{'name':'Integration wishes','user_id':owner})
 for e in (event,second): insert('event_lists',ot,{'event_id':e['id'],'list_id':wish['id']})
 # Safe fields are writable, purchase fields are not.
 status,_=request('/rest/v1/list_items',ot,'POST',{'list_id':wish['id'],'name':'Sneaky gift','purchased_by_user_id':guest})
 assert status==403
 status,_=request('/rest/v1/list_items',ot,'POST',{'list_id':wish['id'],'name':'Test gift','price':39.99})
 assert status==201
 def view(token):
  status,data=request('/rest/v1/list_items_with_privacy?select=*&list_id=eq.'+wish['id'],token)
  assert status==200,(status,data)
  return data
 item=view(ot)[0]
 assert len(view(gt))==1 and len(view(xt))==0
 def claim(token): return request('/rest/v1/rpc/trove_claim_item',token,'POST',{'p_item_id':item['id'],'p_claim':True})
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
  results=list(pool.map(claim,[gt,rt]))
 assert sorted(status for status,_ in results)==[204,400],results
 winner=gt if results[0][0]==204 else rt; loser=rt if winner==gt else gt
 hidden=view(ot)[0]; visible=view(winner)[0]
 assert hidden['purchase_hidden'] and not hidden['is_purchased'] and hidden['purchased_by_user_id'] is None and hidden['purchaser_name'] is None
 assert visible['is_purchased'] and visible['purchaser_name'] in ['Guest','Rival']
 status,_=request('/rest/v1/list_items?select=purchased_by_user_id',ot)
 assert status==403,'Owner must not be able to bypass privacy with a raw table query'
 status,_=request('/rest/v1/list_items?id=eq.'+item['id'],winner,'PATCH',{'purchased_by_user_id':owner})
 assert status==403
 status,_=request('/rest/v1/rpc/trove_claim_item',loser,'POST',{'p_item_id':item['id'],'p_claim':False})
 assert status==403,'Cannot release another person\'s gift'
 status,_=request('/rest/v1/list_items?id=eq.'+item['id'],gt,'PATCH',{'name':'Tampered'})
 assert status==204 and view(gt)[0]['name']=='Test gift','Guests cannot edit gift details'
 status,_=request('/rest/v1/events?id=eq.'+event['id'],ot,'PATCH',{'date':past})
 assert status==204 and view(ot)[0]['purchase_hidden'],'Second upcoming event must preserve the surprise'
 status,_=request('/rest/v1/events?id=eq.'+second['id'],ot,'PATCH',{'date':past})
 assert status==204
 assert view(ot)[0]['purchase_hidden'],'Changing event dates cannot reveal an already claimed surprise early'
 # Simulate the stored deadline passing, using the local service role only.
 status,_=request('/rest/v1/list_items?id=eq.'+item['id'],method='PATCH',body={'claim_reveal_at':past+'T00:00:00Z'},admin=True)
 assert status==204
 revealed=view(ot)[0]; assert revealed['is_purchased'] and not revealed['purchase_hidden'] and revealed['purchaser_name']
 status,_=request('/rest/v1/rpc/trove_claim_item',winner,'POST',{'p_item_id':item['id'],'p_claim':False})
 assert status==204 and not view(gt)[0]['is_purchased']
 status,_=claim(winner)
 assert status==400,'No new claims after a member\'s events end'
 status,_=request('/rest/v1/rpc/join_event_by_code',gt,'POST',{'p_sharing_code':event['sharing_code'],'p_user_id':outsider})
 assert status==403
 print('PASS: Auth, generated event codes, code-only join, multi-event lists, concurrent claims, protected purchase fields, guest edit isolation, date reveal, and undo permissions.')
finally:
 for uid in created:
  status,data=request('/auth/v1/admin/users/'+uid,method='DELETE',admin=True)
  if status!=200: print('Fixture cleanup failed for '+uid+': '+str(status))
 print('Removed disposable integration users and their cascaded app data.')
