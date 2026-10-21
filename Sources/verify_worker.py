#!/usr/bin/env python3
"""Exercise the real local provider; requires installed English/Chinese models."""
import json
from pathlib import Path
import subprocess
import sys
worker=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]/'outputs/MailTrans.app/Contents/MacOS/TranslationWorker'
def run(payload):
    result=subprocess.run([str(worker)],input=json.dumps(payload),text=True,capture_output=True,timeout=120)
    return result.returncode,json.loads(result.stdout)
code,result=run({'provider':'apple-local','texts':['The workshop has moved to Thursday morning. Please bring the revised schedule.','The revised budget includes travel expenses and two additional monitors.','这段原本是中文，应当原样保留。']})
assert code==0 and result['provider']=='apple-local',result
text=result['translations']
assert len(text)==3 and ('周四' in text[0] or '星期四' in text[0]) and '预算' in text[1],text
assert text[2]=='这段原本是中文，应当原样保留。'
code,result=run({'provider':'future-service','texts':['Hello tomorrow.']})
assert code==4 and result['errorCode']=='provider_unavailable' and 'translations' not in result
code,result=run({'texts':[100]})
assert code==1 and result['errorCode']=='translation_failed' and 'translations' not in result
code,result=run({'texts':['x'*10001]})
assert code==1 and result['errorCode']=='translation_failed'
print('PASS: real Apple translation, ordered batches, Chinese preservation, explicit provider selection and invalid input')
