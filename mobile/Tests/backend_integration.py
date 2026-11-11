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
 def single(token): return next(row for row in view(token) if row['id']==item['id'])
 assert len(view(gt))==1 and len(view(xt))==0
 def claim(token): return request('/rest/v1/rpc/trove_claim_item',token,'POST',{'p_item_id':item['id'],'p_claim':True})
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
  results=list(pool.map(claim,[gt,rt]))
 assert sorted(status for status,_ in results)==[204,400],results
 winner=gt if results[0][0]==204 else rt; loser=rt if winner==gt else gt
 hidden=single(ot); visible=single(winner)
 assert hidden['purchase_hidden'] and not hidden['is_purchased'] and hidden['purchased_by_user_id'] is None and hidden['purchaser_name'] is None
 assert visible['is_purchased'] and visible['purchaser_name'] in ['Guest','Rival']
 status,_=request('/rest/v1/list_items?select=purchased_by_user_id',ot)
 assert status==403,'Owner must not be able to bypass privacy with a raw table query'
 status,_=request('/rest/v1/list_items?id=eq.'+item['id'],winner,'PATCH',{'purchased_by_user_id':owner})
 assert status==403
 status,_=request('/rest/v1/rpc/trove_claim_item',loser,'POST',{'p_item_id':item['id'],'p_claim':False})
 assert status==403,'Cannot release another person\'s gift'
 status,_=request('/rest/v1/list_items?id=eq.'+item['id'],gt,'PATCH',{'name':'Tampered'})
 assert status==204 and single(gt)['name']=='Test gift','Guests cannot edit gift details'
 # Quantity allocation is atomic across multiple buyers and private from the owner.
 multi={'id':str(uuid.uuid4())}
 assert request('/rest/v1/list_items',ot,'POST',{'id':multi['id'],'list_id':wish['id'],'name':'Matching mugs','quantity':5})[0]==201
 def set_quantity(token,amount):
  return request('/rest/v1/rpc/trove_set_claim_quantity',token,'POST',{'p_item_id':multi['id'],'p_quantity':amount})
 def quantity_view(token):
  return next(row for row in view(token) if row['id']==multi['id'])
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
  allocations=list(pool.map(lambda t:set_quantity(t,3),[gt,rt]))
 assert sorted(code for code,_ in allocations)==[204,400],allocations
 first=gt if allocations[0][0]==204 else rt; other=rt if first==gt else gt
 assert quantity_view(first)['available_quantity']==2
 assert set_quantity(other,2)[0]==204
 visible_quantity=quantity_view(gt)
 assert visible_quantity['claimed_quantity']==5 and visible_quantity['available_quantity']==0 and len(visible_quantity['purchasers'])==2
 private_quantity=quantity_view(ot)
 assert private_quantity['claimed_quantity'] is None and private_quantity['available_quantity'] is None and private_quantity['purchasers']==[]
 assert set_quantity(ot,1)[0]==403 and set_quantity(xt,1)[0]==403
 assert set_quantity(first,4)[0]==400
 assert set_quantity(other,0)[0]==204 and quantity_view(first)['available_quantity']==2
 assert set_quantity(first,1)[0]==204 and quantity_view(first)['available_quantity']==4
 assert set_quantity(first,-1)[0]==400 and set_quantity(first,1000)[0]==400
 assert request('/rest/v1/trove_item_claims?select=*',ot)[0]==403
 # Reductions during the surprise period fail consistently, even for unclaimed wishes.
 assert request('/rest/v1/list_items?id=eq.'+multi['id'],ot,'PATCH',{'quantity':4})[0]==400
 assert request('/rest/v1/list_items?id=eq.'+multi['id'],ot,'PATCH',{'quantity':6})[0]==204
 assert quantity_view(first)['available_quantity']==5
 # Owners can rename lists and favorite wishes; members can read but not change them.
 assert request('/rest/v1/lists?id=eq.'+wish['id'],ot,'PATCH',{'name':'Renamed wishes'})[0]==204
 assert request('/rest/v1/lists?id=eq.'+wish['id'],gt,'PATCH',{'name':'Unauthorized name'})[0]==204
 assert request('/rest/v1/lists?id=eq.'+wish['id']+'&select=name,user_id',gt)[1]==[{'name':'Renamed wishes','user_id':owner}]
 assert request('/rest/v1/list_items?id=eq.'+multi['id'],ot,'PATCH',{'is_favorite':True})[0]==204
 assert request('/rest/v1/list_items?id=eq.'+multi['id'],gt,'PATCH',{'is_favorite':False})[0]==204
 assert quantity_view(gt)['is_favorite'] is True
 assert request('/rest/v1/profiles?id=eq.'+owner+'&select=display_name',gt)[1]==[{'display_name':'Owner'}]
 # List creators may see counts early for a managed list, but never early buyer details.
 assert request('/rest/v1/lists?id=eq.'+wish['id'],gt,'PATCH',{'for_someone_else':True})[0]==204
 assert quantity_view(ot)['purchase_hidden']
 assert request('/rest/v1/lists?id=eq.'+wish['id'],ot,'PATCH',{'for_someone_else':True})[0]==204
 managed=quantity_view(ot)
 assert not managed['purchase_hidden'] and managed['claimed_quantity']==1 and managed['available_quantity']==5
 assert not managed['is_purchased'] and managed['purchased_by_user_id'] is None and managed['purchaser_name'] is None and managed['purchased_at'] is None and managed['purchasers']==[]
 assert request('/rest/v1/lists?id=eq.'+wish['id'],ot,'PATCH',{'for_someone_else':False})[0]==204
 assert quantity_view(ot)['purchase_hidden'] and quantity_view(ot)['claimed_quantity'] is None
 managed_list=insert('lists',ot,{'name':'Managed wishes','user_id':owner,'for_someone_else':True})
 assert managed_list['for_someone_else'] is True
 print('PASS: managed list creation, owner-only setting, immediate counts, preserved buyer privacy, and restored surprise mode.')
 # An event setting can hide identities while still showing counts and my claim.
 assert request('/rest/v1/events?id=eq.'+event['id'],gt,'PATCH',{'anonymous_purchases':True})[0]==204
 assert request('/rest/v1/events?id=eq.'+event['id']+'&select=anonymous_purchases',gt)[1]==[{'anonymous_purchases':False}]
 assert request('/rest/v1/events?id=eq.'+second['id'],ot,'PATCH',{'anonymous_purchases':True})[0]==204
 masked=quantity_view(first)
 assert masked['anonymous_purchases'] and masked['available_quantity']==5 and masked['my_claimed_quantity']==1
 assert masked['purchasers']==[] and masked['purchased_by_user_id'] is None and masked['purchaser_name'] is None and masked['purchased_at'] is None
 assert quantity_view(other)['purchasers']==[]
 assert quantity_view(ot)['claimed_quantity'] is None
 assert request('/rest/v1/events?id=eq.'+second['id'],ot,'PATCH',{'anonymous_purchases':False})[0]==204
 assert quantity_view(gt)['purchasers'][0]['name'] in ['Guest','Rival']
 print('PASS: owner-only settings, renaming and favorites; shared creator name; anonymous purchases retain counts without buyer identities.')
 print('PASS: partial quantities, atomic capacity, multiple buyers, release/change, hidden totals, and raw-claim privacy.')
 status,_=request('/rest/v1/events?id=eq.'+event['id'],ot,'PATCH',{'date':past})
 assert status==204 and single(ot)['purchase_hidden'],'Second upcoming event must preserve the surprise'
 status,_=request('/rest/v1/events?id=eq.'+second['id'],ot,'PATCH',{'date':past})
 assert status==204
 assert single(ot)['purchase_hidden'],'Changing event dates cannot reveal an already claimed surprise early'
 # Simulate the stored deadline passing, using the local service role only.
 status,_=request('/rest/v1/list_items?id=eq.'+item['id'],method='PATCH',body={'claim_reveal_at':past+'T00:00:00Z'},admin=True)
 assert status==204
 assert request('/rest/v1/list_items?id=eq.'+multi['id'],method='PATCH',body={'claim_reveal_at':past+'T00:00:00Z'},admin=True)[0]==204
 revealed_multi=quantity_view(ot)
 assert revealed_multi['claimed_quantity']==1 and revealed_multi['available_quantity']==5 and len(revealed_multi['purchasers'])==1
 assert request('/rest/v1/events?id=eq.'+second['id'],ot,'PATCH',{'anonymous_purchases':True})[0]==204
 masked_owner=quantity_view(ot)
 assert masked_owner['claimed_quantity']==1 and masked_owner['available_quantity']==5 and masked_owner['purchasers']==[] and masked_owner['purchaser_name'] is None
 assert request('/rest/v1/events?id=eq.'+second['id'],ot,'PATCH',{'anonymous_purchases':False})[0]==204
 revealed=single(ot); assert revealed['is_purchased'] and not revealed['purchase_hidden'] and revealed['purchaser_name']
 status,_=request('/rest/v1/rpc/trove_claim_item',winner,'POST',{'p_item_id':item['id'],'p_claim':False})
 assert status==204 and not single(gt)['is_purchased']
 status,_=claim(winner)
 assert status==400,'No new claims after a member\'s events end'
 status,_=request('/rest/v1/rpc/join_event_by_code',gt,'POST',{'p_sharing_code':event['sharing_code'],'p_user_id':outsider})
 assert status==403
 # Opt-in is tied to the authenticated install. Multiple shared events do not duplicate alerts.
 def db(sql):
  return subprocess.run(['docker','exec','supabase_db_shared-apps','psql','-X','-v','ON_ERROR_STOP=1','-U','postgres','-Atc',sql],capture_output=True,text=True,check=True).stdout.strip()
 device=str(uuid.uuid4()); token=uuid.uuid4().hex*2
 def enroll(access,device_id,push_token):
  return request('/rest/v1/rpc/trove_set_list_notifications',access,'POST',{'p_id':device_id,'p_token':push_token,'p_environment':'development'})
 enrollment=enroll(gt,device,token)
 assert enrollment[0]==204,enrollment
 assert enroll(ot,str(uuid.uuid4()),uuid.uuid4().hex*2)[0]==204
 assert enroll(xt,str(uuid.uuid4()),uuid.uuid4().hex*2)[0]==204
 assert request('/rest/v1/rpc/join_event_by_code',gt,'POST',{'p_sharing_code':second['sharing_code'],'p_user_id':guest})[1]['success']
 def add_wish():
  assert request('/rest/v1/list_items',ot,'POST',{'list_id':wish['id'],'name':'Batch test gift'})[0]==201
 for _ in range(5): add_wish()
 rows=json.loads(db("SELECT json_agg(json_build_object('device',device_id,'count',item_count,'delay',extract(epoch from due_at-first_at))) FROM trove_private.push_batches WHERE list_id='"+wish['id']+"'"))
 assert len(rows)==1 and rows[0]['device']==device and rows[0]['count']==5 and 300<=rows[0]['delay']<900, rows
 # Continuous additions cannot defer the original batch by more than 15 minutes.
 db("UPDATE trove_private.push_batches SET first_at=now()-interval '14 minutes' WHERE device_id='"+device+"'")
 add_wish()
 assert db("SELECT due_at=first_at+interval '15 minutes' FROM trove_private.push_batches WHERE device_id='"+device+"'")=='t'
 assert request('/rest/v1/rpc/trove_take_list_notifications',gt,'POST',{})[0]==403
 status,premature=request('/rest/v1/rpc/trove_take_list_notifications',method='POST',body={},admin=True)
 assert status==200 and not any(row['token']==token for row in premature),(status,premature)
 db("UPDATE trove_private.push_batches SET due_at=now() WHERE device_id='"+device+"'")
 status,due=request('/rest/v1/rpc/trove_take_list_notifications',method='POST',body={},admin=True)
 assert status==200,(status,due)
 leased=next(row for row in due if row['token']==token)
 assert leased['item_count']==6 and leased['list_name']=='Renamed wishes'
 status,repeated=request('/rest/v1/rpc/trove_take_list_notifications',method='POST',body={},admin=True)
 assert status==200 and not any(row['token']==token for row in repeated)
 assert request('/rest/v1/rpc/trove_finish_list_notification',method='POST',body={'p_id':leased['id'],'p_lease':leased['lease_id'],'p_result':'sent','p_token':token},admin=True)[0]==204
 assert db("SELECT count(*) FROM trove_private.push_batches WHERE device_id='"+device+"'")=='0'
 add_wish()
 assert enroll(gt,device,None)[0]==204
 assert db("SELECT count(*) FROM trove_private.push_batches WHERE device_id='"+device+"'")=='0'
 enrollment=enroll(gt,device,token)
 assert enrollment[0]==204,enrollment
 add_wish()
 for e in (event,second):
  assert request('/rest/v1/event_members?event_id=eq.'+e['id']+'&user_id=eq.'+guest,gt,'DELETE')[0]==204
 db("UPDATE trove_private.push_batches SET due_at=now() WHERE device_id='"+device+"'")
 status,departed=request('/rest/v1/rpc/trove_take_list_notifications',method='POST',body={},admin=True)
 assert status==200 and not any(row['token']==token for row in departed)
 print('PASS: opt-in only, multi-event deduplication, batching window and cap, worker lease, opt-out, and membership recheck.')
 print('PASS: Auth, generated event codes, code-only join, multi-event lists, concurrent claims, protected purchase fields, guest edit isolation, date reveal, and undo permissions.')
finally:
 for uid in created:
  status,data=request('/auth/v1/admin/users/'+uid,method='DELETE',admin=True)
  if status!=200: print('Fixture cleanup failed for '+uid+': '+str(status))
 print('Removed disposable integration users and their cascaded app data.')
