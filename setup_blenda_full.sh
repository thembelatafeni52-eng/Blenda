#!/usr/bin/env bash
set -e
ROOT="$(pwd)"
echo "Creating Blenda full-stack scaffold at $ROOT"

# Branding asset path expected (uploaded via GitHub or available at /mnt/data)
BRAND_SRC="/mnt/data/A_digital_graphic_design_displays_a_branding_packa.png"

# Create folders
mkdir -p "$ROOT"/{backend/{strategies,controllers,adapters,tasks,logs,data,scripts},mobile/blenda-app/{src/assets,src/screens,src/components},.github}

###########################
#  Backend: requirements
###########################
cat > "$ROOT/backend/requirements.txt" <<'REQ'
fastapi uvicorn python-dotenv sqlalchemy pandas numpy scikit-learn joblib httpx redis celery requests textblob aiohttp
REQ

cat > "$ROOT/backend/.env.example" <<'ENV'
MODE=paper
JWT_SECRET=replace_with_random_secret
API_PORT=8000
DB_PATH=./logs/trades.db
ACCOUNT_BALANCE=10000

REDIS_URL=redis://redis:6379/0

DAILY_LOSS_LIMIT_PCT=0.05
MAX_CONSECUTIVE_LOSSES=3
MAX_POSITION_RISK=0.01

AUTOTRADE_SYMBOLS=EURUSD,GBPUSD,USDJPY

ORCHESTRATOR_MIN_CONF=0.6
ORCHESTRATOR_AGG_THRESHOLD=0.6
ORCHESTRATOR_LOCK_TTL=10
EXEC_IDEMP_TTL=600

FXPRO_API_KEY=
FXPRO_API_SECRET=
FXPRO_API_BASE=https://api.fxpro.example
ENV

###########################
# Backend: core helpers
###########################
cat > "$ROOT/backend/journal.py" <<'PY'
import os, json, threading, time
JOURNAL_FILE = os.path.join(os.getcwd(),'logs','journal.jsonl')
_lock = threading.Lock()
def record_trade(entry):
    os.makedirs(os.path.dirname(JOURNAL_FILE), exist_ok=True)
    entry['ts'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    with _lock:
        with open(JOURNAL_FILE,'a',encoding='utf-8') as f:
            f.write(json.dumps(entry) + '\\n')
def read_journal():
    if not os.path.exists(JOURNAL_FILE):
        return []
    with open(JOURNAL_FILE,'r',encoding='utf-8') as f:
        return [json.loads(line) for line in f if line.strip()]
PY

cat > "$ROOT/backend/audit.py" <<'PY'
import os, json, time
LOG = os.path.join(os.getcwd(),'logs','audit.log')
def audit_event(user, ev, data):
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG,'a') as f:
        f.write(f"{time.asctime()} | {user} | {ev} | {json.dumps(data)}\\n")
PY

cat > "$ROOT/backend/risk/risk_manager.py" <<'PY'
import time
class RiskManager:
    def __init__(self, balance=10000.0, daily_loss_pct=0.05, max_consec_losses=3, max_position_risk=0.01):
        self.balance = float(balance)
        self.daily_loss_limit = self.balance * float(daily_loss_pct)
        self.max_consec_losses = int(max_consec_losses)
        self.max_position_risk = float(max_position_risk)
        self.daily_loss = 0.0
        self.consec_losses = 0
        self.last_reset = time.time()
    def reset_daily(self):
        if time.time() - self.last_reset > 24*3600:
            self.daily_loss = 0.0
            self.consec_losses = 0
            self.last_reset = time.time()
    def can_trade(self, stake):
        self.reset_daily()
        if stake > self.balance * self.max_position_risk:
            return False, 'stake_exceeds_max_position_risk'
        if (self.daily_loss + stake) > self.daily_loss_limit:
            return False, 'daily_loss_limit_exceeded'
        if self.consec_losses >= self.max_consec_losses:
            return False, 'max_consecutive_losses_reached'
        return True, 'ok'
    def on_result(self, pnl):
        self.reset_daily()
        if pnl < 0:
            self.daily_loss += -pnl
            self.consec_losses += 1
        else:
            self.consec_losses = 0
PY

###########################
# Backend: Broker adapters
###########################
cat > "$ROOT/backend/adapters/broker_template.py" <<'PY'
import time, random
class BrokerAdapter:
    def __init__(self, mode='paper'):
        self.mode = mode
    def place_order(self, symbol, side, amount, price=None):
        if self.mode != 'live':
            fake_id = f"sim-{int(time.time()*1000)}"
            fill_price = price if price else round(1 + random.uniform(-0.0005,0.0005), 6)
            return {"id": fake_id, "status":"filled", "fill_price": fill_price}
        else:
            raise NotImplementedError("Implement live broker API here")
PY

cat > "$ROOT/backend/adapters/fxpro_adapter.py" <<'PY'
import os, time, requests
from dotenv import load_dotenv
load_dotenv()
class FXProAdapter:
    def __init__(self, mode='paper'):
        self.mode = mode
        self.api_key = os.getenv('FXPRO_API_KEY')
        self.api_secret = os.getenv('FXPRO_API_SECRET')
        self.base = os.getenv('FXPRO_API_BASE','https://api.fxpro.example')
        self.session = requests.Session()
        if self.api_key:
            self.session.headers.update({'Authorization': f'Bearer {self.api_key}'})
    def place_order(self, symbol, side, amount, price=None, order_type='market'):
        if self.mode != 'live':
            return {
                "id": f"sim-{int(time.time()*1000)}",
                "symbol": symbol,
                "side": side,
                "amount": amount,
                "fill_price": price or 1.0,
                "status": "filled"
            }
        raise NotImplementedError("Implement FXPro live REST calls here using FXPro API docs")
PY

###########################
# Backend: Candles + SR strategies
###########################
cat > "$ROOT/backend/strategies/candles.py" <<'PY'
import pandas as pd
import numpy as np
DETECTORS = {}
def is_bearish_engulfing(df):
    if len(df) < 2: return False
    a,b = df.iloc[-2], df.iloc[-1]
    return bool(a['close']>a['open'] and b['close']<b['open'] and (b['open']>a['close']) and (b['close']<a['open']))
def is_bullish_engulfing(df):
    if len(df) < 2: return False
    a,b = df.iloc[-2], df.iloc[-1]
    return bool(a['close']<a['open'] and b['close']>b['open'] and (b['open']<a['close']) and (b['close']>a['open']))
# ... (more detectors can be added similarly)
DETECTORS['bearish_engulfing']=is_bearish_engulfing
DETECTORS['bullish_engulfing']=is_bullish_engulfing
PY

cat > "$ROOT/backend/strategies/support_resistance_strategies.py" <<'PY'
import numpy as np
import pandas as pd
from scipy import stats
def _swing_highs_lows(df, order=5):
    highs=[]; lows=[]
    n=len(df)
    for i in range(order,n-order):
        if df['high'].iloc[i]==df['high'].iloc[i-order:i+order+1].max():
            highs.append(i)
        if df['low'].iloc[i]==df['low'].iloc[i-order:i+order+1].min():
            lows.append(i)
    return highs,lows
def detect_pivots(df):
    if len(df)<2: return {}
    prev=df.iloc[-2]
    high,low,close=prev['high'],prev['low'],prev['close']
    pivot=(high+low+close)/3.0
    r1=2*pivot - low; s1=2*pivot - high
    r2=pivot + (high-low); s2=pivot - (high-low)
    return {'pivot':pivot,'r1':r1,'s1':s1,'r2':r2,'s2':s2}
def detect_sr_levels(df,lookback=200):
    highs_idx,lows_idx=_swing_highs_lows(df,order=5)
    highs=df['high'].iloc[highs_idx].values if highs_idx else np.array([])
    lows=df['low'].iloc[lows_idx].values if lows_idx else np.array([])
    def cluster(vals,tol_pct=0.0015):
        if vals.size==0: return []
        vals=np.sort(vals); lvl=[vals[0]]
        levels=[]
        for v in vals[1:]:
            if abs(v - np.mean(lvl)) <= (np.mean(lvl) * tol_pct):
                lvl.append(v)
            else:
                levels.append(np.mean(lvl)); lvl=[v]
        if lvl: levels.append(np.mean(lvl))
        return sorted(levels)
    return {'resistance': cluster(highs), 'support': cluster(lows)}
def detect_supply_demand_zones(df,lookback=200,zone_width_bars=3):
    highs_idx,lows_idx=_swing_highs_lows(df,order=5)
    zones=[]
    for i in highs_idx[-10:]:
        top=float(df['high'].iloc[i]); bottom=float(df['low'].iloc[max(0,i-zone_width_bars):i+1].min())
        zones.append({'type':'supply','top':top,'bottom':bottom,'index':int(i)})
    for i in lows_idx[-10:]:
        bottom=float(df['low'].iloc[i]); top=float(df['high'].iloc[i:min(len(df),i+zone_width_bars+1)].max())
        zones.append({'type':'demand','top':top,'bottom':bottom,'index':int(i)})
    return zones
def detect_fib_levels(df,lookback=500):
    if len(df)<10: return {}
    highs_idx,lows_idx=_swing_highs_lows(df,order=8)
    sub=df.tail(lookback)
    if highs_idx and lows_idx:
        high_val=float(df['high'].iloc[highs_idx[-1]]); low_val=float(df['low'].iloc[lows_idx[-1]])
    else:
        high_val=float(sub['high'].max()); low_val=float(sub['low'].min())
    diff=high_val-low_val
    levels={'0.0':high_val,'0.236':high_val-0.236*diff,'0.382':high_val-0.382*diff,'0.5':high_val-0.5*diff,'0.618':high_val-0.618*diff,'1.0':low_val}
    return levels
def detect_trendlines(df,lookback=200):
    sub=df.tail(lookback).reset_index(drop=True)
    if len(sub)<20: return {}
    x=np.arange(len(sub)); y_low=sub['low'].values; y_high=sub['high'].values
    slope_low, intercept_low, r_low, p_low, se_low = stats.linregress(x,y_low)
    slope_high, intercept_high, r_high, p_high, se_high = stats.linregress(x,y_high)
    return {'up':{'slope':float(slope_low),'intercept':float(intercept_low),'r':float(r_low)}, 'down':{'slope':float(slope_high),'intercept':float(intercept_high),'r':float(r_high)}}
def detect_daily_high_low(df):
    if 'timestamp' in df.columns:
        df['date']=pd.to_datetime(df['timestamp']).dt.date
        last_date=df['date'].iloc[-1]
        sub=df[df['date']==last_date]
        if sub.empty: sub=df.tail(24)
    else:
        sub=df.tail(24)
    return {'daily_high': float(sub['high'].max()), 'daily_low': float(sub['low'].min())}
def sr_strategy(df, symbol=None, method='pivot', params=None):
    params=params or {}
    if method=='pivot':
        piv=detect_pivots(df);price=float(df['close'].iloc[-1]); r1=piv.get('r1'); s1=piv.get('s1'); tol=params.get('tol_pct',0.001)
        if r1 and abs(price-r1)<=abs(r1)*tol: return {'signal':'SELL','score':0.7,'meta':{'level':'r1','value':r1}}
        if s1 and abs(price-s1)<=abs(s1)*tol: return {'signal':'BUY','score':0.7,'meta':{'level':'s1','value':s1}}
        return {'signal':'HOLD','score':0.0,'meta':{'method':'pivot'}}
    if method=='sr_levels':
        levels=detect_sr_levels(df,lookback=params.get('lookback',200)); price=float(df['close'].iloc[-1])
        for rlv in levels.get('resistance',[]):
            if abs(price-rlv)<=abs(rlv)*params.get('tol_pct',0.0015): return {'signal':'SELL','score':0.6,'meta':{'level':rlv,'type':'resistance'}}
        for slv in levels.get('support',[]):
            if abs(price-slv)<=abs(slv)*params.get('tol_pct',0.0015): return {'signal':'BUY','score':0.6,'meta':{'level':slv,'type':'support'}}
        return {'signal':'HOLD','score':0.0,'meta':{'method':'sr_levels'}}
    if method=='supply_demand':
        zones=detect_supply_demand_zones(df,lookback=params.get('lookback',200)); price=float(df['close'].iloc[-1])
        for z in zones:
            if z['bottom']<=price<=z['top']: return {'signal':'SELL' if z['type']=='supply' else 'BUY','score':0.65,'meta':{'zone':z}}
        return {'signal':'HOLD','score':0.0,'meta':{}}
    if method=='fibonacci':
        fib=detect_fib_levels(df,lookback=params.get('lookback',500)); price=float(df['close'].iloc[-1])
        for key,val in fib.items():
            if abs(price-val)<=abs(val)*params.get('tol_pct',0.002):
                if float(key)>=0.382 and float(key)<=0.618: return {'signal':'BUY','score':0.5,'meta':{'fib':key,'value':val}}
                else: return {'signal':'HOLD','score':0.2,'meta':{'fib':key,'value':val}}
        return {'signal':'HOLD','score':0.0,'meta':{}}
    if method=='trendline':
        t=detect_trendlines(df, lookback=params.get('lookback',200))
        up=t.get('up'); down=t.get('down')
        if up and up.get('slope',0)>0: return {'signal':'BUY','score':min(0.8,abs(up.get('r',0))),'meta':{'trend':'up','slope':up.get('slope')}}
        if down and down.get('slope',0)<0: return {'signal':'SELL','score':min(0.8,abs(down.get('r',0))),'meta':{'trend':'down','slope':down.get('slope')}}
        return {'signal':'HOLD','score':0.0,'meta':{}}
    if method=='daily':
        d=detect_daily_high_low(df); price=float(df['close'].iloc[-1])
        if price > d['daily_high']*(1+params.get('tol_pct',0.0005)): return {'signal':'BUY','score':0.6,'meta':{'daily':'break_high','value':d['daily_high']}}
        if price < d['daily_low']*(1-params.get('tol_pct',0.0005)): return {'signal':'SELL','score':0.6,'meta':{'daily':'break_low','value':d['daily_low']}}
        return {'signal':'HOLD','score':0.0,'meta':{}}
    return {'signal':'HOLD','score':0.0,'meta':{'error':'unknown_method'}}
PY

###########################
# Backend: Strategy registry + orchestrator + execute
###########################
cat > "$ROOT/backend/strategies/strategy_registry.py" <<'PY'
from .candles import DETECTORS
from .support_resistance_strategies import sr_strategy, list as _list
def list_patterns():
    return list(DETECTORS.keys())
def list_sr_methods():
    return ['pivot','sr_levels','supply_demand','fibonacci','trendline','daily']
PY

cat > "$ROOT/backend/controllers/execute.py" <<'PY'
import os, time, json, hashlib
from risk.risk_manager import RiskManager
from adapters.broker_template import BrokerAdapter
from journal import record_trade
from audit import audit_event
import redis
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
r = redis.from_url(REDIS_URL, decode_responses=True)
IDEMP_TTL = int(os.getenv("EXEC_IDEMP_TTL", "600"))
class ExecutionController:
    def __init__(self, mode="paper"):
        balance = float(os.getenv("ACCOUNT_BALANCE", "10000"))
        daily_loss_pct = float(os.getenv("DAILY_LOSS_LIMIT_PCT", "0.05"))
        max_consec = int(os.getenv("MAX_CONSECUTIVE_LOSSES", "3"))
        max_pos_risk = float(os.getenv("MAX_POSITION_RISK", "0.01"))
        self.risk = RiskManager(balance=balance, daily_loss_pct=daily_loss_pct, max_consec_losses=max_consec, max_position_risk=max_pos_risk)
        self.mode = mode or os.getenv("MODE", "paper")
        self.broker = BrokerAdapter(mode=self.mode)
    def _idempotency_key(self, symbol, side, metadata):
        raw = f"{symbol}|{side}|{json.dumps(metadata, sort_keys=True)}"
        return "idem:" + hashlib.sha256(raw.encode()).hexdigest()
    def execute(self, symbol, side, confidence=1.0, metadata=None):
        metadata = metadata or {}
        idem = self._idempotency_key(symbol, side, metadata)
        if r.get(idem):
            return {"ok": False, "reason": "duplicate_decision"}
        stake_pct = float(os.getenv("MAX_POSITION_RISK", "0.01"))
        stake = self.risk.balance * stake_pct * float(confidence)
        can, reason = self.risk.can_trade(stake)
        if not can:
            audit_event("system", "exec_blocked", {"symbol": symbol, "side": side, "reason": reason})
            return {"ok": False, "reason": reason}
        try:
            order = self.broker.place_order(symbol, side, amount=stake)
        except Exception as e:
            audit_event("system", "exec_error", {"symbol": symbol, "error": str(e)})
            return {"ok": False, "reason": "broker_error", "error": str(e)}
        record_trade({"symbol": symbol, "side": side, "stake": stake, "order": order, "metadata": metadata})
        audit_event("system", "exec_success", {"symbol": symbol, "side": side, "order_id": order.get("id")})
        r.set(idem, json.dumps(order), ex=IDEMP_TTL)
        return {"ok": True, "order": order}
PY

cat > "$ROOT/backend/controllers/orchestrator.py" <<'PY'
import os, time, json
from concurrent.futures import ThreadPoolExecutor, as_completed
import pandas as pd
import redis
from controllers.execute import ExecutionController
from strategies.strategy_registry import list_patterns
from strategies.support_resistance_strategies import sr_strategy, list_sr_methods
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
r = redis.from_url(REDIS_URL, decode_responses=True)
LOCK_TTL = int(os.getenv("ORCHESTRATOR_LOCK_TTL", "5"))
def fetch_recent_candles(symbol: str, limit: int = 200):
    path = os.path.join(os.getcwd(), "data", "sample_1m.csv")
    df = pd.read_csv(path, parse_dates=["timestamp"]).tail(limit).reset_index(drop=True)
    return df
def acquire_symbol_lock(symbol: str) -> bool:
    key = f"lock:symbol:{symbol}"
    acquired = r.set(key, "1", nx=True, ex=LOCK_TTL)
    return bool(acquired)
def release_symbol_lock(symbol: str):
    key = f"lock:symbol:{symbol}"
    try: r.delete(key)
    except Exception: pass
def run_all_strategies(symbol, candles):
    results=[]
    # candlestick detectors
    import strategies.candles as candles_mod
    for name,fn in candles_mod.DETECTORS.items():
        try:
            res = fn(candles)
            if res:
                # map -> BUY/SELL heuristics
                results.append({'strategy':name,'signal':'BUY' if 'bull' in name else 'SELL','score':0.7,'meta':{}})
        except Exception as e:
            results.append({'strategy':name,'signal':'HOLD','score':0.0,'meta':{'error':str(e)}})
    # SR methods
    for method in list_sr_methods():
        try:
            res = sr_strategy(candles, method=method)
            results.append({'strategy':f"sr_{method}", 'signal': res.get('signal','HOLD'), 'score': res.get('score',0.0), 'meta': res.get('meta',{})})
        except Exception as e:
            results.append({'strategy':f"sr_{method}", 'signal':'HOLD','score':0.0,'meta':{'error':str(e)}})
    return results
def aggregate_signals(signals, threshold=0.6):
    votes={'BUY':0.0,'SELL':0.0,'HOLD':0.0}; total=0.0
    for s in signals:
        sig=s.get('signal','HOLD').upper(); score=float(s.get('score',1.0))
        votes[sig]+=score; total+=score
    if total<=0: return {'decision':'HOLD','confidence':0.0}
    buy_w=votes['BUY']/total; sell_w=votes['SELL']/total
    if buy_w>=threshold: return {'decision':'BUY','confidence':buy_w}
    if sell_w>=threshold: return {'decision':'SELL','confidence':sell_w}
    return {'decision':'HOLD','confidence':max(buy_w,sell_w)}
def orchestrate_single_symbol(symbol, mode='paper'):
    if not acquire_symbol_lock(symbol): return {'ok':False,'msg':'locked'}
    try:
        candles = fetch_recent_candles(symbol)
        signals = run_all_strategies(symbol, candles)
        agg = aggregate_signals(signals, threshold=float(os.getenv('ORCHESTRATOR_AGG_THRESHOLD','0.6')))
        if agg['decision'] in ('BUY','SELL') and agg['confidence']>=float(os.getenv('ORCHESTRATOR_MIN_CONF','0.6')):
            ec = ExecutionController(mode=mode)
            res = ec.execute(symbol, agg['decision'], confidence=agg['confidence'], metadata={'signals':signals})
            return {'ok':True,'executed':res}
        return {'ok':True,'executed':None,'agg':agg}
    finally:
        release_symbol_lock(symbol)
def orchestrate_many(symbols, mode='paper'):
    out={}
    for s in symbols:
        out[s]=orchestrate_single_symbol(s.strip(), mode=mode)
    return out
PY

###########################
# Backend: main_full.py (FastAPI)
###########################
cat > "$ROOT/backend/main_full.py" <<'PY'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from strategies.strategy_registry import list_patterns, list_sr_methods
from controllers.orchestrator import orchestrate_many
import os
app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=['*'], allow_methods=['*'], allow_headers=['*'])
@app.get("/api/health")
def health():
    return {"ok": True}
@app.get("/api/strategies/candles")
def api_patterns():
    return {"patterns": list_patterns()}
@app.get("/api/strategies/sr_methods")
def api_sr_methods():
    return {"sr_methods": list_sr_methods()}
@app.post("/api/autotrade/run_once")
def api_run_once(payload: dict):
    symbols = payload.get('symbols', os.getenv('AUTOTRADE_SYMBOLS','EURUSD').split(','))
    mode = payload.get('mode','paper')
    return orchestrate_many(symbols, mode=mode)
@app.get("/api/journal")
def api_journal():
    from journal import read_journal
    return read_journal()
PY

###########################
# Backend: tasks for Celery (minimal)
###########################
cat > "$ROOT/backend/tasks/celery_app.py" <<'PY'
from celery import Celery
import os
CELERY_BROKER = os.getenv('REDIS_URL','redis://localhost:6379/0')
app = Celery('blenda_tasks', broker=CELERY_BROKER, backend=CELERY_BROKER)
PY

cat > "$ROOT/backend/tasks/tasks.py" <<'PY'
from .celery_app import app
from controllers.orchestrator import orchestrate_many
@app.task(bind=True)
def run_orchestrator(self, symbols=None, mode='paper'):
    if not symbols:
        symbols_env = "EURUSD,GBPUSD,USDJPY"
        symbols=[s.strip() for s in symbols_env.split(',')]
    elif isinstance(symbols,str):
        symbols=[s.strip() for s in symbols.split(',')]
    return orchestrate_many(symbols, mode=mode)
PY

###########################
# Sample data
###########################
python - <<'PY'
import pandas as pd, numpy as np, os
now=pd.Timestamp.utcnow()
prices=1.1000 + np.cumsum(np.random.randn(1200)*0.00005)
df=pd.DataFrame({
 'timestamp':[now - pd.Timedelta(minutes=i) for i in range(1200)][::-1],
 'open':prices,
 'high':prices + abs(np.random.randn(1200)*0.00002),
 'low':prices - abs(np.random.randn(1200)*0.00002),
 'close':prices + np.random.randn(1200)*0.00001,
 'volume': np.random.randint(1,100, size=1200)
})
os.makedirs('$ROOT/backend/data', exist_ok=True)
df.to_csv('$ROOT/backend/data/sample_1m.csv', index=False)
print('sample data created at backend/data/sample_1m.csv')
PY

###########################
# Mobile: Expo app (minimal)
###########################
cat > "$ROOT/mobile/blenda-app/package.json" <<'JSON'
{
  "name": "blenda",
  "version": "1.0.0",
  "main": "node_modules/expo/AppEntry.js",
  "scripts": {
    "start": "expo start",
    "android": "expo run:android",
    "web": "expo start --web"
  },
  "dependencies": {
    "expo": "~48.0.0",
    "react": "18.2.0",
    "react-native": "0.71.8",
    "axios": "^1.4.0"
  }
}
JSON

cat > "$ROOT/mobile/blenda-app/App.js" <<'JS'
import React from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';
export default function App(){
  return (
    <View style={styles.container}>
      <Image source={require('./src/assets/branding_pack.png')} style={{width:180,height:80,resizeMode:'contain'}} />
      <Text style={styles.title}>Blenda</Text>
      <Text style={styles.slogan}>Have a bright future</Text>
    </View>
  );
}
const styles = StyleSheet.create({
  container:{flex:1,backgroundColor:'#07132b',alignItems:'center',justifyContent:'center'},
  title:{fontSize:40,color:'#6fb3ff',fontWeight:'700'},
  slogan:{fontSize:16,color:'#cfe9ff',marginTop:8}
});
JS

cat > "$ROOT/mobile/blenda-app/src/screens/StrategyLibrary.js" <<'JS'
import React, {useEffect, useState} from 'react';
import {View,Text,FlatList,TouchableOpacity,Image} from 'react-native';
import axios from 'axios';
export default function StrategyLibrary({navigation}){
  const [patterns,setPatterns]=useState([]);
  useEffect(()=>{ axios.get('http://127.0.0.1:8000/api/strategies/candles').then(r=>setPatterns(r.data.patterns||[])).catch(()=>{}); },[]);
  return (
    <View style={{flex:1,backgroundColor:'#07132b',padding:12}}>
      <Image source={require('../assets/branding_pack.png')} style={{width:140,height:60,alignSelf:'center'}} />
      <Text style={{color:'#a8d1ff',fontSize:20,marginTop:8}}>Candlestick Strategies</Text>
      <FlatList data={patterns} keyExtractor={(i)=>i} renderItem={({item})=>(
        <TouchableOpacity style={{backgroundColor:'#0b2540',padding:12,borderRadius:8,marginTop:8}}>
          <Text style={{color:'#cfe9ff'}}>{item}</Text>
        </TouchableOpacity>
      )} />
    </View>
  )
}
JS

cat > "$ROOT/mobile/blenda-app/src/screens/StrategyDetail.js" <<'JS'
import React,{useState} from 'react';
import {View,Text,Button} from 'react-native';
import axios from 'axios';
export default function StrategyDetail({route}) {
  const pattern = route.params.pattern;
  const [result,setResult]=useState(null);
  async function run(){
    const res = await axios.post('http://127.0.0.1:8000/api/strategies/run_candle',{symbol:'EURUSD',pattern});
    setResult(res.data);
  }
  return (
    <View style={{flex:1,backgroundColor:'#07132b',padding:12}}>
      <Text style={{color:'#a8d1ff',fontSize:20}}>{pattern}</Text>
      <Button title="Test Pattern" onPress={run} />
      {result && <Text style={{color:'#cfe9ff',marginTop:12}}>{JSON.stringify(result)}</Text>}
    </View>
  )
}
JS

# copy branding asset if available
if [ -f "$BRAND_SRC" ]; then
  cp "$BRAND_SRC" "$ROOT/mobile/blenda-app/src/assets/branding_pack.png"
  echo "branding asset copied to mobile/blenda-app/src/assets/branding_pack.png"
else
  echo "branding asset not found at $BRAND_SRC; please upload it or replace path in mobile App.js"
fi

###########################
# Docker compose for Redis + worker (optional)
###########################
cat > "$ROOT/docker-compose.celery.yml" <<'YML'
version: '3.8'
services:
  redis:
    image: redis:6.2
    restart: unless-stopped
    ports:
      - "6379:6379"
YML

###########################
# Scripts & README
###########################
cat > "$ROOT/README.md" <<'MD'
# Blenda - Full-stack trading scaffold

See backend/ and mobile/blenda-app for files.

## Quick start (Codespace or Linux machine)

# Backend
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
# Start Redis (docker)
docker run -d --name blenda-redis -p 6379:6379 redis:6.2
# Start backend
uvicorn main_full:app --reload --host 0.0.0.0 --port 8000

# Mobile (Expo)
cd mobile/blenda-app
npm install
npx expo start

Open Expo Go on your phone to load the app (scan QR).

MD

echo "Scaffold created. Inspect the backend/ and mobile/blenda-app/ folders. Follow README.md for next steps."