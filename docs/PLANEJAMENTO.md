# Escopo do DueWise

Agenda acadêmica em português para Android. O tema claro usa azul como cor principal, o monge na abertura e o monograma DW nas telas internas. A navegação reúne agenda, calendário e perfil.

## Dados e sincronização

- O Firebase Authentication identifica o estudante. O perfil fica em `users/{uid}` e as subcoleções `activities` e `disciplines` pertencem à mesma conta.
- Cada criação, edição ou exclusão de atividade grava primeiro uma operação em `pending_operations`, no SQLite. O UUID da atividade também identifica o documento no Firestore. O app reenvia as pendências ao abrir, voltar ao primeiro plano ou recuperar a conexão.
- Após a confirmação do servidor e a leitura do cache, o app remove do SQLite somente a revisão enviada. Uma edição feita durante o envio continua pendente. Fora da rede, a agenda combina o histórico disponível no cache do Firestore e as alterações locais.
- Cada atividade pode ter coordenadas e endereço. O GPS é acionado pelo estudante. O ViaCEP preenche o endereço e o formulário aceita entrada manual. A foto de perfil fica no aparelho, associada à conta.

## Conferência no celular

1. Entre com uma conta, crie uma atividade e confira o mesmo registro no calendário e no Firestore.
2. Desligue o Wi-Fi e os dados móveis. Cadastre e edite uma segunda atividade e exclua a primeira. Feche e reabra o app ainda offline e confira as mudanças.
3. Religue a internet. Confira no Firestore a exclusão da primeira atividade e uma única cópia da segunda com a última edição.
4. Capture o GPS e consulte um CEP na atividade. Selecione uma foto no perfil, reabra o app e confira a imagem. Troque de conta para verificar a separação dos registros e das fotos.
