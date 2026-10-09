# FORMA — Reinos de Éter

RPG de arena **infinita**, multiplayer competitivo por padrão, com **até 10 participantes por sala**, em Godot. Jogável no macOS e no navegador com teclado e mouse. Colete essência, cresça, evolua sua classe e enfrente criaturas místicas desenhadas inteiramente com conjuntos de formas geométricas. Derrotar um chefe **não encerra a partida**: outro encontro será sorteado, e você continua enquanto sobreviver.

**Jogar no macOS:** abra `Jogar.command` com dois cliques. A cópia local inclui Godot 4.5 em `.tools/`. O cliente entra no servidor configurado; execute `Servidor.command` se ainda não houver servidor local ativo. Se uma versão anterior estiver aberta, feche essa janela e abra o iniciador novamente.

**Editar:** importe `project.godot` no Godot 4.3+ e pressione **F5**. A versão validada é **Godot 4.5 stable**, com renderizador Compatibility. Para exportar Web e executar servidor/cliente juntos, use essa mesma versão. O código-fonte também pode ser aberto no Godot para Windows e Linux; o iniciador incluído é específico do macOS.


## Jogar no navegador

No macOS, abra **`Jogar no Navegador.command`**. Ele inicia a página em **http://127.0.0.1:8787**, abre o navegador e inicia o gerenciador de salas WebSocket na porta **9080**. A pasta `web/` já contém a versão exportada; não é necessário instalar nada para quem acessa o jogo pelo navegador. O computador que inicia o servidor local precisa de Python 3 e Godot (já incluído em `.tools/` nesta cópia).

- Escolha a classe, escreva o **nome do personagem** no campo do menu e clique em **Jogar online** (ou Enter no campo). O jogo encontra uma sala automaticamente. Nome e endereço são salvos localmente.
- **Servidor / Ajustes** permite trocar o servidor. No mesmo computador, use `ws://127.0.0.1:9080`. Na primeira visita Web, o endereço usa o mesmo host da página.
- Para servir a página na rede local: `python3 tools/serve_web.py --multiplayer --bind 0.0.0.0`. Os outros computadores abrem `http://IP-DO-SERVIDOR:8787` e entram em `ws://IP-DO-SERVIDOR:9080`. Permita essas portas no firewall quando necessário.
- O cliente Web usa WebGL 2 e uma única thread, sem exigir cabeçalhos de isolamento. Sirva por HTTP/HTTPS; abrir `index.html` como arquivo não funciona. Os controles são teclado e mouse; não há controles de toque.
- Recordes e preferências ficam no armazenamento local de cada navegador. Não são sincronizados entre dispositivos.

Para gerar uma nova versão após editar o código:

```bash
./tools/export_web.sh
```

O script instala os templates oficiais do Godot 4.5 em `.tools/web-templates/` quando necessário. Em outro sistema operacional, informe o executável: `FORMA_GODOT=/caminho/para/godot ./tools/export_web.sh`.

## Multiplayer competitivo

- Salas automáticas de **10 participantes** por padrão, todos contra todos. Uma pessoa já pode jogar: as outras nove vagas são ocupadas por bots. Chefes são encontros adicionais e não ocupam vagas de participante.
- O servidor preenche uma sala existente antes de criar outra. O 11º humano entra em uma segunda sala. Cada sala tem seu próprio mundo, chefes, tempo e progressão. Clientes só recebem o estado da própria sala.
- Ao entrar um humano, um bot sai sem deixar saque. Ao sair um humano, um bot repõe a vaga. Morrer conserva a vaga humana para renascer. Salas extras vazias são encerradas; a sala base reinicia e aguarda.
- Nome no menu inicial; servidor, porta, limite de 2–10 vagas e dificuldade nas configurações de hospedagem. Bots são automáticos. As preferências são salvas. **As regras do anfitrião prevalecem sobre as do cliente.**
- No aplicativo nativo, “Criar sala neste computador” hospeda e joga. No navegador, entre em um servidor nativo/dedicado.
- O servidor controla movimento, dano, coleta, melhorias, dons e renascimento. Clientes enviam comandos; a arena é atualizada 20 vezes por segundo pela rede.
- Cada jogador recebe suas próprias escolhas de evolução. **Menus, bestiário e perda de foco não pausam a sala. Sua forma permanece vulnerável. Melhorias ficam num painel lateral e permitem continuar movendo, atacando, usando habilidade e esquivando.**
- Morrer mostra o resultado individual. “Jogar novamente” renasce na mesma sala, sem dons. Entradas tardias recebem até 250 de essência inicial para reduzir a desvantagem.
- O golpe final continua sendo o único dono do dom; não há herança de poderes. Sair remove o personagem e libera a vaga. Se o anfitrião fechar, os clientes retornam ao menu.
- As partidas online não alteram os recordes de solo. A distribuição automática funciona dentro do servidor escolhido. Não há migração de anfitrião ou recuperação da mesma vida após desconectar.

Servidor dedicado (sem janela):

```bash
./Servidor.command --port=9080 --players=10 --difficulty=1
# Windows/Linux com Godot 4.5:
godot --headless --path . -- --server --port=9080 --players=10 --difficulty=1
```

Dificuldade: `0` Normal, `1` Intenso (padrão), `2` Cataclismo. A ameaça cresce em todos os modos. O servidor dedicado aguarda jogadores antes de avançar a simulação e reinicia a arena quando o último jogador sai.

### Publicar na internet

Publique **todo o conteúdo de `web/`** em uma hospedagem estática HTTPS. O modo padrão exige também um processo Godot executando o gerenciador de salas em uma máquina acessível. A distribuição de salas acontece nesse processo.

Para clientes HTTPS, use **`wss://`** com certificado válido, por meio de um proxy TLS para a porta WebSocket. Exemplo de bloco `location` dentro de um servidor Nginx já configurado com HTTPS:

```nginx
location /ws {
    proxy_pass http://127.0.0.1:9080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600s;
}
```

Os jogadores usam `wss://SEU-DOMINIO/ws`. Uma página HTTPS não deve tentar conectar a `ws://`. A publicação em domínio público não é feita pelo iniciador local. Referência: [exportação Web do Godot](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html).

## Tela responsiva e nitidez

O jogo desenha diretamente na resolução física do canvas (`canvas_items`) e usa a densidade de pixels do navegador/monitor para manter o texto legível em telas Retina. Não estica mais uma imagem fixa de 1440×900: a arena preenche a janela e reposiciona a câmera e a mira após redimensionar.

O HUD se reorganiza em telas verticais, horizontais e ultrawide. Ele ocupa seis zonas fixas nas bordas e deixa o centro da arena livre. Abaixo de 1000 px de largura, o chefe e os avisos descem para cima da barra de habilidades. Abaixo de 1100 px, o ranking sai da tela. Telas estreitas usam seletor de uma classe por vez, e o painel de dons e melhorias vira um botão que abre o bestiário. Configurações, ajuda e detalhes do bestiário permitem rolagem em janelas pequenas. A entrada continua sendo teclado e mouse.

## Custo crescente de evolução

A essência adicional para sair do nível `n` é `35 + 22 × (n−1) + 7 × (n−1)²`. O aumento é quadrático: quanto maior o nível, maior o próximo custo e maior o crescimento desse custo.

| Passagem | Essência adicional |
| --- | ---: |
| 1 → 2 | 35 |
| 5 → 6 | 235 |
| 10 → 11 | 800 |
| 20 → 21 | 2.980 |

O HUD mostra quanto falta. Novos níveis preservam as opções já exibidas e acumulam escolhas; não é necessário parar de jogar para gastar uma melhoria.

## Desafio que acompanha a partida

O indicador **AMEAÇA** no HUD cresce com tempo de sobrevivência, essência acumulada, nível, multiplicador de dano e dons dos jogadores vivos. Não há o antigo teto de crescimento dos reforços. A subida é gradual, no máximo 0,035 ponto por segundo (+2,1 por minuto), para não criar um pico instantâneo após um saque grande.

- Novos rivais recebem massa, vida e dano proporcionais à ameaça e ao líder; continuam evoluindo com o próprio farm.
- Após 75 segundos, podem surgir **Elites** (até 35% dos reforços), identificados no nome, com mais resistência, perseguição mais ampla e escudo breve ao entrar.
- Chefes novos têm resistência e dano ajustados ao poder dos jogadores e ao número de humanos. Ataques ficam mais frequentes; áreas perigosas preservam o tempo de aviso.
- O intervalo entre chefes diminui conforme a ameaça cresce. Inimigos feridos não recuperam vida por causa do ajuste de dificuldade.
- Uma nova partida solo reinicia a ameaça. Crescer continua trazendo vantagens, mas não torna os próximos encontros inofensivos.

## A arena infinita

- Arena de 3.600 × 2.800 por sala, com bots nas vagas livres que coletam, perseguem, fogem, atacam e usam habilidades.
- Fragmentos atraídos pelo personagem aumentam massa e tamanho, reduzindo sua velocidade. O raio visual/físico para de crescer em 120 px, para que a progressão infinita não ultrapasse os limites do mapa; massa e níveis continuam crescendo.
- Abater um rival concede até 35% da massa dele, limitado a meio nível do vencedor (absorver: até 65%, limitado a um nível inteiro). Os fragmentos deixados valem no máximo 30 cada. Isso impede que reforços, que entram proporcionais ao líder, alimentem um crescimento exponencial.
- Absorção por proximidade ao centro: exige mais de 1,45× a massa de um rival abaixo de 45% da vida, ou mais de 2,2× a massa de um rival saudável. Escudos impedem absorção. Chefes não absorvem e não podem ser absorvidos.
- Subir de nível libera três melhorias no canto inferior direito, sem pausar a arena nem bloquear controles, tanto no solo quanto no multiplayer. Escolha com 1–3 ou clique; o painel pode ser recolhido e acumula escolhas pendentes.
- O primeiro chefe surge entre **90 e 150 segundos**, ou antes se você reunir **500 de essência**. Depois de cada derrota, outro surge após **35–65 segundos**. Há um chefe ativo por vez.
- Os dez chefes são sorteados **sem repetição dentro de cada ciclo**, inclusive sem repetir o último chefe na passagem entre ciclos. A ordem muda a cada ciclo e a cada partida.
- A cada encontro, a vida base do chefe aumenta 12% e seu dano base aumenta 4,5%. O diretor acrescenta escalas de ameaça, poder e quantidade de jogadores; a frequência de ataques cresce até um limite que preserva os avisos de esquiva.
- Ataques de área e feixes mostram contornos e contagem visual antes de causar dano. Formas menores podem escapar dos ataques com movimento ou esquiva.
- Não há tela de vitória nem limite de tempo. A morte encerra a vida atual e permite recomeçar com qualquer classe.
- Bestiário acessível com **B**, minimapa, ranking, recargas, efeitos sonoros, pausa ao perder foco no solo e recordes locais de solo. Há multiplayer por WebSocket, com servidor autoritativo. Não há salvamento da partida em andamento.

## Chefes e dons exclusivos

| Criatura | Ataques próprios | Dom recebido |
| --- | --- | --- |
| O Vazio | Órbitas de antimatéria e singularidade que puxa e desacelera | **Núcleo singular**: +140 px de coleta; usar habilidade puxa rivais próximos |
| Dragão Rubro | Sopro de cinco chamas e trilha persistente de fogo | **Sangue dracônico**: acertos incendeiam por 3 s, causando 6 de dano/s |
| Necromante | Três almas perseguidoras e sepulturas espectrais ao redor do alvo | **Pacto de almas**: recupera 12% do dano efetivamente causado |
| Hidra Esmeralda | Três cabeças disparam veneno; três lagoas envenenam a área | **Eco tricéfalo**: cada terceiro ataque dispara dois projéteis extras |
| Fênix Solar | Espiral de plumas, explosão de cinzas e um renascimento com 35% da vida | **Cinza imortal**: impede golpe fatal, restaura 25% da vida e protege por 2 s; recarga de 60 s |
| Golem Obsidiano | Punho sísmico, fraturas em cruz e couraça temporária | **Pele de obsidiana**: reduz todo dano recebido em 22% |
| Kraken Abissal | Tentáculos em leque e maré de tinta que desacelera | **Toque abissal**: acertos desaceleram por 1,5 s |
| Basilisco | Presas venenosas e dois feixes de petrificação | **Olhar de jade**: cada quarto acerto paralisa por 0,7 s (0,3 s em chefes) |
| Unicórnio Astral | Lança de luz e constelação de seis explosões | **Graça astral**: usar habilidade cura 8% da vida e concede escudo de 1,2 s |
| Djinn da Tempestade | Três raios antecipam o movimento; teleporte e vendaval radial | **Ressonância da tormenta**: usar habilidade dispara oito relâmpagos ao redor |

Cada criatura tem uma silhueta animada própria: asas, chifres, cabeças múltiplas, tentáculos, segmentos, órbitas e outras composições de polígonos, círculos e linhas. O contorno central representa o corpo vulnerável; extensões decorativas não ampliam a colisão.

### Propriedade dos dons

O personagem que dá o **golpe final** recebe o dom automaticamente. Isso vale tanto para você quanto para os rivais de IA. Outro personagem não recebe uma cópia, mesmo que tenha ajudado na luta.

Os dons ficam no personagem, podem coexistir entre si e valem apenas durante sua vida. **Morrer elimina todos os dons; absorver ou matar o portador nunca transfere nenhum deles.** O saque contém apenas essência. Personagens novos e novas partidas começam sem dons, e o arquivo de recordes nunca armazena esses poderes.

Derrotar novamente uma criatura cujo dom você já possui recupera 30% da vida máxima, sem duplicar o poder. A Cinza imortal evita uma morte; se a proteção estiver em recarga e o personagem morrer, seus dons também desaparecem. Uma morte por absorção elimina os dons diretamente.

## Classes

| Classe | Forma | Ataque | Habilidade |
| --- | --- | --- | --- |
| Mago | Triângulo violeta | Orbe arcano | Supernova: explosão, dano e empurrão |
| Paladino | Hexágono dourado | Martelo de luz | Santuário: cura e escudo |
| Cavaleiro | Quadrado coral | Corte de aço | Investida: avanço ofensivo |
| Arqueiro | Triângulo azul direcional | Flecha de cristal | Chuva de flechas: leque de quatro projéteis |
| Druida | Pentágono verde | Espinho que desacelera | Raízes ancestrais: cura, dano e lentidão |

| Classe | Vida | Vida/nível | Velocidade | Dano | Cadência | Alcance |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Mago | 100 | 9 | 205 | 23 | 0,48 s | 640 |
| Paladino | 155 | 14 | 188 | 24 | 0,65 s | 130 |
| Cavaleiro | 140 | 13 | 210 | 31 | 0,50 s | 140 |
| Arqueiro | 90 | 9 | 207 | 15 | 0,32 s | 760 |
| Druida | 110 | 11 | 195 | 17 | 0,55 s | 550 |

O dano básico cresce 7% por nível. A melhoria **Poder primordial** soma 20 de dano por segundo a qualquer classe (o acréscimo por golpe acompanha a cadência), para que classes de ataque rápido não multipliquem o bônus. Lentidão reduz a velocidade para 60%; o espinho do Druida desacelera por 0,5 s. Paladino recebe 18% menos dano e Cavaleiro 12% menos.

Os dons dos chefes funcionam em qualquer uma das cinco classes.

## Magias até o nível 100

Cada classe começa com sua habilidade básica e recebe **10 evoluções automáticas**, nos níveis **10, 20, 30, 40, 50, 60, 70, 80, 90 e 100**. A tecla **Q** continua ativando a magia atual. O HUD mostra o nome e a evolução `0/10` a `10/10`; o guia “Como jogar” lista todos os desbloqueios da classe selecionada.

As evoluções aumentam o poder e acrescentam mecânicas: o Mago ganha ignição, atração e ecos; o Paladino, cura, julgamento e aura; o Cavaleiro, investidas maiores, lâminas e explosões; o Arqueiro, perfuração, perseguição e rajadas; o Druida, veneno, espinhos e múltiplos bosques. Os efeitos funcionam tanto para humanos quanto para bots e são calculados pelo servidor.

| Nível | Mago | Paladino | Cavaleiro | Arqueiro | Druida |
| --- | --- | --- | --- | --- | --- |
| 10 | Nova ampliada | Luz restauradora | Investida brutal | Rajada de cristal | Bosque desperto |
| 20 | Pulso astral | Égide radiante | Rastro de aço | Flechas penetrantes | Raízes profundas |
| 30 | Ignição arcana | Julgamento | Impacto sísmico | Caçada glacial | Esporos venenosos |
| 40 | Estilhaços estelares | Martelos sagrados | Lâminas do vendaval | Mira astral | Coroa de espinhos |
| 50 | Gravidade zero | Purificação | Armadura de guerra | Flechas incendiárias | Seiva da vida |
| 60 | Eco da supernova | Círculo de luz | Ruptura | Chuva de estrelas | Floresta ancestral |
| 70 | Prisão cósmica | Sentença divina | Marcha do titã | Caçada infinita | Prisão selvagem |
| 80 | Tempestade astral | Aurora imortal | Tempestade de aço | Horizonte de flechas | Fúria da natureza |
| 90 | Colapso dimensional | Trono solar | Golpe do destino | Eclipse de cristal | Mundo verde |
| 100 | Big Bang | Apoteose | Fim dos reinos | Mil sóis | Árvore da eternidade |

A partir do nível 100, a magia mantém o nome, padrão, alcance, recarga e parâmetros da forma final. Nível e melhorias do personagem continuam avançando. O dano das magias cresce de forma linear com a evolução: 0,6× na forma inicial até 3,4× no nível 100. As evoluções de magia não exigem gastar as escolhas do painel lateral.

## Controles

| Entrada | Ação |
| --- | --- |
| WASD / setas | Movimento |
| Mouse | Mira |
| Clique esquerdo segurado | Ataque repetido |
| Q / clique direito | Habilidade da classe |
| Espaço | Esquiva; recarga de 4 s |
| E | Movimento seguindo o mouse, estilo Agar.io |
| F | Autoataque na direção da mira |
| B | Abrir/fechar o bestiário; pausa apenas no solo |
| Setas no bestiário | Selecionar criatura |
| Esc | Pausar / continuar / fechar bestiário |
| M | Silenciar efeitos |
| F11 | Tela cheia |
| 1–5 / Enter | Escolher classe / iniciar no menu |
| 1–3 | Escolher melhoria |

## Estrutura

- `scripts/spells.gd`: 50 evoluções de habilidade, desbloqueios a cada 10 níveis, projéteis e efeitos.
- `scripts/arena.gd`: simulação, combate, coleta, ciclos e atribuição de recompensas.
- `bosses.gd`: catálogo e balanceamento dos dez chefes e dons.
- `boss_combat.gd`: IA e padrões exclusivos dos chefes.
- `boss_art.gd`: desenho procedural das dez criaturas.
- `boon_system.gd`: aquisição, efeitos e descarte dos dons por personagem.
- `hazard.gd`: áreas e feixes com aviso, duração, dano e efeitos de estado.
- `actor.gd`, `orb.gd`, `shot.gd`, `effect.gd`: modelos das entidades.
- `classes.gd`: balanceamento das classes.
- `palette.gd`, `type.gd`: tokens do design system (cores, espaçamento, raios, traços e os nove estilos de texto em Outfit). `paint.gd` desenha painéis por papel, key caps, ícones, barras e sigilos a partir deles.
- `world_view.gd`, `interface.gd`: cenário, HUD, menus e bestiário.
- `main.gd`: entrada, simulação e áudio.
- `display.gd`, `layout.gd`: densidade de pixels e as seis zonas fixas do HUD (vitais, sessão, sistema, ranking, build, ações e mapa), com regras responsivas.
- `progression.gd`: custo crescente dos níveis e progresso da barra.
- `director.gd`: ameaça progressiva e escala de reforços/chefes.
- `network.gd`: servidor WebSocket, comandos, snapshots e ciclo de conexão.
- `settings_panel.gd`: configuração visual e preferências persistentes.
- `export_presets.cfg`, `tools/`: exportação Web e servidor local.

GDScript nativo, sem serviços externos, plugins ou arte paga. Os sons são sintetizados; a fonte Outfit usa SIL OFL (`assets/OFL.txt`); a licença do Godot está em `assets/GODOT_LICENSE.txt`. `.tools/` e `.godot/` não fazem parte do código-fonte distribuível.

## Verificação

```bash
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
.tools/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/smoke_test.tscn
```

A suíte verifica as 50 evoluções de magia, limites após nível 100, perfuração, ecos, classes, absorção, progressão, os ataques dos dez chefes, avisos antes do dano, renascimento da Fênix, todos os dons, exclusividade para o golpe final, descarte na morte, ausência de herança, reinício e **30 encontros consecutivos em três ciclos completos**. Inclui uma simulação de três minutos. Use `-- --quick` para executar sem essa simulação. Os testes não leem nem alteram os recordes reais.

```bash
./Jogar.command -- --capture-menu
./Jogar.command -- --capture-arena
./Jogar.command -- --capture-bestiary
./Jogar.command -- --capture-boss
./Jogar.command -- --capture-pause
./Jogar.command -- --capture-result
```

Capturas ficam em `artifacts/` (use `--screen` para escolher um monitor 1× e manter a escala lógica de 1440 × 900); recordes reais, em `user://forma_records.cfg`. O relatório final de validação está em `artifacts/validation.txt`: **965 verificações de gameplay/layout e 36 verificações de rede, zero falhas**, incluindo três ciclos de chefes e a simulação de três minutos.

Relatório de balanceamento (duelos entre classes nos níveis 1, 10, 30 e 60 e partidas solo com um jogador controlado por IA cautelosa). Não faz verificações, apenas mede:

```bash
.tools/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/balance_sim.gd -- --runs=6 --minutes=6
```

Testes de conexão real com servidor e clientes independentes:

```bash
.tools/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/network_test.tscn
```
