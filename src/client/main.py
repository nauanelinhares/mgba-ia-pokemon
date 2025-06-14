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
        self.type_names = self.load_type_names()
        
    def load_pokemon_names(self) -> Dict[int, str]:
        """Load Pokemon names from JSON file"""
        try:
            with open('data/game/pokemon_unbound/pokemon_data.json', 'r') as f:
                data = json.load(f)
                return {int(k): v for k, v in data.items()}
        except FileNotFoundError:
            print("⚠️  File pokemon_unbound_data.json not found")
            print("   Pokemon will be displayed with numeric ID only")
            return {}
    
    def load_type_names(self) -> Dict[int, str]:
        """Load Pokemon type names from JSON file"""
        try:
            with open('data/game/types.json', 'r') as f:
                data = json.load(f)
                return {int(k): v for k, v in data.items()}
        except FileNotFoundError:
            print("⚠️  File types.json not found")
            print("   Types will be displayed with numeric ID only")
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
    
    def get_type_name(self, type_id: int) -> str:
        """Retorna o nome do tipo ou o ID se não encontrado"""
        return self.type_names.get(type_id, f"Type #{type_id}")
    
    def format_types(self, type1: int, type2: int) -> str:
        """Formata os tipos do Pokémon"""
        type1_name = self.get_type_name(type1)
        if type2 != type1 and type2 != 0:
            type2_name = self.get_type_name(type2)
            return f"{type1_name}/{type2_name}"
        return type1_name
    
    def format_pokemon_data(self, pokemon: Dict) -> str:
        """Formata dados do Pokémon para exibição"""
        name = self.get_pokemon_name(pokemon['species'])
        types = self.format_types(pokemon.get('type1', 0), pokemon.get('type2', 0))
        hp_percent = (pokemon['hp_current'] / pokemon['hp_max']) * 100 if pokemon['hp_max'] > 0 else 0
        
        hp_bar = self.create_hp_bar(hp_percent)
        
        return (f"📍 Slot {pokemon['slot']}: {name} ({types}) | "
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
        
        print(f"\n{'='*80}")
        print(f"🕒 {timestamp} | Frame: {team_data['frame']}")
        print(f"{'='*80}")
        
        # Display player team
        player_data = team_data.get('player', {})
        player_count = player_data.get('pokemon_count', 0)
        
        print(f"👤 PLAYER TEAM - Pokémon: {player_count}")
        print("-" * 40)
        
        if player_count == 0:
            print("⚠️  Nenhum Pokémon detectado no time do jogador")
        else:
            for slot in range(1, 7):
                pokemon = player_data.get('team', {}).get(str(slot))
                if pokemon:
                    print(self.format_pokemon_data(pokemon))
                else:
                    print(f"📍 Slot {slot}: [VAZIO]")
        
        # Display enemy team
        enemy_data = team_data.get('enemy', {})
        enemy_count = enemy_data.get('pokemon_count', 0)
        
        print(f"\n🔥 ENEMY TEAM - Pokémon: {enemy_count}")
        print("-" * 40)
        
        if enemy_count == 0:
            print("⚠️  Nenhum Pokémon detectado no time inimigo")
        else:
            for slot in range(1, 7):
                pokemon = enemy_data.get('team', {}).get(str(slot))
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