-- functions.lua
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

function js(text)
    if text == nil then
        return ""
    end
    
    -- Escapar las comillas para evitar problemas con el JSON
    local escaped = string.gsub(text, '"', '\\"')
    
    return escaped
end