class_name FormaClasses
extends RefCounted

const DATA = [
	{"name": "Mago", "role": "CONTROLE ARCANO", "shape": 3, "hp": 100.0, "growth": 9.0, "speed": 205.0, "damage": 23.0, "rate": 0.48, "range": 640.0, "cooldown": 8.0, "skill": "Supernova", "attack": "Orbe arcano", "description": "Concentre o caos.\nExploda tudo ao seu redor.", "detail": "Uma nova de 240 px causa 39 de dano e afasta rivais.", "stats": [5, 2, 3]},
	{"name": "Paladino", "role": "LUZ & PROTEÇÃO", "shape": 6, "hp": 155.0, "growth": 14.0, "speed": 188.0, "damage": 24.0, "rate": 0.65, "range": 130.0, "cooldown": 12.0, "skill": "Santuário", "attack": "Martelo de luz", "description": "Seja a última luz.\nResista, cure e conquiste.", "detail": "Recupera 35% da vida e bloqueia dano por 2,5 segundos.", "stats": [3, 5, 2]},
	{"name": "Cavaleiro", "role": "FORÇA & IMPACTO", "shape": 4, "hp": 140.0, "growth": 13.0, "speed": 210.0, "damage": 31.0, "rate": 0.5, "range": 140.0, "cooldown": 7.0, "skill": "Investida", "attack": "Corte de aço", "description": "Abra seu caminho.\nTransforme impulso em força.", "detail": "Avança na direção da mira e causa 35 de dano no trajeto.", "stats": [4, 4, 3]},
	{"name": "Arqueiro", "role": "PRECISÃO & AGILIDADE", "shape": 3, "hp": 90.0, "growth": 9.0, "speed": 207.0, "damage": 15.0, "rate": 0.32, "range": 760.0, "cooldown": 7.0, "skill": "Chuva de flechas", "attack": "Flecha de cristal", "description": "Encontre a distância.\nFaça cada disparo contar.", "detail": "Dispara um leque de 4 flechas; cada flecha causa 15 de dano.", "stats": [4, 2, 5]},
	{"name": "Druida", "role": "VIDA & NATUREZA", "shape": 5, "hp": 110.0, "growth": 11.0, "speed": 195.0, "damage": 17.0, "rate": 0.55, "range": 550.0, "cooldown": 11.0, "skill": "Raízes ancestrais", "attack": "Espinho vivo", "description": "Cultive seu poder.\nPrenda rivais. Renove a vida.", "detail": "Cria um bosque por 4 segundos que cura e causa dano aos rivais.", "stats": [3, 4, 3]},
]

static func get_data(index: int) -> Dictionary:
	return DATA[clampi(index, 0, 4)]
