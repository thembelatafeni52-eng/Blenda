import React from "react";
import { Link } from "react-router-dom";

function Home() {
  return (
    <div style={{ padding: "40px", textAlign: "center" }}>
      <h1>Welcome to Blenda</h1>
      <p>Your smart trading assistant.</p>

      <div style={{ marginTop: "30px" }}>
        <Link to="/login" style={{ marginRight: "20px" }}>
          Login
        </Link>
        <Link to="/register">Register</Link>
      </div>
    </div>
  );
}

export default Home;
