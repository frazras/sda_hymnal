#!/usr/bin/env python3
import concurrent.futures, hashlib, json, pathlib, subprocess, urllib.parse
import argparse
parser=argparse.ArgumentParser(description='Download and validate the pinned Spanish instrumental recordings (about 1.8 GiB). Requires curl and macOS afinfo.')
parser.add_argument('--cache',type=pathlib.Path,default=pathlib.Path('tmp/spanish_music_audit/recordings'))
parser.add_argument('--output',type=pathlib.Path,default=pathlib.Path('tmp/spanish_music_audit/recording-validation.json'))
args=parser.parse_args()
root=args.cache;root.mkdir(parents=True,exist_ok=True)
m=json.load(open('tool/data/spanish_recording_sources.json'))
def check(pair):
 book,item=pair;p=root/(book+'-'+item['itemId']+'.m4a')
 if not p.exists():
  url='https://raw.githubusercontent.com/'+m['repository']+'/'+m['revision']+'/'+urllib.parse.quote(item['path'])
  subprocess.run(['curl','-fLsS','--retry','2','--max-time','90',url,'-o',str(p)+'.part'],check=True)
  pathlib.Path(str(p)+'.part').rename(p)
 b=p.read_bytes(); h=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
 if len(b)!=item['bytes'] or h!=item['gitBlobSha1']: raise ValueError('Hash mismatch '+str(p))
 r=subprocess.run(['afinfo',str(p)],capture_output=True,text=True,check=True).stdout
 import re
 dur=float(re.search(r'estimated duration: ([\d.]+) sec',r)[1])
 if dur<=0 or b[4:8]!=b'ftyp':raise ValueError('Invalid audio '+str(p))
 return {'bookId':book,'itemId':item['itemId'],'durationSeconds':dur,'gitBlobSha1':h}
items=[(b['bookId'],i) for b in m['books'] for i in b['items']]
results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
 for n,r in enumerate(pool.map(check,items),1):
  results.append(r)
  if n%50==0: print(f'Validated {n}/{len(items)}',flush=True)
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps({'revision':m['revision'],'items':results},indent=2)+'\n')
print('Complete:',len(results),flush=True)
