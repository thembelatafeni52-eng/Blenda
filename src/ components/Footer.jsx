export default function Footer() {
  return (
    <footer style={styles.footer}>
      <p>© {new Date().getFullYear()} Blenda — Have a bright future</p>
    </footer>
  );
}

const styles = {
  footer: {
    textAlign: "center",
    backgroundColor: "#e7e7e7",
    padding: "20px",
    marginTop: "40px",
    fontSize: "16px",
  },
};
