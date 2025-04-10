// Simple HTTP server para probar conexiones
const http = require('http');

// Función para generar una respuesta exitosa en formato JSON
function successResponse(req, res, data) {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data || { success: true }));
}

// Creando el servidor
const server = http.createServer((req, res) => {
  const url = req.url;
  const method = req.method;
  
  console.log(`${method} ${url}`);

  // Para logs, recolectar el cuerpo de la petición
  let body = '';
  req.on('data', chunk => {
    body += chunk.toString();
  });

  req.on('end', () => {
    if (body) {
      console.log('Request body:', body);
    }

    // Responder según la URL y método
    if (url === '/health' && method === 'GET') {
      successResponse(req, res, { status: 'ok' });
    } 
    else if (url === '/api/messages/send-message' && method === 'POST') {
      console.log('Mensaje recibido para enviar por WhatsApp:', body);
      successResponse(req, res, { 
        message_id: "msg_" + Date.now(),
        status: "sent",
        timestamp: new Date().toISOString()
      });
    }
    else if (url === '/api/v1/conversation' && method === 'POST') {
      console.log('Mensaje recibido para procesamiento IA:', body);
      successResponse(req, res, {
        text: "¡Gracias por tu mensaje! Soy el servidor simulado de IA.",
        session_id: JSON.parse(body).session_id || "session-unknown",
        metadata: {
          intent: "conversacion_general",
          source: "ai_assistant_mock"
        }
      });
    }
    else {
      console.log('Petición no reconocida:', url, method);
      successResponse(req, res, { message: 'Endpoint de prueba' });
    }
  });
});

// Puerto en el que escuchará el servidor (ajustar para simular diferentes servicios)
const PORT = process.argv[2] || 8089;
server.listen(PORT, () => {
  console.log(`Servidor de prueba ejecutándose en el puerto ${PORT}`);
  console.log('Para probar: curl http://localhost:' + PORT + '/health');
});

// Manejar la terminación del servidor
process.on('SIGINT', () => {
  console.log('Cerrando servidor...');
  server.close(() => {
    console.log('Servidor cerrado');
    process.exit(0);
  });
});