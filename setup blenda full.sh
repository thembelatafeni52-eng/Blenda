#!/usr/bin/env bash
set -e
ROOT="$(pwd)"
echo "Scaffolding Blenda into $ROOT"

# Basic paths
mkdir -p "$ROOT"/{backend/{strategies,controllers,adapters,tasks,logs,data},mobile/blenda-app/{src,src/assets,src/screens,src/components},public}

# backend requirements and env example
cat > "$ROOT/backend/requirements.txt" <<'REQ'
fastapi uvicorn python-dotenv pandas numpy scipy requests redis celery aiohttp
REQ

cat > "$ROOT/backend/.env.example" <<'ENV'
MODE=paper
API_PORT=8000
REDIS_URL=redis://localhost:6379/0
ACCOUNT_BALANCE=10000
FXPRO_API_KEY=
FXPRO_API_SECRET=
FXPRO_API_BASE=https://api.fxpro.example
IBKR_API_KEY=
IBKR_API_SECRET=
ENV

# Simple journal and audit
cat > "$ROOT/backend/journal.py" <<'PY'
import os, json, time, threading
JOURNAL_FILE = os.path.join(os.getcwd(),'logs','journal.jsonl')
_lock = threading.Lock()
def record_trade(entry):
    os.makedirs(os.path.dirname(JOURNAL_FILE), exist_ok=True)
    entry['ts'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    with _lock:
        with open(JOURNAL_FILE,'a',encoding='utf-8') as f:
            f.write(json.dumps(entry) + '\\n')
def read_journal():
    if not os.path.exists(JOURNAL_FILE): return []
    with open(JOURNAL_FILE,'r',encoding='utf-8') as f:
        return [json.loads(line) for line in f if line.strip()]
PY

# backend: broker template + fxpro adapter (safe template)
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
    def place_order(self, symbol, side, amount, price=None):
        if self.mode != 'live':
            return {"id": f"sim-{int(time.time()*1000)}", "symbol": symbol, "side": side, "amount": amount, "fill_price": price or 1.0, "status":"filled"}
        raise NotImplementedError("Implement FXPro live REST calls here using FXPro API docs")
PY

# backend orchestrator (starter)
cat > "$ROOT/backend/controllers/orchestrator.py" <<'PY'
import os, pandas as pd
from controllers.exec_controller import ExecutionController
from strategies.mse import MarketStructure
from strategies.smc import SmartMoney
from strategies.liquidity import LiquidityDetector

def fetch_sample_candles(symbol, limit=500):
    path = os.path.join(os.getcwd(), "data", "sample_1m.csv")
    if not os.path.exists(path):
        return pd.DataFrame()
    return pd.read_csv(path, parse_dates=["timestamp"]).tail(limit).reset_index(drop=True)

def run_strategies_for_symbol(symbol, mode="paper"):
    df = fetch_sample_candles(symbol)
    if df.empty:
        return {"ok": False, "reason": "no_data"}
    ms = MarketStructure(df); ms_state = ms.analyze()
    lq = LiquidityDetector(df); lq_zones = lq.detect()
    smc = SmartMoney(df); smc_signals = smc.scan()
    score = 0.0
    if ms_state.get("trend") == "up": score += 0.3
    if smc_signals.get("bull_ob"): score += 0.4
    if len(lq_zones.get("demand", []))>0: score += 0.3
    decision = "HOLD"
    if score >= 0.8: decision = "BUY"
    if score <= -0.8: decision = "SELL"
    exec_ctrl = ExecutionController(mode=mode)
    if decision in ("BUY","SELL"):
        res = exec_ctrl.execute(symbol, decision, confidence=score)
        return {"ok": True, "decision": decision, "score": score, "exec": res}
    return {"ok": True, "decision": decision, "score": score}

def orchestrate_many(symbols, mode="paper"):
    out = {}
    for s in symbols:
        out[s] = run_strategies_for_symbol(s, mode=mode)
    return out
PY

# exec controller stub
cat > "$ROOT/backend/controllers/exec_controller.py" <<'PY'
import os, json, time
class ExecutionController:
    def __init__(self, mode="paper"):
        self.mode = mode
        self.log_path = os.path.join(os.getcwd(), "logs"); os.makedirs(self.log_path, exist_ok=True)
    def execute(self, symbol, side, confidence=1.0, metadata=None):
        metadata = metadata or {}
        order = {"id": f"sim-{int(time.time()*1000)}","symbol": symbol,"side": side,"confidence": float(confidence),"status": "filled" if self.mode!="live" else "submitted"}
        with open(os.path.join(self.log_path, "trades.jsonl"), "a") as f:
            f.write(json.dumps(order) + "\\n")
        return {"ok": True, "order": order}
PY

# simple strategy modules
cat > "$ROOT/backend/strategies/mse.py" <<'PY'
class MarketStructure:
    def __init__(self, df): self.df = df
    def analyze(self):
        if self.df.empty: return {}
        ma = self.df['close'].rolling(200, min_periods=1).mean().iloc[-1]
        last = self.df['close'].iloc[-1]
        return {"trend": "up" if last > ma else "down", "ma": float(ma)}
PY

cat > "$ROOT/backend/strategies/smc.py" <<'PY'
class SmartMoney:
    def __init__(self, df): self.df = df
    def scan(self):
        if self.df.empty: return {}
        last = self.df.iloc[-1]; prev = self.df.iloc[-2] if len(self.df)>1 else last
        bull_ob = (prev['close'] < prev['open']) and (last['close'] > last['open'])
        bear_ob = (prev['close'] > prev['open']) and (last['close'] < last['open'])
        return {"bull_ob": bool(bull_ob), "bear_ob": bool(bear_ob)}
PY

cat > "$ROOT/backend/strategies/liquidity.py" <<'PY'
class LiquidityDetector:
    def __init__(self, df): self.df = df
    def detect(self):
        if self.df.empty: return {"demand": [], "supply": []}
        highs = float(self.df['high'].tail(20).max()); lows = float(self.df['low'].tail(20).min())
        return {"demand":[lows], "supply":[highs]}
PY

# backend FastAPI entry
cat > "$ROOT/backend/main.py" <<'PY'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from controllers.orchestrator import orchestrate_many
app = FastAPI(title="Blenda")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
@app.get("/health")
def health(): return {"ok": True}
@app.post("/autotrade/run")
def run(payload: dict):
    symbols = payload.get("symbols", ["EURUSD"]); mode = payload.get("mode", "paper")
    return orchestrate_many(symbols, mode=mode)
PY

# sample data generation
python - <<'PY'
import pandas as pd, numpy as np, os
now = pd.Timestamp.utcnow()
prices = 1.1000 + np.cumsum(np.random.randn(1200)*0.00005)
df = pd.DataFrame({
 'timestamp':[now - pd.Timedelta(minutes=i) for i in range(1200)][::-1],
 'open':prices,
 'high':prices + abs(np.random.randn(1200)*0.00002),
 'low':prices - abs(np.random.randn(1200)*0.00002),
 'close':prices + np.random.randn(1200)*0.00001,
 'volume': np.random.randint(1,100, size=1200)
})
os.makedirs('$ROOT/backend/data', exist_ok=True)
df.to_csv('$ROOT/backend/data/sample_1m.csv', index=False)
print('sample data created')
PY

# mobile minimal app (web React) — quick demo
cat > "$ROOT/mobile/blenda-app/package.json" <<'JSON'
{"name":"blenda","version":"1.0.0","private":true,"dependencies":{"react":"18.2.0","react-dom":"18.2.0","react-router-dom":"6"},"scripts":{"start":"vite"}}
JSON

cat > "$ROOT/mobile/blenda-app/index.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Blenda Demo</title></head><body><div id="root"></div><script type="module" src="/src/main.jsx"></script></body></html>
HTML

cat > "$ROOT/mobile/blenda-app/src/main.jsx" <<'JS'
import React from "react"; import { createRoot } from "react-dom/client"; import App from "./App"; import "./styles.css";
createRoot(document.getElementById("root")).render(<App />);
JS

cat > "$ROOT/mobile/blenda-app/src/App.jsx" <<'JS'
import React from "react";
export default function App(){ return (<div style={{fontFamily:'Arial',padding:20,background:'#07132b',minHeight:'100vh',color:'#cfe9ff'}}><h1 style={{color:'#6fb3ff'}}>Blenda</h1><p>Have a bright future — demo UI</p></div>); }
JS

cat > "$ROOT/mobile/blenda-app/src/styles.css" <<'CSS'
body{margin:0} 
CSS

# README
cat > "$ROOT/README.md" <<'MD'
Blenda scaffold created. See /backend and /mobile/blenda-app.
Run instructions in next steps (Codespace or PC).
MD

echo "Scaffold done. Now open a Codespace (or clone repo locally) and run the commands from the assistant."
