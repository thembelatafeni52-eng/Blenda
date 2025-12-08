import React, { useState } from "react";
import "./Trading.css";

function Trading() {
  const [strategy, setStrategy] = useState("AI-PRO");
  const [status, setStatus] = useState("Idle");

  const startTrading = () => {
    setStatus("Running strategy: " + strategy);
  };

  const stopTrading = () => {
    setStatus("Stopped");
  };

  return (
    <div className="trading-container">
      <h1>Trading Bot</h1>

      <div className="trading-box">
        <label>Select Trading Strategy:</label>
        <select
          value={strategy}
          onChange={(e) => setStrategy(e.target.value)}
        >
          <option value="AI-PRO">AI PRO Strategy</option>
          <option value="AI-SCALPER">AI Scalping Strategy</option>
          <option value="AI-LONG">AI Long-Term Strategy</option>
          <option value="AI-SWING">AI Swing Strategy</option>
        </select>

        <div className="buttons">
          <button onClick={startTrading} className="start-btn">Start</button>
          <button onClick={stopTrading} className="stop-btn">Stop</button>
        </div>

        <p className="status">Status: {status}</p>
      </div>
    </div>
  );
}

export default Trading;
