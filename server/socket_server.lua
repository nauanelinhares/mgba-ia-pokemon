-- Módulo de servidor socket para comunicação com clientes externos
local socket_server = {}

-- Variáveis do módulo
local server = nil
socket_server.socketList = {}
local nextID = 1
local port = 8888

-- Função para inicializar servidor socket
function socket_server.InitializeServer()
    while not server do
        server, error = socket.bind(nil, port)
        if error then
            if error == socket.ERRORS.ADDRESS_IN_USE then
                port = port + 1
            else
                console:error("❌ Erro ao Bind servidor:", error)
                break
            end
        else
            local ok
            ok, error = server:listen()
            if error then
                server:close()
                console:error("❌ Erro ao iniciar servidor:", error)
            else
                console:log("✅ Servidor socket inicializado na porta " .. port)
                server:add("received", socket_server.SocketAccept)
            end
        end
    end
    return server ~= nil
end

-- Função para aceitar novas conexões
function socket_server.SocketAccept()
    console:log("✅ Aceitando conexão...")
    local sock, error = server:accept()
    if error then
        console:error("❌ Erro ao aceitar conexão:", error)
        return
    end
    local id = nextID
    nextID = id + 1
    table.insert(socket_server.socketList, sock)
    console:log("✅ Conexão estabelecida com o cliente " .. id)
end

-- Retorna o módulo
return socket_server