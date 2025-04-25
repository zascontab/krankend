-- functions.lua

-- Extrae el ID del usuario desde el token JWT en el encabezado Authorization
function extractUserID(authHeader)
    if authHeader == nil or authHeader == "" then
      return ""
    end
  
    -- Asume que el encabezado es "Bearer <token>"
    local token = string.match(authHeader, "Bearer%s+(.+)")
    if token == nil then
      return ""
    end
  
    -- Divide el JWT en header, payload, signature
    local _, payload_b64 = string.match(token, "([^%.]+)%.([^%.]+)%.([^%.]+)")
    if payload_b64 == nil then
      return ""
    end
  
    -- Decodifica el payload (base64)
    local payload = base64.decode(payload_b64)
    if payload == nil then
      return ""
    end
  
    -- Parsea el JSON del payload
    local payload_json = json.decode(payload)
    if payload_json == nil then
      return ""
    end
  
    -- Extrae el campo 'sub' (o el campo que contenga el user ID en tu JWT)
    return payload_json.sub or ""
  end
  
  -- Extrae el número de teléfono desde el campo sender
  function extractPhone(whatsappId)
    if whatsappId == nil then
      return ""
    end
  
    -- Extraer el número de teléfono de formato "123456789@s.whatsapp.net"
    local phone = string.match(whatsappId, "(%d+)@")
    if phone then
      -- Agregar el "+" delante del número
      return "+" .. phone
    else
      -- Si no coincide con el patrón, devolver el original
      return whatsappId
    end
  end
  
  -- Procesa el texto de respuesta (escapa comillas para JSON)
  function js(text)
    if text == nil then
      return ""
    end
  
    -- Escapar las comillas para evitar problemas con el JSON
    local escaped = string.gsub(text, '"', '\\"')
    return escaped
  end