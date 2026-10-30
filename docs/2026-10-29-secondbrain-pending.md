# Registo pendente no Segundo Cérebro

A escrita no vault foi bloqueada pelas permissões desta sessão. Texto preparado para acrescentar, sem substituir histórico:

## 2026-10-29: revisão Apple e renomeação para iVidiMahjong

Projeto local: /Users/vidi/Desktop/PROGRAMMING/Programas feitos por mim/Mahjong/iVidiMahjong. Renomeados projeto/módulo/targets/interface; bundle ID e chaves antigos preservados para compatibilidade. Removidas aplicações Android e Web, servidor integrado no repo Apple. Corrigidos regras/pontuação Riichi, reações, gravações, timer, ligações online e código morto identificado. 36 testes Swift passaram, 1 integração omitida; 8 testes de servidor passaram. Builds SwiftUI e WebSocket real bloqueados por sandbox, não validados. Commits locais criados; push e rename remoto falharam por DNS. Fonte: docs/2026-10-29-audit.md no projeto. Próximo passo: validar Xcode/dispositivos/rede e concluir publicação.

Destino exato indicado pelo hook: /Users/vidi/Desktop/SecondBrain/conhecimento/sessoes-ai/2026-10-29-Mahjong-5.md

## Registo confirmado da conversa

### Tarefa
Revisão geral do Mahjong, correção de problemas, remoção de código morto e Android/Kotlin, foco Apple e renomeação de iMahjong para iVidiMahjong. Commit e push autorizados.

### O que foi feito
- Lidas CLAUDE.md e INDICE.md do vault e procurado contexto do projeto.
- Identificados três repositórios inicialmente limpos: iMahjong, DroidMahjong e MahjongWeb.
- Renomeados diretórios, projeto Xcode, módulo, targets, testes e interface Apple para iVidiMahjong.
- Retiradas aplicações Android e Web; preservados históricos em .retired-repositories e integrado servidor online no repositório Apple. Foi colocada uma pergunta opcional sobre Web, sem resposta recebida; prosseguiu-se com a indicação original de manter apenas Apple.
- Corrigidos regras Riichi, pontuação, apostas, reações de vários humanos, fim da partida, validação de gravações, cronómetro e ciclo de vida WebSocket. Removidas funções sem chamadas e implementação incompleta de kan acrescentado. Acrescentados recordes no menu, controlo de som e testes/CI.
- Validação final: 37 testes Swift, 36 passaram e 1 integração omitida; 8 testes do servidor passaram, incluindo 20 mãos completas. Testados os 15 níveis. Parser Swift e git diff --check passaram.
- Builds completos macOS/iOS bloqueados por sandbox/macros SwiftUI e serviços CoreSimulator. WebSocket real bloqueado por listen EPERM. Não foi validada a interface em execução nem em dispositivos.
- Commits Apple: 5fc9f90 e 42a0683. Remoção Android: 94e0f16. Remoção Web: 90e1b0e. Push dos três repositórios e rename remoto tentados, sem sucesso por rede/DNS. Repositório Apple ficou limpo, main dois commits à frente de origin/main.
- Relatório: iVidiMahjong/docs/2026-10-29-audit.md. Primeira tentativa de escrita no vault bloqueada; criado registo pendente no projeto.

### Aprendizados / padrões
- Separar testes do núcleo Swift em Swift Package permite verificar regras sem lançar a interface, mas não substitui builds/UI.
- Nome visível e nome do módulo podem mudar mantendo bundle ID e chaves de preferências para preservar dados existentes.
- Callbacks de sockets antigos devem verificar a identidade da ligação antes de alterar o estado atual.
- Testes aleatórios de incompatibilidade entre peças devem excluir a própria peça e respeitar as regras especiais de flores/estações.

### Decisões
- Manter com.vidi.iMahjong e imahjong-* apenas por compatibilidade de instalação/dados.
- Manter servidor de rede para o cliente Apple; retirar a aplicação Web.
- Não apresentar o Riichi casual como implementação completa/certificada. Documentadas limitações, incluindo honba, kan acrescentado e alguns yakuman.
- Preservar histórico das versões retiradas; não apagar repositórios remotos.

### Próximos passos
- Executar builds Xcode e testes de interface em Mac, iPhone e iPad num ambiente sem os bloqueios encontrados.
- Validar WebSocket real, reconexão e vários clientes.
- Concluir pushes e renomeação GitHub quando houver rede.
- Integrar este registo no vault quando houver permissão de escrita. Melhorias futuras propostas: passagem privada de mãos, regras Riichi completas e sons próprios.

## Correção posterior de nomenclatura

Por indicação explícita do utilizador, nome visível uniformizado para iVidiMahjong, incluindo logótipo e textos de menu/ajuda. Bundle ID alterado para dev.ividi.ividimahjong e preferências para ividimahjong-*. Esta decisão substitui a opção anterior de manter identificadores antigos.

## 2026-10-30: conclusão da uniformização do nome

Tarefa: substituir o nome antigo pelo nome exato iVidiMahjong. Logótipo, menu e ajuda PT/EN atualizados; bundle ID dev.ividi.ividimahjong, testes dev.ividi.ividimahjong.tests e preferências ividimahjong-*. Projeto Xcode regenerado. Os testes da alteração passaram: 36 testes Swift, 1 integração omitida, zero falhas. Parser Swift passou; pesquisa final não encontrou nomes antigos ativos. O ficheiro novo iVidiMahjong_logo.jpeg já estava presente ao retomar e não foi alterado nem incluído no commit. Rename remoto novamente bloqueado pela rede. Próximo passo: push/rename GitHub e validação visual quando o ambiente permitir.
