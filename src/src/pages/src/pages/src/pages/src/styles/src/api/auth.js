// Authentication API — connects to your backend securely
// No API keys stored inside the app

const BACKEND_URL = "https://your-backend-url.com"; // Replace later

export const loginUser = async (email, password) => {
  const response = await fetch(`${BACKEND_URL}/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password })
  });

  return response.json();
};

export const registerUser = async (email, password) => {
  const response = await fetch(`${BACKEND_URL}/register`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password })
  });

  return response.json();
};
