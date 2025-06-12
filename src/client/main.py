import socket
import json
import time
import threading
from datetime import datetime
from typing import Dict, List, Optional

class PokemonClient:
    def __init__(self, host='172.26.16.1', port=8888):
        self.host = host
        self.port = port
        self.socket = None
        self.connected = False
        self.running = False
        self.pokemon_names = self.load_pokemon_names()
        
    def load_pokemon_names(self) -> Dict[int, str]:
        """Load Pokemon names from JSON file"""
        try:
            with open('data/game/pokemon_firered/pokemon_data.json', 'r') as f:
                data = json.load(f)
                return {int(k): v for k, v in data.items()}
        except FileNotFoundError:
            print("⚠️  File pokemon_firered_data.json not found")
            print("   Pokemon will be displayed with numeric ID only")
            return {}
    
    def connect(self, retry_interval: float = 2.0, max_retries: int = None) -> bool:
        """Connect to mGBA server with automatic retry attempts"""
        attempt = 0
        
        while max_retries is None or attempt < max_retries:
            try:
                self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                self.socket.connect((self.host, self.port))
                self.connected = True
                print(f"✅ Connected to mGBA server at {self.host}:{self.port}")
                return True
                
            except ConnectionRefusedError:
                attempt += 1
                if attempt == 1:
                    print(f"🔄 Trying to connect to server {self.host}:{self.port}...")
                    print("   Waiting for mGBA server to become available...")
                
                print(f"   Attempt {attempt}... (Ctrl+C to cancel)")
                
                try:
                    time.sleep(retry_interval)
                except KeyboardInterrupt:
                    print("\n⏹️  Connection cancelled by user")
                    return False
                    
            except Exception as e:
                print(f"❌ Error connecting: {e}")
                return False
                
        print(f"❌ Failed after {max_retries} attempts")
        return False
    
    def disconnect(self):
        """Desconecta do servidor"""
        self.running = False
        self.connected = False
        if self.socket:
            self.socket.close()
        print("🔌 Desconectado do servidor")
    
    def get_pokemon_name(self, species_id: int) -> str:
        """Retorna o nome do Pokémon ou o ID se não encontrado"""
        return self.pokemon_names.get(species_id, f"Pokémon #{species_id}")
    
    def format_pokemon_data(self, pokemon: Dict) -> str:
        """Formata dados do Pokémon para exibição"""
        name = self.get_pokemon_name(pokemon['species'])
        hp_percent = (pokemon['hp_current'] / pokemon['hp_max']) * 100 if pokemon['hp_max'] > 0 else 0
        
        hp_bar = self.create_hp_bar(hp_percent)
        
        return (f"📍 Slot {pokemon['slot']}: {name} | "
               f"Lv.{pokemon['level']} | "
               f"HP: {pokemon['hp_current']}/{pokemon['hp_max']} {hp_bar}")
    
    def create_hp_bar(self, hp_percent: float) -> str:
        """Cria uma barra visual de HP"""
        bar_length = 10
        filled = int((hp_percent / 100) * bar_length)
        empty = bar_length - filled
        
        if hp_percent > 60:
            color = "🟢"
        elif hp_percent > 25:
            color = "🟡"
        else:
            color = "🔴"
            
        return f"[{'█' * filled}{'░' * empty}] {hp_percent:.1f}% {color}"
    
    def display_team(self, team_data: Dict):
        """Exibe dados do time de forma organizada"""
        timestamp = datetime.fromtimestamp(team_data['timestamp']).strftime("%H:%M:%S")
        
        print(f"\n{'='*60}")
        print(f"🕒 {timestamp} | Frame: {team_data['frame']} | Pokémon no time: {team_data['pokemon_count']}")
        print(f"{'='*60}")
        
        if team_data['pokemon_count'] == 0:
            print("⚠️  Nenhum Pokémon detectado no time")
            return
        
        for slot in range(1, 7):
            pokemon = team_data['team'].get(str(slot))
            if pokemon:
                print(self.format_pokemon_data(pokemon))
            else:
                print(f"📍 Slot {slot}: [VAZIO]")
    
    def listen_for_data(self):
        """Loop principal para receber dados do servidor"""
        buffer = ""
        
        while self.running and self.connected:
            try:
                data = self.socket.recv(1024).decode('utf-8')
                if not data:
                    print("🔌 Servidor encerrou a conexão")
                    break
                
                buffer += data
                
                while '\n' in buffer:
                    line, buffer = buffer.split('\n', 1)
                    if line.strip():
                        try:
                            team_data = json.loads(line)
                            self.display_team(team_data)
                        except json.JSONDecodeError as e:
                            print(f"❌ Erro ao decodificar JSON: {e}")
                            print(f"   Dados recebidos: {line[:100]}...")
                            
            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    print(f"❌ Erro ao receber dados: {e}")
                break
    
    def start_monitoring(self):
        """Inicia o monitoramento dos dados do Pokémon"""
        print("\n🎮 Iniciando cliente Pokemon mGBA...")
        
        if not self.connect():
            print("❌ Não foi possível estabelecer conexão")
            return
        
        self.running = True
        self.socket.settimeout(1.0)
        
        print("\n📡 Monitoramento ativo!")
        print("   Pressione Ctrl+C para parar\n")
        
        try:
            self.listen_for_data()
        except KeyboardInterrupt:
            print("\n⏹️  Monitoramento interrompido pelo usuário")
        except Exception as e:
            print(f"❌ Erro durante monitoramento: {e}")
        finally:
            self.disconnect()

def main(host, port):
    print("🚀 Cliente Pokemon mGBA")
    print("   Conectando ao emulador...")
    
    client = PokemonClient(host, port)
    
    try:
        client.start_monitoring()
    except Exception as e:
        print(f"❌ Erro crítico: {e}")
    
    print("👋 Programa encerrado")

if __name__ == "__main__":
    main(host='172.26.16.1', port=8888) 