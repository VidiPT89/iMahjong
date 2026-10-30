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

Validação final: 36 testes passaram, incluindo as três fixtures de formatos antigos do modo fácil; git diff --check sem erros.
