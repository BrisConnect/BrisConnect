// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'Bem-vindo';

  @override
  String get signIn => 'Entrar';

  @override
  String get signUp => 'Cadastrar-se';

  @override
  String get signOut => 'Sair';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Senha';

  @override
  String get phone => 'Telefone';

  @override
  String get name => 'Nome';

  @override
  String get save => 'Salvar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get profileInfo => 'Informações do perfil';

  @override
  String get preferences => 'Preferências';

  @override
  String get language => 'Idioma';

  @override
  String get locationRadius => 'Raio de localização';

  @override
  String get appearanceSettings => 'Aparência';

  @override
  String get feedback => 'Feedback';

  @override
  String get myFeedback => 'Meu feedback';

  @override
  String get helpAndSupport => 'Ajuda e suporte';

  @override
  String get discover => 'Descobrir';

  @override
  String get community => 'Comunidade';

  @override
  String get map => 'Mapa';

  @override
  String get saved => 'Salvo';

  @override
  String get profile => 'Perfil';

  @override
  String get food => 'Comida';

  @override
  String get events => 'Eventos';

  @override
  String get businesses => 'Negócios';

  @override
  String get promotions => 'Promoções';

  @override
  String get photos => 'Fotos';

  @override
  String get newPost => 'Novo';

  @override
  String get search => 'Pesquisar';

  @override
  String get filter => 'Filtrar';

  @override
  String get clearFilters => 'Limpar filtros';

  @override
  String get noResults => 'Nenhum resultado encontrado';

  @override
  String get loading => 'Carregando...';

  @override
  String get error => 'Erro';

  @override
  String get success => 'Sucesso';

  @override
  String get profileUpdated => 'Perfil atualizado com sucesso.';

  @override
  String get profileUpdateFailed =>
      'Não foi possível atualizar o perfil. Tente novamente.';

  @override
  String get guestVisitor => 'Visitante convidado';

  @override
  String get localUser => 'Local';

  @override
  String get filterEventsTitle => 'Filtrar eventos';

  @override
  String get priceLabel => 'Preço';

  @override
  String get dateLabel => 'Data';

  @override
  String get pickADate => 'Escolha uma data';

  @override
  String get resetButton => 'Redefinir';

  @override
  String get applyButton => 'Aplicar';

  @override
  String get freeLabel => 'Grátis';

  @override
  String get paidLabel => 'Pago';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle salvo para Interessados.';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return '$eventTitle removido de Interessados.';
  }

  @override
  String savedToAttractions(String title) {
    return '$title salvo em atrações salvas.';
  }

  @override
  String removedFromAttractions(String title) {
    return '$title removido das atrações salvas.';
  }

  @override
  String get pleaseSignInToSaveEvents =>
      'Faça login como visitante para salvar eventos.';

  @override
  String get pleaseSignInToReview =>
      'Faça login para escrever um comentário ou BuzzVote.';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return 'Comentário enviado\\! ⭐ $rating / Buzz ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return 'Não foi possível enviar a avaliação: $error';
  }

  @override
  String get noExternalLink =>
      'Nenhum link externo disponível para este item ainda.';

  @override
  String get unableToOpenLink =>
      'Não é possível abrir o link do evento no momento.';

  @override
  String shareTitle(String title) {
    return 'Compartilhar: $title';
  }

  @override
  String get reportEvent => 'Reportar Evento';

  @override
  String get reviewsOnlyForFood =>
      'As avaliações estão disponíveis apenas para itens alimentares';

  @override
  String get chooseFromGallery => 'Escolha na galeria';

  @override
  String get takeAPhoto => 'Tire uma foto';

  @override
  String get pleaseLoginVisitor => 'Faça login como visitante primeiro.';

  @override
  String get onlyJpgPng => 'Apenas imagens JPG e PNG são suportadas.';

  @override
  String get imageTooLarge =>
      'A imagem é muito grande. Escolha uma imagem menor.';

  @override
  String get profilePictureUpdated => 'Foto do perfil atualizada com sucesso.';

  @override
  String get profilePictureUpdateFailed =>
      'Não foi possível atualizar a foto do perfil. Por favor, tente novamente.';

  @override
  String get enterYourName => 'Digite seu nome';

  @override
  String get phoneHint => 'por exemplo 04xxxxxxx';

  @override
  String get nameCannotBeEmpty => 'O nome não pode ficar vazio.';

  @override
  String get nameMinLength => 'O nome deve ter pelo menos 2 caracteres.';

  @override
  String get enterValidPhone => 'Insira um número de telefone válido.';

  @override
  String get changeProfilePicture => 'Alterar foto do perfil';

  @override
  String get uploadProfilePicture => 'Carregar foto do perfil';

  @override
  String get areYouSureSignOut => 'Tem certeza de que deseja sair?';

  @override
  String get returnWelcome => 'Retorne à tela de boas-vindas';

  @override
  String get setHowFarRecommendations =>
      'Defina até que ponto as recomendações podem ser';

  @override
  String get themeTextSizeFeedback => 'Tema, tamanho do texto e feedback';

  @override
  String get faqsContactAppInfo =>
      'Perguntas frequentes, entre em contato conosco e informações do aplicativo';

  @override
  String get viewSubmittedFeedback =>
      'Veja os comentários enviados e as respostas do administrador';

  @override
  String get discoverSubtitle => 'Descubra comida e experiências locais';

  @override
  String get searchHintLocalFood => 'Pesquise empresas de alimentos locais...';

  @override
  String get homeLabel => 'Página inicial';

  @override
  String get recommendedForYou => 'Recomendado para você';

  @override
  String get seeAll => 'Ver tudo';

  @override
  String get categories => 'Categorias';

  @override
  String get nearby => 'Perto';

  @override
  String get noFoodPlacesFound => 'Nenhum restaurante encontrado';

  @override
  String get noFoodPlacesSubtitle =>
      'Tente alterar suas seleções de pesquisa ou filtro.';

  @override
  String get localFoodBusinesses => 'Empresas locais de alimentos';

  @override
  String get localFoodSubtitle =>
      'Apoie pequenas e médias empresas alimentícias de Brisbane';

  @override
  String get exploreReviewFoodBusinesses =>
      'Explorar e avaliar empresas alimentícias';

  @override
  String get noSavedItemsTitle => 'Nenhum item salvo ainda';

  @override
  String get noSavedItemsSubtitle =>
      'Toque no ícone de coração em cartões de visita de alimentos ou no marcador de um perfil comercial para salvá-los aqui.';

  @override
  String get savedEvents => 'Eventos salvos';

  @override
  String get savedEventsSubtitle => 'Seus lembretes e planos de eventos';

  @override
  String get savedAttractions => 'Atrações salvas';

  @override
  String get savedAttractionsSubtitle =>
      'Locais a visitar independentemente dos eventos';

  @override
  String get savedBusinesses => 'Negócios salvos';

  @override
  String get savedBusinessesSubtitle => 'Empresas de alimentos que você marcou';

  @override
  String get savedItemsUnavailableTitle => 'Itens salvos indisponíveis';

  @override
  String get savedItemsUnavailableSubtitle =>
      'Alguns itens salvos não são mais publicados no feed de descoberta.';

  @override
  String get retryAction => 'Tentar novamente';

  @override
  String get unableToLoadDiscover =>
      'Não é possível carregar os itens descobertos no momento. Por favor, tente novamente.';

  @override
  String get unableToLoadSaved =>
      'Não é possível carregar os itens salvos no momento. Por favor, tente novamente.';

  @override
  String get dateTBA => 'Data a definir';

  @override
  String get timeTBA => 'Horário a definir';

  @override
  String get untitledEvent => 'Evento sem título';

  @override
  String get locationTBA => 'Localização a definir';

  @override
  String get priceTBA => 'Preço a definir';

  @override
  String get placeFallback => 'Lugar';

  @override
  String get foodExperienceFallback => 'Experiência Alimentar';

  @override
  String get stadiumFallback => 'Estádio';

  @override
  String get eventFallback => 'Evento';

  @override
  String get attractionFallback => 'Atração';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count comentários';
  }

  @override
  String get approved => 'Aprovado';

  @override
  String get audience => 'Público';

  @override
  String get businessLabel => 'Negócios';

  @override
  String get controlDistance =>
      'Controle a distância para oportunidades próximas';

  @override
  String get dashboard => 'Painel';

  @override
  String get delete => 'Excluir';

  @override
  String get deleteEvent => 'Excluir evento';

  @override
  String get deletingEvent => 'Excluindo evento...';

  @override
  String get displayName => 'Nome de exibição';

  @override
  String errorDeletingEvent(String error) {
    return 'Erro ao excluir evento: $error';
  }

  @override
  String errorLoadingMap(String error) {
    return 'Erro ao carregar o mapa: $error';
  }

  @override
  String eventDeleted(String title) {
    return 'O evento \"$title\" foi excluído.';
  }

  @override
  String get failedToDeleteEvent =>
      'Falha ao excluir evento. Por favor, tente novamente.';

  @override
  String get feed => 'Alimentação';

  @override
  String get localBusinessPortal => 'Portal de negócios locais';

  @override
  String get pending => 'Pendente';

  @override
  String get phoneNumber => 'Número de telefone';

  @override
  String get pleaseLoginLocal => 'Faça login como usuário local primeiro.';

  @override
  String get pleaseLoginToDelete => 'Faça login para excluir eventos.';

  @override
  String get pushAlerts => 'Alertas push para o seu negócio';

  @override
  String get rejected => 'Rejeitado';

  @override
  String get reviews => 'Avaliações';

  @override
  String get saveChanges => 'Salvar alterações';

  @override
  String get searchHintEvents => 'Pesquisar eventos, reservas...';

  @override
  String get suburb => 'Subúrbio';

  @override
  String get thisLinkUnavailable => 'Este link não está disponível no momento.';

  @override
  String get total => 'Total';

  @override
  String get couldNotSaveSettings =>
      'Não foi possível salvar as configurações. Por favor, tente novamente.';

  @override
  String get locationAccessDisabled =>
      'Acesso à localização desativado para recursos do aplicativo.';

  @override
  String get locationPermissionGranted => 'Permissão de localização concedida.';

  @override
  String get openSettings => 'Abra Configurações';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themeLight => 'Luz';

  @override
  String get themeSystem => 'Sistema';

  @override
  String textScalePercent(String value) {
    return '$value%';
  }

  @override
  String categoryLabel(String category) {
    return 'Categoria: $category';
  }

  @override
  String severityLabel(String severity) {
    return 'Gravidade: $severity';
  }

  @override
  String get languageEnglish => 'Inglês';

  @override
  String get languageSpanish => 'Espanhol';

  @override
  String get languageFrench => 'Francês';

  @override
  String get languageGerman => 'Alemão';

  @override
  String get languageChinese => 'Chinês';

  @override
  String get languageArabic => 'Árabe';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageJapanese => 'Japonês';

  @override
  String get languageKorean => 'Coreano';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageRussian => 'Russo';

  @override
  String get languageVietnamese => 'Vietnamita';

  @override
  String get languageGreek => 'Grego';

  @override
  String get discoverTitle => 'Descubra comida local';

  @override
  String get openSourceLink => 'Link de código aberto';

  @override
  String get pendingApproval => 'Aprovação pendente';

  @override
  String deleteEventConfirmation(String title) {
    return 'Tem certeza de que deseja excluir \"$title\"? ';
  }

  @override
  String get myActivity => 'Minha atividade';

  @override
  String get businessNotifications => 'Notificações comerciais';

  @override
  String get about => 'Sobre';

  @override
  String get aboutDescription =>
      'BrisConnect+ é um guia de cidade inteligente que ajuda visitantes e moradores locais a descobrir eventos, explorar atrações e capturar suas experiências em Brisbane em uma plataforma conectada.';

  @override
  String versionLabel(String version) {
    return 'Versão $version';
  }

  @override
  String get locationPermissions => 'Permissões de localização';

  @override
  String get enableLocationAccess => 'Habilitar acesso ao local';

  @override
  String get allowNearbyMapFeatures =>
      'Permitir recomendações próximas e recursos de reconhecimento de mapa.';

  @override
  String get locationSettings => 'Configurações de localização';

  @override
  String get setSearchRadius =>
      'Defina seu raio de pesquisa para eventos e atrações.';

  @override
  String get pleaseLoginToViewSettings =>
      'Faça login para ver as configurações.';

  @override
  String get locationPermissionNotGranted =>
      'A permissão de localização não foi concedida. Você pode habilitá-lo nas configurações do sistema.';

  @override
  String get theme => 'Tema';

  @override
  String get appTheme => 'Tema do aplicativo';

  @override
  String get chooseHowAppLooks => 'Escolha a aparência do aplicativo.';

  @override
  String get textSize => 'Tamanho do texto';

  @override
  String get adjustTextSize => 'Ajuste o tamanho do texto no aplicativo.';

  @override
  String get smaller => 'Menor';

  @override
  String get larger => 'Maior';

  @override
  String get support => 'Apoiar';

  @override
  String get sendAppFeedback => 'Enviar feedback sobre o aplicativo';

  @override
  String get reportBugsImprovements =>
      'Relate bugs, informações enganosas ou sugestões de melhorias.';

  @override
  String get noFeedbackYet => 'Você ainda não enviou nenhum feedback.';

  @override
  String get adminResponse => 'Resposta do administrador';

  @override
  String get awaitingAdminResponse => 'Aguardando resposta do administrador...';

  @override
  String get statusPending => 'Pendente';

  @override
  String get statusInProgress => 'Em andamento';

  @override
  String get statusResolved => 'Resolvido';

  @override
  String get statusWontFix => 'Não vou consertar';
}
