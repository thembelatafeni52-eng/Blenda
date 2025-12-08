export default function Login() {
  return (
    <div style={{ padding: "40px", textAlign: "center" }}>
      <h1>Login</h1>

      <input type="email" placeholder="Email" style={styles.input} />
      <input type="password" placeholder="Password" style={styles.input} />

      <button style={styles.btn}>Login</button>
    </div>
  );
}

const styles = {
  input: {
    width: "80%",
    padding: "15px",
    margin: "15px auto",
    display: "block",
    borderRadius: "8px",
    border: "1px solid #ccc",
  },
  btn: {
    padding: "12px 30px",
    background: "#0A4DFF",
    color: "#fff",
    borderRadius: "8px",
    border: "none",
    cursor: "pointer",
    marginTop: "15px",
  },
};
