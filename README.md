# 🎮 mGBA Pokemon Team Monitor with AI

> Real-time Pokemon team monitoring for mGBA emulator with intelligent analysis via Ollama

Monitor your Pokemon team in real-time while playing GBA Pokemon games, with AI-powered battle analysis and strategic recommendations.

## ✨ Features

- **Real-time team monitoring** - HP, levels, and team changes
- **AI analysis** - Smart battle recommendations via Ollama
- **Visual display** - Color-coded HP bars and status indicators
- **Socket communication** - Data available for external apps

## 🚀 Quick Setup

### Prerequisites
- mGBA emulator (v0.10+)
- Python 3.8+
- Ollama installed locally

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Setup Ollama
```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Download a model (recommended)
ollama pull qwen2.5:1.5b

# Start Ollama service
ollama serve
```

### 3. Run mGBA Script
1. Open mGBA emulator
2. Load your Pokemon ROM
3. Go to `Tools > Scripting...`
4. Load `server_mgba.lua`

### 4. Start Client
```bash
python run.py
```

## 🎯 Usage

The client will automatically connect and display:
- Real-time Pokemon data with HP bars
- AI analysis of battle situations
- Strategic recommendations
- Critical health alerts

### Example Output
```
🤖 14:30:25 | 👤3 vs 🔥1
────────────────────────────────────────────────────────────
🚨 CRÍTICO: Venusaur (15% HP) precisa de cura urgente!
💡 Recomendação: Substitua por Charizard - vantagem contra tipos Grama
⚡ Situação: 2 Pokemon saudáveis, 1 em risco
────────────────────────────────────────────────────────────
```

## ⚙️ Configuration

### Memory Addresses (Pokemon Unbound)
- Base Address: `0x02024284`
- Pokemon Size: `100 bytes`

### Network Settings
- Host: `172.26.16.1`
- Port: `8888`

### AI Models
- Default: `qwen2.5:1.5b` (fast)
- Available: `llama3.2:1b`, `gemma2:2b`, `llama3.2:3b`

## 🔧 Troubleshooting

**Connection Issues:**
- Check if mGBA script is running
- Verify IP/port settings

**Ollama Issues:**
- Ensure Ollama is installed: `ollama --version`
- Check model is downloaded: `ollama list`
- Start service: `ollama serve`

**No Pokemon Detected:**
- Make sure you're in-game (not menus)
- Verify ROM compatibility

## 📁 Project Structure

```
mcp-gba-pokemon/
├── server_mgba.lua         # mGBA script
├── src/client/main.py      # Python client with AI
├── data/game/             # Pokemon data files
```

## 🤝 Contributing

Contributions welcome! This project is great for learning:
- Memory manipulation
- Socket programming
- AI integration
- Game reverse engineering

---

**TL;DR**: Monitor Pokemon teams in real-time with AI analysis. Install Ollama, run mGBA script, start Python client. Get smart battle recommendations automatically! 🎮🤖 