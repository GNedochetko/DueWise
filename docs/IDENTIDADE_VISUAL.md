# Identidade visual do DueWise

## Direção

Identidade séria, profissional e discreta. Interface clara, respiro entre elementos, cantos de 10 a 12 pixels e ícones apenas quando indicam ação ou destino. Sem slogans e sem elementos ornamentais repetidos.

## Paleta

| Uso | Cor |
| --- | --- |
| Azul principal | `#245D9F` |
| Azul-marinho: títulos e texto | `#14375B` |
| Azul claro: seleção e apoio | `#EAF2FA` |
| Fundo | `#F6F8FB` |
| Superfícies | `#FFFFFF` |
| Bordas | `#DCE3EB` |
| Texto secundário | `#5E6D7D` |

O tema é sempre claro, inclusive quando o Android usa modo escuro. Tipografia Roboto, padrão visual do Material/Android, incluída em assets/fonts com sua licença para uso offline e prévias consistentes.

## Marcas

- `assets/branding/monk_icon.png`: monge barbudo, azul e branco, para o launcher Android e a splash nativa. Gerado com a ferramenta integrada de imagens.
- `assets/branding/dw_monogram.svg`: monograma DW vetorial, reutilizado dentro do aplicativo pelo widget `BrandLogo`.

### Prompt final do monge

Use case: logo-brand. Asset type: final Android launcher icon for DueWise, a serious minimalist academic planner. Primary request: a stylized bearded monk head, calm wise face with a hood and a clearly visible full beard. Flat vector-like graphic, restrained professional design, bold simple geometric shapes that remain recognizable at 48 pixels. Color palette: deep navy #14375B, primary blue #245D9F, pale ice blue #EAF2FA, off-white beard. Composition: square 1024x1024 icon, opaque solid pale ice-blue background filling all edges, monk head and hood precisely centered entirely within central 60 percent so circular Android cropping will preserve the head and beard. No rounded app tile drawn inside the image, no border, no text, no letters, no slogan, no book, no calendar, no gradients, no shadows, no photorealism, no tiny decorative details. This is a functional production app icon, not a mockup or a presentation sheet. One single icon.

O arquivo recebido possui resolução de 1254 × 1254 pixels. Os geradores produzem os recursos Android nas dimensões necessárias.

## Regenerar os recursos nativos

Após alterar os assets ou as configurações em `pubspec.yaml`:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Após regenerar, mantenha os estilos em values-night e values-night-v31 com o tema pai Theme.Light.NoTitleBar, como nos arquivos versionados, para preservar também o fundo nativo claro. Os arquivos Android gerados devem acompanhar o código no Git. Recompile o app após mudanças nativas. Em alguns launchers é necessário reinstalar o aplicativo para atualizar o ícone em cache.

## Componentes

- `FilledButton`: entrar, criar conta, enviar recuperação e salvar perfil.
- `TextButton`: mudar entre telas de autenticação.
- `OutlinedButton`: sair da conta e tentar novamente.
- `IconButton`: mostrar ou ocultar senha.
- Barra inferior: início, calendário e perfil.

A splash usa o monge; as telas internas usam o DW. Nenhum slogan é apresentado.
