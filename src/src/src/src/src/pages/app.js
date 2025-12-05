document.addEventListener("DOMContentLoaded", () => {
  console.log("App loaded!");

  const startBtn = document.getElementById("startBtn");

  if (startBtn) {
    startBtn.addEventListener("click", () => {
      alert("Your AI Motivation App has started!");
    });
  }
});
