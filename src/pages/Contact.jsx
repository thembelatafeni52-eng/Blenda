export default function Contact() {
  return (
    <div style={{ padding: "40px" }}>
      <h1>Contact Us</h1>

      <form style={{ marginTop: "30px" }}>
        <input type="text" placeholder="Your Name" style={styles.input} />
        <input type="email" placeholder="Email" style={styles.input} />
        <textarea placeholder="Message" style={styles.textarea}></textarea>

        <button style={styles.btn}>Send Message</button>
      </form>
    </div>
  );
}

const styles = {
  input: {
    width: "100%",
    padding: "15px",
    marginBottom: "20px",
    borderRadius: "8px",
    border: "1px solid #ccc",
  },
  textarea: {
    width: "100%",
    height: "120px",
    padding: "15px",
    borderRadius: "8px",
    border: "1px solid #ccc",
    marginBottom: "20px",
  },
  btn: {
    padding: "12px 30px",
    background: "#0A4DFF",
    color: "#fff",
    borderRadius: "8px",
    border: "none",
    cursor: "pointer",
  },
};
