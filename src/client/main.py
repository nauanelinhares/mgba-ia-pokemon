import socket
import json
import time
from datetime import datetime
from typing import Dict, List, Optional
import ollama
import os

from google import genai

client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))

class PokemonClient:
    def __init__(self, host='172.26.16.1', port=8888, llm_model='qwen3:1.7b', concise_mode=True):
        self.host = host
        self.port = port
        self.socket = None
        self.connected = False
        self.running = False
        self.llm_model = llm_model
        self.concise_mode = concise_mode
        self.pokemon_names = self.load_pokemon_names()
        self.type_names = self.load_type_names()
        self.last_analysis_time = 0
        self.analysis_cooldown = 3  # segundos entre análises
        
   
        
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
    
    def format_pokemon_data_for_ai(self, pokemon: Dict) -> str:
        """Formata dados do Pokémon para análise da IA"""
        name = self.get_pokemon_name(pokemon['species'])
        types = self.format_types(pokemon.get('type1', 0), pokemon.get('type2', 0))
        hp_percent = (pokemon['hp_current'] / pokemon['hp_max']) * 100 if pokemon['hp_max'] > 0 else 0
        
        status = "💀" if hp_percent <= 0 else "🔴" if hp_percent < 25 else "🟡" if hp_percent < 60 else "🟢"
        
        return f"{name} ({types}) Lv.{pokemon['level']} - {hp_percent:.0f}%HP {status}"
    
    def should_analyze(self) -> bool:
        """Verifica se deve fazer análise (cooldown)"""
        current_time = time.time()
        if current_time - self.last_analysis_time >= self.analysis_cooldown:
            self.last_analysis_time = current_time
            return True
        return False
    
    def analyze_team_with_ai(self, team_data: Dict):
        """Analisa dados do time usando Ollama"""
        
        # Aplicar cooldown para evitar spam
        if not self.should_analyze():
            return
            
        timestamp = datetime.fromtimestamp(team_data['timestamp']).strftime("%H:%M:%S")
        
        # Contar Pokemon ativos
        player_data = team_data.get('player', {})
        enemy_data = team_data.get('enemy', {})
        player_count = player_data.get('pokemon_count', 0)
        enemy_count = enemy_data.get('pokemon_count', 0)
        
        # Pular análise se não há dados suficientes
        if player_count == 0:
            print(f"⏸️  {timestamp} - Aguardando dados do time...")
            return
        
        # Preparar dados de forma mais compacta
        player_pokemon = []
        for slot in range(1, 7):
            pokemon = player_data.get('team', {}).get(str(slot))
            if pokemon:
                player_pokemon.append(self.format_pokemon_data_for_ai(pokemon))
        
        enemy_pokemon = []
        for slot in range(1, 7):
            pokemon = enemy_data.get('team', {}).get(str(slot))
            if pokemon:
                enemy_pokemon.append(self.format_pokemon_data_for_ai(pokemon))
        
        # Prompt mais direto e conciso
        if self.concise_mode:
            analysis_prompt = f"""Analise rapidamente esta situação Pokemon:

JOGADOR: {' | '.join(player_pokemon) if player_pokemon else 'Nenhum'}
INIMIGO: {' | '.join(enemy_pokemon) if enemy_pokemon else 'Nenhum'}

Responda em 2-3 linhas máximo:
- Situação crítica? (HP baixo)
- Recomendação principal
- Vantagem de tipos (se relevante)

Seja direto e use emojis."""
        else:
            analysis_prompt = f"""Você é um especialista Pokemon. Analise:

🔵 JOGADOR: {' | '.join(player_pokemon)}
🔴 INIMIGO: {' | '.join(enemy_pokemon) if enemy_pokemon else 'Não detectado'}

Forneça:
1. Status geral das equipes
2. Pokemon em situação crítica (HP baixo)
3. Vantagens/desvantagens de tipos
4. Recomendação estratégica

Escreva em português brasileiro. Seja conciso e use emojis."""

        try:
            print(f"\n🤖 {timestamp} | 👤{player_count} vs 🔥{enemy_count}")
            print("─" * 60)
            
            # Usar stream mais eficiente
            # response_content = ""
            # for chunk in ollama.generate(
            #     model=self.llm_model,
            #     prompt=analysis_prompt,
            #     stream=True
            # ):
            #     if chunk.get('response'):
            #         chunk_text = chunk['response']
            #         print(chunk_text, end='', flush=True)
            #         response_content += chunk_text
            
            # print("\n" + "─" * 60)
            
            response = client.models.generate_content(
                model=self.llm_model,
                contents=analysis_prompt,
            )
            print(response.text)
                
        except Exception as e:
            print(f"❌ Erro na análise IA: {e}")
            # Fallback mais simples
            self.display_team_simple(team_data)
    
    def display_team_simple(self, team_data: Dict):
        """Exibição simples como fallback"""
        timestamp = datetime.fromtimestamp(team_data['timestamp']).strftime("%H:%M:%S")
        
        player_data = team_data.get('player', {})
        player_count = player_data.get('pokemon_count', 0)
        
        print(f"\n📊 {timestamp} | Pokémon: {player_count}")
        
        if player_count > 0:
            for slot in range(1, 7):
                pokemon = player_data.get('team', {}).get(str(slot))
                if pokemon:
                    name = self.get_pokemon_name(pokemon['species'])
                    hp_percent = (pokemon['hp_current'] / pokemon['hp_max']) * 100 if pokemon['hp_max'] > 0 else 0
                    status = "🔴" if hp_percent < 25 else "🟡" if hp_percent < 60 else "🟢"
                    print(f"  {slot}. {name} Lv.{pokemon['level']} - {hp_percent:.0f}% {status}")
    
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
                            # Usar análise IA ao invés de display tradicional
                            self.analyze_team_with_ai(team_data)
                        except json.JSONDecodeError as e:
                            print(f"❌ Erro JSON: {e}")
                            
            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    print(f"❌ Erro ao receber dados: {e}")
                break
    
    def start_monitoring(self):
        """Inicia o monitoramento dos dados do Pokémon"""
        mode_text = "CONCISO" if self.concise_mode else "DETALHADO"
        print(f"\n🎮 Cliente Pokemon mGBA com IA ({mode_text})")
        
        if not self.connect():
            print("❌ Não foi possível estabelecer conexão")
            return
        
        self.running = True
        self.socket.settimeout(1.0)
        
        print(f"\n📡 Monitoramento ativo! Modelo: {self.llm_model}")
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
    print("🚀 Cliente Pokemon mGBA com IA")
    print("   Conectando ao emulador e inicializando Ollama...")
    
    # Opções de configuração
    client = PokemonClient(
        host=host, 
        port=port, 
        llm_model='gemini-2.5-flash-preview-05-20',  # Modelo mais rápido e leve
        concise_mode=True  # Respostas mais diretas
    )
    
    
    try:
        client.start_monitoring()
    except Exception as e:
        print(f"❌ Erro crítico: {e}")
    
    print("👋 Programa encerrado")

if __name__ == "__main__":
    main(host='172.26.16.1', port=8888) 