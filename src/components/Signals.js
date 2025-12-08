import React from "react";
import "./Signals.css";

function Signals() {
  return (
    <div className="signals-container">
      <h2>AI Market Signals</h2>

      <div className="signal-card green">
        <h3>EUR/USD</h3>
        <p>Signal: BUY</p>
        <span>Confidence: 92%</span>
      </div>

      <div className="signal-card red">
        <h3>GBP/JPY</h3>
        <p>Signal: SELL</p>
        <span>Confidence: 87%</span>
      </div>

      <div className="signal-card blue">
        <h3>NAS100</h3>
        <p>Signal: STRONG BUY</p>
        <span>Confidence: 95%</span>
      </div>
    </div>
  );
}

export default Signals;
