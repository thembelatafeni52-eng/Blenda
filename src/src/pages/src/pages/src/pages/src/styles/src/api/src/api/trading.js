// Trading API — secure communication with backend bot
// App NEVER stores API keys — backend stores keys safely

const BACKEND_URL = "https://your-backend-url.com"; // Replace when backend is ready

export const getSignals = async () => {
  const response = await fetch(`${BACKEND_URL}/signals`);
  return response.json();
};

export const getStrategies = async () => {
  const response = await fetch(`${BACKEND_URL}/strategies`);
  return response.json();
};

export const executeTrade = async (payload) => {
  const response = await fetch(`${BACKEND_URL}/trade`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });

  return response.json();
};

export const getBotStatus = async () => {
  const response = await fetch(`${BACKEND_URL}/status`);
  return response.json();
};

export const toggleBot = async (isRunning) => {
  const response = await fetch(`${BACKEND_URL}/toggle-bot`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ isRunning })
  });

  return response.json();
};
