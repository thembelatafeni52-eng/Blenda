export default function Home() {
  return (
    <div style={{ padding: "40px", fontSize: "30px" }}>
      <h1>Blenda</h1>
      <p>Welcome to my site!</p>
    </div>
  );
}
export default function Home() {
  return (
    <div style={styles.container}>
      {/* HERO SECTION */}
      <section style={styles.hero}>
        <h1 style={styles.title}>Blenda</h1>
        <p style={styles.subtitle}>
          Where creativity meets innovation.  
          Build. Create. Transform.
        </p>

        <button style={styles.ctaButton}>
          Get Started
        </button>
      </section>

      {/* FEATURES SECTION */}
      <section style={styles.featuresSection}>
        <h2 style={styles.sectionTitle}>What We Offer</h2>

        <div style={styles.featuresGrid}>
          <div style={styles.featureCard}>
            <h3 style={styles.featureTitle}>🚀 Fast</h3>
            <p style={styles.featureText}>
              Lightning-speed performance designed to deliver the best experience.
            </p>
          </div>

          <div style={styles.featureCard}>
            <h3 style={styles.featureTitle}>🎨 Creative</h3>
            <p style={styles.featureText}>
              Beautiful designs meant to inspire and impress.
            </p>
          </div>

          <div style={styles.featureCard}>
            <h3 style={styles.featureTitle}>📱 Responsive</h3>
            <p style={styles.featureText}>
              Works perfectly on all devices — mobile, tablet, or desktop.
            </p>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer style={styles.footer}>
        <p>© {new Date().getFullYear()} Blenda. All rights reserved.</p>
      </footer>
    </div>
  );
}

const styles = {
  container: {
    fontFamily: "Arial, sans-serif",
    color: "#222",
  },

  hero: {
    textAlign: "center",
    padding: "80px 20px",
    background: "linear-gradient(135deg, #7B5FFF, #4ACBFF)",
    color: "#fff",
  },

  title: {
    fontSize: "48px",
    fontWeight: "bold",
    marginBottom: "10px",
  },

  subtitle: {
    fontSize: "20px",
    marginBottom: "30px",
  },

  ctaButton: {
    padding: "12px 30px",
    fontSize: "18px",
    borderRadius: "8px",
    border: "none",
    cursor: "pointer",
    backgroundColor: "#fff",
    color: "#4A3AFF",
    fontWeight: "bold",
  },

  featuresSection: {
    padding: "50px 20px",
    textAlign: "center",
  },

  sectionTitle: {
    fontSize: "32px",
    marginBottom: "40px",
  },

  featuresGrid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(250px, 1fr))",
    gap: "20px",
  },

  featureCard: {
    padding: "20px",
    borderRadius: "12px",
    backgroundColor: "#f7f7f7",
    boxShadow: "0 4px 10px rgba(0,0,0,0.1)",
  },

  featureTitle: {
    fontSize: "22px",
    marginBottom: "10px",
  },

  featureText: {
    fontSize: "16px",
    color: "#555",
  },

  footer: {
    textAlign: "center",
    padding: "20px",
    marginTop: "40px",
    backgroundColor: "#eee",
  },
};
