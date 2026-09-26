class_name FormaBosses
extends RefCounted

enum Kind { VOID, DRAGON, NECROMANCER, HYDRA, PHOENIX, GOLEM, KRAKEN, BASILISK, UNICORN, DJINN }

const DATA = [
	{"name": "O Vazio", "title": "DEVORADOR DE ESTRELAS", "color": FormaPalette.MAGE, "hp": 620.0, "speed": 72.0, "rate": 2.5, "skill_rate": 7.0, "attack": "Órbitas de antimatéria", "skill": "Singularidade gravitacional", "boon": "Núcleo singular", "description": "Sua habilidade puxa rivais próximos\ne amplia a coleta em 140 px."},
	{"name": "Dragão Rubro", "title": "SENHOR DAS BRASAS", "color": FormaPalette.KNIGHT, "hp": 800.0, "speed": 88.0, "rate": 2.1, "skill_rate": 6.5, "attack": "Sopro de cinco chamas", "skill": "Trilha de fogo", "boon": "Sangue dracônico", "description": "Acertos incendeiam o alvo por 3 s:\n6 de dano por segundo."},
	{"name": "Necromante", "title": "ARQUITETO DAS ALMAS", "color": FormaPalette.DRUID, "hp": 580.0, "speed": 75.0, "rate": 2.8, "skill_rate": 7.5, "attack": "Três almas perseguidoras", "skill": "Sepulturas espectrais", "boon": "Pacto de almas", "description": "Recupera vida igual a 12% do dano\ncausado a outros seres."},
	{"name": "Hidra Esmeralda", "title": "AS TRÊS FOMES", "color": FormaPalette.DRUID, "hp": 900.0, "speed": 64.0, "rate": 2.2, "skill_rate": 6.0, "attack": "Rajada de três cabeças", "skill": "Lagoas de veneno", "boon": "Eco tricéfalo", "description": "A cada terceiro ataque, dispara\ndois espinhos adicionais."},
	{"name": "Fênix Solar", "title": "A CHAMA RENASCIDA", "color": FormaPalette.GOLD, "hp": 520.0, "speed": 110.0, "rate": 2.0, "skill_rate": 7.0, "attack": "Espiral de doze plumas", "skill": "Eclipse de cinzas e renascimento", "boon": "Cinza imortal", "description": "Impede um golpe fatal: restaura\n25% da vida. Recarga de 60 s."},
	{"name": "Golem Obsidiano", "title": "O CORAÇÃO DA MONTANHA", "color": FormaPalette.MUTED, "hp": 1100.0, "speed": 48.0, "rate": 3.0, "skill_rate": 8.0, "attack": "Punho sísmico", "skill": "Fraturas em cruz e couraça", "boon": "Pele de obsidiana", "description": "Reduz todo dano recebido em 22%.\nVale também para dano contínuo."},
	{"name": "Kraken Abissal", "title": "TERROR DAS PROFUNDEZAS", "color": FormaPalette.ARCHER, "hp": 850.0, "speed": 62.0, "rate": 2.8, "skill_rate": 7.0, "attack": "Tentáculos em leque", "skill": "Maré de tinta", "boon": "Toque abissal", "description": "Acertos desaceleram rivais\npor 1,5 s."},
	{"name": "Basilisco", "title": "O OLHAR DE JADE", "color": FormaPalette.DRUID, "hp": 690.0, "speed": 85.0, "rate": 2.5, "skill_rate": 6.0, "attack": "Presas venenosas", "skill": "Olhar petrificante", "boon": "Olhar de jade", "description": "Cada quarto acerto paralisa\no alvo por 0,7 s."},
	{"name": "Unicórnio Astral", "title": "ORÁCULO DO CREPÚSCULO", "color": FormaPalette.PALADIN, "hp": 650.0, "speed": 120.0, "rate": 2.6, "skill_rate": 6.5, "attack": "Lança de luz", "skill": "Constelação de estrelas", "boon": "Graça astral", "description": "Sua habilidade cura 8% da vida\ne concede um escudo por 1,2 s."},
	{"name": "Djinn da Tempestade", "title": "O VENTO SEM NOME", "color": FormaPalette.ARCHER, "hp": 700.0, "speed": 105.0, "rate": 2.4, "skill_rate": 6.5, "attack": "Três raios marcados", "skill": "Translação e vendaval", "boon": "Ressonância da tormenta", "description": "Sua habilidade também dispara\noito relâmpagos ao redor."},
]
