# Resolução dos gráficos, 2026-10-30

## Atualização: maior resolução dos gráficos

Pedido: melhorar a resolução dos gráficos. Faces tradicionais regeneradas em 768×1024 (antes 384×512), quatro vezes mais píxeis. ImageRenderer entrega CGImage diretamente ao SceneKit para evitar ambiguidades entre pontos e píxeis. Configuradas filtragem trilinear de mipmaps e anisotropia 16 nas texturas, e seis segmentos nos biséis das peças. SCNView acompanha escala Retina da janela no Mac e screen.scale no iOS, incluindo alterações de janela/ecrã.

Validação: builds Debug macOS e iOS para dispositivo passaram. Harness temporário compilou o desenho real das peças m4, p9 e s4 e exportou PNGs a 768×1024; saída e uma imagem inspecionadas. Preview atualizada, partida existente continuada e três ampliações conferidas numa captura real: faces, contornos e detalhes legíveis. Não alteradas regras nem saves. git diff --check passou. Sem novo teste num iPhone físico, medição de GPU/memória ou publicação.

Nota de desempenho: texturas em cache por tipo, partilhadas pelas peças do mesmo tipo; a memória de textura aumenta com a resolução. Falta medir desempenho em hardware iPhone. Próximo passo: experimentar a nitidez no dispositivo e em zoom máximo.

Padrão: a resolução de textura deve ser expressa e verificada em píxeis; ao passar de SwiftUI para SceneKit, CGImage torna a dimensão inequívoca. Filtragem anisotrópica depende de mipmaps (documentação Apple: https://developer.apple.com/documentation/scenekit/scnmaterialproperty/maxanisotropy).
