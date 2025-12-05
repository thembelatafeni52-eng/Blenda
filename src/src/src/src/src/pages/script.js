document.addEventListener("DOMContentLoaded", () => {
  console.log("Website Loaded Successfully!");

  // Example button click function (you can add more later)
  const exampleButton = document.getElementById("example-btn");

  if (exampleButton) {
    exampleButton.addEventListener("click", () => {
      alert("Button clicked!");
    });
  }
});
