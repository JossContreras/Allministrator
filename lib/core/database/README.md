# Database

Contiene el adaptador local de Drift, sus tablas y el punto de migración. El
dominio no depende de Drift ni de ningún detalle de persistencia.

Después de modificar tablas, ejecuta:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Antes de elevar `schemaVersion`, añade una migración explícita para todas las
versiones publicadas.
