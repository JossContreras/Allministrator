/// Identificador serializable cuyo valor debe ser un UUID.
///
/// La generación y validación pertenecen a las capas que crean o persisten
/// entidades, no al dominio declarativo.
typedef Uuid = String;

/// Estructura preparada para valores JSON que persistan los adaptadores.
typedef JsonMap = Map<String, Object?>;
