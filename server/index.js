// server/index.js
const http = require("http");
const WebSocket = require("ws");

const PORT = process.env.PORT || 3000;

// Простой HTTP сервер (не обязателен, но удобно для health-check)
const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true }));
    return;
  }
  res.writeHead(200);
  res.end("WebSocket chat server is running.\n");
});

// WebSocket сервер поверх HTTP
const wss = new WebSocket.Server({ server });

function broadcast(jsonString) {
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(jsonString);
    }
  });
}

wss.on("connection", (ws) => {
  console.log("✅ Client connected");

  ws.on("message", (data) => {
    // Клиент шлёт JSON (message)
    try {
      const text = data.toString();
      const msg = JSON.parse(text);

      // Мини-валидация
      if (!msg.type) return;
      if (msg.type === "chat" && typeof msg.text === "string") {
        const payload = {
          type: "chat",
          text: msg.text,
          sender: msg.sender || "anonymous",
          time: msg.time || new Date().toISOString(),
        };
        broadcast(JSON.stringify(payload));
      }
    } catch (e) {
      console.log("⚠️ Bad message:", e.message);
    }
  });

  ws.on("close", () => {
    console.log("❌ Client disconnected");
  });
});

server.listen(PORT, () => {
  console.log(`🚀 Server listening: http://localhost:${PORT}`);
  console.log(`🔌 WS endpoint: ws://localhost:${PORT}`);
});