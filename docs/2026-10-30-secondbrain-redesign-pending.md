# Registo para acrescentar à sessão 2026-10-30-iVidiMahjong-2

## Tarefa
Simplificar e melhorar os gráficos, as peças e a experiência de jogo, com liberdade de alteração dada pelo David.

## O que foi feito
Menu reorganizado, entrada direta sem splash, mesa verde e peças de marfim sem sobreposição na mesma camada. Números ocidentais nas peças e marcadores numéricos nos círculos/bambus. Fácil reduzido para 48 peças e 12 tipos, mantendo leitura de saves antigos de 108 peças. Destaque de pares compatíveis, explicações de bloqueio e ausência de par, controlos legendados, progresso e pares restantes. Passagem de nível agora exige Próximo nível. Dicas duram quatro segundos e distribuição respeita redução de movimento.
Validação: 36 testes passaram; builds Debug macOS e iOS para dispositivo passaram sem assinatura. Observada a interface Mac com 48 peças e progresso de 24 para 23 pares. Não foi feita uma partida completa na interface nem observada uma transição de nível. git diff --check passou. Relatório: iVidiMahjong/docs/2026-10-30-redesign.md. Sem commit, push ou submissão nesta conversa.

## Aprendizados / padrões
Uma entrada de 108 peças com 27 tipos criava densidade excessiva para o objetivo de simplicidade. Peças da mesma camada sobrepunham-se visualmente; o espaçamento passou a superar as dimensões da peça. Mudanças no layout exigem preservar a validação de saves anteriores. Teste novo restaura, resolve e reinicia o formato antigo.

## Decisões
Partida fácil curta, assistência visual na seleção e menor destaque para modos avançados; Riichi mantido. Não alteradas submissões anteriores. Preferência explícita: experiência prática e simples, menos confusa e mais convidativa.

## Próximos passos
Validar visualmente em iPhone/iPad, orientações, Dynamic Type e VoiceOver. Percorrer uma transição de nível completa na interface. Rever a experiência com o David antes de eventual publicação.

### Atualização confirmada: tentativa 3D e rejeição visual

- David pediu uma mudança mais profunda, peças mais bonitas, interação e 3D.
- Implementado Board3DView.swift com SceneKit, peças com base e tampa de cerâmica, texturas geradas de SwiftUI, mesa, luz e sombras, rotação limitada por arrasto, seleção por hit-test, levantamento da peça, animação de recolha e partículas. Vista de cima e escolha entre peças ilustradas e clássicas. Alternativa semântica para VoiceOver. Não foi validado VoiceOver num dispositivo.
- Fácil passou a 36 peças na base e 12 num segundo andar. Preservada leitura dos formatos antigos de 108 peças e 48 peças planas. Alterados menu, ajuda e feedback de pares consecutivos. Som passou de alertas do sistema para WAV sintetizado em memória com AVAudioPlayer, com feedback tátil no iPhone.
- Compilação Mac 3D inicial passou; versão isolada Mahjong3DPreview (bundle dev.ividi.ividimahjong.preview), incluindo áudio/ajuda, e build iOS para dispositivo passaram. 36 testes passaram após o novo layout; a extensão posterior do teste do save plano de 48 peças ainda não foi novamente executada.
- Interface da versão isolada foi aberta e a mesa foi observada por captura. Não foi concluída uma partida nem uma transição de nível nesta versão. A ferramenta de controlo da janela teve erros e uma chamada de abertura demorou cerca de 33 minutos.
- David rejeitou explicitamente a captura: «está horrivel! nao quero isto!». A versão 3D NÃO está aprovada nem concluída. O trabalho permanece local, sem commit, push ou publicação nesta conversa.
- Identificado visualmente: símbolos demasiado pequenos, faces brancas sem detalhe suficiente e composição ainda semelhante a grelha. Decisão de processo: validar uma referência visual antes de continuar a alterar o aspeto.
- Gerada com imagegen uma comparação com três propostas: A clássico, B divertido, C zen. É concept art, não uma captura nem prova de implementação. Ficheiro original: /Users/vidi/.codex/generated_images/01a18ca6-1118-7c83-86cb-f3609c00da10/exec-444d6713-bc35-4e9c-b88a-9265ae90fd24.png.
- Pendente resposta de David sobre A/B/C. Não inferir uma escolha ou aprovação. Depois, implementar a direção escolhida e validar uma partida completa, transição de nível e apresentação em iPhone/iPad.

### Preferência e aprendizagem a preservar
Neste projeto, simplificar e introduzir geometria 3D não chegou: David procura um resultado visual marcadamente mais bonito e convidativo e rejeitou os pequenos símbolos genéricos sobre faces quase vazias. Após rejeição explícita, mostrar alternativas visuais concretas antes de investir noutra direção. Uma compilação bem-sucedida não valida qualidade visual nem aprovação do utilizador.

## Atualização: direção realista implementada

# Revisão realista, 2026-10-30

## Direção pedida
David rejeitou a versão com símbolos genéricos e escolheu uma direção mais realista, deixando a decisão visual ao agente. A implementação anterior não deve ser apresentada como aprovada.

## Implementação
- Peças tradicionais com rosetas de círculos, bambus articulados, caracteres grandes e figuras botânicas; texturas próprias desenhadas em SwiftUI em resolução de 192×256 a 2×.
- Espessura aumentada, base em tom de bambu, tampa de marfim, iluminação reduzida, oclusão ambiente, sombras suaves e câmara inclinada com rotação inicial.
- Mesa de nogueira com textura gerada e integrada no catálogo de assets. Removido o tampo verde e a moldura dourada.
- Fácil de 48 peças com base recortada e um terraço de 12 peças. Saves de 108, 48 planas e 48 com terraço retangular continuam reconhecidos.
- Símbolos genéricos retirados. Menu de aspeto conserva perspetiva e vista de cima. Cores da interface passam a castanhos discretos.

## Validação observada
- Builds Debug Mac e iOS para dispositivo passaram, sem assinatura.
- 36 testes do motor passaram após o novo layout; ver registo final de execução para a extensão da fixture de terraço anterior.
- Captura real da app mostra a madeira texturada, o tabuleiro recortado e faces tradicionais legíveis.
- Teste real por clique: selecionar círculo de um motivo, observar levantamento e indicação de par; clicar na correspondência e confirmar 24 → 23 pares; Desfazer confirmado em 24 pares.
- Versão isolada de teste: /tmp/mahjong-3d-preview/Build/Products/Debug/Mahjong3DPreview.app (dev.ividi.ividimahjong.preview). Não substitui a app publicada nem os saves da app principal.
- Não foram percorridos uma partida completa ou uma transição de nível na interface. Sem validação visual num iPhone/iPad, nem validação física de haptics.

## Asset gerado
Ferramenta integrada imagegen; destino: iVidiMahjong/Assets.xcassets/Walnut.imageset/walnut.png.
Prompt: “A seamless tileable physically based albedo texture of beautiful medium dark warm walnut wood, top-down orthographic macro scan, fine flowing elongated natural grain horizontally across the image, subtle honey brown variation, beautifully maintained satin wood, no planks, no seams, no knots larger than 3 percent of image, no objects, no perspective, no lighting, no specular highlights, no shadows, no text. Flat neutral diffuse illumination. Texture for a realistic luxury mahjong tabletop 3D material. Square composition, detailed fine grain, restrained contrast.”

## Limites e próximo passo
Testar uma partida completa e passagem de nível, iPhone/iPad, rotação, VoiceOver e desempenho em hardware real. Obter feedback do David sobre o resultado real. Sem commit, push ou publicação. Registo do Segundo Cérebro pendente no repositório por falta de escrita no vault.

Aprendizagem: substituir símbolos pequenos e reduzir iluminação saturada foi necessário para o volume ser legível. Não tratar concept art como prova de qualidade do produto. Validar os materiais com captura real e seleção por hit-test.

Validação final: 36 testes passaram, incluindo as três fixtures de formatos antigos do modo fácil; git diff --check sem erros.

## Atualização: revisão realista concluída localmente

David pediu explicitamente uma direção mais realista e deixou a escolha estética ao agente. Substituídos os símbolos genéricos por faces tradicionais grandes (círculos ornamentados, bambus, caracteres e motivos botânicos), base em tom de bambu e tampa de marfim mais espessas. Mesa de nogueira com textura gerada pela ferramenta integrada imagegen e guardada no catálogo Walnut.imageset. Câmara mais inclinada, rotação inicial, iluminação reduzida, oclusão ambiente e sombras suaves. Removidos tampo verde e moldura dourada; interface em castanhos discretos. Modo fácil mantém 48 peças, agora com base recortada e terraço. Mantida compatibilidade com os três formatos anteriores (108 peças, 48 planas, 48 com terraço retangular).

Validação final: 36 testes passaram, incluindo fixtures dos três formatos anteriores; builds Debug macOS e iOS para dispositivo passaram sem assinatura; git diff --check passou. Na interface real da versão isolada, seleção por clique levantou a peça, formar par alterou 24 para 23 pares, e Desfazer repôs 24. Versão final reaberta no Mac com a partida pronta. Não foi concluída uma partida completa nem validada visualmente a versão iPhone/iPad ou a transição de nível. Sem commit, push ou publicação. Não inferir aprovação visual do David.

Documentação: docs/2026-10-30-realistic-redesign.md e docs/2026-10-30-secondbrain-redesign-pending.md, no repositório iVidiMahjong. Preview isolada: /tmp/mahjong-3d-preview/Build/Products/Debug/Mahjong3DPreview.app, bundle dev.ividi.ividimahjong.preview; não substitui saves da app principal.

Aprendizagem/preferência: David prefere peças e materiais realistas; rejeitou os símbolos genéricos pequenos. Geometria 3D, por si só, não garante qualidade visual: escala do desenho, iluminação, materiais e câmara têm de ser inspecionados numa captura real. Concept art não equivale a resultado implementado nem a aprovação.

Próximos passos: feedback sobre a revisão realista; partida completa e transição de nível na interface; verificação iPhone/iPad, orientações, VoiceOver, haptics e desempenho em hardware real.

## Atualização: tipografia
David pediu outro tipo de letra. Substituída a serifa do título por SF Rounded e uniformizadas as fontes da interface (menus, controlos, ajuda, níveis e Riichi) com o desenho arredondado nativo. Preservada a arte dos caracteres tradicionais das peças. Sem novas dependências. Validação por compilação, sem novos testes para esta alteração visual.

## Atualização: tipografia SF Rounded

Pedido de David: escolher outro tipo de letra por não gostar do anterior. Aplicada SF Rounded à interface (título principal, menus, botões, ajuda, níveis, modais e mesa Riichi), substituindo a serifa do título e uniformizando os restantes textos. Mantidos os caracteres tradicionais na arte das peças. Sem dependências novas nem alteração das regras.

Validação: build Debug macOS da preview passou; git diff --check sem erros. Preview reiniciada e captura real confirmou título e botões com a nova fonte. Não executados testes novos para esta mudança visual nem nova build iOS neste turno. A preview ficou aberta no menu.

Preferência confirmada: David rejeitou a tipografia anterior. SF Rounded foi escolhida pelo agente; ainda não há aprovação explícita de David à nova fonte. Sem novo padrão técnico ou decisão de arquitetura. Sem commit, push ou publicação.

## Atualização: zoom na mesa 3D
Pergunta de David: dá para fazer zoom no iPhone? A mesa 3D não tinha zoom. Implementados pinch de 1× a 3× em iOS e magnificação no trackpad Mac, arrasto para deslocar quando ampliada (sem zoom continua a rodar), limites de deslocação e botão Mostrar mesa inteira. Nova partida/nível e troca de perspetiva repõem zoom e centro. A alteração atua na câmara ortográfica e mantém hit-test da geometria; não amplia um screenshot. Ajuda PT/EN atualizada. Builds iOS para dispositivo e macOS passaram, git diff --check sem erros. Gesto ainda não verificado num iPhone físico; não afirmar que já está disponível na versão instalada/loja. Sem publicação. Registo no vault continua pendente por permissões.

## Atualização: validação do zoom e controlos alternativos

Após «continua», acrescentados botões Ampliar, Reduzir e Mostrar mesa inteira, além dos gestos existentes. Os botões usam a mesma câmara e os mesmos limites de 1× a 3×. Validado na preview Mac pela interface: duas ampliações, arrasto da mesa, seleção de peça e remoção de par (24 → 23), e reposição do enquadramento inteiro. Capturas reais confirmaram deslocação e zoom, sem perder correspondência do clique com a peça. Builds finais macOS e iOS para dispositivo passaram; git diff --check sem erros. Não foram criados testes que apenas espelham a implementação.

Tentativa de detetar iPhone com xcrun devicectl list devices terminou com timeout de inicialização de CoreDeviceService. Não foi possível confirmar dispositivos nem instalar/testar num iPhone físico. Não afirmar validação do gesto pinch em hardware. A preview ficou aberta no Mac. Sem publicação.

Aprendizagem: zoom e deslocação devem ser testados em conjunto com a seleção por hit-test; confirmar só a imagem ampliada não prova que a interação permanece correta. Controlo por botões oferece alternativa ao gesto. Registo local preservado porque o vault tem recusado escrita.

## Atualização: maior resolução dos gráficos

Pedido: melhorar a resolução dos gráficos. Faces tradicionais regeneradas em 768×1024 (antes 384×512), quatro vezes mais píxeis. ImageRenderer entrega CGImage diretamente ao SceneKit para evitar ambiguidades entre pontos e píxeis. Configuradas filtragem trilinear de mipmaps e anisotropia 16 nas texturas, e seis segmentos nos biséis das peças. SCNView acompanha escala Retina da janela no Mac e screen.scale no iOS, incluindo alterações de janela/ecrã.

Validação: builds Debug macOS e iOS para dispositivo passaram. Harness temporário compilou o desenho real das peças m4, p9 e s4 e exportou PNGs a 768×1024; saída e uma imagem inspecionadas. Preview atualizada, partida existente continuada e três ampliações conferidas numa captura real: faces, contornos e detalhes legíveis. Não alteradas regras nem saves. git diff --check passou. Sem novo teste num iPhone físico, medição de GPU/memória ou publicação.

Nota de desempenho: texturas em cache por tipo, partilhadas pelas peças do mesmo tipo; a memória de textura aumenta com a resolução. Falta medir desempenho em hardware iPhone. Próximo passo: experimentar a nitidez no dispositivo e em zoom máximo.

Padrão: a resolução de textura deve ser expressa e verificada em píxeis; ao passar de SwiftUI para SceneKit, CGImage torna a dimensão inequívoca. Filtragem anisotrópica depende de mipmaps (documentação Apple: https://developer.apple.com/documentation/scenekit/scnmaterialproperty/maxanisotropy).
