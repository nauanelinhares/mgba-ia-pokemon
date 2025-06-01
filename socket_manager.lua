-- Módulo para gerenciamento de sockets no mGBA
-- Responsável por criar servidor, aceitar conexões e enviar dados

local SocketManager = {}

-- Configurações do Socket
local SOCKET_HOST = "127.0.0.1"
local SOCKET_PORT = 12345

-- Variáveis do módulo
local socket_server = nil
local connected_clients = {}

-- Função para serializar tabela em JSON simples
local function tableToJson(data)
    if type(data) ~= "table" then
        if type(data) == "string" then
            return '"' .. data .. '"'
        else
            return tostring(data)
        end
    end
    
    local json_parts = {}
    table.insert(json_parts, "{")
    
    local first = true
    for key, value in pairs(data) do
        if not first then
            table.insert(json_parts, ",")
        end
        first = false
        
        -- Chave
        if type(key) == "string" then
            table.insert(json_parts, '"' .. key .. '":')
        else
            table.insert(json_parts, '"' .. tostring(key) .. '":')
        end
        
        -- Valor
        if type(value) == "table" then
            table.insert(json_parts, tableToJson(value))
        elseif type(value) == "string" then
            table.insert(json_parts, '"' .. value .. '"')
        elseif value == nil then
            table.insert(json_parts, "null")
        else
            table.insert(json_parts, tostring(value))
        end
    end
    
    table.insert(json_parts, "}")
    return table.concat(json_parts)
end

-- Função para inicializar o servidor socket
function SocketManager.initialize()
    if not socket then
        console:warn("Biblioteca socket não disponível. Funcionalidade de rede desabilitada.")
        return false
    end
    
    socket_server = socket.bind(SOCKET_HOST, SOCKET_PORT)
    if not socket_server then
        console:error("Erro ao criar servidor socket")
        return false
    end
    
    local success, err = socket_server:listen(5)
    if success ~= 0 then
        console:error("Erro ao fazer listen do socket: " .. (socket.ERRORS[err] or "desconhecido"))
        return false
    end
    
    console:log("Servidor socket iniciado em " .. SOCKET_HOST .. ":" .. SOCKET_PORT)
    return true
end

-- Função para aceitar novas conexões
function SocketManager.acceptNewConnections()
    if not socket_server then return end
    
    local client, err = socket_server:accept()
    if client then
        table.insert(connected_clients, client)
        console:log("Novo cliente conectado! Total de clientes: " .. #connected_clients)
    elseif err and err ~= 1 then -- 1 = AGAIN (sem conexões pendentes)
        console:warn("Erro ao aceitar conexão: " .. (socket.ERRORS[err] or "desconhecido"))
    end
end

-- Função para enviar dados via socket para todos os clientes
function SocketManager.sendDataToClients(data)
    if #connected_clients == 0 then return end
    
    local json_data = tableToJson(data)
    if not json_data then
        console:error("Erro ao converter dados para JSON")
        return
    end
    
    local clients_to_remove = {}
    
    for i, client in ipairs(connected_clients) do
        local bytes_sent, err = client:send(json_data .. "\n")
        if not bytes_sent then
            console:warn("Cliente desconectado: " .. (socket.ERRORS[err] or "erro desconhecido"))
            table.insert(clients_to_remove, i)
        end
    end
    
    -- Remove clientes desconectados
    for i = #clients_to_remove, 1, -1 do
        table.remove(connected_clients, clients_to_remove[i])
    end
end

-- Função para obter número de clientes conectados
function SocketManager.getConnectedClientsCount()
    return #connected_clients
end

-- Função para verificar se o servidor está ativo
function SocketManager.isServerActive()
    return socket_server ~= nil
end

-- Função de limpeza
function SocketManager.shutdown()
    console:log("Fechando servidor socket...")
    
    for _, client in ipairs(connected_clients) do
        if client then
            client:send("DISCONNECT\n")
        end
    end
    
    connected_clients = {}
    socket_server = nil
    console:log("Servidor socket encerrado")
end

return SocketManager 