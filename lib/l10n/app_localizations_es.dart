// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'Bienvenido';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signUp => 'Registrarse';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get phone => 'Teléfono';

  @override
  String get name => 'Nombre';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get profileInfo => 'Información del perfil';

  @override
  String get preferences => 'Preferencias';

  @override
  String get language => 'Idioma';

  @override
  String get locationRadius => 'Radio de ubicación';

  @override
  String get appearanceSettings => 'Apariencia';

  @override
  String get feedback => 'Comentarios';

  @override
  String get myFeedback => 'Mis comentarios';

  @override
  String get helpAndSupport => 'Ayuda y soporte';

  @override
  String get discover => 'Descubrir';

  @override
  String get community => 'Comunidad';

  @override
  String get map => 'Mapa';

  @override
  String get saved => 'Guardado';

  @override
  String get profile => 'Perfil';

  @override
  String get food => 'Comida';

  @override
  String get events => 'Eventos';

  @override
  String get businesses => 'Negocios';

  @override
  String get promotions => 'Promociones';

  @override
  String get photos => 'Fotos';

  @override
  String get newPost => 'Nuevo';

  @override
  String get search => 'Buscar';

  @override
  String get filter => 'Filtrar';

  @override
  String get clearFilters => 'Borrar filtros';

  @override
  String get noResults => 'No se encontraron resultados';

  @override
  String get loading => 'Cargando...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Éxito';

  @override
  String get profileUpdated => 'Perfil actualizado con éxito.';

  @override
  String get profileUpdateFailed =>
      'No se pudo actualizar el perfil. Inténtalo de nuevo.';

  @override
  String get guestVisitor => 'Visitante invitado';

  @override
  String get localUser => 'Local';

  @override
  String get filterEventsTitle => 'Filtrar eventos';

  @override
  String get priceLabel => 'Precio';

  @override
  String get dateLabel => 'Fecha';

  @override
  String get pickADate => 'Elige una fecha';

  @override
  String get resetButton => 'Reiniciar';

  @override
  String get applyButton => 'Aplicar';

  @override
  String get freeLabel => 'Gratis';

  @override
  String get paidLabel => 'Pagado';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle guardado como Interesado.';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return '$eventTitle eliminado de Interesado.';
  }

  @override
  String savedToAttractions(String title) {
    return '$title guardado en Atracciones guardadas.';
  }

  @override
  String removedFromAttractions(String title) {
    return '$title eliminado de las atracciones guardadas.';
  }

  @override
  String get pleaseSignInToSaveEvents =>
      'Inicie sesión como visitante para guardar eventos.';

  @override
  String get pleaseSignInToReview =>
      'Inicie sesión para escribir una reseña o BuzzVote.';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return '¡Revisión enviada! ⭐ $rating / Buzz ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return 'No se pudo enviar la reseña: $error';
  }

  @override
  String get noExternalLink =>
      'Aún no hay ningún enlace externo disponible para este artículo.';

  @override
  String get unableToOpenLink =>
      'No se puede abrir el enlace del evento en este momento.';

  @override
  String shareTitle(String title) {
    return 'Compartir: $title';
  }

  @override
  String get reportEvent => 'Informar evento';

  @override
  String get reviewsOnlyForFood =>
      'Las reseñas solo están disponibles para alimentos.';

  @override
  String get chooseFromGallery => 'Elige de la galería';

  @override
  String get takeAPhoto => 'tomar una foto';

  @override
  String get pleaseLoginVisitor => 'Primero inicie sesión como visitante.';

  @override
  String get onlyJpgPng => 'Sólo se admiten imágenes JPG y PNG.';

  @override
  String get imageTooLarge =>
      'La imagen es demasiado grande. Elija una imagen más pequeña.';

  @override
  String get profilePictureUpdated =>
      'Imagen de perfil actualizada correctamente.';

  @override
  String get profilePictureUpdateFailed =>
      'No se pudo actualizar la foto de perfil. Por favor inténtalo de nuevo.';

  @override
  String get enterYourName => 'Introduce tu nombre';

  @override
  String get phoneHint => 'por ej. 04xxxxxxxxx';

  @override
  String get nameCannotBeEmpty => 'El nombre no puede estar vacío.';

  @override
  String get nameMinLength => 'El nombre debe tener al menos 2 caracteres.';

  @override
  String get enterValidPhone => 'Ingrese un número de teléfono válido.';

  @override
  String get changeProfilePicture => 'Cambiar foto de perfil';

  @override
  String get uploadProfilePicture => 'Subir foto de perfil';

  @override
  String get areYouSureSignOut => '¿Estás seguro de que deseas cerrar sesión?';

  @override
  String get returnWelcome => 'Volver a la pantalla de bienvenida';

  @override
  String get setHowFarRecommendations =>
      'Establecer hasta qué punto pueden llegar las recomendaciones';

  @override
  String get themeTextSizeFeedback => 'Tema, tamaño del texto y comentarios';

  @override
  String get faqsContactAppInfo =>
      'Preguntas frecuentes, contáctenos e información de la aplicación';

  @override
  String get viewSubmittedFeedback =>
      'Ver los comentarios enviados y las respuestas del administrador';

  @override
  String get discoverSubtitle =>
      'Descubra la comida y las experiencias locales.';

  @override
  String get searchHintLocalFood => 'Buscar negocios de comida locales...';

  @override
  String get homeLabel => 'Inicio';

  @override
  String get recommendedForYou => 'Recomendado para ti';

  @override
  String get seeAll => 'Ver todo';

  @override
  String get categories => 'Categorías';

  @override
  String get nearby => 'cerca';

  @override
  String get noFoodPlacesFound => 'No se encontraron lugares de comida';

  @override
  String get noFoodPlacesSubtitle =>
      'Intente cambiar sus selecciones de búsqueda o filtro.';

  @override
  String get localFoodBusinesses => 'Empresas de alimentos locales';

  @override
  String get localFoodSubtitle =>
      'Apoyar a las pequeñas y medianas empresas alimentarias de Brisbane';

  @override
  String get exploreReviewFoodBusinesses =>
      'Explorar y revisar empresas alimentarias';

  @override
  String get noSavedItemsTitle => 'Aún no hay elementos guardados';

  @override
  String get noSavedItemsSubtitle =>
      'Toque el ícono del corazón en las tarjetas de presentación de alimentos o el marcador en un perfil comercial para guardarlas aquí.';

  @override
  String get savedEvents => 'Eventos guardados';

  @override
  String get savedEventsSubtitle => 'Sus recordatorios y planes de eventos';

  @override
  String get savedAttractions => 'Atracciones guardadas';

  @override
  String get savedAttractionsSubtitle =>
      'Lugares para visitar independientemente de los eventos.';

  @override
  String get savedBusinesses => 'Negocios salvados';

  @override
  String get savedBusinessesSubtitle =>
      'Empresas de alimentación que has marcado como favoritas';

  @override
  String get savedItemsUnavailableTitle => 'Artículos guardados no disponibles';

  @override
  String get savedItemsUnavailableSubtitle =>
      'Algunos elementos guardados ya no se publican en el feed de descubrimiento.';

  @override
  String get retryAction => 'Reintentar';

  @override
  String get unableToLoadDiscover =>
      'No se pueden cargar elementos de descubrimiento en este momento. Por favor inténtalo de nuevo.';

  @override
  String get unableToLoadSaved =>
      'No se pueden cargar elementos guardados en este momento. Por favor inténtalo de nuevo.';

  @override
  String get dateTBA => 'Fecha por determinar';

  @override
  String get timeTBA => 'Hora por determinar';

  @override
  String get untitledEvent => 'Evento sin título';

  @override
  String get locationTBA => 'Ubicación por determinar';

  @override
  String get priceTBA => 'Precio por determinar';

  @override
  String get placeFallback => 'Lugar';

  @override
  String get foodExperienceFallback => 'Experiencia gastronómica';

  @override
  String get stadiumFallback => 'Estadio';

  @override
  String get eventFallback => 'Evento';

  @override
  String get attractionFallback => 'Atracción';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count reseñas';
  }

  @override
  String get approved => 'Aprobado';

  @override
  String get audience => 'Audiencia';

  @override
  String get businessLabel => 'Negocios';

  @override
  String get controlDistance =>
      'Controlar la distancia para oportunidades cercanas';

  @override
  String get dashboard => 'Panel de control';

  @override
  String get delete => 'Eliminar';

  @override
  String get deleteEvent => 'Eliminar evento';

  @override
  String get deletingEvent => 'Eliminando evento...';

  @override
  String get displayName => 'Nombre para mostrar';

  @override
  String errorDeletingEvent(String error) {
    return 'Error al eliminar evento: $error';
  }

  @override
  String errorLoadingMap(String error) {
    return 'Error al cargar el mapa: $error';
  }

  @override
  String eventDeleted(String title) {
    return 'Se ha eliminado el evento \"$title\".';
  }

  @override
  String get failedToDeleteEvent =>
      'No se pudo eliminar el evento. Por favor inténtalo de nuevo.';

  @override
  String get feed => 'alimentar';

  @override
  String get localBusinessPortal => 'portal de negocios locales';

  @override
  String get pending => 'Pendiente';

  @override
  String get phoneNumber => 'Número de teléfono';

  @override
  String get pleaseLoginLocal => 'Primero inicie sesión como usuario local.';

  @override
  String get pleaseLoginToDelete => 'Inicie sesión para eliminar eventos.';

  @override
  String get pushAlerts => 'Alertas push para tu negocio';

  @override
  String get rejected => 'Rechazado';

  @override
  String get reviews => 'Reseñas';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get searchHintEvents => 'Buscar eventos, reservas...';

  @override
  String get suburb => 'suburbio';

  @override
  String get thisLinkUnavailable =>
      'Este enlace no está disponible en este momento.';

  @override
  String get total => 'totales';

  @override
  String get couldNotSaveSettings =>
      'No se pudo guardar la configuración. Por favor inténtalo de nuevo.';

  @override
  String get locationAccessDisabled =>
      'Acceso a la ubicación deshabilitado para las funciones de la aplicación.';

  @override
  String get locationPermissionGranted => 'Permiso de ubicación concedido.';

  @override
  String get openSettings => 'Abrir configuración';

  @override
  String get themeDark => 'oscuro';

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
    return 'Categoría: $category';
  }

  @override
  String severityLabel(String severity) {
    return 'Gravedad: $severity';
  }

  @override
  String get languageEnglish => 'ingles';

  @override
  String get languageSpanish => 'español';

  @override
  String get languageFrench => 'francés';

  @override
  String get languageGerman => 'alemán';

  @override
  String get languageChinese => 'chino';

  @override
  String get languageArabic => 'árabe';

  @override
  String get languageHindi => 'hindi';

  @override
  String get languageItalian => 'italiano';

  @override
  String get languageJapanese => 'japonés';

  @override
  String get languageKorean => 'coreano';

  @override
  String get languagePortuguese => 'portugués';

  @override
  String get languageRussian => 'ruso';

  @override
  String get languageVietnamese => 'vietnamita';

  @override
  String get languageGreek => 'griego';

  @override
  String get discoverTitle => 'Descubra la comida local';

  @override
  String get openSourceLink => 'Enlace de código abierto';

  @override
  String get pendingApproval => 'Pendiente de aprobación';

  @override
  String deleteEventConfirmation(String title) {
    return '¿Está seguro de que desea eliminar \"$title\"? ';
  }

  @override
  String get myActivity => 'Mi actividad';

  @override
  String get businessNotifications => 'Notificaciones comerciales';

  @override
  String get about => 'Acerca de';

  @override
  String get aboutDescription =>
      'BrisConnect+ es una guía de ciudad inteligente que ayuda a visitantes y lugareños a descubrir eventos, explorar atracciones y capturar sus experiencias de Brisbane en una plataforma conectada.';

  @override
  String versionLabel(String version) {
    return 'Versión $version';
  }

  @override
  String get locationPermissions => 'Permisos de ubicación';

  @override
  String get enableLocationAccess => 'Habilitar acceso a la ubicación';

  @override
  String get allowNearbyMapFeatures =>
      'Permita recomendaciones cercanas y funciones de reconocimiento de mapas.';

  @override
  String get locationSettings => 'Configuración de ubicación';

  @override
  String get setSearchRadius =>
      'Establezca su radio de búsqueda para eventos y atracciones.';

  @override
  String get pleaseLoginToViewSettings =>
      'Inicie sesión para ver la configuración.';

  @override
  String get locationPermissionNotGranted =>
      'No se concedió el permiso de ubicación. Puede habilitarlo en la configuración del sistema.';

  @override
  String get theme => 'Tema';

  @override
  String get appTheme => 'Tema de la aplicación';

  @override
  String get chooseHowAppLooks => 'Elige cómo se ve la aplicación.';

  @override
  String get textSize => 'Tamaño del texto';

  @override
  String get adjustTextSize =>
      'Ajuste el tamaño del texto en toda la aplicación.';

  @override
  String get smaller => 'Menor';

  @override
  String get larger => 'Más grande';

  @override
  String get support => 'Apoyo';

  @override
  String get sendAppFeedback => 'Enviar comentarios sobre la aplicación';

  @override
  String get reportBugsImprovements =>
      'Informar errores, información engañosa o sugerencias de mejora.';

  @override
  String get noFeedbackYet => 'Aún no has enviado ningún comentario.';

  @override
  String get adminResponse => 'Respuesta del administrador';

  @override
  String get awaitingAdminResponse =>
      'Esperando respuesta del administrador...';

  @override
  String get statusPending => 'Pendiente';

  @override
  String get statusInProgress => 'En curso';

  @override
  String get statusResolved => 'Resuelto';

  @override
  String get statusWontFix => 'No se arreglará';

  @override
  String get foodBusinessDetails => 'Detalles del negocio';

  @override
  String get aboutThisFoodExperience =>
      'Acerca de esta experiencia gastronómica';

  @override
  String get highlights => 'Destacados';

  @override
  String get contactAndLinks => 'Contacto y enlaces';

  @override
  String get gallery => 'Galería';

  @override
  String get openingHours => 'Horario de apertura';

  @override
  String get menu => 'Menú';

  @override
  String get menuFallback => 'Menú';

  @override
  String get call => 'Llamar';

  @override
  String get website => 'Sitio web';

  @override
  String get orderOnline => 'Ordenar en línea';

  @override
  String get viewOnMap => 'Ver en el mapa';

  @override
  String get foodDiscoveryGuide => 'Guía de descubrimiento gastronómico';

  @override
  String get foodDiscoveryGuideHelper =>
      'Toca reproducir para escuchar a tu Guía de descubrimiento gastronómico describir este lugar y sus puntos destacados.';

  @override
  String get stop => 'Detener';

  @override
  String get unableToStartNarration =>
      'No se puede iniciar la narración de la Guía de descubrimiento gastronómico en este momento.';

  @override
  String get unableToCallNumber =>
      'No se puede llamar a este número en este momento.';

  @override
  String get unableToSendEmail =>
      'No se puede enviar el correo electrónico en este momento.';

  @override
  String get foodSpotCannotBeShared =>
      'Este lugar gastronómico no se puede compartir en este momento.';

  @override
  String foodDescriptionIntro(String title, String cuisine, String location) {
    return 'Adéntrate en $title, un destino de $cuisine en el corazón de $location.';
  }

  @override
  String foodDescriptionRating(String rating) {
    return 'Amado por lugareños y visitantes por igual, cuenta con una calificación de $rating estrellas.';
  }

  @override
  String foodDescriptionCategories(String categories) {
    return 'El menú celebra $categories, elaborados con ingredientes frescos y de origen local.';
  }

  @override
  String foodDescriptionPrice(String price) {
    return 'Espera una experiencia $price que equilibra calidad y valor.';
  }

  @override
  String foodDescriptionOutro(String title) {
    return 'Ya sea que busques un brunch relajado, un almuerzo de negocios o una cena animada, $title ofrece un ambiente acogedor y sabores que capturan la escena gastronómica de Brisbane.';
  }

  @override
  String foodNarrationWelcome(String title) {
    return 'Bienvenido a $title';
  }

  @override
  String foodNarrationBadge(String badge) {
    return 'Esta es una parada $badge que vale la pena agregar a tu ruta gastronómica de Brisbane';
  }

  @override
  String foodNarrationCuisine(String cuisine) {
    return 'Es mejor conocido por su $cuisine';
  }

  @override
  String foodNarrationLocation(String location) {
    return 'Lo encontrarás en $location, donde la escena gastronómica local cobra vida';
  }

  @override
  String foodNarrationDateTime(String dateTime) {
    return 'Generalmente puedes visitar durante $dateTime';
  }

  @override
  String foodNarrationDescription(String description) {
    return 'Así se siente la experiencia. $description';
  }

  @override
  String get foodNarrationPriceFree =>
      'No hay costo de entrada para explorar este lugar gastronómico';

  @override
  String foodNarrationPrice(String price) {
    return 'El precio se indica como $price';
  }

  @override
  String foodNarrationRating(String rating) {
    return 'Los visitantes actualmente lo califican con $rating de 5';
  }

  @override
  String foodNarrationCategories(String categories) {
    return 'Espera una mezcla de $categories';
  }
}
