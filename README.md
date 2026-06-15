# Bookself App

O **Bookself App** é um aplicativo mobile desenvolvido em Flutter para ajudar usuários a gerenciarem suas leituras, catalogarem seus livros favoritos e também explorarem a leitura da Bíblia Sagrada. Integrado com o Firebase, o aplicativo oferece sincronização em tempo real e autenticação segura de usuários.

---

## 🚀 Funcionalidades Principais

*   **Autenticação de Usuários:** Cadastro, Login e Recuperação de Senha utilizando o Firebase Authentication.
*   **Gerenciamento de Estante (Bookshelf):** Adicionar, visualizar, editar e remover livros da sua estante virtual, com controle de status de leitura (Lido, Lendo, Quero Ler).
*   **Integração com Firebase:** Armazenamento em nuvem em tempo real com o Cloud Firestore, garantindo que seus dados estejam sempre sincronizados entre dispositivos.
*   **Leitor de Bíblia Integrado:** Acesso a textos bíblicos diretamente no aplicativo para acompanhar suas leituras diárias.
*   **Busca Avançada:** Procure por novos livros utilizando a barra de pesquisa integrada.
*   **Perfil Personalizável:** Edição de foto de perfil (utilizando `image_picker`) e informações do usuário.
*   **Tema Claro e Escuro (Dark Mode):** Suporte completo a temas visuais dinâmicos para melhor conforto visual.

---

## 🛠️ Tecnologias Utilizadas

Este projeto foi construído utilizando as seguintes tecnologias e pacotes:

*   **[Flutter](https://flutter.dev/):** SDK do Google para desenvolvimento multiplataforma.
*   **[Provider](https://pub.dev/packages/provider):** Gerenciamento de estado pragmático e injeção de dependências.
*   **[Firebase Core & Auth](https://pub.dev/packages/firebase_auth):** Configuração básica e autenticação do Firebase.
*   **[Cloud Firestore](https://pub.dev/packages/cloud_firestore):** Banco de dados NoSQL em tempo real.
*   **[Google Fonts](https://pub.dev/packages/google_fonts):** Tipografia dinâmica e elegante.
*   **[Image Picker](https://pub.dev/packages/image_picker):** Seleção de imagens da galeria ou câmera para o perfil.
*   **[HTTP](https://pub.dev/packages/http):** Requisições de rede para APIs externas.

---

## 📦 Como Instalar e Executar o Projeto

### Pré-requisitos
Antes de começar, você precisará ter o **Flutter SDK** configurado em sua máquina. Para instruções detalhadas, consulte o [guia de instalação oficial do Flutter](https://docs.flutter.dev/get-started/install).

### Passos para Configuração:

1.  **Clonar o Repositório:**
    ```bash
    git clone <url-do-repositorio>
    cd bookself-app
    ```

2.  **Instalar Dependências:**
    Obtenha todos os pacotes necessários especificados no `pubspec.yaml`:
    ```bash
    flutter pub get
    ```

3.  **Configurar o Firebase (Opcional, mas Recomendado):**
    O projeto está preparado para utilizar o Firebase. Caso deseje habilitar a sincronização na nuvem e autenticação:
    *   Crie um projeto no [Console do Firebase](https://console.firebase.google.com/).
    *   Ative o **Authentication** (método Email/Senha) e o **Firestore Database**.
    *   Configure o FlutterFire CLI e execute o comando:
        ```bash
        flutterfire configure
        ```
    *   Isso gerará ou atualizará o arquivo `lib/firebase_options.dart`.

4.  **Executar o Aplicativo:**
    Certifique-se de que possui um emulador ativo ou um dispositivo físico conectado e execute:
    ```bash
    flutter run
    ```

---

## 📂 Estrutura de Diretórios

A organização do código-fonte dentro de `lib/` segue o padrão de separação de responsabilidades:

*   `data/`: Modelos de dados e dados locais (como dados bíblicos).
*   `services/`: Classes de serviço que gerenciam interações externas (autenticação Firebase, chamadas do banco de dados Firestore, controle de tema).
*   `ui/`: Telas e widgets reutilizáveis do aplicativo.
    *   `screens/`: Telas completas (Home, Login, Estante, Bíblia, Perfil, Busca).
    *   `theme.dart`: Configuração de temas claro e escuro.
*   `utils/`: Funções utilitárias auxiliares.
*   `main.dart`: Ponto de entrada do aplicativo que inicializa serviços e provedores globais.
