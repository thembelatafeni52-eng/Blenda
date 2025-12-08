import { Link } from "react-router-dom";

export default function Navbar() {
  return (
    <nav style={styles.nav}>
      <h2 style={styles.logo}>Blenda</h2>

      <div style={styles.links}>
        <Link style={styles.link} to="/">Home</Link>
        <Link style={styles.link} to="/about">About</Link>
        <Link style={styles.link} to="/contact">Contact</Link>
        <Link style={styles.loginBtn} to="/login">Login</Link>
      </div>
    </nav>
  );
}

const styles = {
  nav: {
    display: "flex",
    justifyContent: "space-between",
    padding: "20px 40px",
    backgroundColor: "#0A4DFF",
    color: "#fff",
    alignItems: "center",
  },

  logo: {
    fontSize: "28px",
    fontWeight: "bold",
  },

  links: {
    display: "flex",
    gap: "20px",
  },

  link: {
    color: "#fff",
    textDecoration: "none",
    fontSize: "18px",
  },

  loginBtn: {
    color: "#0A4DFF",
    background: "#fff",
    padding: "8px 20px",
    borderRadius: "6px",
    textDecoration: "none",
    fontWeight: "bold",
  },
};
