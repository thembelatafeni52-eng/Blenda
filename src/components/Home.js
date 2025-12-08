import React from "react";
import "./Home.css";

function Home() {
  return (
    <div className="home-container">
      <h1>Welcome to Your Motivation App</h1>
      <p>Your daily dose of growth, discipline and purpose.</p>

      <div className="home-buttons">
        <a href="/videos" className="btn primary">Watch Videos</a>
        <a href="/quotes" className="btn secondary">Daily Quotes</a>
      </div>
    </div>
  );
}

export default Home;
