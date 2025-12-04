import React from "react";
import "./Trade.css";

function Trade() {
  return (
    <div className="trade-container">
      <h2>Auto Trading</h2>

      <div className="trade-box">
        <p>Select Trading Mode:</p>

        <select className="trade-select">
          <option>Smart AI Trading</option>
          <option>Scalping Strategy</option>
          <option>Trend Follower</option>
          <option>Breakout System</option>
          <option>Reversal Strategy</option>
          <option>Multi-Strategy Auto Mode</option>
        </select>

        <button className="trade-btn">Start Trading</button>
      </div>
    </div>
  );
}

export default Trade;
