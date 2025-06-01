local socket = require("socket")

print("📱 Cliente Socket Simples")
print("=========================")

-- Cria o cliente
local client = socket.tcp()

-- Conecta ao servidor
print("🔗 Conectando ao servidor...")
local result, err = client:connect("172.26.16.1", 8888)

if not result then
    print("❌ Erro ao conectar:", err)
    client:close()
    return
end

print("✅ Conectado ao servidor!")

-- Envia mensagem
local message = "Olá servidor! Teste de socket funcionando 👋"
print("📤 Enviando:", message)
client:send(message .. "\n")

-- Recebe resposta
local response = client:receive()
if response then
    print("📥 Resposta recebida:", response)
else
    print("❌ Nenhuma resposta recebida")
end

client:close()
print("🔌 Desconectado do servidor") 