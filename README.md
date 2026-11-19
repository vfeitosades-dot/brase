# Brisa

Navegador nativo em SwiftUI e WebKit para iPhone com iOS 15.0 ou posterior. A tela inicial tem um atalho para a página oficial de login do Instagram. O Brisa usa uma única página e guarda os cookies do site no armazenamento do próprio app. O Brisa não inclui serviços de telemetria ou um servidor intermediário.

## Instalar pelo Mac com Xcode

1. Baixe o código, descompacte e abra `Brisa.xcodeproj`.
2. No Xcode, entre com sua Conta Apple em **Xcode → Settings → Accounts**. Use uma versão com suporte ao dispositivo iOS 15. O Xcode 16.4 é um exemplo, se for compatível com seu Mac.
3. Em **Brisa → Signing & Capabilities**, mantenha **Automatically manage signing** ativado e selecione sua equipe. Se o identificador `com.vfeitosades.brisa` estiver ocupado, troque-o por um identificador único.
4. Conecte o iPhone por USB, confirme a confiança se solicitada, selecione o iPhone como destino e clique em **Run ▶**. No iOS 16 ou posterior, ative o Modo de Desenvolvedor se o sistema solicitar.
5. Se o próprio iPhone solicitar confiança no desenvolvedor, abra **Ajustes → Geral → VPN e Gerenciamento de Dispositivo** e selecione sua conta.

Com uma Conta Apple gratuita, o perfil de desenvolvimento expira em sete dias. Basta executar a instalação novamente com a mesma conta. [Instruções da Apple](https://developer.apple.com/help/account/basics/about-your-developer-account/) e [compatibilidade do Xcode](https://developer.apple.com/xcode/system-requirements/).

## Obter o IPA pelo GitHub

Em **Actions → Compilar Brisa para iOS**, abra uma execução concluída e baixe o artefato **Brisa-iOS15**. Descompacte o arquivo para obter `Brisa-sem-assinatura.ipa`. O IPA precisa ser assinado para instalação. Uma opção com Mac ou Windows é o AltStore Classic usando sua própria Conta Apple. [Guia oficial do AltStore](https://faq.altstore.io/altstore-classic/your-altstore).

## Testar o Instagram no iPhone SE

1. Abra o Brisa e toque em **Instagram**. O login acontece em `www.instagram.com`.
2. Se a página móvel falhar, toque em **⋯ → Solicitar versão para computador**. O Brisa recarrega a página.
3. Se a opção para computador também falhar, anote a mensagem que aparece e a versão exata do iOS em **Ajustes → Geral → Sobre**.

O Brisa utiliza o WebKit disponível no iOS instalado. Ele pode contornar problemas causados pelos dados do Safari ao iniciar com uma sessão própria. Se a Meta exigir um recurso ausente no WebKit do iOS 15, a opção para computador pode continuar sem funcionar. O login no aparelho precisa ser testado.

## Bloqueio de anúncios

O bloqueador vem ativado e usa uma lista local de redes de anúncios de terceiros. Use **⋯** para ligar ou desligar. O Instagram fica fora das regras para preservar a compatibilidade. Publicidade servida pelo próprio site pode continuar aparecendo.
