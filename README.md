# 🎮 mGBA Pokemon Team Monitor

> **Real-time Pokemon team monitoring system for mGBA emulator**

A comprehensive monitoring tool that reads Pokemon team data directly from Game Boy Advance Pokemon games running in mGBA emulator, providing real-time team status via socket communication.

## 🔍 What This Project Does

This project creates a **bridge between the mGBA emulator and external applications**, allowing you to:

- **Monitor your Pokemon team in real-time** while playing
- **Track HP changes, level ups, and team modifications** as they happen
- **Access Pokemon data via network socket** for external applications
- **Display beautiful team status** with visual HP bars and Pokemon names

### 🧠 How It Works (Educational Overview)

The system works by directly **reading memory addresses** from the Pokemon game while it runs:

1. **Memory Reading**: The Lua script accesses specific memory locations where Pokemon data is stored
2. **Data Processing**: Raw bytes are converted into meaningful Pokemon information (species, level, HP, etc.)
3. **Socket Server**: A TCP server broadcasts this data to connected clients
4. **Client Display**: Python client receives and displays the data with nice formatting

This is essentially **reverse engineering** - we figured out where the game stores Pokemon data in memory!

## 📁 Project Structure

```
mcp-gba-pokemon/
├── server_mgba.lua          # Main mGBA script - the "brain" of the system
├── read_pokemon_data.lua    # Memory reading functions - the "decoder"
├── socket_server.lua        # Network communication - the "broadcaster"
├── pokemon_client.py        # Python client - the "display"
├── test_client.lua          # Simple test client for debugging
├── pokemon_unbound_data.json # Pokemon names database
└── README.md               # This file
```

## 🚀 Quick Start

### Prerequisites

- **mGBA emulator** (v0.10+) with scripting support
- **Python 3.7+** for the client
- A **Pokemon GBA ROM** (Pokemon Unbound recommended)

### Step 1: Start the mGBA Server

1. Open mGBA emulator
2. Load your Pokemon ROM
3. Go to `Tools > Scripting...`
4. Load `server_mgba.lua`
5. The script will start monitoring on port `8888`

### Step 2: Run the Python Client

```bash
python pokemon_client.py
```

The client will automatically connect and start displaying your team status!

## 🔧 Configuration

### Memory Addresses
The script is currently configured for Pokemon Unbound:
- **Base Address**: `0x02024284` (first Pokemon in team)
- **Pokemon Size**: `100 bytes` per Pokemon
- **Max Team Size**: `6 Pokemon`

### Network Settings
- **Host**: `172.26.16.1` (adjust for your network)
- **Port**: `8888`

## 📊 Features

### Real-time Monitoring
- ✅ **Species identification** with name lookup
- ✅ **Level tracking** with level-up detection
- ✅ **HP monitoring** with visual bars
- ✅ **Team changes** detection (add/remove Pokemon)

### Visual Display
- 🟢 **Green HP bar** (>60% HP)
- 🟡 **Yellow HP bar** (25-60% HP)  
- 🔴 **Red HP bar** (<25% HP)
- 📍 **Slot indicators** (1-6)
- 🕒 **Timestamps** for each update

### Example Output
```
============================================================
🕒 14:30:25 | Frame: 12450 | Pokemon in team: 3
============================================================
📍 Slot 1: Charizard | Lv.45 | HP: 156/156 [██████████] 100.0% 🟢
📍 Slot 2: Blastoise | Lv.43 | HP: 98/145 [██████░░░░] 67.6% 🟡
📍 Slot 3: Venusaur | Lv.44 | HP: 23/152 [██░░░░░░░░] 15.1% 🔴
📍 Slot 4: [EMPTY]
📍 Slot 5: [EMPTY]
📍 Slot 6: [EMPTY]
```

## 🎯 Use Cases

### For Players
- **Monitor team health** during battles
- **Track experience gains** and level progress
- **Team management** assistance

### For Developers
- **Game data extraction** for research
- **Bot development** foundation
- **Statistics collection** for analysis

### For Educators
- **Reverse engineering** demonstration
- **Memory manipulation** concepts
- **Network programming** examples

## 🔧 Technical Details

### Memory Structure (Pokemon Data)
Each Pokemon occupies 100 bytes in memory:
- **Species ID**: Identifies which Pokemon it is
- **Level**: Current experience level
- **Current HP**: Health points remaining
- **Max HP**: Maximum health points
- Plus many other stats not currently used

### Socket Protocol
The server sends **JSON data** over TCP:
```json
{
  "timestamp": 1703123425,
  "frame": 12450,
  "pokemon_count": 3,
  "team": {
    "1": {
      "slot": 1,
      "species": 6,
      "level": 45,
      "hp_current": 156,
      "hp_max": 156
    }
  }
}
```

## 🔄 Extending the Project

### Adding New Pokemon Games
1. Find the **base memory address** for Pokemon data
2. Update `BASE_ADDRESS` in `server_mgba.lua`
3. Test with known Pokemon to verify

### Adding More Pokemon Data
The memory contains much more information:
- **Stats** (Attack, Defense, etc.)
- **Moves** (4 learned moves)
- **Items** (held items)
- **Status conditions** (poison, sleep, etc.)

### Creating New Clients
Any language can connect to the socket server:
- **JavaScript** for web interfaces
- **C++** for high-performance applications  
- **Mobile apps** for phone notifications

## 🐛 Troubleshooting

### Connection Issues
- Verify mGBA script is loaded and running
- Check firewall settings
- Confirm correct IP address and port

### No Pokemon Detected
- Ensure you're in-game (not in menus)
- Verify correct ROM compatibility
- Check if Pokemon are actually in your team

### Performance Issues
- Reduce `UPDATE_FREQUENCY` in the script
- Close unnecessary applications
- Use a faster computer/emulator settings

## 🤝 Contributing

This project is perfect for learning! Consider adding:
- Support for more Pokemon games
- Additional Pokemon data fields
- Web-based client interface
- Mobile app integration
- Battle analysis features

## 📚 Learning Resources

### Understanding the Code
- **Lua scripting**: Learn mGBA's API documentation
- **Memory management**: Study how games store data
- **Socket programming**: Understand TCP/IP basics
- **JSON parsing**: Learn data serialization

### Reverse Engineering
- **Cheat Engine**: Tool for finding memory addresses
- **Hex editors**: View raw binary data
- **Debuggers**: Step through game execution
- **Documentation**: Pokemon data structure guides

---

**TL;DR**: This is a real-time Pokemon team monitor that reads game memory from mGBA emulator and broadcasts the data to Python clients via TCP sockets. It shows Pokemon species, levels, HP with visual bars, and detects team changes. Perfect for learning reverse engineering, socket programming, and game data extraction. Just load the Lua script in mGBA and run the Python client to see your team status live! 